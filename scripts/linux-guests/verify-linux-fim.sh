set -eu
config=/var/ossec/etc/ossec.conf
lab=/opt/soc-lab
mkdir -p "$lab"
if ! grep -Fq ">$lab</directories>" "$config"; then
    cp -p "$config" "$config.soc-lab-$(date +%s)"
    sed -i "0,/<syscheck>/{s|<syscheck>|<syscheck>\n    <directories realtime=\"yes\" check_all=\"yes\">$lab</directories>|;}" "$config"
    /var/ossec/bin/wazuh-syscheckd -t
    systemctl restart wazuh-manager
fi
for n in $(seq 1 90); do
    if grep -i 'real.time' /var/ossec/logs/ossec.log | grep -Fq "$lab"; then break; fi
    sleep 2
done
file="$lab/lighting-schedule-$(date +%s).txt"
printf 'occupied_until=18:00\n' > "$file"
# Wait until Wazuh has observed the original file before changing it.
alerts=/var/ossec/logs/alerts/alerts.json
for n in $(seq 1 45); do
    if grep -F "$file" "$alerts" | grep -q '"added"'; then break; fi
    sleep 2
done
printf 'occupied_until=19:00\n' > "$file"
for n in $(seq 1 45); do
    if grep -F "$file" "$alerts" | grep -q '"modified"'; then break; fi
    sleep 2
done
python3 - "$alerts" "$file" <<'PY'
import json, sys
events = []
with open(sys.argv[1]) as stream:
    for line in stream:
        if sys.argv[2] not in line:
            continue
        a = json.loads(line)
        f = a.get('syscheck', {})
        if f.get('path') == sys.argv[2]:
            events.append(dict(time=a['timestamp'], rule=a['rule']['id'],
                description=a['rule']['description'], agent=a['agent']['id'],
                path=f['path'], event=f['event'], before=f.get('sha256_before'),
                after=f.get('sha256_after')))
print(json.dumps(events, indent=2))
if not any(e['event']=='modified' and e['before'] and e['before']!=e['after'] for e in events):
    sys.exit('No matching file modification alert with before/after hashes')
PY
