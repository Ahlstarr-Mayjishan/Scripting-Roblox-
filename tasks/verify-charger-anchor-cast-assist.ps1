$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$control = Get-Content -Raw -LiteralPath (Join-Path $root "NULLSCAPE/Class Adjustment/Control.luau")
$executor = Get-Content -Raw -LiteralPath (Join-Path $root "NULLSCAPE/Class Adjustment/Executor.luau")
$tab = Get-Content -Raw -LiteralPath (Join-Path $root "NULLSCAPE/Class Adjustment/tab.luau")
$suitePath = Join-Path $root "NULLSCAPE/Class Adjustment/Charger/Anchor Cast Assist.luau"
$suite = ""
if (Test-Path -LiteralPath $suitePath) {
	$suite = Get-Content -Raw -LiteralPath $suitePath
}

$checks = @(
	[pscustomobject]@{ Name = "anchor-cast toggle is in the Charger menu"; Passed = $tab -match 'Name = "Anchor Cast Assist"' }
	[pscustomobject]@{ Name = "anchor-cast timing slider is in the Charger menu"; Passed = $tab -match 'Name = "Anchor Cast Delay"' }
	[pscustomobject]@{ Name = "anchor-cast settings persist"; Passed = $control -match 'ChargerAnchorCastAssistToggle' -and $control -match 'ChargerAnchorCastDelaySlider' }
	[pscustomobject]@{ Name = "anchor-cast has safe defaults"; Passed = $control -match 'ChargerAnchorCastAssistEnabled = false' -and $control -match 'ChargerAnchorCastDelay = 0\.04' }
	[pscustomobject]@{ Name = "executor wires the anchor-cast assist"; Passed = $executor -match 'updateChargerAnchorCastAssist' -and $executor -match 'Anchor Cast Assist\.luau' }
	[pscustomobject]@{ Name = "JumpPad timing waits for a native launch"; Passed = $suite -match 'jumpPadDebounce' -and $suite -match 'AssemblyLinearVelocity' }
	[pscustomobject]@{ Name = "GrapplePoint timing waits for native target state"; Passed = $suite -match 'grapplePoint' }
	[pscustomobject]@{ Name = "native touch is preserved before cast"; Passed = $suite -match 'originalOnHitboxTouch\(' }
	[pscustomobject]@{ Name = "ability pulse uses the native action"; Passed = $suite -match 'SpecialAction' -and $suite -match 'Enum\.UserInputState\.Begin' }
	[pscustomobject]@{ Name = "hook is restorable"; Passed = $suite -match 'function AnchorCastAssist\.stop' }
)

$failed = 0
foreach ($check in $checks) {
	if ($check.Passed) {
		Write-Host "PASS - $($check.Name)"
	} else {
		Write-Host "FAIL - $($check.Name)"
		$failed++
	}
}

if ($failed -gt 0) {
	exit 1
}
