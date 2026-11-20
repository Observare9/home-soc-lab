# After the promotion reboot: domain facts, services, audit policy, and where directory services listen.
# Host side: Invoke-DcGuest.ps1 -Domain SOCLAB
"checked $((Get-Date).ToUniversalTime().ToString('s'))Z on $env:COMPUTERNAME"
'--- domain'
$domain = Get-ADDomain
"DNSRoot=$($domain.DNSRoot)  NetBIOSName=$($domain.NetBIOSName)  DomainMode=$($domain.DomainMode)  ForestMode=$((Get-ADForest).ForestMode)"
"domain controllers: $((Get-ADDomainController -Filter * | ForEach-Object { $_.HostName + ' (' + $_.IPv4Address + ')' }) -join ', ')"
'--- services'
Get-Service NTDS, DNS, Netlogon, Kdc, LanmanServer, wazuhsvc -ErrorAction SilentlyContinue | ForEach-Object { "{0}  {1}" -f $_.Name, $_.Status }
'--- audit policy, Account Management'
& auditpol.exe /get /category:"Account Management"
'--- ipv4 addresses'
Get-NetIPAddress -AddressFamily IPv4 | Sort-Object InterfaceAlias | ForEach-Object { "{0}  {1}/{2}" -f $_.InterfaceAlias, $_.IPAddress, $_.PrefixLength }
'--- adapters'
Get-NetAdapter | ForEach-Object { "{0}  mac={1}  status={2}" -f $_.Name, $_.MacAddress, $_.Status }
'--- default routes'
$routes = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue)
if ($routes.Count) { $routes | ForEach-Object { "{0} via {1}" -f $_.InterfaceAlias, $_.NextHop } } else { 'none' }
'--- dns client and dns server addresses'
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } | ForEach-Object { "{0} uses {1}" -f $_.InterfaceAlias, ($_.ServerAddresses -join ', ') }
"dns server listens on: $(((Get-DnsServerSetting -All -WarningAction SilentlyContinue).ListeningIPAddress) -join ', ')"
'--- listening addresses for DNS 53, Kerberos 88, LDAP 389, SMB 445'
Get-NetTCPConnection -State Listen -LocalPort 53, 88, 389, 445 -ErrorAction SilentlyContinue | Sort-Object LocalPort, LocalAddress | ForEach-Object { "{0}  {1}" -f $_.LocalPort, $_.LocalAddress }
'--- network profile'
Get-NetConnectionProfile | ForEach-Object { "{0}  {1}  category={2}" -f $_.InterfaceAlias, $_.Name, $_.NetworkCategory }
'--- wazuh agent'
Get-Content -LiteralPath 'C:\Program Files (x86)\ossec-agent\wazuh-agent.state' -ErrorAction SilentlyContinue | Where-Object { $_ -match '^(status|last_keepalive|last_ack)=' }
$global:LASTEXITCODE = 0
