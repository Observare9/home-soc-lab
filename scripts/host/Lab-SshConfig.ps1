# Dot-source this file. It writes the lab's SSH client configuration to the user's temp folder
# and sets $LabSshConfig to its path. Paths with spaces are quoted inside the file, because
# passing them on the ssh command line splits them at the spaces.
#   soc-ubuntu  reaches SOC-Ubuntu through its loopback forward, 127.0.0.1:12223.
#   soc-kali    reaches SOC-Kali (10.77.0.40) by hopping through soc-ubuntu.
# The key and known-hosts files stay in the credential store. Only this generated file, which
# holds no secret, lives in the temp folder.
$labStore = (Join-Path $env:LOCALAPPDATA 'Home SOC Lab').Replace('\','/')
$LabSshConfig = Join-Path $env:TEMP 'home-soc-lab-ssh-config'
$labSshConfigForward = $LabSshConfig.Replace('\','/')
$labSshText = @"
Host soc-ubuntu
  HostName 127.0.0.1
  Port 12223
  User labuser
  IdentityFile "$labStore/ubuntu-key"
  IdentitiesOnly yes
  UserKnownHostsFile "$labStore/ubuntu-known-hosts"
  StrictHostKeyChecking accept-new
  BatchMode yes
  ConnectTimeout 12
Host soc-kali
  HostName 10.77.0.40
  User labuser
  IdentityFile "$labStore/ubuntu-key"
  IdentitiesOnly yes
  UserKnownHostsFile "$labStore/kali-known-hosts"
  StrictHostKeyChecking accept-new
  BatchMode yes
  ConnectTimeout 20
  ProxyCommand ssh.exe -F "$labSshConfigForward" -W %h:%p soc-ubuntu
"@
[IO.File]::WriteAllText($LabSshConfig, $labSshText.Replace("`r",""), (New-Object System.Text.UTF8Encoding($false)))
