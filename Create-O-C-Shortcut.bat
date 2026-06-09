@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$root=(Resolve-Path '%~dp0').Path; ^
   $exe=Join-Path $root 'O-C.exe'; ^
   $vbs=Join-Path $root 'Run-O-C.vbs'; ^
   if ((-not (Test-Path -LiteralPath $exe)) -and (-not (Test-Path -LiteralPath $vbs))) { throw 'O-C.exe or Run-O-C.vbs not found.' }; ^
   $shell=New-Object -ComObject WScript.Shell; ^
   $desktop=[Environment]::GetFolderPath('Desktop'); ^
   foreach ($linkPath in @((Join-Path $root 'O-C.lnk'), (Join-Path $desktop 'O-C.lnk'))) { ^
     $shortcut=$shell.CreateShortcut($linkPath); ^
     if (Test-Path -LiteralPath $exe) { ^
       $shortcut.TargetPath=$exe; ^
       $shortcut.Arguments=''; ^
     } else { ^
       $shortcut.TargetPath=(Join-Path $env:WINDIR 'System32\wscript.exe'); ^
       $shortcut.Arguments='\"' + $vbs + '\"'; ^
     }; ^
     $shortcut.WorkingDirectory=$root; ^
     $shortcut.IconLocation=(Join-Path $env:WINDIR 'System32\imageres.dll') + ',109'; ^
     $shortcut.WindowStyle=1; ^
     $shortcut.Save(); ^
   }; ^
   Write-Host 'O-C shortcuts created.'"

pause
