param(
    [switch]$NoUi
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function U($text) {
    return [System.Text.RegularExpressions.Regex]::Unescape($text)
}

function Get-DefaultSettingsPath {
    $appData = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
    if ([string]::IsNullOrWhiteSpace($appData)) {
        $appData = Join-Path $env:USERPROFILE "AppData\Roaming"
    }
    return (Join-Path (Join-Path $appData "C-O") "settings.json")
}

function Get-AppRootFromBackupRoot($BackupRoot) {
    if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
        $BackupRoot = $Script:DefaultBackupRoot
    }
    return (Join-Path $BackupRoot "codex-switch")
}

function Get-HistoryBackupRootFromBackupRoot($BackupRoot) {
    if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
        $BackupRoot = $Script:DefaultBackupRoot
    }
    return (Join-Path $BackupRoot "history-sync")
}

$Script:DefaultCodexHome = Join-Path $env:USERPROFILE ".codex"
$Script:DefaultBackupRoot = "D:\codex-back"
$Script:DefaultAppRoot = Join-Path $Script:DefaultBackupRoot "codex-switch"
$Script:DefaultHistoryBackupRoot = Join-Path $Script:DefaultBackupRoot "history-sync"
$Script:DefaultSettingsPath = Get-DefaultSettingsPath
$Script:Title = U "\u0043\u006f\u0064\u0065\u0078 \u6a21\u5f0f\u5207\u6362\u5de5\u5177"
$Script:UiVersion = "RefinedUiV3"
$Script:UiShellVersion = "AcrylicSidebarUiV1"
$Script:UiSurfaceVersion = "SolidDashboardUiV1"
$Script:UiReferenceVersion = "SettingsPanelInspiredUiV1"
$Script:UiCardVersion = "NetcattyCardUiV1"
$Script:UiBackplateVersion = "AcrylicBackplateUiV1"

function Get-DefaultOfficialConfigPath {
    return "D:\" + [char]0x4f18 + [char]0x5316 + "\Team" + [char]0x6e90 + [char]0x6587 + [char]0x4ef6 + "\config.toml"
}

function Get-DefaultCPAMCConfigPath {
    return "D:\" + [char]0x4f18 + [char]0x5316 + "\CPA" + [char]0x6e90 + [char]0x6587 + [char]0x4ef6 + "\config.toml"
}

function Ensure-SwitcherDirs($AppRoot = $Script:DefaultAppRoot) {
    foreach ($path in @(
        $AppRoot,
        (Join-Path $AppRoot "profiles"),
        (Join-Path $AppRoot "profiles\official"),
        (Join-Path $AppRoot "profiles\cpamc"),
        (Join-Path $AppRoot "backups")
    )) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function Load-SwitcherSettings($SettingsPath = $Script:DefaultSettingsPath) {
    $settings = [ordered]@{
        officialConfigPath = Get-DefaultOfficialConfigPath
        cpamcConfigPath = Get-DefaultCPAMCConfigPath
        codexHome = $Script:DefaultCodexHome
        backupRoot = $Script:DefaultBackupRoot
    }

    $sourcePath = $SettingsPath
    $legacyPath = Join-Path $Script:DefaultAppRoot "unified-settings.json"
    if (-not (Test-Path -LiteralPath $sourcePath) -and (Test-Path -LiteralPath $legacyPath)) {
        $sourcePath = $legacyPath
    }

    if (Test-Path -LiteralPath $sourcePath) {
        try {
            $loaded = Get-Content -LiteralPath $sourcePath -Raw | ConvertFrom-Json
            foreach ($name in @("officialConfigPath", "cpamcConfigPath", "codexHome", "backupRoot")) {
                if ($loaded.$name) {
                    $settings[$name] = [string]$loaded.$name
                }
            }
        } catch {}
    }

    return [PSCustomObject]$settings
}

function Save-SwitcherSettings($Settings, $SettingsPath = $Script:DefaultSettingsPath) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $SettingsPath) -Force | Out-Null
    $Settings | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $SettingsPath -Encoding UTF8
}

function Get-CodexProvider($CodexHome = $Script:DefaultCodexHome) {
    $configPath = Join-Path $CodexHome "config.toml"
    if (-not (Test-Path -LiteralPath $configPath)) { return "missing" }

    foreach ($line in Get-Content -LiteralPath $configPath -ErrorAction Stop) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }
        if ($trimmed.StartsWith("[")) {
            break
        }
        $match = [regex]::Match($trimmed, '^model_provider\s*=\s*"([^"]+)"\s*$')
        if ($match.Success) {
            return $match.Groups[1].Value
        }
    }

    return "openai"
}

function Get-CodexAuthMode($CodexHome = $Script:DefaultCodexHome) {
    $authPath = Join-Path $CodexHome "auth.json"
    if (-not (Test-Path -LiteralPath $authPath)) { return "missing" }
    try {
        $auth = Get-Content -LiteralPath $authPath -Raw | ConvertFrom-Json
        if ($auth.auth_mode) { return [string]$auth.auth_mode }
    } catch {}
    return "unknown"
}

function Backup-ActiveAuthConfig(
    $CodexHome = $Script:DefaultCodexHome,
    $AppRoot = $Script:DefaultAppRoot
) {
    Ensure-SwitcherDirs $AppRoot
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backup = Join-Path (Join-Path $AppRoot "backups") "auth-config-$stamp"
    New-Item -ItemType Directory -Path $backup -Force | Out-Null

    foreach ($name in @("auth.json", "config.toml")) {
        $path = Join-Path $CodexHome $name
        if (Test-Path -LiteralPath $path) {
            Copy-Item -LiteralPath $path -Destination (Join-Path $backup $name) -Force
        }
    }

    return $backup
}

function Save-ModeProfile(
    [ValidateSet("official", "cpamc")] $ProfileName,
    $CodexHome = $Script:DefaultCodexHome,
    $AppRoot = $Script:DefaultAppRoot
) {
    Ensure-SwitcherDirs $AppRoot
    $profilePath = Join-Path (Join-Path $AppRoot "profiles") $ProfileName
    New-Item -ItemType Directory -Path $profilePath -Force | Out-Null

    foreach ($name in @("auth.json", "config.toml")) {
        $source = Join-Path $CodexHome $name
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $profilePath $name) -Force
        }
    }

    return $profilePath
}

function Save-CurrentModeProfile(
    $CodexHome = $Script:DefaultCodexHome,
    $AppRoot = $Script:DefaultAppRoot
) {
    $provider = Get-CodexProvider $CodexHome
    if ($provider -eq "openai" -or $provider -eq "missing") {
        return Save-ModeProfile -ProfileName "official" -CodexHome $CodexHome -AppRoot $AppRoot
    }
    if ($provider -eq "CPA" -or $provider -eq "CPAMC") {
        return Save-ModeProfile -ProfileName "cpamc" -CodexHome $CodexHome -AppRoot $AppRoot
    }
    return $null
}

function Close-CodexIfRunning {
    $processes = Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ProcessName -ieq "codex" -or
            $_.ProcessName -ieq "Codex" -or
            $_.ProcessName -ieq "Codex (Beta)"
        }

    if (-not $processes) { return }

    $message = U "\u68c0\u6d4b\u5230 Codex \u6b63\u5728\u8fd0\u884c\u3002\u5207\u6362\u524d\u9700\u8981\u5148\u5173\u95ed\uff0c\u662f\u5426\u73b0\u5728\u5173\u95ed\uff1f"
    $result = [System.Windows.Forms.MessageBox]::Show($message, $Script:Title, "YesNo", "Question")
    if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
        throw (U "\u5df2\u53d6\u6d88\uff1aCodex \u4ecd\u5728\u8fd0\u884c\u3002")
    }

    $processes | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

function Read-FirstLineRecord($Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $lfIndex = [Array]::IndexOf($bytes, [byte]10)
    if ($lfIndex -lt 0) {
        $lineLength = $bytes.Length
        $separator = ""
        $restOffset = $bytes.Length
    } else {
        $lineLength = $lfIndex
        $separator = "`n"
        if ($lineLength -gt 0 -and $bytes[$lineLength - 1] -eq [byte]13) {
            $lineLength -= 1
            $separator = "`r`n"
        }
        $restOffset = $lfIndex + 1
    }

    $firstLine = [System.Text.Encoding]::UTF8.GetString($bytes, 0, $lineLength).TrimStart([char]0xFEFF)
    return [PSCustomObject]@{
        Bytes = $bytes
        FirstLine = $firstLine
        Separator = $separator
        RestOffset = $restOffset
    }
}

function Rewrite-FirstLine($Path, $Record, $NextFirstLine) {
    $lastWrite = [System.IO.File]::GetLastWriteTimeUtc($Path)
    $head = [System.Text.Encoding]::UTF8.GetBytes($NextFirstLine + $Record.Separator)
    if ($Record.RestOffset -lt $Record.Bytes.Length) {
        $restLength = $Record.Bytes.Length - $Record.RestOffset
        $rest = New-Object byte[] $restLength
        [Array]::Copy($Record.Bytes, $Record.RestOffset, $rest, 0, $restLength)
        $next = New-Object byte[] ($head.Length + $rest.Length)
        [Array]::Copy($head, 0, $next, 0, $head.Length)
        [Array]::Copy($rest, 0, $next, $head.Length, $rest.Length)
    } else {
        $next = $head
    }
    [System.IO.File]::WriteAllBytes($Path, $next)
    [System.IO.File]::SetLastWriteTimeUtc($Path, $lastWrite)
}

function Get-RelativeBackupPath($BasePath, $ChildPath) {
    $baseFull = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $childFull = [System.IO.Path]::GetFullPath($ChildPath)
    if ($childFull.StartsWith($baseFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $childFull.Substring($baseFull.Length)
    }
    return ($childFull -replace '[:\\\/]+', '_')
}

function Get-RolloutProviderChanges($CodexHome, $TargetProvider) {
    $changes = New-Object System.Collections.Generic.List[object]
    foreach ($dirName in @("sessions", "archived_sessions")) {
        $root = Join-Path $CodexHome $dirName
        if (-not (Test-Path -LiteralPath $root)) { continue }

        foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter "rollout-*.jsonl" -ErrorAction SilentlyContinue) {
            $record = Read-FirstLineRecord $file.FullName
            if ([string]::IsNullOrWhiteSpace($record.FirstLine)) { continue }
            try {
                $json = $record.FirstLine | ConvertFrom-Json
            } catch {
                continue
            }
            if ($json.type -ne "session_meta" -or -not $json.payload) { continue }

            $currentProvider = [string]$json.payload.model_provider
            if ([string]::IsNullOrWhiteSpace($currentProvider)) {
                $currentProvider = "(missing)"
            }
            if ($currentProvider -eq $TargetProvider) { continue }

            $payloadProperties = @($json.payload.PSObject.Properties.Name)
            if ($payloadProperties -contains "model_provider") {
                $json.payload.model_provider = $TargetProvider
            } else {
                Add-Member -InputObject $json.payload -NotePropertyName "model_provider" -NotePropertyValue $TargetProvider -Force
            }

            $changes.Add([PSCustomObject]@{
                Path = $file.FullName
                Directory = $dirName
                OriginalProvider = $currentProvider
                UpdatedFirstLine = ($json | ConvertTo-Json -Compress -Depth 100)
                Record = $record
            }) | Out-Null
        }
    }
    return $changes.ToArray()
}

function Backup-HistorySyncState(
    $CodexHome,
    $TargetProvider,
    $Changes,
    $HistoryBackupRoot = $Script:DefaultHistoryBackupRoot
) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupRoot = Join-Path $HistoryBackupRoot "$stamp-$TargetProvider"
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

    foreach ($name in @("config.toml", "state_5.sqlite", ".codex-global-state.json")) {
        $path = Join-Path $CodexHome $name
        if (Test-Path -LiteralPath $path) {
            $target = Join-Path $backupRoot $name
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Copy-Item -LiteralPath $path -Destination $target -Force
        }
    }

    foreach ($change in $Changes) {
        $relative = Get-RelativeBackupPath -BasePath $CodexHome -ChildPath $change.Path
        $target = Join-Path (Join-Path $backupRoot "rollouts") $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath $change.Path -Destination $target -Force
    }

    return $backupRoot
}

function Invoke-SqliteProviderSync($CodexHome, $TargetProvider) {
    $dbPath = Join-Path $CodexHome "state_5.sqlite"
    if (-not (Test-Path -LiteralPath $dbPath)) {
        return [PSCustomObject]@{ UpdatedRows = 0; Present = $false; Warning = $null }
    }

    $sqlite = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if (-not $sqlite) {
        return [PSCustomObject]@{
            UpdatedRows = 0
            Present = $true
            Warning = "sqlite3.exe not found; SQLite provider metadata was not updated."
        }
    }

    $safeProvider = $TargetProvider.Replace("'", "''")
    $sql = "PRAGMA busy_timeout=5000; BEGIN IMMEDIATE; UPDATE threads SET model_provider = '$safeProvider' WHERE COALESCE(model_provider, '') <> '$safeProvider'; SELECT changes(); COMMIT;"
    $output = & $sqlite.Source $dbPath $sql 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw (($output | Out-String).Trim())
    }

    $updated = 0
    foreach ($line in $output) {
        $text = [string]$line
        if ($text -match '^\d+$') {
            $updated = [int]$text
        }
    }

    return [PSCustomObject]@{ UpdatedRows = $updated; Present = $true; Warning = $null }
}

function Invoke-HistoryProviderSync(
    $TargetProvider,
    $CodexHome = $Script:DefaultCodexHome,
    $HistoryBackupRoot = $Script:DefaultHistoryBackupRoot
) {
    if ([string]::IsNullOrWhiteSpace($TargetProvider) -or $TargetProvider -eq "missing") {
        return [PSCustomObject]@{
            TargetProvider = $TargetProvider
            BackupDir = $null
            ChangedRollouts = 0
            SqliteRowsUpdated = 0
            Warning = "Skipped sync because target provider is missing."
        }
    }

    $changes = @(Get-RolloutProviderChanges -CodexHome $CodexHome -TargetProvider $TargetProvider)
    $backupDir = Backup-HistorySyncState -CodexHome $CodexHome -TargetProvider $TargetProvider -Changes $changes -HistoryBackupRoot $HistoryBackupRoot
    foreach ($change in $changes) {
        Rewrite-FirstLine -Path $change.Path -Record $change.Record -NextFirstLine $change.UpdatedFirstLine
    }

    $sqliteResult = Invoke-SqliteProviderSync -CodexHome $CodexHome -TargetProvider $TargetProvider
    return [PSCustomObject]@{
        TargetProvider = $TargetProvider
        BackupDir = $backupDir
        ChangedRollouts = $changes.Count
        SqliteRowsUpdated = $sqliteResult.UpdatedRows
        Warning = $sqliteResult.Warning
    }
}

function Copy-ConfigToCodex($SourcePath, $CodexHome) {
    if (-not (Test-Path -LiteralPath $SourcePath)) {
        throw ((U "\u627e\u4e0d\u5230\u914d\u7f6e\u6587\u4ef6\uff1a") + "`n$SourcePath")
    }
    New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null
    Copy-Item -LiteralPath $SourcePath -Destination (Join-Path $CodexHome "config.toml") -Force
}

function Move-ApiAuthForOAuth($CodexHome, $CurrentProvider, $AuthMode) {
    $authPath = Join-Path $CodexHome "auth.json"
    if (-not (Test-Path -LiteralPath $authPath)) { return $null }

    $shouldMove = ($CurrentProvider -ne "openai") -or ($AuthMode -match "api|key")
    if (-not $shouldMove) { return $null }

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $target = Join-Path $CodexHome "auth.json.api-before-oauth-$stamp"
    Move-Item -LiteralPath $authPath -Destination $target -Force
    return $target
}

function Move-OAuthAuthForCPAMC($CodexHome, $CurrentProvider, $AuthMode) {
    $authPath = Join-Path $CodexHome "auth.json"
    if (-not (Test-Path -LiteralPath $authPath)) { return $null }

    $shouldMove = ($CurrentProvider -eq "openai") -or ($AuthMode -match "chatgpt|oauth")
    if (-not $shouldMove) { return $null }

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $target = Join-Path $CodexHome "auth.json.oauth-before-cpamc-$stamp"
    Move-Item -LiteralPath $authPath -Destination $target -Force
    return $target
}

function Switch-CodexProfileMode(
    [ValidateSet("OAuth", "CPAMC")] $Target,
    $CodexHome = $Script:DefaultCodexHome,
    $OfficialConfigPath = (Get-DefaultOfficialConfigPath),
    $CPAMCConfigPath = (Get-DefaultCPAMCConfigPath),
    $AppRoot = $Script:DefaultAppRoot,
    $HistoryBackupRoot = $Script:DefaultHistoryBackupRoot,
    [switch]$SkipProcessCheck
) {
    Ensure-SwitcherDirs $AppRoot
    if (-not $SkipProcessCheck) {
        Close-CodexIfRunning
    }

    $currentProvider = Get-CodexProvider $CodexHome
    $authMode = Get-CodexAuthMode $CodexHome
    $preSync = Invoke-HistoryProviderSync -TargetProvider $currentProvider -CodexHome $CodexHome -HistoryBackupRoot $HistoryBackupRoot
    $savedProfile = Save-CurrentModeProfile -CodexHome $CodexHome -AppRoot $AppRoot
    $authBackup = Backup-ActiveAuthConfig -CodexHome $CodexHome -AppRoot $AppRoot
    $movedAuth = $null
    $targetProvider = $null

    if ($Target -eq "CPAMC") {
        $cpamcProfile = Join-Path $AppRoot "profiles\cpamc"
        $cpamcAuth = Join-Path $cpamcProfile "auth.json"
        Copy-ConfigToCodex -SourcePath $CPAMCConfigPath -CodexHome $CodexHome
        if (Test-Path -LiteralPath $cpamcAuth) {
            Copy-Item -LiteralPath $cpamcAuth -Destination (Join-Path $CodexHome "auth.json") -Force
        } else {
            $movedAuth = Move-OAuthAuthForCPAMC -CodexHome $CodexHome -CurrentProvider $currentProvider -AuthMode $authMode
        }
        $targetProvider = "CPA"
    } else {
        $movedAuth = Move-ApiAuthForOAuth -CodexHome $CodexHome -CurrentProvider $currentProvider -AuthMode $authMode
        Copy-ConfigToCodex -SourcePath $OfficialConfigPath -CodexHome $CodexHome
        $officialAuth = Join-Path $AppRoot "profiles\official\auth.json"
        if (Test-Path -LiteralPath $officialAuth) {
            Copy-Item -LiteralPath $officialAuth -Destination (Join-Path $CodexHome "auth.json") -Force
        }
        $targetProvider = "openai"
    }

    $postSync = Invoke-HistoryProviderSync -TargetProvider $targetProvider -CodexHome $CodexHome -HistoryBackupRoot $HistoryBackupRoot
    return [PSCustomObject]@{
        Target = $Target
        PreviousProvider = $currentProvider
        TargetProvider = $targetProvider
        PreSync = $preSync
        PostSync = $postSync
        SavedProfile = $savedProfile
        AuthBackup = $authBackup
        MovedAuth = $movedAuth
    }
}

function Format-SwitchResult($Result) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add((U "\u5df2\u5207\u6362\u81f3") + " $(Get-FriendlyModeName $Result.TargetProvider)")
    $lines.Add((U "\u5386\u53f2\u8bb0\u5f55\u5df2\u540c\u6b65\uff1a") + " provider=$($Result.TargetProvider)")
    $lines.Add("")
    $lines.Add((U "\u5207\u6362\u524d\u68c0\u67e5\uff1a") + " rollout=$($Result.PreSync.ChangedRollouts), sqlite=$($Result.PreSync.SqliteRowsUpdated)")
    $lines.Add((U "\u5207\u6362\u540e\u540c\u6b65\uff1a") + " rollout=$($Result.PostSync.ChangedRollouts), sqlite=$($Result.PostSync.SqliteRowsUpdated)")
    $lines.Add((U "\u5b89\u5168\u5907\u4efd\uff1a") + " $($Result.AuthBackup)")
    $lines.Add((U "\u8bb0\u5f55\u5907\u4efd\uff1a") + " $($Result.PostSync.BackupDir)")
    if ($Result.MovedAuth) {
        $lines.Add((U "\u5df2\u79fb\u8d70 API auth\uff1a") + " $($Result.MovedAuth)")
    }
    if ($Result.PostSync.Warning) {
        $lines.Add("")
        $lines.Add("Warning: $($Result.PostSync.Warning)")
    }
    return ($lines -join [Environment]::NewLine)
}

function Get-FriendlyModeName($Provider) {
    if ($Provider -eq "openai" -or $Provider -eq "OAuth") {
        return "OAuth"
    }
    if ($Provider -eq "CPA" -or $Provider -eq "CPAMC") {
        return "CPAMC"
    }
    if ([string]::IsNullOrWhiteSpace($Provider) -or $Provider -eq "missing") {
        return (U "\u672a\u8bc6\u522b")
    }
    return [string]$Provider
}

function Get-FriendlyAuthName($AuthMode) {
    if ($AuthMode -eq "chatgpt" -or $AuthMode -eq "oauth") {
        return "OAuth"
    }
    if ($AuthMode -eq "apikey") {
        return "API"
    }
    if ([string]::IsNullOrWhiteSpace($AuthMode) -or $AuthMode -eq "missing") {
        return (U "\u672a\u767b\u5f55")
    }
    return [string]$AuthMode
}

function Test-ToolReadiness($Settings, $AppRoot = $Script:DefaultAppRoot) {
    if ($Settings -and $Settings.backupRoot) {
        $AppRoot = Get-AppRootFromBackupRoot $Settings.backupRoot
    }
    $cpamcAuth = Join-Path $AppRoot "profiles\cpamc\auth.json"
    $officialAuth = Join-Path $AppRoot "profiles\official\auth.json"
    return [PSCustomObject]@{
        OfficialConfigExists = Test-Path -LiteralPath $Settings.officialConfigPath
        CPAMCConfigExists = Test-Path -LiteralPath $Settings.cpamcConfigPath
        OfficialAuthSaved = Test-Path -LiteralPath $officialAuth
        CPAMCAuthSaved = Test-Path -LiteralPath $cpamcAuth
        Sqlite3Exists = [bool](Get-Command sqlite3 -ErrorAction SilentlyContinue)
    }
}

function Enable-GlassBackdrop($Form) {
    try {
        if (-not ([System.Management.Automation.PSTypeName]'DwmGlassNative').Type) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class DwmGlassNative {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
}
"@
        }

        $darkMode = 1
        [DwmGlassNative]::DwmSetWindowAttribute($Form.Handle, 20, [ref]$darkMode, 4) | Out-Null
        $backdrop = 3
        [DwmGlassNative]::DwmSetWindowAttribute($Form.Handle, 38, [ref]$backdrop, 4) | Out-Null
        $corner = 2
        [DwmGlassNative]::DwmSetWindowAttribute($Form.Handle, 33, [ref]$corner, 4) | Out-Null
    } catch {}
}

function New-RoundedPath($Rectangle, $Radius) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $Radius * 2
    $path.AddArc($Rectangle.X, $Rectangle.Y, $diameter, $diameter, 180, 90)
    $path.AddArc($Rectangle.Right - $diameter, $Rectangle.Y, $diameter, $diameter, 270, 90)
    $path.AddArc($Rectangle.Right - $diameter, $Rectangle.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($Rectangle.X, $Rectangle.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Set-RoundedRegion($Control, $Radius) {
    if ($Control.Width -le 0 -or $Control.Height -le 0) { return }
    $rect = New-Object System.Drawing.Rectangle(0, 0, $Control.Width, $Control.Height)
    $path = New-RoundedPath $rect $Radius
    $Control.Region = New-Object System.Drawing.Region($path)
    $path.Dispose()
}

function Add-SubtleCardBorder($Panel, $Radius = 10) {
    $Panel.Add_Paint({
        param($sender, $eventArgs)
        if ($sender.Width -le 1 -or $sender.Height -le 1) { return }
        $eventArgs.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $rect = New-Object System.Drawing.Rectangle(1, 1, ($sender.Width - 3), ($sender.Height - 3))
        $path = New-RoundedPath $rect ([Math]::Max(1, ($Radius - 1)))
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(48, 70, 58), 1)
        $eventArgs.Graphics.DrawPath($pen, $path)
        $pen.Dispose()
        $path.Dispose()
    }.GetNewClosure())
}

function New-GlassPanel($Location, $Size, $Radius = 18) {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = $Location
    $panel.Size = $Size
    $panel.BackColor = [System.Drawing.Color]::FromArgb(22, 34, 27)
    $panel.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $panel.Add_HandleCreated({ Set-RoundedRegion $panel 10 })
    $panel.Add_Resize({ Set-RoundedRegion $panel 10 })
    Add-SubtleCardBorder $panel 10
    return $panel
}

function New-GlassButton($Text, $Location, $Size, $Kind = "secondary") {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = $Location
    $button.Size = $Size
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 1
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10.5, [System.Drawing.FontStyle]::Bold)

    if ($Kind -eq "primary") {
        $button.BackColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
        $button.ForeColor = [System.Drawing.Color]::FromArgb(240, 253, 250)
        $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(52, 211, 153)
        $button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(5, 150, 105)
        $button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(4, 120, 87)
    } elseif ($Kind -eq "accent") {
        $button.BackColor = [System.Drawing.Color]::FromArgb(217, 119, 6)
        $button.ForeColor = [System.Drawing.Color]::FromArgb(255, 251, 235)
        $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(245, 158, 11)
        $button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(180, 83, 9)
        $button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(146, 64, 14)
    } else {
        $button.BackColor = [System.Drawing.Color]::FromArgb(18, 30, 24)
        $button.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
        $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(42, 60, 49)
        $button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(28, 44, 35)
        $button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(10, 20, 15)
    }

    $button.Add_HandleCreated({ Set-RoundedRegion $button 8 })
    $button.Add_Resize({ Set-RoundedRegion $button 8 })
    return $button
}

function Ensure-RoundedTextBoxControl {
    if (([System.Management.Automation.PSTypeName]'RoundedTextBoxControl').Type) {
        return
    }

    Add-Type -ReferencedAssemblies "System.Windows.Forms", "System.Drawing" -TypeDefinition @"
using System;
using System.ComponentModel;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

public class RoundedTextBoxControl : UserControl {
    public TextBox InnerTextBox;
    private Color borderColor = Color.FromArgb(42, 60, 49);
    private Color focusBorderColor = Color.FromArgb(58, 85, 69);

    public RoundedTextBoxControl() {
        this.DoubleBuffered = true;
        this.BackColor = Color.FromArgb(25, 39, 31);
        this.Padding = new Padding(12, 5, 12, 4);
        this.Height = 30;

        InnerTextBox = new TextBox();
        InnerTextBox.BorderStyle = BorderStyle.None;
        InnerTextBox.BackColor = Color.FromArgb(25, 39, 31);
        InnerTextBox.ForeColor = Color.FromArgb(226, 232, 240);
        InnerTextBox.Font = new Font("Microsoft YaHei UI", 9.5f);
        InnerTextBox.Location = new Point(12, 6);
        InnerTextBox.Anchor = AnchorStyles.Left | AnchorStyles.Top | AnchorStyles.Right;
        InnerTextBox.Width = this.Width - 24;
        InnerTextBox.TextChanged += delegate { this.OnTextChanged(EventArgs.Empty); };
        InnerTextBox.GotFocus += delegate { this.Invalidate(); };
        InnerTextBox.LostFocus += delegate { this.Invalidate(); };
        this.Controls.Add(InnerTextBox);

        this.Resize += delegate {
            InnerTextBox.Width = this.Width - 24;
            InnerTextBox.Location = new Point(12, Math.Max(5, (this.Height - InnerTextBox.Height) / 2));
            this.Invalidate();
        };
        this.Click += delegate { InnerTextBox.Focus(); };
    }

    [Browsable(true)]
    public override string Text {
        get { return InnerTextBox.Text; }
        set { InnerTextBox.Text = value; }
    }

    protected override void OnPaint(PaintEventArgs e) {
        base.OnPaint(e);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        Rectangle rect = new Rectangle(0, 0, this.Width - 1, this.Height - 1);
        int radius = 9;
        using (GraphicsPath path = new GraphicsPath()) {
            int d = radius * 2;
            path.AddArc(rect.X, rect.Y, d, d, 180, 90);
            path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90);
            path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90);
            path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            using (SolidBrush brush = new SolidBrush(this.BackColor)) {
                e.Graphics.FillPath(brush, path);
            }
            using (Pen pen = new Pen(InnerTextBox.Focused ? focusBorderColor : borderColor, 1)) {
                e.Graphics.DrawPath(pen, path);
            }
        }
    }
}
"@
}

function New-GlassTextBox($Text, $Location, $Size) {
    Ensure-RoundedTextBoxControl
    $box = New-Object RoundedTextBoxControl
    $box.Text = $Text
    $box.Location = $Location
    $box.Size = $Size
    $box.BackColor = [System.Drawing.Color]::FromArgb(25, 39, 31)
    $box.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
    $box.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.5)
    return $box
}

function New-FolderIconBitmap($Width = 18, $Height = 18) {
    $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $tabBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 158, 11))
    $bodyBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(217, 119, 6))
    $linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(253, 230, 138), 1.2)

    $graphics.FillRectangle($tabBrush, 2, 4, 6, 3)
    $graphics.FillRectangle($bodyBrush, 2, 6, 14, 9)
    $graphics.DrawRectangle($linePen, 2, 6, 14, 9)

    $tabBrush.Dispose()
    $bodyBrush.Dispose()
    $linePen.Dispose()
    $graphics.Dispose()
    return $bitmap
}

function New-FolderButton($Location, $ToolTipText) {
    $button = New-GlassButton -Text "" -Location $Location -Size (New-Object System.Drawing.Size(42, 32))
    $button.Image = New-FolderIconBitmap
    $button.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $button.AccessibleName = $ToolTipText
    return $button
}

function New-SidebarButton($Text, $Location, $Size) {
    $button = New-GlassButton -Text $Text -Location $Location -Size $Size
    $button.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $button.Padding = New-Object System.Windows.Forms.Padding(20, 0, 0, 0)
    $button.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10.5, [System.Drawing.FontStyle]::Bold)
    $button.FlatAppearance.BorderSize = 0
    $button.FlatAppearance.BorderColor = $button.BackColor
    return $button
}

function Select-FolderPath($TextBox, $DialogDescription, $Owner = $null) {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $DialogDescription
    $dialog.ShowNewFolderButton = $true
    if (-not [string]::IsNullOrWhiteSpace($TextBox.Text) -and (Test-Path -LiteralPath $TextBox.Text)) {
        $dialog.SelectedPath = $TextBox.Text
    }
    if ($Owner) {
        $result = $dialog.ShowDialog($Owner)
    } else {
        $result = $dialog.ShowDialog()
    }
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $TextBox.Text = $dialog.SelectedPath
    }
    $dialog.Dispose()
}

function New-ConfigHealthDot($Location) {
    $dot = New-Object System.Windows.Forms.Label
    $dot.Text = U "\u25cf"
    $dot.Location = $Location
    $dot.Size = New-Object System.Drawing.Size(22, 24)
    $dot.BackColor = [System.Drawing.Color]::Transparent
    $dot.ForeColor = [System.Drawing.Color]::FromArgb(160, 73, 73)
    $dot.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $dot.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    return $dot
}

function Update-ConfigHealthDot($Dot, $IsOk) {
    if ($IsOk) {
        $Dot.ForeColor = [System.Drawing.Color]::FromArgb(52, 211, 153)
        $Dot.AccessibleName = "OK"
    } else {
        $Dot.ForeColor = [System.Drawing.Color]::FromArgb(248, 113, 113)
        $Dot.AccessibleName = "Missing"
    }
}

function New-GlassLabel($Text, $Location, $Size, $Style = "body") {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = $Location
    $label.Size = $Size
    $label.BackColor = [System.Drawing.Color]::Transparent
    $label.ForeColor = [System.Drawing.Color]::FromArgb(232, 241, 236)
    if ($Style -eq "title") {
        $label.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 18, [System.Drawing.FontStyle]::Bold)
        $label.ForeColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
    } elseif ($Style -eq "muted") {
        $label.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 8.8)
        $label.ForeColor = [System.Drawing.Color]::FromArgb(151, 169, 160)
    } elseif ($Style -eq "section") {
        $label.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10.2, [System.Drawing.FontStyle]::Bold)
        $label.ForeColor = [System.Drawing.Color]::FromArgb(82, 255, 157)
    } else {
        $label.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.2)
    }
    return $label
}

function New-StatusBadge($Title, $Location, $Size) {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = $Location
    $panel.Size = $Size
    $panel.BackColor = [System.Drawing.Color]::FromArgb(18, 30, 24)
    $panel.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $panel.Add_HandleCreated({ Set-RoundedRegion $panel 8 })
    $panel.Add_Resize({ Set-RoundedRegion $panel 8 })

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = $Title
    $titleLabel.Location = New-Object System.Drawing.Point(10, 6)
    $titleLabel.Size = New-Object System.Drawing.Size(72, 18)
    $titleLabel.BackColor = [System.Drawing.Color]::Transparent
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(151, 169, 160)
    $titleLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 8)
    $panel.Controls.Add($titleLabel)

    $valueLabel = New-Object System.Windows.Forms.Label
    $valueLabel.Text = "-"
    $valueLabel.Location = New-Object System.Drawing.Point(84, 5)
    $valueLabel.Size = New-Object System.Drawing.Size(($Size.Width - 92), 20)
    $valueLabel.BackColor = [System.Drawing.Color]::Transparent
    $valueLabel.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
    $valueLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 8.5, [System.Drawing.FontStyle]::Bold)
    $panel.Controls.Add($valueLabel)

    return [PSCustomObject]@{
        Panel = $panel
        ValueLabel = $valueLabel
    }
}

function Update-StatusBadge($Badge, $Value, $IsOk = $true) {
    $Badge.ValueLabel.Text = [string]$Value
    if ($IsOk) {
        $Badge.ValueLabel.ForeColor = [System.Drawing.Color]::FromArgb(110, 231, 183)
    } else {
        $Badge.ValueLabel.ForeColor = [System.Drawing.Color]::FromArgb(251, 191, 36)
    }
}

function Show-SettingsDialog($Owner, $Settings) {
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = U "\u8bbe\u7f6e"
    $dialog.Size = New-Object System.Drawing.Size(760, 420)
    $dialog.StartPosition = "CenterParent"
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.BackColor = [System.Drawing.Color]::FromArgb(8, 14, 12)
    $dialog.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

    $title = New-GlassLabel -Text (U "\u8bbe\u7f6e") -Location (New-Object System.Drawing.Point(26, 18)) -Size (New-Object System.Drawing.Size(180, 34)) -Style "title"
    $dialog.Controls.Add($title)

    $panel = New-GlassPanel -Location (New-Object System.Drawing.Point(26, 64)) -Size (New-Object System.Drawing.Size(692, 238)) -Radius 6
    $dialog.Controls.Add($panel)

    function Add-SettingRow($LabelText, $Text, $Y, $Kind) {
        $label = New-GlassLabel -Text $LabelText -Location (New-Object System.Drawing.Point(20, $Y)) -Size (New-Object System.Drawing.Size(120, 26)) -Style "section"
        $panel.Controls.Add($label)

        $box = New-GlassTextBox -Text $Text -Location (New-Object System.Drawing.Point(142, ($Y - 2))) -Size (New-Object System.Drawing.Size(462, 26))
        $panel.Controls.Add($box)

        $button = New-FolderButton -Location (New-Object System.Drawing.Point(620, ($Y - 4))) -ToolTipText $LabelText
        $panel.Controls.Add($button)

        if ($Kind -eq "file") {
            $button.Add_Click({
                $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
                $fileDialog.Title = $LabelText
                $fileDialog.Filter = "config.toml|config.toml|TOML files (*.toml)|*.toml|All files (*.*)|*.*"
                $fileDialog.FileName = "config.toml"
                if (-not [string]::IsNullOrWhiteSpace($box.Text)) {
                    $folder = Split-Path -Parent $box.Text
                    if (Test-Path -LiteralPath $folder) {
                        $fileDialog.InitialDirectory = $folder
                    }
                }
                if ($fileDialog.ShowDialog($dialog) -eq [System.Windows.Forms.DialogResult]::OK) {
                    $box.Text = $fileDialog.FileName
                }
                $fileDialog.Dispose()
            })
        } else {
            $button.Add_Click({ Select-FolderPath $box $LabelText $dialog })
        }

        return $box
    }

    $officialBox = Add-SettingRow (U "OpenAI \u914d\u7f6e") $Settings.officialConfigPath 22 "file"
    $cpamcBox = Add-SettingRow (U "CPAMC \u914d\u7f6e") $Settings.cpamcConfigPath 72 "file"
    $codexBox = Add-SettingRow (U "Codex \u6570\u636e") $Settings.codexHome 122 "folder"
    $backupBox = Add-SettingRow (U "\u5907\u4efd\u76ee\u5f55") $Settings.backupRoot 172 "folder"

    $cancelButton = New-GlassButton -Text (U "\u53d6\u6d88") -Location (New-Object System.Drawing.Point(454, 326)) -Size (New-Object System.Drawing.Size(110, 38))
    $dialog.Controls.Add($cancelButton)

    $saveButton = New-GlassButton -Text (U "\u4fdd\u5b58") -Location (New-Object System.Drawing.Point(584, 326)) -Size (New-Object System.Drawing.Size(110, 38)) -Kind "primary"
    $dialog.Controls.Add($saveButton)

    $script:settingsSaved = $false
    $cancelButton.Add_Click({ $dialog.Close() })
    $saveButton.Add_Click({
        if ([string]::IsNullOrWhiteSpace($backupBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show((U "\u8bf7\u9009\u62e9\u5907\u4efd\u76ee\u5f55"), $Script:Title, "OK", "Warning") | Out-Null
            return
        }

        $Settings.officialConfigPath = $officialBox.Text.Trim()
        $Settings.cpamcConfigPath = $cpamcBox.Text.Trim()
        $Settings.codexHome = $codexBox.Text.Trim()
        $Settings.backupRoot = $backupBox.Text.Trim()
        Save-SwitcherSettings $Settings
        $script:settingsSaved = $true
        $dialog.Close()
    })

    if ($Owner) {
        [void]$dialog.ShowDialog($Owner)
    } else {
        [void]$dialog.ShowDialog()
    }
    return $script:settingsSaved
}

function Show-UnifiedForm {
    $settings = Load-SwitcherSettings
    Ensure-SwitcherDirs (Get-AppRootFromBackupRoot $settings.backupRoot)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Script:Title
    $form.Size = New-Object System.Drawing.Size(980, 600)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "None"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.Opacity = 1.0
    $form.BackColor = [System.Drawing.Color]::FromArgb(38, 45, 42)
    $form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)
    $form.Add_Shown({ Enable-GlassBackdrop $form; Set-RoundedRegion $form 10 })
    $form.Add_Resize({ Set-RoundedRegion $form 10 })

    $dragging = $false
    $dragOffset = New-Object System.Drawing.Point(0, 0)
    $startDrag = {
        $script:dragging = $true
        $script:dragOffset = [System.Windows.Forms.Cursor]::Position
        $script:dragOffset.Offset((0 - $form.Left), (0 - $form.Top))
    }
    $moveDrag = {
        if ($script:dragging) {
            $point = [System.Windows.Forms.Cursor]::Position
            $point.Offset((0 - $script:dragOffset.X), (0 - $script:dragOffset.Y))
            $form.Location = $point
        }
    }
    $endDrag = { $script:dragging = $false }

    $sidebar = New-Object System.Windows.Forms.Panel
    $sidebar.Location = New-Object System.Drawing.Point(0, 0)
    $sidebar.Size = New-Object System.Drawing.Size(220, 600)
    $sidebar.BackColor = [System.Drawing.Color]::FromArgb(12, 24, 18)
    $sidebar.Add_MouseDown($startDrag)
    $sidebar.Add_MouseMove($moveDrag)
    $sidebar.Add_MouseUp($endDrag)
    $form.Controls.Add($sidebar)

    $brandMark = New-Object System.Windows.Forms.Label
    $brandMark.Text = "C"
    $brandMark.Location = New-Object System.Drawing.Point(26, 28)
    $brandMark.Size = New-Object System.Drawing.Size(36, 36)
    $brandMark.BackColor = [System.Drawing.Color]::FromArgb(30, 52, 40)
    $brandMark.ForeColor = [System.Drawing.Color]::FromArgb(110, 231, 183)
    $brandMark.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 15, [System.Drawing.FontStyle]::Bold)
    $brandMark.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $brandMark.Add_HandleCreated({ Set-RoundedRegion $brandMark 12 })
    $sidebar.Controls.Add($brandMark)

    $brand = New-GlassLabel -Text "C-O" -Location (New-Object System.Drawing.Point(76, 28)) -Size (New-Object System.Drawing.Size(110, 30)) -Style "title"
    $brand.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 15, [System.Drawing.FontStyle]::Bold)
    $sidebar.Controls.Add($brand)

    $brandSub = New-GlassLabel -Text (U "\u6a21\u5f0f\u4e0e\u8bb0\u5f55\u540c\u6b65") -Location (New-Object System.Drawing.Point(78, 58)) -Size (New-Object System.Drawing.Size(128, 22)) -Style "muted"
    $sidebar.Controls.Add($brandSub)

    $modeNav = New-SidebarButton -Text (U "\u6a21\u5f0f\u5207\u6362") -Location (New-Object System.Drawing.Point(14, 132)) -Size (New-Object System.Drawing.Size(192, 44))
    $sidebar.Controls.Add($modeNav)

    $settingsNav = New-SidebarButton -Text (U "\u8bbe\u7f6e") -Location (New-Object System.Drawing.Point(14, 188)) -Size (New-Object System.Drawing.Size(192, 44))
    $sidebar.Controls.Add($settingsNav)

    $sideLine = New-Object System.Windows.Forms.Panel
    $sideLine.Location = New-Object System.Drawing.Point(24, 270)
    $sideLine.Size = New-Object System.Drawing.Size(172, 1)
    $sideLine.BackColor = [System.Drawing.Color]::FromArgb(35, 50, 41)
    $sidebar.Controls.Add($sideLine)

    $hint = New-GlassLabel -Text (U "\u5907\u4efd\u76ee\u5f55\u7531\u8bbe\u7f6e\u9875\u7edf\u4e00\u7ba1\u7406") -Location (New-Object System.Drawing.Point(24, 520)) -Size (New-Object System.Drawing.Size(166, 46)) -Style "muted"
    $sidebar.Controls.Add($hint)

    $contentRoot = New-Object System.Windows.Forms.Panel
    $contentRoot.Location = New-Object System.Drawing.Point(220, 0)
    $contentRoot.Size = New-Object System.Drawing.Size(760, 600)
    $contentRoot.BackColor = [System.Drawing.Color]::Transparent
    $form.Controls.Add($contentRoot)

    $topBar = New-Object System.Windows.Forms.Panel
    $topBar.Location = New-Object System.Drawing.Point(0, 0)
    $topBar.Size = New-Object System.Drawing.Size(760, 76)
    $topBar.BackColor = [System.Drawing.Color]::Transparent
    $topBar.Add_MouseDown($startDrag)
    $topBar.Add_MouseMove($moveDrag)
    $topBar.Add_MouseUp($endDrag)
    $contentRoot.Controls.Add($topBar)

    $pageTitle = New-GlassLabel -Text (U "\u6a21\u5f0f\u5207\u6362") -Location (New-Object System.Drawing.Point(44, 14)) -Size (New-Object System.Drawing.Size(220, 30)) -Style "title"
    $pageTitle.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 14, [System.Drawing.FontStyle]::Bold)
    $topBar.Controls.Add($pageTitle)

    $pageSubTitle = New-GlassLabel -Text (U "\u4e00\u4e2a\u7a97\u53e3\u5b8c\u6210\u8d26\u53f7\u5207\u6362\u548c\u5386\u53f2\u8bb0\u5f55\u540c\u6b65") -Location (New-Object System.Drawing.Point(46, 46)) -Size (New-Object System.Drawing.Size(420, 20)) -Style "muted"
    $topBar.Controls.Add($pageSubTitle)

    $minButton = New-GlassButton -Text "-" -Location (New-Object System.Drawing.Point(646, 20)) -Size (New-Object System.Drawing.Size(36, 30))
    $minButton.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $topBar.Controls.Add($minButton)

    $closeTopButton = New-GlassButton -Text "X" -Location (New-Object System.Drawing.Point(696, 20)) -Size (New-Object System.Drawing.Size(36, 30))
    $closeTopButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $closeTopButton.ForeColor = [System.Drawing.Color]::FromArgb(203, 213, 225)
    $topBar.Controls.Add($closeTopButton)

    $modePage = New-Object System.Windows.Forms.Panel
    $modePage.Location = New-Object System.Drawing.Point(0, 76)
    $modePage.Size = New-Object System.Drawing.Size(760, 524)
    $modePage.BackColor = [System.Drawing.Color]::Transparent
    $contentRoot.Controls.Add($modePage)

    $settingsPage = New-Object System.Windows.Forms.Panel
    $settingsPage.Location = New-Object System.Drawing.Point(0, 76)
    $settingsPage.Size = New-Object System.Drawing.Size(760, 524)
    $settingsPage.BackColor = [System.Drawing.Color]::Transparent
    $settingsPage.Visible = $false
    $contentRoot.Controls.Add($settingsPage)

    $statusPanel = New-GlassPanel -Location (New-Object System.Drawing.Point(56, 398)) -Size (New-Object System.Drawing.Size(640, 112)) -Radius 10
    $modePage.Controls.Add($statusPanel)

    $statusTitle = New-GlassLabel -Text (U "\u5f53\u524d\u72b6\u6001") -Location (New-Object System.Drawing.Point(24, 18)) -Size (New-Object System.Drawing.Size(120, 24)) -Style "section"
    $statusPanel.Controls.Add($statusTitle)

    $modeBadge = New-StatusBadge -Title (U "\u5f53\u524d\u6a21\u5f0f") -Location (New-Object System.Drawing.Point(24, 58)) -Size (New-Object System.Drawing.Size(136, 32))
    $statusPanel.Controls.Add($modeBadge.Panel)

    $authBadge = New-StatusBadge -Title (U "\u767b\u5f55\u65b9\u5f0f") -Location (New-Object System.Drawing.Point(174, 58)) -Size (New-Object System.Drawing.Size(136, 32))
    $statusPanel.Controls.Add($authBadge.Panel)

    $configBadge = New-StatusBadge -Title (U "\u914d\u7f6e\u6587\u4ef6") -Location (New-Object System.Drawing.Point(324, 58)) -Size (New-Object System.Drawing.Size(136, 32))
    $statusPanel.Controls.Add($configBadge.Panel)

    $backupBadge = New-StatusBadge -Title (U "\u5b89\u5168\u5907\u4efd") -Location (New-Object System.Drawing.Point(474, 58)) -Size (New-Object System.Drawing.Size(136, 32))
    $statusPanel.Controls.Add($backupBadge.Panel)

    $configPanel = New-GlassPanel -Location (New-Object System.Drawing.Point(56, 44)) -Size (New-Object System.Drawing.Size(640, 320)) -Radius 10
    $modePage.Controls.Add($configPanel)

    $configTitle = New-GlassLabel -Text (U "\u914d\u7f6e\u6587\u4ef6") -Location (New-Object System.Drawing.Point(26, 24)) -Size (New-Object System.Drawing.Size(160, 26)) -Style "title"
    $configTitle.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 13, [System.Drawing.FontStyle]::Bold)
    $configPanel.Controls.Add($configTitle)

    $configDesc = New-GlassLabel -Text (U "\u9009\u62e9\u4e24\u5957 Codex \u914d\u7f6e\uff0c\u5207\u6362\u65f6\u4f1a\u81ea\u52a8\u5907\u4efd\u5e76\u540c\u6b65\u8bb0\u5f55\u3002") -Location (New-Object System.Drawing.Point(26, 54)) -Size (New-Object System.Drawing.Size(548, 22)) -Style "muted"
    $configPanel.Controls.Add($configDesc)

    $officialLabel = New-GlassLabel -Text (U "OpenAI") -Location (New-Object System.Drawing.Point(26, 90)) -Size (New-Object System.Drawing.Size(92, 24)) -Style "section"
    $configPanel.Controls.Add($officialLabel)

    $officialText = New-GlassTextBox -Text $settings.officialConfigPath -Location (New-Object System.Drawing.Point(26, 116)) -Size (New-Object System.Drawing.Size(508, 30))
    $configPanel.Controls.Add($officialText)

    $officialPicker = New-FolderButton -Location (New-Object System.Drawing.Point(548, 115)) -ToolTipText (U "\u9009\u62e9 OpenAI \u914d\u7f6e\u6587\u4ef6")
    $configPanel.Controls.Add($officialPicker)

    $officialDot = New-ConfigHealthDot -Location (New-Object System.Drawing.Point(592, 120))
    $configPanel.Controls.Add($officialDot)

    $cpamcLabel = New-GlassLabel -Text (U "CPAMC") -Location (New-Object System.Drawing.Point(26, 164)) -Size (New-Object System.Drawing.Size(92, 24)) -Style "section"
    $configPanel.Controls.Add($cpamcLabel)

    $cpamcText = New-GlassTextBox -Text $settings.cpamcConfigPath -Location (New-Object System.Drawing.Point(26, 190)) -Size (New-Object System.Drawing.Size(508, 30))
    $configPanel.Controls.Add($cpamcText)

    $cpamcPicker = New-FolderButton -Location (New-Object System.Drawing.Point(548, 189)) -ToolTipText (U "\u9009\u62e9 CPAMC \u914d\u7f6e\u6587\u4ef6")
    $configPanel.Controls.Add($cpamcPicker)

    $cpamcDot = New-ConfigHealthDot -Location (New-Object System.Drawing.Point(592, 194))
    $configPanel.Controls.Add($cpamcDot)

    $oauthButton = New-GlassButton -Text (U "\u5207\u6362\u81f3OAuth") -Location (New-Object System.Drawing.Point(102, 252)) -Size (New-Object System.Drawing.Size(172, 44)) -Kind "primary"
    $oauthButton.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 12, [System.Drawing.FontStyle]::Bold)
    $configPanel.Controls.Add($oauthButton)

    $cpamcButton = New-GlassButton -Text (U "\u5207\u6362\u81f3CPAMC") -Location (New-Object System.Drawing.Point(298, 252)) -Size (New-Object System.Drawing.Size(172, 44)) -Kind "accent"
    $cpamcButton.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 12, [System.Drawing.FontStyle]::Bold)
    $configPanel.Controls.Add($cpamcButton)

    $settingsCard = New-GlassPanel -Location (New-Object System.Drawing.Point(56, 44)) -Size (New-Object System.Drawing.Size(640, 438)) -Radius 10
    $settingsPage.Controls.Add($settingsCard)

    $settingsTitle = New-GlassLabel -Text (U "\u8def\u5f84\u8bbe\u7f6e") -Location (New-Object System.Drawing.Point(26, 24)) -Size (New-Object System.Drawing.Size(180, 30)) -Style "title"
    $settingsTitle.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 13, [System.Drawing.FontStyle]::Bold)
    $settingsCard.Controls.Add($settingsTitle)

    $settingsDesc = New-GlassLabel -Text (U "\u8fd9\u4e9b\u8def\u5f84\u4f1a\u4fdd\u5b58\u5230 AppData\uff0c\u5907\u4efd\u5185\u5bb9\u4f1a\u6309\u8bbe\u5b9a\u76ee\u5f55\u5b58\u653e\u3002") -Location (New-Object System.Drawing.Point(28, 54)) -Size (New-Object System.Drawing.Size(560, 22)) -Style "muted"
    $settingsCard.Controls.Add($settingsDesc)

    function Add-InlineSettingRow($LabelText, $Text, $Y, $Kind) {
        $yPos = [int]$Y
        $label = New-GlassLabel -Text $LabelText -Location (New-Object System.Drawing.Point(28, $yPos)) -Size (New-Object System.Drawing.Size(180, 24)) -Style "section"
        $settingsCard.Controls.Add($label)

        $box = New-GlassTextBox -Text $Text -Location (New-Object System.Drawing.Point(28, ($yPos + 28))) -Size (New-Object System.Drawing.Size(508, 30))
        $settingsCard.Controls.Add($box)

        $button = New-FolderButton -Location (New-Object System.Drawing.Point(548, ($yPos + 27))) -ToolTipText $LabelText
        $settingsCard.Controls.Add($button)

        if ($Kind -eq "file") {
            $localBox = $box
            $button.Add_Click({
                $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
                $fileDialog.Title = $LabelText
                $fileDialog.Filter = "config.toml|config.toml|TOML files (*.toml)|*.toml|All files (*.*)|*.*"
                $fileDialog.FileName = "config.toml"
                if (-not [string]::IsNullOrWhiteSpace($localBox.Text)) {
                    $folder = Split-Path -Parent $localBox.Text
                    if (Test-Path -LiteralPath $folder) {
                        $fileDialog.InitialDirectory = $folder
                    }
                }
                if ($fileDialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
                    $localBox.Text = $fileDialog.FileName
                }
                $fileDialog.Dispose()
            }.GetNewClosure())
        } else {
            $localBox = $box
            $button.Add_Click({ Select-FolderPath $localBox $LabelText $form }.GetNewClosure())
        }

        return $box
    }

    $officialSettingsText = Add-InlineSettingRow (U "OpenAI \u914d\u7f6e") $settings.officialConfigPath 88 "file"
    $cpamcSettingsText = Add-InlineSettingRow (U "CPAMC \u914d\u7f6e") $settings.cpamcConfigPath 156 "file"
    $codexHomeText = Add-InlineSettingRow (U "Codex \u6570\u636e") $settings.codexHome 224 "folder"
    $backupRootText = Add-InlineSettingRow (U "\u5907\u4efd\u76ee\u5f55") $settings.backupRoot 292 "folder"

    $saveSettingsButton = New-GlassButton -Text (U "\u4fdd\u5b58\u8bbe\u7f6e") -Location (New-Object System.Drawing.Point(28, 374)) -Size (New-Object System.Drawing.Size(154, 40)) -Kind "primary"
    $settingsCard.Controls.Add($saveSettingsButton)

    $toolTip = New-Object System.Windows.Forms.ToolTip
    $toolTip.SetToolTip($officialPicker, (U "\u9009\u62e9 OpenAI \u914d\u7f6e\u6587\u4ef6"))
    $toolTip.SetToolTip($cpamcPicker, (U "\u9009\u62e9 CPAMC \u914d\u7f6e\u6587\u4ef6"))

    function Save-UiSettings {
        $settings.officialConfigPath = $officialText.Text.Trim()
        $settings.cpamcConfigPath = $cpamcText.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($settings.codexHome)) {
            $settings.codexHome = $Script:DefaultCodexHome
        }
        if ([string]::IsNullOrWhiteSpace($settings.backupRoot)) {
            $settings.backupRoot = $Script:DefaultBackupRoot
        }
        Save-SwitcherSettings $settings
    }

    function Sync-SettingsInputsToMode {
        $officialText.Text = $settings.officialConfigPath
        $cpamcText.Text = $settings.cpamcConfigPath
        $officialSettingsText.Text = $settings.officialConfigPath
        $cpamcSettingsText.Text = $settings.cpamcConfigPath
        $codexHomeText.Text = $settings.codexHome
        $backupRootText.Text = $settings.backupRoot
    }

    function Refresh-UiStatus {
        Ensure-SwitcherDirs (Get-AppRootFromBackupRoot $settings.backupRoot)
        $readiness = Test-ToolReadiness -Settings $settings
        $provider = Get-CodexProvider $settings.codexHome
        $authMode = Get-CodexAuthMode $settings.codexHome
        $configsOk = $readiness.OfficialConfigExists -and $readiness.CPAMCConfigExists
        $backupsOk = $readiness.OfficialAuthSaved -or $readiness.CPAMCAuthSaved

        Update-StatusBadge $modeBadge (Get-FriendlyModeName $provider) ($provider -ne "missing")
        Update-StatusBadge $authBadge (Get-FriendlyAuthName $authMode) ($authMode -ne "missing" -and $authMode -ne "unknown")
        Update-StatusBadge $configBadge ($(if ($configsOk) { (U "\u6b63\u5e38") } else { (U "\u9700\u68c0\u67e5") })) $configsOk
        Update-StatusBadge $backupBadge ($(if ($backupsOk) { (U "\u5df2\u5f00\u542f") } else { (U "\u5f85\u751f\u6210") })) $true

        Update-ConfigHealthDot $officialDot $readiness.OfficialConfigExists
        Update-ConfigHealthDot $cpamcDot $readiness.CPAMCConfigExists
    }

    function Select-ConfigFile($textBox, $dialogTitle) {
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = $dialogTitle
        $dialog.Filter = "config.toml|config.toml|TOML files (*.toml)|*.toml|All files (*.*)|*.*"
        $dialog.FileName = "config.toml"
        if (-not [string]::IsNullOrWhiteSpace($textBox.Text)) {
            $folder = Split-Path -Parent $textBox.Text
            if (Test-Path -LiteralPath $folder) {
                $dialog.InitialDirectory = $folder
            }
        }
        if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
            $textBox.Text = $dialog.FileName
            Save-UiSettings
            Sync-SettingsInputsToMode
            Refresh-UiStatus
        }
        $dialog.Dispose()
    }

    function Run-Switch($target) {
        try {
            Save-UiSettings
            $form.UseWaitCursor = $true
            $oauthButton.Enabled = $false
            $cpamcButton.Enabled = $false
            $result = Switch-CodexProfileMode `
                -Target $target `
                -CodexHome $settings.codexHome `
                -OfficialConfigPath $officialText.Text.Trim() `
                -CPAMCConfigPath $cpamcText.Text.Trim() `
                -AppRoot (Get-AppRootFromBackupRoot $settings.backupRoot) `
                -HistoryBackupRoot (Get-HistoryBackupRootFromBackupRoot $settings.backupRoot)
            Refresh-UiStatus
            [System.Windows.Forms.MessageBox]::Show((Format-SwitchResult $result), $Script:Title, "OK", "Information") | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, $Script:Title, "OK", "Warning") | Out-Null
        } finally {
            $oauthButton.Enabled = $true
            $cpamcButton.Enabled = $true
            $form.UseWaitCursor = $false
        }
    }

    function Show-Page($Name) {
        $modePage.Visible = ($Name -eq "mode")
        $settingsPage.Visible = ($Name -eq "settings")
        if ($Name -eq "mode") {
            $pageTitle.Text = U "\u6a21\u5f0f\u5207\u6362"
            $pageSubTitle.Text = U "\u4e00\u4e2a\u7a97\u53e3\u5b8c\u6210\u8d26\u53f7\u5207\u6362\u548c\u5386\u53f2\u8bb0\u5f55\u540c\u6b65"
            $modeNav.BackColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
            $modeNav.FlatAppearance.BorderColor = $modeNav.BackColor
            $settingsNav.BackColor = [System.Drawing.Color]::FromArgb(18, 30, 24)
            $settingsNav.FlatAppearance.BorderColor = $settingsNav.BackColor
            Refresh-UiStatus
        } else {
            $pageTitle.Text = U "\u8bbe\u7f6e"
            $pageSubTitle.Text = U "\u7edf\u4e00\u7ba1\u7406\u914d\u7f6e\u6587\u4ef6\u3001Codex \u6570\u636e\u76ee\u5f55\u548c\u5907\u4efd\u76ee\u5f55"
            $modeNav.BackColor = [System.Drawing.Color]::FromArgb(18, 30, 24)
            $modeNav.FlatAppearance.BorderColor = $modeNav.BackColor
            $settingsNav.BackColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
            $settingsNav.FlatAppearance.BorderColor = $settingsNav.BackColor
            Sync-SettingsInputsToMode
        }
    }

    $officialText.Add_Leave({ Save-UiSettings; Sync-SettingsInputsToMode; Refresh-UiStatus })
    $cpamcText.Add_Leave({ Save-UiSettings; Sync-SettingsInputsToMode; Refresh-UiStatus })
    $officialPicker.Add_Click({ Select-ConfigFile $officialText (U "\u9009\u62e9 OpenAI \u914d\u7f6e\u6587\u4ef6") })
    $cpamcPicker.Add_Click({ Select-ConfigFile $cpamcText (U "\u9009\u62e9 CPAMC \u914d\u7f6e\u6587\u4ef6") })
    $oauthButton.Add_Click({ Run-Switch "OAuth" })
    $cpamcButton.Add_Click({ Run-Switch "CPAMC" })
    $modeNav.Add_Click({ Show-Page "mode" })
    $settingsNav.Add_Click({ Show-Page "settings" })
    $saveSettingsButton.Add_Click({
        if ([string]::IsNullOrWhiteSpace($backupRootText.Text)) {
            [System.Windows.Forms.MessageBox]::Show((U "\u8bf7\u9009\u62e9\u5907\u4efd\u76ee\u5f55"), $Script:Title, "OK", "Warning") | Out-Null
            return
        }
        $settings.officialConfigPath = $officialSettingsText.Text.Trim()
        $settings.cpamcConfigPath = $cpamcSettingsText.Text.Trim()
        $settings.codexHome = $codexHomeText.Text.Trim()
        $settings.backupRoot = $backupRootText.Text.Trim()
        Save-SwitcherSettings $settings
        Sync-SettingsInputsToMode
        Ensure-SwitcherDirs (Get-AppRootFromBackupRoot $settings.backupRoot)
        Refresh-UiStatus
        [System.Windows.Forms.MessageBox]::Show((U "\u8bbe\u7f6e\u5df2\u4fdd\u5b58"), $Script:Title, "OK", "Information") | Out-Null
    })
    $closeTopButton.Add_Click({ $form.Close() })
    $minButton.Add_Click({ $form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized })

    Sync-SettingsInputsToMode
    Show-Page "mode"
    [void]$form.ShowDialog()
}

if (-not $NoUi) {
    Show-UnifiedForm
}
