# Step 1 of the experiment: the OU, the security group, then the fictional user.
# Host side: Invoke-DcGuest.ps1 -Domain SOCLAB -Secrets @{ jrivera = 'soclab-jrivera' }
"step 1 started $((Get-Date).ToUniversalTime().ToString('s'))Z"
New-ADOrganizationalUnit -Name 'Lab' -Path 'DC=soclab,DC=internal'
"OU created $((Get-Date).ToUniversalTime().ToString('s'))Z"
New-ADGroup -Name 'GG-Lighting-Operators' -GroupScope Global -GroupCategory Security -Path 'OU=Lab,DC=soclab,DC=internal'
"group created $((Get-Date).ToUniversalTime().ToString('s'))Z"
$password = ConvertTo-SecureString (Get-LabSecret 'jrivera') -AsPlainText -Force
New-ADUser -Name 'Jordan Rivera' -SamAccountName jrivera -UserPrincipalName jrivera@soclab.internal -Path 'OU=Lab,DC=soclab,DC=internal' -AccountPassword $password -Enabled $true
Remove-Variable password
"user created $((Get-Date).ToUniversalTime().ToString('s'))Z"
'--- result'
Get-ADOrganizationalUnit -Identity 'OU=Lab,DC=soclab,DC=internal' | ForEach-Object { "OU: $($_.DistinguishedName)" }
Get-ADGroup -Identity 'GG-Lighting-Operators' | ForEach-Object { "group: $($_.DistinguishedName)  scope=$($_.GroupScope)  category=$($_.GroupCategory)  sid=$($_.SID)" }
Get-ADUser -Identity jrivera -Properties MemberOf, whenCreated | ForEach-Object { "user: $($_.DistinguishedName)  enabled=$($_.Enabled)  upn=$($_.UserPrincipalName)  sid=$($_.SID)  whenCreated(local)=$($_.whenCreated)" ; "user is a member of: $(@($_.MemberOf).Count) groups besides Domain Users" }
"members of GG-Lighting-Operators: $(@(Get-ADGroupMember -Identity 'GG-Lighting-Operators').Count)"
