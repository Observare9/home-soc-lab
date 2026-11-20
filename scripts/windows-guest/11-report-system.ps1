# Reports the facts worth recording about the guest: name, edition, build, accounts, adapters, clock.
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
"computer name: $env:COMPUTERNAME"
"product: $((Get-CimInstance Win32_OperatingSystem).Caption)"
"edition id: $($cv.EditionID)   installation type: $($cv.InstallationType)   display version: $($cv.DisplayVersion)"
"os build: $($cv.CurrentBuild).$($cv.UBR)"
$cs = Get-CimInstance Win32_ComputerSystem
"domain or workgroup: $($cs.Domain)   part of a domain: $($cs.PartOfDomain)   domain role: $($cs.DomainRole)"
"time zone: $((Get-TimeZone).Id)   utc now: $((Get-Date).ToUniversalTime().ToString('s'))Z"
"guest additions service: $((Get-Service VBoxService -ErrorAction SilentlyContinue).Status)"
'--- local accounts'
if ($cs.DomainRole -lt 4) { Get-LocalUser | ForEach-Object { "{0}  enabled={1}" -f $_.Name, $_.Enabled } } else { 'domain controller: local accounts are domain accounts' }
'--- adapters'
Get-NetAdapter | Sort-Object Name | ForEach-Object { "{0}  mac={1}  status={2}  {3}" -f $_.Name, $_.MacAddress, $_.Status, $_.InterfaceDescription }
'--- ipv4 addresses'
Get-NetIPAddress -AddressFamily IPv4 | Sort-Object InterfaceAlias | ForEach-Object { "{0}  {1}/{2}  origin={3}" -f $_.InterfaceAlias, $_.IPAddress, $_.PrefixLength, $_.PrefixOrigin }
'--- default routes'
$routes = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue)
if ($routes.Count) { $routes | ForEach-Object { "{0} via {1}" -f $_.InterfaceAlias, $_.NextHop } } else { 'none' }
'--- network profiles'
Get-NetConnectionProfile | ForEach-Object { "{0}  {1}  category={2}" -f $_.InterfaceAlias, $_.Name, $_.NetworkCategory }
