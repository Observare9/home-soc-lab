param(
    # Credential file in the store (without .xml) whose password should be typed.
    [string]$CredentialName = 'dc01-administrator',
    [string]$Vm = 'SOC-DC01'
)
# Types a stored password into the VM as keystrokes, for the Windows sign-in screen where paste is not available.
# Click the password box in the SOC-DC01 window first, run this, then press Enter in the VM.
# VBoxManage reads the text from a file. The file is created in the user's own temp folder
# (%LOCALAPPDATA%\Temp), used, and deleted in this call.
$ErrorActionPreference = 'Stop'
$store = Join-Path $env:LOCALAPPDATA 'Home SOC Lab'
$file = Join-Path $env:TEMP ("home-soc-lab-" + [guid]::NewGuid().ToString('N') + ".txt")
try {
    [IO.File]::WriteAllText($file, (Import-Clixml -LiteralPath (Join-Path $store "$CredentialName.xml")).GetNetworkCredential().Password, (New-Object System.Text.ASCIIEncoding))
    & 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' controlvm $Vm keyboardputfile $file
    if ($LASTEXITCODE -ne 0) { throw "VBoxManage could not type into $Vm" }
} finally {
    Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
}
