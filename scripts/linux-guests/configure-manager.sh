set -eu
uplink=$(ip -4 route show default | awk 'NR==1 {print $5}')
test -n "$uplink"
labdev=$(ls /sys/class/net | grep -vxF -e lo -e "$uplink" | head -n 1)
test -n "$labdev"
mac=$(cat "/sys/class/net/$labdev/address")
if systemctl is-active --quiet systemd-networkd; then
    mkdir -p /etc/systemd/network
    printf '[Match]\nMACAddress=%s\n\n[Network]\nAddress=10.77.0.10/24\nLinkLocalAddressing=no\n' "$mac" > /etc/systemd/network/10-soc-lab.network
    chmod 644 /etc/systemd/network/10-soc-lab.network
    networkctl reload
    networkctl reconfigure "$labdev"
elif systemctl is-active --quiet NetworkManager; then
    if ! nmcli connection show soc-private >/dev/null 2>&1; then
        nmcli connection add type ethernet ifname "$labdev" con-name soc-private ipv4.method manual ipv4.addresses 10.77.0.10/24 ipv4.never-default yes ipv6.method disabled
    fi
    nmcli connection up soc-private
else
    echo 'Private interface needs manual configuration' >&2
    exit 1
fi
for n in $(seq 1 90); do
    if curl -skf --max-time 4 -u admin:admin https://127.0.0.1:9200/ >/dev/null; then break; fi
    if curl -skf --max-time 4 -u admin:__DASHBOARD_PASSWORD__ https://127.0.0.1:9200/ >/dev/null; then break; fi
    sleep 2
done
if ! curl -skf --max-time 8 -u admin:__DASHBOARD_PASSWORD__ https://127.0.0.1:9200/ >/dev/null; then
    tool=/usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-passwords-tool.sh
    bash "$tool" -u admin -p __DASHBOARD_PASSWORD__ >/var/log/soc-lab-password-setup.log 2>&1
fi
curl -skf --max-time 8 -u admin:__DASHBOARD_PASSWORD__ https://127.0.0.1:9200/ >/dev/null
ip -br -4 address
systemctl is-active wazuh-manager wazuh-indexer wazuh-dashboard filebeat
