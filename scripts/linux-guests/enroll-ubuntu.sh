set -eu
export DEBIAN_FRONTEND=noninteractive
mkdir -p /opt/soc-lab /etc/apt/keyrings
if ! dpkg-query -W -f='${Status}' wazuh-agent 2>/dev/null | grep -q 'install ok installed'; then
    curl -fsSL https://packages.wazuh.com/key/GPG-KEY-WAZUH -o /tmp/wazuh.key
    gpg --batch --yes --dearmor -o /etc/apt/keyrings/wazuh.gpg /tmp/wazuh.key
    chmod 644 /etc/apt/keyrings/wazuh.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main' > /etc/apt/sources.list.d/wazuh.list
    apt-get update -o Dir::Etc::sourcelist=sources.list.d/wazuh.list -o Dir::Etc::sourceparts=- -o APT::Get::List-Cleanup=0
    WAZUH_MANAGER=10.77.0.10 WAZUH_AGENT_NAME=soc-ubuntu apt-get install -y wazuh-agent=4.14.10-1
    # Keep the agent from upgrading past the manager's version.
    apt-mark hold wazuh-agent
fi
config=/var/ossec/etc/ossec.conf
if ! grep -Fq '>/opt/soc-lab</directories>' "$config"; then
    cp -p "$config" "$config.original"
    sed -i '0,/<syscheck>/{s|<syscheck>|<syscheck>\n    <directories realtime="yes" check_all="yes">/opt/soc-lab</directories>|;}' "$config"
fi
/var/ossec/bin/wazuh-syscheckd -t
systemctl enable wazuh-agent
systemctl restart wazuh-agent
systemctl is-active wazuh-agent
