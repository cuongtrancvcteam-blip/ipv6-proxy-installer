#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${1:-./ipv6_pool.conf}"

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Config not found: $CONFIG_PATH" >&2
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo/root." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ABS="$(cd "$(dirname "$CONFIG_PATH")" && pwd)/$(basename "$CONFIG_PATH")"
SERVICE_PATH="/etc/systemd/system/vultr-ipv6-pool.service"

cat >"$SERVICE_PATH" <<EOF
[Unit]
Description=Assign generated IPv6 pool on boot
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${SCRIPT_DIR}/add_ipv6_pool.sh ${CONFIG_ABS}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vultr-ipv6-pool.service

echo "Installed systemd service: $SERVICE_PATH"
echo "Run: sudo systemctl start vultr-ipv6-pool.service"
