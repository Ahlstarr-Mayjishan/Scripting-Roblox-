$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$control = Get-Content -Raw -LiteralPath (Join-Path $root "NULLSCAPE/Class Adjustment/Control.luau")
$executor = Get-Content -Raw -LiteralPath (Join-Path $root "NULLSCAPE/Class Adjustment/Executor.luau")
$tab = Get-Content -Raw -LiteralPath (Join-Path $root "NULLSCAPE/Class Adjustment/tab.luau")
$master = Get-Content -Raw -LiteralPath (Join-Path $root "NULLSCAPE/Main UI/master.luau")
$suitePath = Join-Path $root "NULLSCAPE/Class Adjustment/Charger/Charger Assist Suite.luau"
$suite = if (Test-Path -LiteralPath $suitePath) { Get-Content -Raw -LiteralPath $suitePath } else { "" }
$hooksPath = Join-Path $root "NULLSCAPE/Class Adjustment/Charger/Charger Assist Hooks.luau"
$hooks = if (Test-Path -LiteralPath $hooksPath) { Get-Content -Raw -LiteralPath $hooksPath } else { "" }

$checks = [ordered]@{
	"charge chain toggle is in Charger menu" = $tab -match 'Name\s*=\s*"Charge Chain Assist"'
	"charge chain buffer is configurable" = $tab -match 'Name\s*=\s*"Charge Chain Buffer"[\s\S]*?Range\s*=\s*\{\s*0\.05,\s*0\.5\s*\}'
	"shark tail timing toggle is in Charger menu" = $tab -match 'Name\s*=\s*"Shark Tail Timing Assist"'
	"shark tail window is configurable" = $tab -match 'Name\s*=\s*"Shark Tail Timing Window"[\s\S]*?Range\s*=\s*\{\s*0\.05,\s*0\.6\s*\}'
	"air platform assist is in Charger menu" = $tab -match 'Name\s*=\s*"Air Platform Assist"'
	"long jump guard is in Charger menu" = $tab -match 'Name\s*=\s*"Long Jump Guard"'
	"long jump guard distance is configurable" = $tab -match 'Name\s*=\s*"Long Jump Guard Distance"[\s\S]*?Range\s*=\s*\{\s*8,\s*40\s*\}'
	"all assist settings persist" = $control -match 'ChargerChargeChainAssistToggle' -and $control -match 'ChargerSharkTailTimingAssistToggle' -and $control -match 'ChargerAirPlatformAssistToggle' -and $control -match 'ChargerLongJumpGuardToggle'
	"fresh installs receive safe defaults" = $master -match 'ChargerChargeChainAssistToggle\s*=\s*false' -and $master -match 'ChargerLongJumpGuardToggle\s*=\s*false'
	"executor wires the Charger assist suite" = $executor -match 'ChargerAssistSuite' -and $executor -match 'updateChargerAssistSuite'
	"charge chain is buffered on landing" = $suite -match 'bufferChargeChain'
	"shark tail input is retried in its window" = $suite -match 'retrySharkTail'
	"air platform input release is protected" = $suite -match 'protectAirPlatformInput'
	"unsafe long jumps are guarded" = $suite -match 'guardLongJump'
	"suite restores all hooks" = $hooks -match 'function Hooks\.restore'
}

$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value })
foreach ($check in $checks.GetEnumerator()) {
	$status = if ($check.Value) { "PASS" } else { "FAIL" }
	Write-Host "$status - $($check.Key)"
}

if ($failed.Count -gt 0) {
	throw "$($failed.Count) Charger assist-suite contract check(s) failed."
}
