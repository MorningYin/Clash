[Unit]
Description=Clash Proxy Service
Documentation=https://github.com/MetaCubeX/mihomo
After=network.target

[Service]
Type=simple
User={{USER}}
Group={{GROUP}}
ExecStart={{CLASH_BIN}} -d {{CLASH_CONFIG_DIR}}
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=clash

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths={{CLASH_CONFIG_DIR}}

[Install]
WantedBy=multi-user.target
