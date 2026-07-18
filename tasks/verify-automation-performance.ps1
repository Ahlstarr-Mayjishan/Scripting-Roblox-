$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot

function Read-Source([string]$relativePath) {
	return [IO.File]::ReadAllText((Join-Path $root $relativePath))
}

function Assert-Contains([string]$source, [string]$needle, [string]$message) {
	if (-not $source.Contains($needle)) {
		throw $message
	}
}

function Assert-NotContains([string]$source, [string]$needle, [string]$message) {
	if ($source.Contains($needle)) {
		throw $message
	}
}

$scanner = Read-Source "NULLSCAPE/Automation/Gift Farm/Scanner.luau"
Assert-Contains $scanner "NativeGiftRegistry.getRevision()" "Scanner must be revision-driven."
Assert-Contains $scanner "gch.GiftsByType" "Scanner must use the native GiftsByType index."
Assert-Contains $scanner "SCAN_FRAME_BUDGET" "Scanner must preserve its frame budget."
Assert-Contains $scanner "GiftFarmXpTripcoinMode == true" "Scanner must support normal-only XP + Tripcoin routes."

$upgradeCompletion = Read-Source "NULLSCAPE/Automation/Gift Farm/Upgrade Completion.luau"
Assert-Contains $upgradeCompletion "GetActiveUpgrades" "Upgrade completion must use the server ownership snapshot."
Assert-Contains $upgradeCompletion "definition.MaxStack" "Upgrade completion must require every native stack."
Assert-Contains $upgradeCompletion "resetGame.OnClientEvent" "Upgrade completion must invalidate ownership between runs."
Assert-Contains $upgradeCompletion "stage == math.huge" "Unobtainable native upgrade entries must not block completion."
Assert-NotContains $upgradeCompletion 'ORB_UPGRADE' "Default Orb must not be treated as a shop purchase."
Assert-Contains $upgradeCompletion 'playerCount <= maximumPlayers' "Player-count-limited upgrades must follow their native maximum player rule."
Assert-Contains $upgradeCompletion 'price == nil' "Non-shop upgrades must not block shop completion."
Assert-Contains $upgradeCompletion 'price[difficulty] == nil' "Difficulty-specific missing shop prices must exclude unavailable upgrades."

$xpTripcoin = Read-Source "NULLSCAPE/Automation/Gift Farm/XP Tripcoin Mode.luau"
Assert-Contains $xpTripcoin "All normal gifts collected" "XP + Tripcoin mode must return after normal gifts."
Assert-Contains $xpTripcoin "forceReturn" "XP + Tripcoin mode must not depend on the golden return setting."

$collapse = Read-Source "NULLSCAPE/Automation/Gift Farm/Collapse.luau"
Assert-Contains $collapse "CELL_SIZE" "Collapse tracking must keep its spatial index."
Assert-Contains $collapse "GetInstanceAddedSignal" "Collapse tracking must remain event-driven."

$medal = Read-Source "NULLSCAPE/Automation/Gift Farm/Medal.luau"
Assert-Contains $medal "MedalRegistry.getInstances()" "Medal must use MedalRegistry."
Assert-NotContains $medal "workspace:GetDescendants()" "Medal must not perform repeated workspace scans."

$autoChoose = Read-Source "NULLSCAPE/Automation/Auto Choose Things.luau"
Assert-Contains $autoChoose "ChoiceRegistry.getOrbs()" "Auto Choose must use ChoiceRegistry."

$manifestPath = Join-Path $root "NULLSCAPE/update_manifest.json"
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$required = @(
	"NULLSCAPE/Automation/Choice Registry.luau",
	"NULLSCAPE/Automation/Gift Farm/Medal Registry.luau",
	"NULLSCAPE/Automation/Gift Farm/Native Gift Registry.luau",
	"NULLSCAPE/Automation/Gift Farm/Upgrade Completion.luau",
	"NULLSCAPE/Automation/Gift Farm/XP Tripcoin Mode.luau"
)
$entries = @{}
foreach ($entry in $manifest.Files) {
	$entries[$entry.Path] = $entry
}
$sha = [Security.Cryptography.SHA256]::Create()
foreach ($path in $required) {
	if (-not $entries.ContainsKey($path)) {
		throw "Manifest is missing $path"
	}
	$bytes = [IO.File]::ReadAllBytes((Join-Path $root $path))
	$actual = -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") })
	if ($actual -ne $entries[$path].Sha256) {
		throw "Manifest hash mismatch for $path"
	}
}

Write-Output "PASS - Automation performance invariants"
