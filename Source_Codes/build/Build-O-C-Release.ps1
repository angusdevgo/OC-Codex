param(
    [string] $Version = "v0.1.0"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$program = Join-Path $repoRoot "Source_Codes\launcher\Program.cs"
$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$distRoot = Join-Path $repoRoot "dist"
$packageDir = Join-Path $distRoot "O-C"
$zipPath = Join-Path $distRoot "O-C-$Version-win-x64.zip"

if (-not (Test-Path -LiteralPath $program)) {
    throw "Launcher source not found: $program"
}
if (-not (Test-Path -LiteralPath $csc)) {
    $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe"
}
if (-not (Test-Path -LiteralPath $csc)) {
    throw "C# compiler not found. Expected Windows .NET Framework csc.exe."
}

Remove-Item -LiteralPath $packageDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $packageDir | Out-Null

$exe = Join-Path $packageDir "O-C.exe"
$compileArgs = @(
    "/nologo",
    "/target:winexe",
    "/optimize+",
    "/out:$exe",
    "/reference:System.Windows.Forms.dll",
    "/reference:System.Drawing.dll",
    $program
)

Write-Host "csc.exe /target:winexe /out:O-C.exe"
& $csc @compileArgs

if (-not (Test-Path -LiteralPath $exe)) {
    throw "Compiled exe not found: $exe"
}

Copy-Item -LiteralPath (Join-Path $repoRoot "README.md") -Destination (Join-Path $packageDir "README.md") -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "LICENSE") -Destination (Join-Path $packageDir "LICENSE") -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "Run-O-C.vbs") -Destination (Join-Path $packageDir "Run-O-C.vbs") -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "Create-O-C-Shortcut.bat") -Destination (Join-Path $packageDir "Create-O-C-Shortcut.bat") -Force

Copy-Item -LiteralPath (Join-Path $repoRoot "picture") -Destination (Join-Path $packageDir "picture") -Recurse -Force
New-Item -ItemType Directory -Force -Path (Join-Path $packageDir "Source_Codes\tools") | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot "Source_Codes\tools\CodexUnifiedSwitcher.ps1") -Destination (Join-Path $packageDir "Source_Codes\tools\CodexUnifiedSwitcher.ps1") -Force

Compress-Archive -Path (Join-Path $packageDir "*") -DestinationPath $zipPath -Force

Write-Host "Built release package:"
Write-Host "  $packageDir"
Write-Host "  $zipPath"
