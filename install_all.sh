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
apt-get install -y python3 iproute2 curl tar

install_3proxy() {
  if command -v 3proxy >/dev/null 2>&1; then
    return 0
  fi

  if apt-get install -y 3proxy; then
    return 0
  fi

  echo "3proxy is not available in the default apt repositories. Falling back to the official GitHub release..."

  apt-get install -y ca-certificates

  local arch
  local asset_suffix
  local release_api
  local asset_url
  local deb_path

  arch="$(dpkg --print-architecture)"
  case "$arch" in
    amd64)
      asset_suffix=".x86_64.deb"
      ;;
    arm64)
      asset_suffix=".aarch64.deb"
      ;;
    armhf|arm)
      asset_suffix=".arm.deb"
      ;;
    *)
      echo "Unsupported architecture for automatic 3proxy install: $arch" >&2
      exit 1
      ;;
  esac

  release_api="https://api.github.com/repos/3proxy/3proxy/releases/latest"
  asset_url="$(
    curl -fsSL "$release_api" \
      | python3 -c "import json,sys; data=json.load(sys.stdin); suffix=sys.argv[1]; urls=[a['browser_download_url'] for a in data.get('assets', []) if a.get('name','').endswith(suffix)]; print(urls[0] if urls else '')" \
        "$asset_suffix"
  )"

  if [[ -z "$asset_url" ]]; then
    echo "Could not find a matching 3proxy release asset for $arch" >&2
    exit 1
  fi

  deb_path="/tmp/3proxy_latest_${arch}.deb"
  curl -fsSL "$asset_url" -o "$deb_path"
  dpkg -i "$deb_path" || apt-get install -fy
}

install_3proxy

bash "${SCRIPT_DIR}/add_ipv6_pool.sh" "${CONFIG_ABS}"
bash "${SCRIPT_DIR}/install_boot_service.sh" "${CONFIG_ABS}"
bash "${SCRIPT_DIR}/generate_3proxy_cfg.sh" "${CONFIG_ABS}"
bash "${SCRIPT_DIR}/setup_download_link.sh" "${CONFIG_ABS}"

open_firewall_ports() {
  if ! command -v ufw >/dev/null 2>&1; then
    echo "UFW not found. Skipping automatic firewall rules."
    return 0
  fi

  local ufw_status
  ufw_status="$(ufw status 2>/dev/null || true)"
  if [[ "$ufw_status" != Status:\ active* ]]; then
    echo "UFW is not active. Skipping automatic firewall rules."
    return 0
  fi

  local end_port
  end_port=$((START_PORT + COUNT - 1))

  if [[ "${ENABLE_HTTP_SHARE:-yes}" == "yes" ]]; then
    ufw allow "${SHARE_PORT}/tcp"
  fi
  ufw allow "${START_PORT}:${end_port}/tcp"
  ufw reload

  echo "Opened UFW ports : ${START_PORT}-${end_port}/tcp"
  if [[ "${ENABLE_HTTP_SHARE:-yes}" == "yes" ]]; then
    echo "Opened UFW share : ${SHARE_PORT}/tcp"
  fi
}

open_firewall_ports

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
if [[ -n "${PUBLIC_ENDPOINT_HOST:-}" ]]; then
  echo "Proxy host     : $PUBLIC_ENDPOINT_HOST"
fi
if [[ -n "${DOWNLOAD_EXPORT_PATH:-}" ]]; then
  echo "Download copy  : $DOWNLOAD_EXPORT_PATH"
fi
if [[ -n "$DOWNLOAD_URL" ]]; then
  echo "Download URL   : $DOWNLOAD_URL"
fi
echo
echo "Preview:"
head -n 5 "$PROXY_EXPORT_PATH" || true
