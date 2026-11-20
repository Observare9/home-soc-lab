"""Run lab maintenance through the loopback SSH port of the local Wazuh VM."""
import json
import os
import shlex
import sys
from pathlib import Path

import paramiko

sys.stdin.reconfigure(encoding="utf-8-sig")
sys.stdout.reconfigure(errors="backslashreplace")
sys.stderr.reconfigure(errors="backslashreplace")
credentials = json.loads(sys.stdin.readline())
script = sys.stdin.read()
user = "wazuh-user"
known_hosts = Path(os.environ["LOCALAPPDATA"]) / "Home SOC Lab" / "known_hosts"
client = paramiko.SSHClient()
first_contact = not known_hosts.exists()
if first_contact:
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
else:
    client.load_host_keys(str(known_hosts))
try:
    connection = dict(hostname="127.0.0.1", port=12222, username=user,
                      look_for_keys=False, allow_agent=False, timeout=10)
    try:
        client.connect(**connection, password=credentials[user])
        fresh = False
    except paramiko.AuthenticationException:
        # A freshly imported appliance still has its published default login.
        client.connect(**connection, password="wazuh")
        fresh = True
    if first_contact:
        # Record the appliance's host key the first time only. Later runs verify against it.
        client.save_host_keys(str(known_hosts))
    if fresh:
        script = "printf '%s\\n' " + shlex.quote(user + ":" + credentials[user]) + " | chpasswd\n" + script
    if "__DASHBOARD_PASSWORD__" in script:
        script = script.replace("__DASHBOARD_PASSWORD__", shlex.quote(credentials["admin"]))
    inp, out, err = client.exec_command("sudo -n /bin/bash -se", timeout=240)
    inp.write(script)
    inp.channel.shutdown_write()
    print(out.read().decode(errors="replace"), end="")
    print(err.read().decode(errors="replace"), file=sys.stderr, end="")
    sys.exit(out.channel.recv_exit_status())
finally:
    client.close()
