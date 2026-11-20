# Downloads the Wazuh agent installer while the temporary NAT adapter is up, and checks its signature.
# The agent version must not be newer than the manager (4.14.10).
$dir = 'C:\LabSetup'
$msi = Join-Path $dir 'wazuh-agent-4.14.10-1.msi'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri 'https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.10-1.msi' -OutFile $msi -UseBasicParsing
$item = Get-Item -LiteralPath $msi
"downloaded: $($item.FullName)  bytes: $($item.Length)"
"sha256: $((Get-FileHash -LiteralPath $msi -Algorithm SHA256).Hash)"
$sig = Get-AuthenticodeSignature -LiteralPath $msi
"signature status: $($sig.Status)"
"signer: $($sig.SignerCertificate.Subject)"
if ($sig.Status -ne 'Valid') { throw 'The installer signature is not valid. Do not install it.' }
