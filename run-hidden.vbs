Option Explicit
Dim shell, script, i, command
Set shell = CreateObject("WScript.Shell")
If WScript.Arguments.Count < 1 Then WScript.Quit 2
script = WScript.Arguments(0)
command = "powershell.exe -NoLogo -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File " & Quote(script)
For i = 1 To WScript.Arguments.Count - 1
  command = command & " " & Quote(WScript.Arguments(i))
Next
WScript.Quit shell.Run(command, 0, True)
Function Quote(value)
  Quote = Chr(34) & Replace(value, Chr(34), Chr(34) & Chr(34)) & Chr(34)
End Function
