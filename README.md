# Home SOC lab

A personal home security operations lab: a Wazuh SIEM, a Linux endpoint, a Windows Server 2025 domain controller and a Kali guest on one isolated virtual network. Each exercise makes one deliberate change, finds it in the SIEM, and writes down what the alert proves and what it does not.

Owner: Kevin Reeves ([@Observare9](https://github.com/Observare9)).

## The lab

| VM | Role | Lab address |
| --- | --- | --- |
| `SOC-Wazuh` | Wazuh 4.14.10 manager, indexer and dashboard | 10.77.0.10 |
| `SOC-Ubuntu` | Ubuntu 24.04 endpoint, Wazuh agent `soc-ubuntu` | 10.77.0.20 |
| `SOC-DC01` | Windows Server 2025 domain controller for `soclab.internal`, Wazuh agent `soc-dc01` | 10.77.0.30 |
| `SOC-Kali` | Kali Linux guest | 10.77.0.40 |

Everything runs in VirtualBox on one Windows 11 PC, on an internal network (`SOC-LAB`, 10.77.0.0/24) that the host and the home network cannot reach. The Windows server has no other adapter, so Active Directory, DNS and SMB only exist inside the lab. See [lab architecture](docs/01-lab-architecture.md).

## Exercises

| # | Exercise | What was shown | Write-up |
| --- | --- | --- | --- |
| 1 | File integrity monitoring on Linux | A one-line change to a monitored file raised Wazuh rule 550 within a second, with before and after SHA-256 hashes that match hashes taken on the endpoint | [Ubuntu file integrity](docs/02-ubuntu-file-integrity.md) |
| 2 | Access control with Active Directory groups | A new user was denied a file share until added to a security group, tested from the server and from a second machine. Wazuh recorded the group creation (4727), the account creation (4720) and the membership changes (4728, 4729) | [Windows and Active Directory](docs/03-windows-active-directory.md) |

Each write-up has a triage section. The short version is the same both times: the alert tells you what changed, where and when, and for Windows which account did it. It does not tell you whether the change was authorized. That has to come from somewhere else.

A known gap, stated plainly: the Windows agent's default configuration does not forward file-access events, so the denied and permitted file reads in exercise 2 are not in Wazuh. They are evidenced by captured command output. Closing that gap is the next exercise.

## Who did what

This matters for reading the evidence honestly.

- **The build and the first verified run of each exercise were assistant-operated.** AI coding assistants ran the commands on the lab host at Kevin's direction: the Wazuh and Ubuntu setup in one session, and the lab rename, the Windows Server installation, the domain controller promotion and both evidence runs in this repository in another (Claude, on 2026-11-19). The evidence files and write-ups record those runs.
- **Kevin's own repeats are tracked here** and are added as he does them.

| Exercise | Assistant-operated run | Kevin's own repeat |
| --- | --- | --- |
| 1, Ubuntu file integrity | 2026-11-19 | Pending |
| 2, Windows and Active Directory | 2026-11-19 | Pending, with a second fictional user (`mchen`) |

## Repository layout

```
docs/       Architecture, the two exercise write-ups, and build notes
evidence/   Selected alert fields and captured command output from the runs
scripts/
  host/           PowerShell and Python run on the Windows host to reach each guest
  linux-guests/   Shell and Python run inside the Wazuh appliance and the Ubuntu endpoint
  windows-guest/  PowerShell run inside SOC-DC01, numbered in the order it ran
```

The [build notes](docs/04-build-notes.md) cover what went wrong along the way and how each problem was resolved. They are the most useful part if you are building something similar.

## What is deliberately not here

No passwords, credential files, agent keys, certificates, SSH keys, VM disks or installation media. Passwords are generated and kept in an encrypted per-user store on the lab host, and the scripts read them at run time. The setup scripts mention the Wazuh appliance's published default logins only to detect a freshly imported appliance, and the lab replaces them during setup. All user names, group names and the domain are fictional.

## Running the scripts

The scripts assume this lab's names, addresses and folder (`D:\Home SOC Lab`). They are published as a record of what was run, and as a starting point, more than as a turnkey installer. Read a script before running it.
