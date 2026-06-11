$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptPath = Join-Path $repoRoot "Push-GitHub.bat"

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Missing push script: $scriptPath"
}

$source = Get-Content -LiteralPath $scriptPath -Raw

foreach ($needle in @(
    "title O-C GitHub Sync Tool",
    "set ""ROOT_DIR=%~dp0""",
    "git status -s",
    "set ""msg=",
    "git add .",
    "git -c core.quotepath=false commit -m ""%msg%""",
    "git push",
    "Nothing new to commit, continuing to push existing commits"
)) {
    if (-not $source.Contains($needle)) {
        throw "Push script missing expected behavior: $needle"
    }
}

foreach ($forbidden in @(
    "set /p COMMIT_MSG=",
    "git push origin main"
)) {
    if ($source.Contains($forbidden)) {
        throw "Push script should no longer contain: $forbidden"
    }
}

Write-Host "Push script checks passed."
