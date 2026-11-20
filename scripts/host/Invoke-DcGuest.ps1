param(
    [Parameter(Mandatory)][string]$ScriptText,
    # Name of the credential file in the store (without .xml) used to log on in the guest.
    [string]$CredentialName = 'dc01-administrator',
    # Windows domain for the logon. Leave empty before the server is a domain controller, use SOCLAB after.
    [string]$Domain = '',
    # Secrets the guest script needs: guest-side name -> credential file name in the store.
    # Each arrives in the guest as a file and is read with Get-LabSecret '<name>'. Nothing goes on a command line.
    [hashtable]$Secrets = @{},
    [int]$TimeoutSeconds = 900,
    [string]$Vm = 'SOC-DC01'
)
# Runs a PowerShell script inside the SOC-DC01 guest through VirtualBox guest control.
# The host cannot reach the lab's internal network, so this is the only path into the Windows guest.
# VBoxManage needs the logon password in a file. That file is created in the user's own temp folder
# (%LOCALAPPDATA%\Temp), used, and deleted again in this same call. The guest-side script and secret
# files are deleted when it ends. The temp folder is used, and not the credential store, because
# VirtualBox's background service must be able to read the files it copies into the guest.
$ErrorActionPreference = 'Stop'
$vbox = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
$store = Join-Path $env:LOCALAPPDATA 'Home SOC Lab'
$id = [guid]::NewGuid().ToString('N')
$work = Join-Path $env:TEMP "home-soc-lab-$id"
$guestDir = 'C:\LabTemp'
$guestScript = "$guestDir\run-$id.ps1"
$ascii = New-Object System.Text.ASCIIEncoding
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $credential = Import-Clixml -LiteralPath (Join-Path $store "$CredentialName.xml")
    $passwordFile = Join-Path $work 'logon.txt'
    [IO.File]::WriteAllText($passwordFile, $credential.GetNetworkCredential().Password, $ascii)
    $logon = @("--username=$($credential.UserName)", "--passwordfile=$passwordFile")
    if ($Domain) { $logon += "--domain=$Domain" }

    $prefix = @"
`$ErrorActionPreference = 'Stop'
`$ProgressPreference = 'SilentlyContinue'
function Get-LabSecret([string]`$Name) { [IO.File]::ReadAllText("$guestDir\`$Name-$id.secret") }
try {
"@
    $suffix = @"

} catch {
    Write-Output ("GUEST SCRIPT ERROR: " + `$_.Exception.Message)
    Write-Output (`$_.ScriptStackTrace)
    `$global:LASTEXITCODE = 1
} finally {
    Remove-Item -Path "$guestDir\*-$id.secret" -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "$guestScript" -Force -ErrorAction SilentlyContinue
}
exit `$global:LASTEXITCODE
"@
    $localScript = Join-Path $work "run-$id.ps1"
    [IO.File]::WriteAllText($localScript, $prefix + "`r`n" + $ScriptText + $suffix, $utf8Bom)

    $ErrorActionPreference = 'Continue'
    & $vbox guestcontrol $Vm mkdir @logon --parents $guestDir 2>$null | Out-Null
    $toCopy = @($localScript)
    foreach ($name in $Secrets.Keys) {
        $secretFile = Join-Path $work "$name-$id.secret"
        [IO.File]::WriteAllText($secretFile, (Import-Clixml -LiteralPath (Join-Path $store "$($Secrets[$name]).xml")).GetNetworkCredential().Password, $ascii)
        $toCopy += $secretFile
    }
    # The trailing backslash tells VBoxManage the target is an existing directory to copy into.
    & $vbox guestcontrol $Vm copyto @logon "--target-directory=$guestDir\" @toCopy 2>&1 | ForEach-Object { "$_" }
    $copyExit = $LASTEXITCODE
    # The host-side copies of the secrets are no longer needed once they are in the guest.
    Get-ChildItem -LiteralPath $work -Filter '*.secret' | Remove-Item -Force
    if ($copyExit -ne 0) { throw "Could not copy the script into the guest (VBoxManage exit $copyExit)" }
    & $vbox guestcontrol $Vm run @logon --exe 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' --wait-stdout --wait-stderr "--timeout=$($TimeoutSeconds * 1000)" -- -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $guestScript 2>&1 | ForEach-Object { "$_" }
    $guestExit = $LASTEXITCODE
    if ($guestExit -ne 0) { throw "Guest script failed (exit $guestExit)" }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
