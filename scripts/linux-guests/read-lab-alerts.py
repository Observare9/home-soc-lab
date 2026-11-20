import json
from pathlib import Path

log = Path("/var/ossec/logs/alerts/alerts.json")
for raw in log.open():
    if "lighting-schedule" not in raw:
        continue
    entry = json.loads(raw)
    change = entry.get("syscheck", {})
    if not change.get("path", "").startswith("/opt/soc-lab/lighting-schedule"):
        continue
    print(json.dumps({
        "timestamp": entry["timestamp"], "agent": entry["agent"]["name"],
        "agent_id": entry["agent"]["id"], "rule": entry["rule"]["id"],
        "description": entry["rule"]["description"], "file": change["path"],
        "action": change["event"], "before": change.get("sha256_before"),
        "after": change.get("sha256_after")}))
