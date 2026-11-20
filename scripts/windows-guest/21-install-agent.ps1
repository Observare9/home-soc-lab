# Installs the Wazuh agent with the documented deployment variables, starts it, and shows its enrollment.
$msi = 'C:\LabSetup\wazuh-agent-4.14.10-1.msi'
$agentDir = 'C:\Program Files (x86)\ossec-agent'
if (-not (Get-Service wazuhsvc -ErrorAction SilentlyContinue)) {
    "installing at $((Get-Date).ToUniversalTime().ToString('s'))Z"
    $p = Start-Process -FilePath msiexec.exe -ArgumentList "/i `"$msi`" /q WAZUH_MANAGER=`"10.77.0.10`" WAZUH_AGENT_NAME=`"soc-dc01`"" -Wait -PassThru
    "msiexec exit code: $($p.ExitCode)"
    if ($p.ExitCode -ne 0) { throw 'Agent installation failed' }
}
Start-Service wazuhsvc
$deadline = (Get-Date).AddSeconds(90)
do {
    Start-Sleep -Seconds 5
    $state = Get-Content -LiteralPath (Join-Path $agentDir 'wazuh-agent.state') -ErrorAction SilentlyContinue | Where-Object { $_ -match "^status=" }
} while ($state -notmatch 'connected' -and (Get-Date) -lt $deadline)
"service: $((Get-Service wazuhsvc).Status)   $state"
"agent version: $((Get-Content -LiteralPath (Join-Path $agentDir 'VERSION.json') -ErrorAction SilentlyContinue | Select-String 'version') -join ' ')"
'--- enrollment (id and name only)'
Get-Content -LiteralPath (Join-Path $agentDir 'client.keys') | ForEach-Object { ($_ -split ' ')[0..1] -join ' ' }
'--- agent log'
Get-Content -LiteralPath (Join-Path $agentDir 'ossec.log') -Tail 15
