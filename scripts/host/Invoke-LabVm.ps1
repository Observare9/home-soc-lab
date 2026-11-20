param([Parameter(Mandatory)][string]$CommandText)
# Runs a root shell script on the SOC-Wazuh appliance through its loopback SSH forward (127.0.0.1:12222).
# Credentials are read from the encrypted store and handed to vm-session.py on stdin, never on a command line.
# Write __DASHBOARD_PASSWORD__ in the script where the dashboard admin password is needed.
$ErrorActionPreference = 'Stop'
$credentials = @{}
foreach ($name in @('wazuh-user','admin')) {
    $file = Join-Path $env:LOCALAPPDATA "Home SOC Lab\$name.xml"
    $credentials[$name] = (Import-Clixml -LiteralPath $file).GetNetworkCredential().Password
}
$payload = ($credentials | ConvertTo-Json -Compress) + "`n" + $CommandText
# Windows PowerShell can put a byte-order mark in front of text piped to a program. Turn that off for this call.
$previousInput = [Console]::InputEncoding
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)
try {
    $payload | & "$PSScriptRoot\tools-env\Scripts\python.exe" "$PSScriptRoot\vm-session.py"
    if ($LASTEXITCODE -ne 0) { throw 'VM command failed' }
} finally {
    [Console]::InputEncoding = $previousInput
}
