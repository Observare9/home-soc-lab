param([Parameter(Mandatory)][string]$CommandText)
# Runs a root shell script on the SOC-Kali guest (10.77.0.40).
# Kali has no adapter the host can reach, so the connection hops through SOC-Ubuntu's loopback SSH forward.
# SOC-Ubuntu must be running. The same lab key is authorized on both guests.
$ErrorActionPreference='Stop'
. "$PSScriptRoot\Lab-SshConfig.ps1"
$previousInput=[Console]::InputEncoding
[Console]::InputEncoding=New-Object System.Text.UTF8Encoding($false)
$OutputEncoding=New-Object System.Text.UTF8Encoding($false)
try {
    $CommandText.Replace("`r","") | ssh.exe -T -F $LabSshConfig soc-kali "tr -d '\015' | sudo bash -se"
    if ($LASTEXITCODE) {throw 'Kali guest command failed'}
} finally {
    [Console]::InputEncoding=$previousInput
}
