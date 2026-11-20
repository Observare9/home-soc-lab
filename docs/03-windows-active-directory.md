# Exercise 2: access control with Active Directory groups, and what the SIEM sees

## Scenario

This continues the lighting-schedule scenario from [exercise 1](02-ubuntu-file-integrity.md). The schedule now lives on a Windows file share. A new operator, Jordan Rivera, should be able to read and edit it only after being added to the operators group. The exercise checks that the control works both ways, and then asks what a SOC analyst can see of it in Wazuh.

All identities are fictional and the forest is lab-only.

| Object | Value |
| --- | --- |
| Server | `SOC-DC01`, Windows Server 2025 Standard Evaluation (Desktop Experience), build 26100.32230, 10.77.0.30 |
| Forest and domain | `soclab.internal`, NetBIOS `SOCLAB` |
| OU | `OU=Lab,DC=soclab,DC=internal` |
| Group | `GG-Lighting-Operators`, global, security |
| User | `jrivera` ("Jordan Rivera") |
| Folder and share | `C:\LabShares\Lighting`, shared as `Lighting` |
| Test file | `lighting-schedule-01.txt`, containing `occupied_until=18:00` |
| Wazuh agent | `soc-dc01`, agent ID 003, version 4.14.10 |

## Design

- **NTFS does the control.** The share permission gives Authenticated Users full access. The folder's NTFS permissions allow only Administrators, SYSTEM and the group (Modify). The more restrictive of the two layers wins, so the group decides who gets in.
- **Inheritance is removed.** A new folder under `C:\` inherits read access for ordinary users. Left in place, that would let the "before membership" read succeed and the test would prove nothing. The `icacls` output before the change shows exactly that inherited `BUILTIN\Users:(RX)` entry.
- **The test is a network logon.** A standard user cannot sign in locally on a domain controller, so the test connects to the share over SMB as `jrivera`.
- **Every attempt uses a new session.** Group membership is read when a session is created. After the membership change the old connection is dropped, any leftover server-side session is closed, and a new one is opened.
- **Auditing.** After promotion the domain controller already audited User Account Management and Security Group Management for success, so no policy change was needed.

## Run of 2026-11-19 (assistant-operated)

This run was carried out by an AI coding assistant working on the lab host at Kevin's direction, using the scripts in [`scripts/windows-guest`](../scripts/windows-guest). Kevin's own repeat, with a second fictional user, is tracked in the [README](../README.md#who-did-what).

Times are UTC by the Windows guest's clock. The run was on the evening of 2026-11-19 US Eastern, which is 2026-11-20 in UTC.

| Step | Time (UTC) | Action | Result |
| --- | --- | --- | --- |
| 1 | 03:56:36 to 03:56:41 | Create the OU, the group, then the user ([`40-create-identity.ps1`](../scripts/windows-guest/40-create-identity.ps1)) | Created. The user is a member of no group besides Domain Users |
| 2 | 03:56:55 | Create the folder, file, permissions and share ([`41-create-share.ps1`](../scripts/windows-guest/41-create-share.ps1)) | `icacls` before and after captured |
| 3 | 03:57:18 | Connect as `SOCLAB\jrivera`, read the file ([`42-access-test.ps1`](../scripts/windows-guest/42-access-test.ps1)) | **Denied.** `System.UnauthorizedAccessException: Access is denied` |
| 4 | 03:57:37 | `Add-ADGroupMember` ([`43-add-member.ps1`](../scripts/windows-guest/43-add-member.ps1)) | `jrivera` is a member |
| 5 | 03:57:42 | New connection as `SOCLAB\jrivera`, read, then append a line | **Allowed.** Read returned `occupied_until=18:00`, append succeeded |

In steps 3 and 5 `Get-SmbSession` on the server showed `SOCLAB\jrivera` as the connected user, so the result belongs to that identity and not to the administrator running the script.

### Second round, from another machine

The first round connects from the server to itself. To make the logon come from a second machine, the test was repeated from the Ubuntu guest (10.77.0.20) with `smbclient` ([`Test-ShareFromUbuntu.ps1`](../scripts/host/Test-ShareFromUbuntu.ps1)).

| Time (UTC) | Action | Result |
| --- | --- | --- |
| 03:59:14 | Remove `jrivera` from the group | Group empty |
| 03:59:44 | From Ubuntu: list the share, read the file | **Denied.** `NT_STATUS_ACCESS_DENIED` on both |
| 04:00:01 | Add `jrivera` again | Member |
| 04:00:10 | From Ubuntu: read the file, append a line, upload it | **Allowed.** |

The captured output of both rounds is in [`evidence/windows-access-test-output.txt`](../evidence/windows-access-test-output.txt).

## What Wazuh recorded

All of these are for agent 003 (`soc-dc01`), and the acting account in every one is `SOCLAB\Administrator`.

| Windows event | Meaning | Event time (UTC) | Wazuh rule | Level | Target |
| --- | --- | --- | --- | --- | --- |
| 4727 | Security-enabled global group created | 03:56:36.272 | 60140 | 5 | `GG-Lighting-Operators` |
| 4720 | User account created | 03:56:39.860 | 60109 | 8 | `jrivera` |
| 4728 | Member added to security-enabled global group | 03:57:37.103 | 60141 | 5 | group `GG-Lighting-Operators`, member `CN=Jordan Rivera,OU=Lab,DC=soclab,DC=internal` |
| 4729 | Member removed from security-enabled global group | 03:59:14.630 | 60142 | 5 | same group and member |
| 4728 | Member added again | 04:00:01.656 | 60141 | 5 | same group and member |

For 4728 and 4729 the field `data.win.eventdata.targetUserName` holds the group. The user is in `memberName` and `memberSid`.

Selected fields of the 4720 and first 4728 alerts are saved in [`evidence/windows-user-creation-alert.json`](../evidence/windows-user-creation-alert.json) and [`evidence/windows-group-membership-alert.json`](../evidence/windows-group-membership-alert.json).

Each SMB connection also produced a 4624 network logon for `jrivera` (logon type 3, NTLM), from 10.77.0.30 in the first round and from 10.77.0.20, workstation `SOC-UBUNTU`, in the second. Wazuh matched them with rule 92657 at level 6.

### What Wazuh did not record

The agent's default configuration filters file-access events out of the Security channel, including 4656, 4663 and 5145. A search of the alert index for those event IDs returned nothing. So the denied read and the permitted read are **not** in Wazuh. The evidence for the access test is the captured command output. Wazuh is the evidence for the account and group changes and for the logons. The default configuration was left as it is, and forwarding file-access events for this one folder is the planned next exercise.

## Triage

**What the alerts establish.** `SOCLAB\Administrator` created a security group and a user account on `SOC-DC01` within a few seconds of each other, added the account to the group about a minute later, removed it and added it again, and the new account then logged on over the network from two different addresses. Each alert gives the time, the acting account and the target.

**What they do not establish.** Whether any of it was authorized, or why it was done. Here the answer comes from the experiment record: one operator made every change deliberately, in the order above. In production it would come from a change ticket or from the administrator.

**Why an analyst would look twice.** A new account that is placed in a group granting access to a share and is used from a second machine within minutes is a pattern worth checking against a ticket, even though each event on its own is routine.

**A note on rule 92657.** Its description reads "possible pass-the-hash attack - Possible RDP connection". The event underneath is a type 3 NTLM logon to an SMB share with a password. The alert title describes one thing that pattern can mean. The fields (logon type, authentication package, source address) say what actually happened.

## Clocks

Event times are the Windows guest's clock and alert times are the Wazuh manager's. Measured against the host, the guest clock was 2.5 seconds ahead just before the run and 6.6 seconds behind just after it, so times here are good to within a few seconds. That is also why one alert's manager timestamp is slightly earlier than its event time.

## Repeating it with a new user

Sign in at the `SOC-DC01` console as `SOCLAB\Administrator` and open PowerShell as administrator.

```powershell
# 1. Create the user. The password is typed at the prompt and never appears in a command.
$pw = Read-Host -AsSecureString 'Password for mchen'
New-ADUser -Name 'Morgan Chen' -SamAccountName mchen -UserPrincipalName mchen@soclab.internal -Path 'OU=Lab,DC=soclab,DC=internal' -AccountPassword $pw -Enabled $true
(Get-Date).ToUniversalTime().ToString('s') + 'Z'
```

```powershell
# 2. Before membership: expect "Access is denied" on the read.
net use \\10.77.0.30\Lighting /user:SOCLAB\mchen *
Get-SmbSession | Select-Object ClientUserName, ClientComputerName
Get-Content \\10.77.0.30\Lighting\lighting-schedule-01.txt
net use \\10.77.0.30\Lighting /delete
Get-SmbSession | Where-Object ClientUserName -eq 'SOCLAB\mchen' | Close-SmbSession -Force
```

```powershell
# 3. Add to the group, open a new connection, read the file.
Add-ADGroupMember -Identity 'GG-Lighting-Operators' -Members mchen
(Get-Date).ToUniversalTime().ToString('s') + 'Z'
net use \\10.77.0.30\Lighting /user:SOCLAB\mchen *
Get-Content \\10.77.0.30\Lighting\lighting-schedule-01.txt
net use \\10.77.0.30\Lighting /delete
```

Then, in the Wazuh dashboard under Threat Hunting, Events:

```
agent.name:"soc-dc01" AND data.win.system.eventID:"4720"
agent.name:"soc-dc01" AND data.win.system.eventID:"4728"
```

Compare the times and names with what you just did, and write a short triage conclusion.
