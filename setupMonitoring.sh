
cp monitoring_ap.sh /usr/local/bin/
chmod +x /usr/local/bin/monitor_ap.sh

# Create a systemd service for the monitoring script
cat > /etc/systemd/system/ap_monitor.service <<EOL
[Unit]
Description=Monitor and maintain AP connection
After=network.target

[Service]
ExecStart=/usr/local/bin/monitor_ap.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOL
