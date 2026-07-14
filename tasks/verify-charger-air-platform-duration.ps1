$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$control = Get-Content -Raw -LiteralPath (Join-Path $root "NULLSCAPE/Class Adjustment/Control.luau")
$executor = Get-Content -Raw -LiteralPath (Join-Path $root "NULLSCAPE/Class Adjustment/Executor.luau")
$tab = Get-Content -Raw -LiteralPath (Join-Path $root "NULLSCAPE/Class Adjustment/tab.luau")
$master = Get-Content -Raw -LiteralPath (Join-Path $root "NULLSCAPE/Main UI/master.luau")

$checks = [ordered]@{
	"default duration is native" = $control -match 'ChargerAirPlatformDuration\s*=\s*1'
	"saved duration is clamped" = $control -match 'ChargerAirPlatformDurationSlider[\s\S]*?math\.clamp[\s\S]*?1,[\s\S]*?10'
	"setter updates executor" = $control -match 'SetChargerAirPlatformDuration[\s\S]*?updateChargerAirPlatformDuration'
	"executor supports native reset" = $executor -match 'ChargerAirPlatformDuration[\s\S]*?restore'
	"executor recognizes Charge module" = $executor -match 'FindFirstChild\("Charge"\)'
	"timer override is scoped to the native call thread" = $executor -match 'ActiveThreads\[activeThread\]'
	"frame timer has a restorable constant fallback" = $executor -match 'ConstantPatches[\s\S]*?MiniatureHourglass[\s\S]*?setconstant'
	"slider uses seconds from one to ten" = $tab -match 'Name\s*=\s*"Air Platform Duration"[\s\S]*?Range\s*=\s*\{\s*1,\s*10\s*\}[\s\S]*?Suffix\s*=\s*"s"'
	"fresh installs default to native duration" = $master -match 'ChargerAirPlatformDurationSlider\s*=\s*1'
}

$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value })
foreach ($check in $checks.GetEnumerator()) {
	$status = if ($check.Value) { "PASS" } else { "FAIL" }
	Write-Host "$status - $($check.Key)"
}

if ($failed.Count -gt 0) {
	throw "$($failed.Count) Charger air-platform duration contract check(s) failed."
}
