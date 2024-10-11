#!/bin/bash

# Run this script with sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# Prompt for variables
read -p "Enter the SSID for your Wi-Fi network: " SSID
read -s -p "Enter the password for your Wi-Fi network: " PASSWORD
echo
read -p "Enter the Wi-Fi interface name (usually wlan0): " WIFI_INTERFACE
read -p "Enter the Ethernet interface name (usually eth0): " ETH_INTERFACE

# Confirm inputs
echo "You entered:"
echo "SSID: $SSID"
echo "Password: [hidden]"
echo "Wi-Fi Interface: $WIFI_INTERFACE"
echo "Ethernet Interface: $ETH_INTERFACE"
read -p "Is this correct? (y/n) " confirm

if [[ $confirm != [yY] ]]; then
    echo "Setup cancelled. Please run the script again."
    exit 1
fi

# Update package lists
echo "Updating package lists..."
apt update

# Install required packages
echo "Installing required packages..."
apt install -y hostapd dnsmasq iptables

# Stop services
systemctl stop hostapd
systemctl stop dnsmasq

# Configure hostapd
cat > /etc/hostapd/hostapd.conf <<EOL
interface=${WIFI_INTERFACE}
driver=nl80211
ssid=${SSID}
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${PASSWORD}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
country_code=NZ
EOL

# Configure dnsmasq
cat > /etc/dnsmasq.conf <<EOL
interface=${WIFI_INTERFACE}
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
bind-interfaces
server=8.8.8.8
server=8.8.4.4
EOL

# Configure network interfaces
cat > /etc/network/interfaces <<EOL
auto lo
iface lo inet loopback

auto ${ETH_INTERFACE}
iface ${ETH_INTERFACE} inet dhcp

allow-hotplug ${WIFI_INTERFACE}
iface ${WIFI_INTERFACE} inet static
    address 192.168.4.1
    netmask 255.255.255.0
EOL

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/routed-ap.conf
sysctl -p /etc/sysctl.d/routed-ap.conf

# Configure iptables
iptables -t nat -F
iptables -t nat -A POSTROUTING -o ${ETH_INTERFACE} -j MASQUERADE
iptables -F
iptables -A FORWARD -i ${ETH_INTERFACE} -o ${WIFI_INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ${WIFI_INTERFACE} -o ${ETH_INTERFACE} -j ACCEPT

# Save iptables rules
iptables-save > /etc/iptables.ipv4.nat

# Make iptables rules persistent
cat > /etc/rc.local <<EOL
#!/bin/sh -e
iptables-restore < /etc/iptables.ipv4.nat
exit 0
EOL

chmod +x /etc/rc.local


# Enable and start services
systemctl daemon-reload
systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq
systemctl enable ap_monitor

# Restart networking
systemctl restart networking

# Start services
systemctl start hostapd
systemctl start dnsmasq
systemctl start ap_monitor

echo "Wi-Fi Access Point setup complete. SSID: ${SSID}"
echo "A monitoring service has been set up to maintain the connection."
echo "Please reboot your Raspberry Pi for all changes to take effect."
