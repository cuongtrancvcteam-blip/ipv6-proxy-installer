#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${1:-./ipv6_pool.conf}"

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Config not found: $CONFIG_PATH" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_PATH"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo/root." >&2
  exit 1
fi

if [[ "${ENABLE_HTTP_SHARE:-yes}" != "yes" ]]; then
  echo "HTTP sharing is disabled in config."
  exit 0
fi

if [[ ! -f "$PROXY_EXPORT_PATH" ]]; then
  echo "Proxy export file not found: $PROXY_EXPORT_PATH" >&2
  exit 1
fi

mkdir -p "$SHARE_DIR"
install -m 644 "$PROXY_EXPORT_PATH" "${SHARE_DIR}/${SHARE_FILE_NAME}"

SERVICE_PATH="/etc/systemd/system/vultr-ipv6-export-http.service"

cat >"$SERVICE_PATH" <<EOF
[Unit]
Description=Simple HTTP server for Vultr IPv6 export file
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -m http.server ${SHARE_PORT} --bind 0.0.0.0 --directory ${SHARE_DIR}
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vultr-ipv6-export-http.service
systemctl restart vultr-ipv6-export-http.service

detect_ipv4() {
  ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}'
}

PUBLIC_IPV4="$(detect_ipv4 || true)"

echo "Shared file path : ${SHARE_DIR}/${SHARE_FILE_NAME}"
if [[ -n "$PUBLIC_IPV4" ]]; then
  echo "Download URL     : http://${PUBLIC_IPV4}:${SHARE_PORT}/${SHARE_FILE_NAME}"
else
  echo "Download URL     : http://<your-vps-ip>:${SHARE_PORT}/${SHARE_FILE_NAME}"
fi
