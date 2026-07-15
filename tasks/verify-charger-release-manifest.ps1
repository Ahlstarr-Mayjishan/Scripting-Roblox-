$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $root "NULLSCAPE/update_manifest.json"
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$requiredPaths = @(
	"NULLSCAPE/Main UI/master.luau",
	"NULLSCAPE/Class Adjustment/Control.luau",
	"NULLSCAPE/Class Adjustment/Executor.luau",
	"NULLSCAPE/Class Adjustment/tab.luau",
	"NULLSCAPE/Class Adjustment/Charger/Steering Assist.luau",
	"NULLSCAPE/Class Adjustment/Charger/Charge Collision Guard.luau",
	"NULLSCAPE/Class Adjustment/Charger/Charger Assist Context.luau",
	"NULLSCAPE/Class Adjustment/Charger/Charger Assist Hooks.luau",
	"NULLSCAPE/Class Adjustment/Charger/Charger Assist Suite.luau"
)

function Get-NormalizedSha256([string]$Path) {
	$text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
	$bytes = [Text.UTF8Encoding]::new($false).GetBytes($text)
	$hash = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
	return ([BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
}

$entries = @{}
foreach ($entry in $manifest.Files) {
	$entries[$entry.Path] = $entry
}

$failures = 0
foreach ($relativePath in $requiredPaths) {
	$entry = $entries[$relativePath]
	$absolutePath = Join-Path $root $relativePath
	if ($null -eq $entry) {
		Write-Host "FAIL - manifest is missing $relativePath"
		$failures++
		continue
	}
	$actualHash = Get-NormalizedSha256 $absolutePath
	if ($entry.Sha256 -ne $actualHash) {
		Write-Host "FAIL - hash mismatch for $relativePath"
		$failures++
	} else {
		Write-Host "PASS - $relativePath"
	}
}

$tabSource = Get-Content -Raw -LiteralPath (Join-Path $root "NULLSCAPE/Class Adjustment/tab.luau")
if ($tabSource -match "ChargerStatusHUD|Charger Status HUD") {
	Write-Host "FAIL - Charger Status HUD must not be released"
	$failures++
} else {
	Write-Host "PASS - no Charger Status HUD"
}

if ($failures -gt 0) {
	exit 1
}
