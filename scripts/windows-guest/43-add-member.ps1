# Step 4 of the experiment: add the fictional user to the security group.
# Host side: Invoke-DcGuest.ps1 -Domain SOCLAB
"step 4 started $((Get-Date).ToUniversalTime().ToString('s'))Z"
Add-ADGroupMember -Identity 'GG-Lighting-Operators' -Members jrivera
"member added $((Get-Date).ToUniversalTime().ToString('s'))Z"
"members of GG-Lighting-Operators: $((Get-ADGroupMember -Identity 'GG-Lighting-Operators' | ForEach-Object SamAccountName) -join ', ')"
