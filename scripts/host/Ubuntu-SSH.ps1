param([Parameter(Mandatory)][string]$CommandText)
# Runs a root shell script on the SOC-Ubuntu guest through its loopback SSH forward (127.0.0.1:12223).
# The script text arrives on stdin. The remote shell runs with "bash -se", so a failing command stops it.
$ErrorActionPreference='Stop'
. "$PSScriptRoot\Lab-SshConfig.ps1"
# Windows PowerShell can put a byte-order mark in front of text piped to a program. Turn that off for this call.
$previousInput=[Console]::InputEncoding
[Console]::InputEncoding=New-Object System.Text.UTF8Encoding($false)
$OutputEncoding=New-Object System.Text.UTF8Encoding($false)
try {
    $CommandText.Replace("`r","") | ssh.exe -T -F $LabSshConfig soc-ubuntu "tr -d '\015' | sudo bash -se"
    if ($LASTEXITCODE) {throw 'Ubuntu guest command failed'}
} finally {
    [Console]::InputEncoding=$previousInput
}
