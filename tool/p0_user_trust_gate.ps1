[CmdletBinding()]
param(
    [switch]$IncludeFirestoreRules,
    [switch]$RunFullSuite,
    [string]$FirebaseProjectId = "pose-estimation-app-dd06c"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    Write-Host ""
    Write-Host "== $Label ==" -ForegroundColor Cyan
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

$p0Tests = @(
    "test/features/workout_analysis/presentation/providers/home_dashboard_provider_test.dart",
    "test/features/workout_analysis/presentation/screens/home_screen_test.dart",
    "test/features/workout_analysis/presentation/widgets/home_recent_session_card_test.dart",
    "test/features/workout_analysis/presentation/providers/exercise_score_trend_provider_test.dart",
    "test/features/workout_analysis/presentation/screens/home_exercise_score_trend_test.dart",
    "test/features/workout_analysis/presentation/screens/score_trend_detail_screen_test.dart",
    "test/features/workout_analysis/presentation/formatters/assessment_result_presentation_formatter_test.dart",
    "test/features/workout_analysis/presentation/screens/assessment_selection_screen_test.dart",
    "test/features/workout_analysis/presentation/screens/assessment_live_screen_test.dart",
    "test/features/workout_analysis/domain/models/session_measurement_evidence_test.dart",
    "test/features/workout_analysis/domain/session_measurement_evidence_policy_test.dart",
    "test/features/workout_analysis/domain/session_evidence_eligibility_policy_test.dart",
    "test/features/workout_analysis/application/workout_session_lifecycle_controller_test.dart",
    "test/features/workout_analysis/infrastructure/mappers/workout_session_firestore_mapper_test.dart",
    "test/features/workout_analysis/infrastructure/remote/firestore_session_remote_source_test.dart",
    "test/features/workout_analysis/presentation/screens/workout_summary_screen_test.dart",
    "test/features/workout_analysis/presentation/screens/session_history_screen_test.dart",
    "test/features/workout_analysis/presentation/screens/session_detail_screen_test.dart",
    "test/features/goals/application/goal_progress_calculator_test.dart",
    "test/features/goals/infrastructure/mappers/user_workout_goal_firestore_mapper_test.dart",
    "test/features/goals/infrastructure/repositories/firestore_workout_goal_repository_test.dart",
    "test/features/goals/presentation/providers/goals_provider_test.dart",
    "test/features/goals/presentation/screens/goals_screen_test.dart",
    "test/features/achievements/presentation/providers/achievements_provider_test.dart",
    "test/features/workout_analysis/application/user_data_management_controller_test.dart"
)

try {
    if (-not (Test-Path "pubspec.yaml")) {
        throw "pubspec.yaml was not found. Run the gate from the project repository."
    }

    Invoke-CheckedCommand `
        -Label "P0 analyzer gate" `
        -FilePath "flutter" `
        -Arguments @("analyze", "--no-pub")

    Invoke-CheckedCommand `
        -Label "P0 user-trust test gate" `
        -FilePath "flutter" `
        -Arguments (@("test", "--no-pub") + $p0Tests)

    if ($IncludeFirestoreRules) {
        Write-Host ""
        Write-Host "== Firebase Java runtime gate ==" -ForegroundColor Cyan

        $javaCommand = Get-Command java -ErrorAction Stop
        $javaStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $javaStartInfo.FileName = $javaCommand.Source
        $javaStartInfo.Arguments = "-version"
        $javaStartInfo.UseShellExecute = $false
        $javaStartInfo.RedirectStandardOutput = $true
        $javaStartInfo.RedirectStandardError = $true
        $javaStartInfo.CreateNoWindow = $true

        $javaProcess = [System.Diagnostics.Process]::Start($javaStartInfo)
        $javaStandardOutput = $javaProcess.StandardOutput.ReadToEnd()
        $javaStandardError = $javaProcess.StandardError.ReadToEnd()
        $javaProcess.WaitForExit()

        $javaExitCode = $javaProcess.ExitCode
        $javaVersionText = @(
            $javaStandardError
            $javaStandardOutput
        ) -join [Environment]::NewLine
        $javaVersionText = $javaVersionText.Trim()
        $javaFirstLine = ($javaVersionText -split "`r?`n")[0]

        if ([string]::IsNullOrWhiteSpace($javaFirstLine)) {
            Write-Host "Java version unavailable"
        }
        else {
            Write-Host $javaFirstLine
        }

        $javaVersionMatch = [regex]::Match(
            $javaVersionText,
            'version "(?:1\.)?(\d+)'
        )
        $javaMajorVersion = if ($javaVersionMatch.Success) {
            [int]$javaVersionMatch.Groups[1].Value
        }
        else {
            0
        }

        if ($javaExitCode -ne 0 -or $javaMajorVersion -lt 21) {
            throw "Firebase Java runtime gate requires Java 21 or newer."
        }

        $previousRequirement = $env:REQUIRE_FIREBASE_EMULATORS
        $env:REQUIRE_FIREBASE_EMULATORS = "true"
        try {
            Invoke-CheckedCommand `
                -Label "P0 Firestore rules gate" `
                -FilePath "firebase.cmd" `
                -Arguments @(
                    "emulators:exec",
                    "--project",
                    $FirebaseProjectId,
                    "--only",
                    "auth,firestore",
                    "flutter test --no-pub test/firestore_rules_test.dart"
                )
        }
        finally {
            if ($null -eq $previousRequirement) {
                Remove-Item Env:REQUIRE_FIREBASE_EMULATORS `
                    -ErrorAction SilentlyContinue
            }
            else {
                $env:REQUIRE_FIREBASE_EMULATORS = $previousRequirement
            }
        }
    }

    if ($RunFullSuite) {
        Invoke-CheckedCommand `
            -Label "Full regression suite" `
            -FilePath "flutter" `
            -Arguments @("test", "--no-pub")
    }

    Write-Host ""
    Write-Host "P0 USER TRUST GATE: PASSED" -ForegroundColor Green
    Write-Host "Market mode work is intentionally excluded by product decision."
}
finally {
    Pop-Location
}
