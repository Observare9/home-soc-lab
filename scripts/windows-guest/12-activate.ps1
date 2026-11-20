# Activates the evaluation online, as Microsoft intends, and prints the license state.
# Needs the temporary NAT adapter. No rearm and no workarounds.
$slmgr = 'C:\Windows\System32\slmgr.vbs'
"--- slmgr /ato at $((Get-Date).ToUniversalTime().ToString('s'))Z"
& cscript.exe //nologo $slmgr /ato
"--- slmgr /dli"
& cscript.exe //nologo $slmgr /dli
"--- slmgr /xpr"
& cscript.exe //nologo $slmgr /xpr
$global:LASTEXITCODE = 0
