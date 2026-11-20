# Steps 3 and 5 of the experiment: connect to the share as the fictional user and try to read the file.
# The caller sets $Phase (a label) and $AppendLine (text to append, or '' for a read-only test) above this script.
# A standard user cannot sign in locally on a domain controller, so this is a network logon over SMB.
# Group membership is read when a session is created, so every run starts from a new connection.
# Host side: Invoke-DcGuest.ps1 -Domain SOCLAB -Secrets @{ jrivera = 'soclab-jrivera' }
$share = '\\10.77.0.30\Lighting'
$file = "$share\lighting-schedule-01.txt"
$user = 'SOCLAB\jrivera'
"=== $Phase -started $((Get-Date).ToUniversalTime().ToString('s'))Z"
"members of GG-Lighting-Operators: $((Get-ADGroupMember -Identity 'GG-Lighting-Operators' | ForEach-Object SamAccountName) -join ', ')"
Get-SmbSession | Where-Object ClientUserName -eq $user | Close-SmbSession -Force -ErrorAction SilentlyContinue
Get-SmbMapping -RemotePath $share -ErrorAction SilentlyContinue | Remove-SmbMapping -Force -ErrorAction SilentlyContinue
$password = Get-LabSecret 'jrivera'
New-SmbMapping -RemotePath $share -UserName $user -Password $password | ForEach-Object { "connected to $($_.RemotePath)  status=$($_.Status)" }
Remove-Variable password
'--- who the server says is connected (Get-SmbSession)'
Get-SmbSession | ForEach-Object { "ClientUserName=$($_.ClientUserName)  ClientComputerName=$($_.ClientComputerName)" }
"--- read attempt $((Get-Date).ToUniversalTime().ToString('s'))Z"
try {
    $text = @(Get-Content -LiteralPath $file -ErrorAction Stop)
    'READ SUCCEEDED'
    $text | ForEach-Object { "    $_" }
} catch {
    "READ FAILED  $($_.Exception.GetType().FullName): $($_.Exception.Message)"
}
if ($AppendLine) {
    "--- write attempt $((Get-Date).ToUniversalTime().ToString('s'))Z"
    try {
        Add-Content -LiteralPath $file -Value $AppendLine -ErrorAction Stop
        "WRITE SUCCEEDED  appended: $AppendLine"
        @(Get-Content -LiteralPath $file) | ForEach-Object { "    $_" }
    } catch {
        "WRITE FAILED  $($_.Exception.GetType().FullName): $($_.Exception.Message)"
    }
}
Remove-SmbMapping -RemotePath $share -Force
Get-SmbSession | Where-Object ClientUserName -eq $user | Close-SmbSession -Force -ErrorAction SilentlyContinue
"disconnected. sessions left for ${user}: $(@(Get-SmbSession | Where-Object ClientUserName -eq $user).Count)"
"=== $Phase -finished $((Get-Date).ToUniversalTime().ToString('s'))Z"
$global:LASTEXITCODE = 0
