# Step 2 of the experiment: the folder, the test file, the NTFS permissions and the share.
# Inheritance is removed because a new folder under C:\ inherits read access for ordinary users,
# which would let the "before membership" read succeed. The share permission is left open to
# authenticated users, so NTFS is the layer doing the control.
# Host side: Invoke-DcGuest.ps1 -Domain SOCLAB
"step 2 started $((Get-Date).ToUniversalTime().ToString('s'))Z"
New-Item -ItemType Directory -Path 'C:\LabShares\Lighting' | Out-Null
Set-Content -LiteralPath 'C:\LabShares\Lighting\lighting-schedule-01.txt' -Value 'occupied_until=18:00'
'--- icacls before'
& icacls.exe 'C:\LabShares\Lighting'
'--- change'
& icacls.exe 'C:\LabShares\Lighting' /inheritance:r /grant 'Administrators:(OI)(CI)F' 'SYSTEM:(OI)(CI)F' 'SOCLAB\GG-Lighting-Operators:(OI)(CI)M'
'--- icacls after'
& icacls.exe 'C:\LabShares\Lighting'
& icacls.exe 'C:\LabShares\Lighting\lighting-schedule-01.txt'
'--- share'
New-SmbShare -Name Lighting -Path 'C:\LabShares\Lighting' -FullAccess 'Authenticated Users' | ForEach-Object { "share $($_.Name) -> $($_.Path)" }
Get-SmbShareAccess -Name Lighting | ForEach-Object { "share permission: $($_.AccountName)  $($_.AccessControlType)  $($_.AccessRight)" }
"file content: $(Get-Content -LiteralPath 'C:\LabShares\Lighting\lighting-schedule-01.txt')"
"file sha256: $((Get-FileHash -LiteralPath 'C:\LabShares\Lighting\lighting-schedule-01.txt' -Algorithm SHA256).Hash)"
"step 2 finished $((Get-Date).ToUniversalTime().ToString('s'))Z"
$global:LASTEXITCODE = 0
