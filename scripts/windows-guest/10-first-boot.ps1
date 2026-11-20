# Runs once in the guest right after the unattended install.
# Replaces the temporary setup password with the stored Administrator password and turns off automatic sign-in.
# Host side: Invoke-DcGuest.ps1 -CredentialName dc01-install-temp -Secrets @{ administrator = 'dc01-administrator' }
$new = ConvertTo-SecureString (Get-LabSecret 'administrator') -AsPlainText -Force
Set-LocalUser -Name 'Administrator' -Password $new
Remove-Variable new
$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $winlogon -Name AutoAdminLogon -Value '0'
foreach ($name in 'DefaultPassword','AutoLogonCount','ForceAutoLogon') {
    Remove-ItemProperty -Path $winlogon -Name $name -ErrorAction SilentlyContinue
}
"Administrator password replaced and automatic sign-in turned off at $((Get-Date).ToUniversalTime().ToString('s'))Z"
"AutoAdminLogon is now: $((Get-ItemProperty -Path $winlogon).AutoAdminLogon)"
"DefaultPassword value present: $($null -ne (Get-ItemProperty -Path $winlogon).DefaultPassword)"
