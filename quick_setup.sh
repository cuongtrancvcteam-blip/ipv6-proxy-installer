#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo/root." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_TEMPLATE="${SCRIPT_DIR}/ipv6_pool.conf.example"
CONFIG_PATH="${SCRIPT_DIR}/ipv6_pool.conf"

if [[ ! -f "$CONFIG_TEMPLATE" ]]; then
  echo "Missing template: $CONFIG_TEMPLATE" >&2
  exit 1
fi

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

read -rp "Network interface [eth0]: " INTERFACE
INTERFACE="${INTERFACE:-eth0}"

read -rp "Vultr IPv6 subnet (example 2001:19f0:1234:5678::/64): " IPV6_SUBNET
if [[ -z "$IPV6_SUBNET" ]]; then
  echo "IPv6 subnet is required." >&2
  exit 1
fi

read -rp "Primary IPv6 to avoid [optional]: " PRIMARY_IPV6
read -rp "How many IPv6 addresses [2000]: " COUNT
COUNT="${COUNT:-2000}"

read -rp "Random seed [vultr-ipv6-pool]: " RANDOM_SEED
RANDOM_SEED="${RANDOM_SEED:-vultr-ipv6-pool}"

read -rp "Start proxy port [30000]: " START_PORT
START_PORT="${START_PORT:-30000}"

read -rp "Proxy username [proxyuser]: " PROXY_LOGIN
PROXY_LOGIN="${PROXY_LOGIN:-proxyuser}"

read -rp "Proxy password [changeme]: " PROXY_PASSWORD
PROXY_PASSWORD="${PROXY_PASSWORD:-changeme}"

read -rp "Downloadable export path [/root/proxy_endpoints.txt]: " DOWNLOAD_EXPORT_PATH
DOWNLOAD_EXPORT_PATH="${DOWNLOAD_EXPORT_PATH:-/root/proxy_endpoints.txt}"

INTERFACE_ESCAPED="$(escape_sed "$INTERFACE")"
IPV6_SUBNET_ESCAPED="$(escape_sed "$IPV6_SUBNET")"
PRIMARY_IPV6_ESCAPED="$(escape_sed "$PRIMARY_IPV6")"
RANDOM_SEED_ESCAPED="$(escape_sed "$RANDOM_SEED")"
PROXY_LOGIN_ESCAPED="$(escape_sed "$PROXY_LOGIN")"
PROXY_PASSWORD_ESCAPED="$(escape_sed "$PROXY_PASSWORD")"
DOWNLOAD_EXPORT_PATH_ESCAPED="$(escape_sed "$DOWNLOAD_EXPORT_PATH")"

sed \
  -e "s|^INTERFACE=.*|INTERFACE=\"${INTERFACE_ESCAPED}\"|" \
  -e "s|^IPV6_SUBNET=.*|IPV6_SUBNET=\"${IPV6_SUBNET_ESCAPED}\"|" \
  -e "s|^PRIMARY_IPV6=.*|PRIMARY_IPV6=\"${PRIMARY_IPV6_ESCAPED}\"|" \
  -e "s|^COUNT=.*|COUNT=${COUNT}|" \
  -e "s|^RANDOM_SEED=.*|RANDOM_SEED=\"${RANDOM_SEED_ESCAPED}\"|" \
  -e "s|^START_PORT=.*|START_PORT=${START_PORT}|" \
  -e "s|^PROXY_LOGIN=.*|PROXY_LOGIN=\"${PROXY_LOGIN_ESCAPED}\"|" \
  -e "s|^PROXY_PASSWORD=.*|PROXY_PASSWORD=\"${PROXY_PASSWORD_ESCAPED}\"|" \
  -e "s|^DOWNLOAD_EXPORT_PATH=.*|DOWNLOAD_EXPORT_PATH=\"${DOWNLOAD_EXPORT_PATH_ESCAPED}\"|" \
  "$CONFIG_TEMPLATE" >"$CONFIG_PATH"

echo
echo "Generated config: $CONFIG_PATH"
echo "Starting full install..."
echo

bash "${SCRIPT_DIR}/install_all.sh" "$CONFIG_PATH"
