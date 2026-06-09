$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "tools\CodexUnifiedSwitcher.ps1"
. $scriptPath -NoUi

$sqlite = Get-Command sqlite3 -ErrorAction SilentlyContinue
if (-not $sqlite) {
    throw "sqlite3 is required for this test"
}

$root = Join-Path $env:TEMP ("codex-unified-no-auth-test-" + [guid]::NewGuid().ToString("N"))
$codexHome = Join-Path $root ".codex"
$appRoot = Join-Path $root "app"
$historyBackupRoot = Join-Path $root "history-sync"
$officialConfig = Join-Path $root "official-config.toml"
$cpamcConfig = Join-Path $root "cpamc-config.toml"

New-Item -ItemType Directory -Path $codexHome -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $codexHome "sessions") -Force | Out-Null

Set-Content -LiteralPath $officialConfig -Encoding UTF8 -Value 'model_provider = "openai"'
Set-Content -LiteralPath $cpamcConfig -Encoding UTF8 -Value @"
model_provider = "CPA"

[model_providers.CPA]
name = "CPA"
"@
Set-Content -LiteralPath (Join-Path $codexHome "config.toml") -Encoding UTF8 -Value (Get-Content -LiteralPath $officialConfig -Raw)
Set-Content -LiteralPath (Join-Path $codexHome "auth.json") -Encoding UTF8 -Value '{"auth_mode":"chatgpt"}'

$rolloutPath = Join-Path $codexHome "sessions\rollout-a.jsonl"
$firstLine = '{"timestamp":"2026-06-08T00:00:00.000Z","type":"session_meta","payload":{"id":"thread-a","cwd":"C:\\Work","source":"cli","model_provider":"openai"}}'
Set-Content -LiteralPath $rolloutPath -Encoding UTF8 -Value $firstLine

$dbPath = Join-Path $codexHome "state_5.sqlite"
& $sqlite.Source $dbPath "CREATE TABLE threads(id TEXT PRIMARY KEY, model_provider TEXT, archived INTEGER DEFAULT 0); INSERT INTO threads(id, model_provider, archived) VALUES('thread-a', 'openai', 0);"

try {
    $result = Switch-CodexProfileMode `
        -Target "CPAMC" `
        -CodexHome $codexHome `
        -OfficialConfigPath $officialConfig `
        -CPAMCConfigPath $cpamcConfig `
        -AppRoot $appRoot `
        -HistoryBackupRoot $historyBackupRoot `
        -SkipProcessCheck

    if ($result.TargetProvider -ne "CPA") {
        throw "Expected CPAMC target provider CPA, got $($result.TargetProvider)"
    }
    if (-not $result.PostSync.BackupDir.StartsWith($historyBackupRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Expected history backup under temp history root, got $($result.PostSync.BackupDir)"
    }
    if ((Get-CodexProvider -CodexHome $codexHome) -ne "CPA") {
        throw "Expected config provider CPA after CPAMC switch"
    }
    if (Test-Path -LiteralPath (Join-Path $codexHome "auth.json")) {
        throw "Expected OAuth auth.json to be moved aside when no CPAMC auth profile exists"
    }
    if ((Get-ChildItem -LiteralPath $codexHome -Filter "auth.json.oauth-before-cpamc-*" -ErrorAction SilentlyContinue).Count -lt 1) {
        throw "Expected OAuth auth move-aside file before CPAMC"
    }
    if ((Get-Content -LiteralPath $rolloutPath -Raw) -notmatch '"model_provider"\s*:\s*"CPA"') {
        throw "Expected rollout provider CPA after CPAMC switch"
    }
    $dbProvider = (& $sqlite.Source $dbPath "SELECT model_provider FROM threads WHERE id='thread-a';").Trim()
    if ($dbProvider -ne "CPA") {
        throw "Expected SQLite provider CPA after CPAMC switch, got $dbProvider"
    }

    Write-Host "Codex unified switcher CPAMC without auth checks passed."
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
