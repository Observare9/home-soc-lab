# Installs AD DS and creates the lab-only forest soclab.internal (NetBIOS SOCLAB) with DNS.
# It refuses to run unless the lab adapter is the only adapter and there is no default route,
# so Active Directory, DNS and SMB can only ever listen on the internal lab network.
# Host side: Invoke-DcGuest.ps1 -Secrets @{ dsrm = 'dc01-dsrm' } -TimeoutSeconds 3000
$labMac = '08-00-27-4E-5C-DC'
$others = @(Get-NetAdapter | Where-Object { $_.MacAddress -ne $labMac })
if ($others.Count) { throw "Remove the other adapter(s) first: $(($others | ForEach-Object Name) -join ', ')" }
if (@(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue).Count) { throw 'A default route exists. The lab network must not have one.' }
if (@(Get-NetIPAddress -AddressFamily IPv4 | Where-Object IPAddress -eq '10.77.0.30').Count -ne 1) { throw '10.77.0.30 is not configured' }
if ($env:COMPUTERNAME -ne 'SOC-DC01') { throw "Computer name is $env:COMPUTERNAME. Rename it before promotion." }

"feature install started $((Get-Date).ToUniversalTime().ToString('s'))Z"
$feature = Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
"feature install success=$($feature.Success)  restart needed=$($feature.RestartNeeded)  exit=$($feature.ExitCode)"
if (-not $feature.Success) { throw 'AD DS feature installation failed' }

Import-Module ADDSDeployment
$dsrm = ConvertTo-SecureString (Get-LabSecret 'dsrm') -AsPlainText -Force
"forest promotion started $((Get-Date).ToUniversalTime().ToString('s'))Z"
$result = Install-ADDSForest -DomainName 'soclab.internal' -DomainNetbiosName 'SOCLAB' -InstallDns -SafeModeAdministratorPassword $dsrm -NoRebootOnCompletion -Force
Remove-Variable dsrm
"forest promotion returned $((Get-Date).ToUniversalTime().ToString('s'))Z"
"status=$($result.Status)  reboot required=$($result.RebootRequired)"
"message: $($result.Message)"
if ($result.Status -ne 'Success') { throw 'Forest promotion did not report success' }
