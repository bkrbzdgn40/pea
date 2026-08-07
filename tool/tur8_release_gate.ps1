param(
  [switch]$UpdateGoldens,
  [switch]$SkipFullSuite,
  [switch]$SkipEmulators
)

$ErrorActionPreference = 'Stop'
$projectId = 'pose-estimation-app-dd06c'
$goldenTest = 'test\features\achievements\presentation\screens\achievements_screen_golden_test.dart'
$goldenDir = 'test\features\achievements\presentation\screens\goldens'

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )

  Write-Host "`n== $Label =="
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed with exit code $LASTEXITCODE."
  }
}

Invoke-Checked 'Flutter analyze' {
  flutter analyze
}

Invoke-Checked 'Tur 8 focused tests' {
  flutter test --no-pub `
    test\app\theme\app_theme_dark_mode_test.dart `
    test\features\achievements `
    test\features\rewards
}

if (-not $SkipFullSuite) {
  Invoke-Checked 'Full Flutter test suite' {
    flutter test --no-pub
  }
}

$goldenArgs = @(
  'test',
  '--no-pub',
  '--dart-define=RUN_GOLDENS=true'
)
if ($UpdateGoldens) {
  $goldenArgs += '--update-goldens'
} elseif (
  -not (Test-Path "$goldenDir\achievements_dark.png") -or
  -not (Test-Path "$goldenDir\reward_history_dark.png")
) {
  throw 'Golden baselines are missing. Run this gate once with -UpdateGoldens and review the generated PNG files.'
}
$goldenArgs += $goldenTest

if ($UpdateGoldens) {
  $goldenLabel = 'Generate/update reward goldens'
} else {
  $goldenLabel = 'Verify reward goldens'
}
Invoke-Checked $goldenLabel {
  flutter @goldenArgs
}

if (-not $SkipEmulators) {
  $env:REQUIRE_FIREBASE_EMULATORS = 'true'
  try {
    Invoke-Checked 'Firebase emulator full-flow contract' {
      firebase emulators:exec `
        --project $projectId `
        --only auth,firestore `
        "flutter test --no-pub test/firestore_rules_test.dart"
    }
  } finally {
    Remove-Item Env:REQUIRE_FIREBASE_EMULATORS -ErrorAction SilentlyContinue
  }
}

Write-Host "`nTur 8 release gate completed successfully."
