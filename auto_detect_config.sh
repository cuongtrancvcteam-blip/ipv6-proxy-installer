#!/usr/bin/env bash
set -euo pipefail

OUTPUT_PATH="${1:-./ipv6_pool.conf}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo/root." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_PATH="${SCRIPT_DIR}/ipv6_pool.conf.example"

if [[ ! -f "$TEMPLATE_PATH" ]]; then
  echo "Missing template: $TEMPLATE_PATH" >&2
  exit 1
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

detect_interface() {
  local iface

  iface="$(ip -o route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')"
  if [[ -n "$iface" ]]; then
    printf '%s\n' "$iface"
    return 0
  fi

  iface="$(ip -o -6 route show default 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')"
  if [[ -n "$iface" ]]; then
    printf '%s\n' "$iface"
    return 0
  fi

  return 1
}

detect_primary_ipv6() {
  local iface="$1"

  ip -o -6 addr show dev "$iface" scope global 2>/dev/null \
    | awk '{print $4}' \
    | cut -d/ -f1 \
    | head -n 1
}

detect_ipv6_subnet() {
  local iface="$1"
  local primary_ipv6="$2"
  local subnet

  subnet="$(ip -6 route show dev "$iface" 2>/dev/null | awk '$1 ~ /\/64$/ && $1 !~ /^fe80::/ {print $1; exit}')"
  if [[ -n "$subnet" ]]; then
    printf '%s\n' "$subnet"
    return 0
  fi

  if [[ -n "$primary_ipv6" ]]; then
    python3 - "$primary_ipv6" <<'PY'
import ipaddress
import sys

address = ipaddress.IPv6Address(sys.argv[1])
network = ipaddress.IPv6Network(f"{address}/64", strict=False)
print(network)
PY
    return 0
  fi

  return 1
}

random_string() {
  python3 - "$1" <<'PY'
import secrets
import string
import sys

length = int(sys.argv[1])
alphabet = string.ascii_letters + string.digits
print("".join(secrets.choice(alphabet) for _ in range(length)))
PY
}

require_cmd ip
require_cmd python3
require_cmd sed

INTERFACE_VALUE="${INTERFACE:-$(detect_interface || true)}"
if [[ -z "$INTERFACE_VALUE" ]]; then
  echo "Could not detect the primary network interface." >&2
  exit 1
fi

PRIMARY_IPV6_VALUE="${PRIMARY_IPV6:-$(detect_primary_ipv6 "$INTERFACE_VALUE" || true)}"
if [[ -z "$PRIMARY_IPV6_VALUE" ]]; then
  echo "Could not detect a global IPv6 on ${INTERFACE_VALUE}. Assign IPv6 in the Vultr panel first." >&2
  exit 1
fi

IPV6_SUBNET_VALUE="${IPV6_SUBNET:-$(detect_ipv6_subnet "$INTERFACE_VALUE" "$PRIMARY_IPV6_VALUE" || true)}"
if [[ -z "$IPV6_SUBNET_VALUE" ]]; then
  echo "Could not detect the routed IPv6 /64 on ${INTERFACE_VALUE}." >&2
  exit 1
fi

COUNT_VALUE="${COUNT:-2000}"
RANDOM_SEED_VALUE="${RANDOM_SEED:-$(random_string 24)}"
START_PORT_VALUE="${START_PORT:-30000}"
PROXY_LOGIN_VALUE="${PROXY_LOGIN:-proxy$(python3 - <<'PY'
import secrets
print(secrets.randbelow(9000) + 1000)
PY
)}"
PROXY_PASSWORD_VALUE="${PROXY_PASSWORD:-$(random_string 16)}"
PROXY_LISTEN_IPV4_VALUE="${PROXY_LISTEN_IPV4:-0.0.0.0}"
STATE_DIR_VALUE="${STATE_DIR:-/var/lib/vultr-ipv6-pool}"
ADDR_LIST_FILE_VALUE="${ADDR_LIST_FILE:-${STATE_DIR_VALUE}/ipv6_pool.txt}"
PROXY_CFG_PATH_VALUE="${PROXY_CFG_PATH:-/etc/3proxy/3proxy.cfg}"
PROXY_EXPORT_PATH_VALUE="${PROXY_EXPORT_PATH:-${STATE_DIR_VALUE}/proxy_endpoints.txt}"
DOWNLOAD_EXPORT_PATH_VALUE="${DOWNLOAD_EXPORT_PATH:-/root/proxy_endpoints.txt}"
ENABLE_HTTP_SHARE_VALUE="${ENABLE_HTTP_SHARE:-yes}"
SHARE_PORT_VALUE="${SHARE_PORT:-8080}"
SHARE_DIR_VALUE="${SHARE_DIR:-/opt/vultr-ipv6-share}"
SHARE_FILE_NAME_VALUE="${SHARE_FILE_NAME:-proxy_endpoints.txt}"

sed \
  -e "s|^INTERFACE=.*|INTERFACE=\"$(escape_sed "$INTERFACE_VALUE")\"|" \
  -e "s|^IPV6_SUBNET=.*|IPV6_SUBNET=\"$(escape_sed "$IPV6_SUBNET_VALUE")\"|" \
  -e "s|^PRIMARY_IPV6=.*|PRIMARY_IPV6=\"$(escape_sed "$PRIMARY_IPV6_VALUE")\"|" \
  -e "s|^COUNT=.*|COUNT=$(escape_sed "$COUNT_VALUE")|" \
  -e "s|^RANDOM_SEED=.*|RANDOM_SEED=\"$(escape_sed "$RANDOM_SEED_VALUE")\"|" \
  -e "s|^STATE_DIR=.*|STATE_DIR=\"$(escape_sed "$STATE_DIR_VALUE")\"|" \
  -e "s|^ADDR_LIST_FILE=.*|ADDR_LIST_FILE=\"$(escape_sed "$ADDR_LIST_FILE_VALUE")\"|" \
  -e "s|^START_PORT=.*|START_PORT=$(escape_sed "$START_PORT_VALUE")|" \
  -e "s|^PROXY_LOGIN=.*|PROXY_LOGIN=\"$(escape_sed "$PROXY_LOGIN_VALUE")\"|" \
  -e "s|^PROXY_PASSWORD=.*|PROXY_PASSWORD=\"$(escape_sed "$PROXY_PASSWORD_VALUE")\"|" \
  -e "s|^PROXY_LISTEN_IPV4=.*|PROXY_LISTEN_IPV4=\"$(escape_sed "$PROXY_LISTEN_IPV4_VALUE")\"|" \
  -e "s|^PROXY_CFG_PATH=.*|PROXY_CFG_PATH=\"$(escape_sed "$PROXY_CFG_PATH_VALUE")\"|" \
  -e "s|^PROXY_EXPORT_PATH=.*|PROXY_EXPORT_PATH=\"$(escape_sed "$PROXY_EXPORT_PATH_VALUE")\"|" \
  -e "s|^DOWNLOAD_EXPORT_PATH=.*|DOWNLOAD_EXPORT_PATH=\"$(escape_sed "$DOWNLOAD_EXPORT_PATH_VALUE")\"|" \
  -e "s|^ENABLE_HTTP_SHARE=.*|ENABLE_HTTP_SHARE=\"$(escape_sed "$ENABLE_HTTP_SHARE_VALUE")\"|" \
  -e "s|^SHARE_PORT=.*|SHARE_PORT=$(escape_sed "$SHARE_PORT_VALUE")|" \
  -e "s|^SHARE_DIR=.*|SHARE_DIR=\"$(escape_sed "$SHARE_DIR_VALUE")\"|" \
  -e "s|^SHARE_FILE_NAME=.*|SHARE_FILE_NAME=\"$(escape_sed "$SHARE_FILE_NAME_VALUE")\"|" \
  "$TEMPLATE_PATH" >"$OUTPUT_PATH"

echo "Generated config : $OUTPUT_PATH"
echo "Interface        : $INTERFACE_VALUE"
echo "Primary IPv6     : $PRIMARY_IPV6_VALUE"
echo "Routed subnet    : $IPV6_SUBNET_VALUE"
echo "Proxy username   : $PROXY_LOGIN_VALUE"
echo "Proxy password   : $PROXY_PASSWORD_VALUE"
