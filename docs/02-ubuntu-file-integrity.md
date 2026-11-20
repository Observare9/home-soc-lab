# Exercise 1: detecting a change to a lighting schedule (Ubuntu, file integrity monitoring)

## Scenario

A fictional building-controls system keeps its lighting schedule in a text file. An operator changes the time the building is treated as occupied. The question for the analyst is simple: which file changed, on which machine, when, and does the change match a planned maintenance action?

The test file is `/opt/soc-lab/lighting-schedule-01.txt` on the Ubuntu endpoint. It holds one line, `occupied_until=18:00` or `occupied_until=19:00`.

## Setup

- Endpoint: `SOC-Ubuntu`, Ubuntu 24.04, hostname `soc-ubuntu`, 10.77.0.20, Wazuh agent 4.14.10.
- Manager: `SOC-Wazuh`, Wazuh 4.14.10 (manager, indexer and dashboard on one appliance), 10.77.0.10.
- The agent watches the lab directory in real time. This line sits in the `<syscheck>` block of `/var/ossec/etc/ossec.conf` on the endpoint:

```xml
<directories realtime="yes" check_all="yes">/opt/soc-lab</directories>
```

[`scripts/linux-guests/enroll-ubuntu.sh`](../scripts/linux-guests/enroll-ubuntu.sh) installs the agent and adds that line.

## Run of 2026-11-19 (assistant-operated)

This run was carried out by an AI coding assistant working on the lab host at Kevin's direction. Kevin's own repeat is tracked in the [README](../README.md#who-did-what).

1. Confirmed the agent's baseline scan had finished and real-time monitoring of `/opt/soc-lab` was active (agent log lines 6016 and 6009).
2. Recorded the file's contents and SHA-256 hash on the endpoint.
3. Changed the occupied time from 19:00 to 18:00 and recorded the new hash.
4. Read the alert back from the manager's `alerts.json` and from the alert index.

| | Value |
| --- | --- |
| Change made on the endpoint | between 21:57:40.966 and 21:57:41.093 UTC by the endpoint's clock |
| Alert time | 2026-11-19 21:57:40.968 UTC (4:57:40 p.m. Eastern), by the manager's clock |
| Rule | 550, "Integrity checksum changed.", level 7 |
| Agent | 002, `soc-ubuntu`, 10.77.0.20 |
| File | `/opt/soc-lab/lighting-schedule-01.txt` |
| Monitoring mode | realtime |
| Changed attributes | mtime, md5, sha1, sha256 |
| SHA-256 before | `2a0106a6f567db3fe98598e9b2d7e2e6a78e6e73af3068a1d798be0886c59e64` |
| SHA-256 after | `9e0f6ecb0fe89bf3f562adb011df11f3a09791365f814b7a50bd28c994478143` |

Both hashes were measured independently on the endpoint with `sha256sum` and match the alert. A search of the alert index for the agent name, rule 550 and this path returned exactly one document. The selected fields are saved in [`evidence/ubuntu-lighting-schedule-alert.json`](../evidence/ubuntu-lighting-schedule-alert.json).

## Triage

The change was expected. The operator deliberately edited one test file at the recorded time, and the alert agrees with the experiment record on the endpoint, the path and both hashes.

What the alert establishes: which endpoint, which file, when the manager saw it, and that the contents changed from one known value to another.

What it does not establish: who made the change or whether it was authorized. A hash cannot answer either question. In this exercise the answer comes from the experiment record. In production it would come from a change ticket, the account's session history, or audit data such as `auditd` who-data.

## Repeating it

Start `SOC-Wazuh` and `SOC-Ubuntu`. Allow about two minutes for the dashboard. From PowerShell on the host:

```powershell
& 'D:\Home SOC Lab\Ubuntu-SSH.ps1' 'f=/opt/soc-lab/lighting-schedule-01.txt; cat "$f"; sha256sum "$f"; if grep -Fxq occupied_until=18:00 "$f"; then new=19:00; else new=18:00; fi; printf "occupied_until=%s\n" "$new" > "$f"; date -u +%FT%TZ; cat "$f"; sha256sum "$f"'
```

The command prints the current value and hash, switches the occupied time between 18:00 and 19:00, and prints the UTC time, the new value and the new hash.

Then open the dashboard at `https://127.0.0.1:18443`, go to Threat Hunting, set a time range that covers the run, and search:

```
agent.name:"soc-ubuntu" AND rule.id:"550"
```

Compare the alert's time, path and both hashes with what the command printed. The new "before" hash should equal the previous run's "after" hash, because the file is switching between the same two contents.
