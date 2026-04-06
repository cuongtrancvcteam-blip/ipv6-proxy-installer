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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ABS="$(cd "$(dirname "$CONFIG_PATH")" && pwd)/$(basename "$CONFIG_PATH")"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y python3 iproute2 3proxy curl tar

bash "${SCRIPT_DIR}/add_ipv6_pool.sh" "${CONFIG_ABS}"
bash "${SCRIPT_DIR}/install_boot_service.sh" "${CONFIG_ABS}"
bash "${SCRIPT_DIR}/generate_3proxy_cfg.sh" "${CONFIG_ABS}"
bash "${SCRIPT_DIR}/setup_download_link.sh" "${CONFIG_ABS}"

THREEPROXY_BIN="$(command -v 3proxy)"
THREEPROXY_SERVICE="/etc/systemd/system/3proxy-vultr-ipv6.service"

cat >"$THREEPROXY_SERVICE" <<EOF
[Unit]
Description=3proxy bound to generated Vultr IPv6 pool
After=network-online.target vultr-ipv6-pool.service
Wants=network-online.target
Requires=vultr-ipv6-pool.service

[Service]
Type=simple
ExecStart=${THREEPROXY_BIN} ${PROXY_CFG_PATH}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vultr-ipv6-pool.service
systemctl enable 3proxy-vultr-ipv6.service
systemctl restart vultr-ipv6-pool.service
systemctl restart 3proxy-vultr-ipv6.service

if [[ -n "${DOWNLOAD_EXPORT_PATH:-}" ]]; then
  install -m 600 "$PROXY_EXPORT_PATH" "$DOWNLOAD_EXPORT_PATH"
fi

detect_ipv4() {
  ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}'
}

PUBLIC_IPV4="$(detect_ipv4 || true)"
DOWNLOAD_URL=""
if [[ "${ENABLE_HTTP_SHARE:-yes}" == "yes" && -n "${PUBLIC_IPV4}" ]]; then
  DOWNLOAD_URL="http://${PUBLIC_IPV4}:${SHARE_PORT}/${SHARE_FILE_NAME}"
fi

echo
echo "Install completed."
echo "Config path     : $CONFIG_ABS"
echo "IPv6 list      : $ADDR_LIST_FILE"
echo "3proxy config  : $PROXY_CFG_PATH"
echo "Proxy text file: $PROXY_EXPORT_PATH"
echo "Proxy username : $PROXY_LOGIN"
echo "Proxy password : $PROXY_PASSWORD"
if [[ -n "${DOWNLOAD_EXPORT_PATH:-}" ]]; then
  echo "Download copy  : $DOWNLOAD_EXPORT_PATH"
fi
if [[ -n "$DOWNLOAD_URL" ]]; then
  echo "Download URL   : $DOWNLOAD_URL"
fi
echo
echo "Preview:"
head -n 5 "$PROXY_EXPORT_PATH" || true
