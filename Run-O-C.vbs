Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
base = fso.GetParentFolderName(WScript.ScriptFullName)
script = fso.BuildPath(base, "Source_Codes\tools\CodexUnifiedSwitcher.ps1")
command = "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & script & """"
shell.Run command, 0, False
