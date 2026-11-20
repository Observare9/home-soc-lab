param(
    # Label printed with the result, for example 'before membership'.
    [Parameter(Mandatory)][string]$Phase,
    # Also download the file, append this line and upload it again. Leave empty for a read-only test.
    [string]$AppendLine = ''
)
# Tries the Lighting share as SOCLAB\jrivera from the SOC-Ubuntu guest (10.77.0.20) with smbclient,
# so the network logon on the domain controller comes from a second machine.
# The password is read from the credential store and sent to Ubuntu inside the script on ssh's standard input.
# On Ubuntu it lives in a root-only file for the length of the test and is then overwritten and removed.
$ErrorActionPreference = 'Stop'
$password = (Import-Clixml -LiteralPath (Join-Path $env:LOCALAPPDATA 'Home SOC Lab\soclab-jrivera.xml')).GetNetworkCredential().Password
$script = @'
exec 2>&1
set +e
umask 077
auth=$(mktemp /root/.soclab-auth.XXXXXX)
work=$(mktemp -d /root/.soclab-work.XXXXXX)
cat > "$auth" <<'AUTH'
username = jrivera
password = __JRIVERA_PASSWORD__
domain = SOCLAB
AUTH
echo "=== __PHASE__ - from $(hostname) ($(hostname -I | tr ' ' '\n' | grep '^10\.77\.') ) started $(date -u +%FT%TZ)"
echo "--- list the share"
smbclient //10.77.0.30/Lighting -A "$auth" -c 'ls'
echo "--- read attempt $(date -u +%FT%TZ)"
if smbclient //10.77.0.30/Lighting -A "$auth" -c "get lighting-schedule-01.txt $work/copy.txt" && [ -f "$work/copy.txt" ]; then
    echo "READ SUCCEEDED"; sed 's/\r$//; s/^/    /' "$work/copy.txt"
else
    echo "READ FAILED"
fi
append='__APPEND__'
if [ -n "$append" ] && [ -f "$work/copy.txt" ]; then
    echo "--- write attempt $(date -u +%FT%TZ)"
    printf '%s\r\n' "$append" >> "$work/copy.txt"
    if smbclient //10.77.0.30/Lighting -A "$auth" -c "put $work/copy.txt lighting-schedule-01.txt"; then echo "WRITE SUCCEEDED  appended: $append"; else echo "WRITE FAILED"; fi
fi
shred -u "$auth" 2>/dev/null || rm -f "$auth"
rm -rf "$work"
echo "=== __PHASE__ - finished $(date -u +%FT%TZ)"
exit 0
'@
$script = $script.Replace('__PHASE__', $Phase).Replace('__APPEND__', $AppendLine).Replace('__JRIVERA_PASSWORD__', $password)
Remove-Variable password
& "$PSScriptRoot\Ubuntu-SSH.ps1" $script
