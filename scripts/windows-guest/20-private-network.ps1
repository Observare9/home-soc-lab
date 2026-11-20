# Gives the lab adapter its reserved address, 10.77.0.30/24, with no default gateway,
# and checks that the Wazuh manager's agent ports answer.
$labMac = '08-00-27-4E-5C-DC'   # SOC-DC01 adapter 1, on the SOC-LAB internal network
$adapters = @(Get-NetAdapter)
'--- adapters'
$adapters | ForEach-Object { "{0}  mac={1}  status={2}" -f $_.Name, $_.MacAddress, $_.Status }
$lab = $adapters | Where-Object { $_.MacAddress -eq $labMac }
if (-not $lab) { throw "No adapter with MAC $labMac" }
if (@(Get-NetIPAddress -InterfaceIndex $lab.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object IPAddress -eq '10.77.0.30').Count -eq 0) {
    Set-NetIPInterface -InterfaceIndex $lab.ifIndex -AddressFamily IPv4 -Dhcp Disabled
    Get-NetIPAddress -InterfaceIndex $lab.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    New-NetIPAddress -InterfaceIndex $lab.ifIndex -IPAddress 10.77.0.30 -PrefixLength 24 | Out-Null
}
if ($lab.Name -ne 'SOC-LAB') { Rename-NetAdapter -Name $lab.Name -NewName 'SOC-LAB' }
Start-Sleep -Seconds 3
'--- ipv4 addresses'
Get-NetIPAddress -AddressFamily IPv4 | Sort-Object InterfaceAlias | ForEach-Object { "{0}  {1}/{2}" -f $_.InterfaceAlias, $_.IPAddress, $_.PrefixLength }
'--- default routes'
$routes = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue)
if ($routes.Count) { $routes | ForEach-Object { "{0} via {1}" -f $_.InterfaceAlias, $_.NextHop } } else { 'none' }
'--- manager ports'
foreach ($port in 1514, 1515) {
    $t = Test-NetConnection -ComputerName 10.77.0.10 -Port $port -WarningAction SilentlyContinue
    "10.77.0.10:{0}  reachable={1}  from {2}" -f $port, $t.TcpTestSucceeded, $t.SourceAddress.IPAddress
}
