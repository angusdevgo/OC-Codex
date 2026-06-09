$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "tools\CodexUnifiedSwitcher.ps1"
$source = Get-Content -LiteralPath $scriptPath -Raw

$tokens = $null
$errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) {
    throw "CodexUnifiedSwitcher.ps1 has syntax errors: $($errors[0].Message)"
}

function Assert-Contains($needle, $label) {
    if (-not $source.Contains($needle)) {
        throw "Missing expected ${label}: $needle"
    }
}

Assert-Contains "function Enable-GlassBackdrop" "glass backdrop helper"
Assert-Contains "function New-GlassButton" "glass button helper"
Assert-Contains "function New-GlassTextBox" "glass textbox helper"
Assert-Contains "RoundedTextBoxControl" "rounded textbox native control"
Assert-Contains "DrawPath" "rounded textbox/card border drawing"
Assert-Contains "Rectangle(1, 1" "inset rounded card border"
Assert-Contains "InnerTextBox" "rounded textbox inner textbox"
Assert-Contains '[System.Windows.Forms.BorderStyle]::None' "filled borderless textbox"
Assert-Contains "[System.Drawing.Color]::FromArgb(25, 39, 31)" "filled textbox surface"
Assert-Contains "function New-FolderButton" "folder picker button helper"
Assert-Contains "function New-SidebarButton" "sidebar button helper"
Assert-Contains "function Add-SubtleCardBorder" "subtle card border helper"
Assert-Contains "function Show-Page" "page switching helper"
Assert-Contains "function Select-ConfigFile" "config file picker"
Assert-Contains "function Get-DefaultSettingsPath" "app settings path helper"
Assert-Contains "function Get-AppRootFromBackupRoot" "app root from backup root helper"
Assert-Contains "function Get-HistoryBackupRootFromBackupRoot" "history root from backup root helper"
Assert-Contains "function Show-SettingsDialog" "settings dialog helper"
Assert-Contains "function Select-FolderPath" "folder picker helper"
Assert-Contains "backupRoot" "custom backup root setting"
Assert-Contains "AppData" "settings stored outside backup root"
Assert-Contains '$Script:DefaultBackupRoot = "D:\codex-back"' "D drive backup root"
Assert-Contains 'Join-Path $Script:DefaultBackupRoot "codex-switch"' "D drive app backup root"
Assert-Contains 'Join-Path $Script:DefaultBackupRoot "history-sync"' "D drive history backup root"
Assert-Contains "function Get-FriendlyModeName" "friendly mode name helper"
Assert-Contains "function Get-FriendlyAuthName" "friendly auth name helper"
Assert-Contains "function New-StatusBadge" "status badge helper"
Assert-Contains "function Update-StatusBadge" "status badge updater"
Assert-Contains "function New-ConfigHealthDot" "config health dot helper"
Assert-Contains "function Update-ConfigHealthDot" "config health dot updater"
Assert-Contains "RefinedUiV3" "refined UI v3 marker"
Assert-Contains "AcrylicSidebarUiV1" "acrylic sidebar UI marker"
Assert-Contains "SolidDashboardUiV1" "solid dashboard UI marker"
Assert-Contains "SettingsPanelInspiredUiV1" "settings panel inspired UI marker"
Assert-Contains "NetcattyCardUiV1" "netcatty card UI marker"
Assert-Contains "AcrylicBackplateUiV1" "acrylic backplate UI marker"
Assert-Contains 'FormBorderStyle = "None"' "borderless glass shell"
Assert-Contains '$form.Opacity = 1.0' "fully opaque form"
Assert-Contains "Enable-GlassBackdrop `$form" "enabled acrylic backplate"
Assert-Contains "Color]::Transparent" "transparent content over acrylic backplate"
Assert-Contains "Set-RoundedRegion `$form 10" "restrained rounded main window"
Assert-Contains "Set-RoundedRegion `$panel 10" "restrained rounded cards"
Assert-Contains "Set-RoundedRegion `$button 8" "restrained rounded buttons"
Assert-Contains "Set-RoundedRegion `$panel 8" "soft rounded status badges"
Assert-Contains "[System.Drawing.Color]::FromArgb(38, 45, 42)" "acrylic backplate shell"
Assert-Contains "[System.Drawing.Color]::FromArgb(22, 34, 27)" "solid dashboard card surface"
Assert-Contains "[System.Drawing.Color]::FromArgb(151, 169, 160)" "muted green-gray text"
Assert-Contains "[System.Drawing.Color]::FromArgb(16, 185, 129)" "calm green primary action"
Assert-Contains "[System.Drawing.Color]::FromArgb(217, 119, 6)" "calm amber CPAMC action"
Assert-Contains "[System.Drawing.Color]::FromArgb(12, 24, 18)" "reference green-black sidebar"
Assert-Contains "[System.Drawing.Color]::FromArgb(22, 34, 27)" "reference card surface"
Assert-Contains "[System.Drawing.Color]::FromArgb(82, 255, 157)" "reference green label"
Assert-Contains "System.Drawing.Size(980, 600)" "netcatty compact window size"
Assert-Contains "System.Drawing.Size(220, 600)" "netcatty sidebar size"
Assert-Contains "System.Drawing.Point(220, 0)" "netcatty content root position"
Assert-Contains "System.Drawing.Size(760, 600)" "netcatty content root size"
Assert-Contains "System.Drawing.Size(508, 30)" "natural config input width"
Assert-Contains "System.Drawing.Point(56, 44)" "natural mode card position"
Assert-Contains "System.Drawing.Size(640, 320)" "natural mode card size"
Assert-Contains "System.Drawing.Point(102, 252)" "centered OAuth switch button"
Assert-Contains "System.Drawing.Point(298, 252)" "centered CPAMC switch button"
Assert-Contains "System.Drawing.Point(56, 398)" "natural status card position"
Assert-Contains "System.Drawing.Size(640, 112)" "natural status card size"
Assert-Contains "System.Drawing.Size(42, 32)" "softer picker button size"
Assert-Contains '(0 - $form.Left)' "drag offset form left compatibility"
Assert-Contains '(0 - $script:dragOffset.X)' "drag offset x compatibility"
Assert-Contains "\u5207\u6362\u81f3OAuth" "OAuth button label"
Assert-Contains "\u5207\u6362\u81f3CPAMC" "CPAMC button label"
Assert-Contains "\u6a21\u5f0f\u5207\u6362" "sidebar mode switch label"
Assert-Contains "\u8bbe\u7f6e" "settings button label"
Assert-Contains '$button.FlatAppearance.BorderSize = 0' "filled sidebar button without hard border"
Assert-Contains "settingsPage" "inline settings page"
Assert-Contains "modePage" "inline mode page"
Assert-Contains "\u5907\u4efd\u76ee\u5f55" "backup directory setting label"
Assert-Contains "FolderBrowserDialog" "folder picker dialog"
Assert-Contains "\u5f53\u524d\u6a21\u5f0f" "current mode badge label"
Assert-Contains "\u767b\u5f55\u65b9\u5f0f" "auth mode badge label"
Assert-Contains "\u914d\u7f6e\u6587\u4ef6" "config health badge label"
Assert-Contains "\u5b89\u5168\u5907\u4efd" "safety backup badge label"
Assert-Contains "\u5df2\u5207\u6362\u81f3" "friendly switch success message"
Assert-Contains "\u5386\u53f2\u8bb0\u5f55\u5df2\u540c\u6b65" "friendly history sync message"
Assert-Contains "\u9009\u62e9 OpenAI \u914d\u7f6e\u6587\u4ef6" "OpenAI folder button tooltip"
Assert-Contains "\u9009\u62e9 CPAMC \u914d\u7f6e\u6587\u4ef6" "CPAMC folder button tooltip"
Assert-Contains "OpenFileDialog" "file picker dialog"
Assert-Contains "Invoke-HistoryProviderSync -TargetProvider `$currentProvider" "pre-switch provider sync"
Assert-Contains "Invoke-HistoryProviderSync -TargetProvider `$targetProvider" "post-switch provider sync"

foreach ($forbidden in @(
    "\u6253\u5f00Provider Sync",
    "\u4fee\u590d\u5f53\u524d\u8bb0\u5f55",
    "\u5237\u65b0\u72b6\u6001",
    '$form.Opacity = 0.97',
    "[System.Windows.Forms.BorderStyle]::FixedSingle",
    "officialBrowse",
    "cpamcBrowse",
    "repairCurrentButton",
    "refreshButton",
    "closeButton = New-GlassButton"
)) {
    if ($source.Contains($forbidden)) {
        throw "Integrated UI must not expose forbidden control: $forbidden"
    }
}

Write-Host "Codex unified switcher UI checks passed."
