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

if [[ ! -f "$ADDR_LIST_FILE" ]]; then
  echo "Address list not found: $ADDR_LIST_FILE" >&2
  echo "Run add_ipv6_pool.sh first." >&2
  exit 1
fi

mkdir -p "$(dirname "$PROXY_CFG_PATH")"
mkdir -p "$(dirname "$PROXY_EXPORT_PATH")"

detect_ipv4() {
  ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}'
}

ENDPOINT_HOST="${PUBLIC_ENDPOINT_HOST:-}"
if [[ -z "$ENDPOINT_HOST" ]]; then
  ENDPOINT_HOST="$(detect_ipv4 || true)"
fi

if [[ -z "$ENDPOINT_HOST" ]]; then
  echo "Could not detect the public IPv4 host for exported proxies." >&2
  exit 1
fi

{
  echo "maxconn 100"
  echo "nserver 1.1.1.1"
  echo "nserver 2606:4700:4700::1111"
  echo "nscache 65536"
  echo "nscache6 65536"
  echo "timeouts 1 5 30 60 180 1800 15 60"
  echo "setgid 65535"
  echo "setuid 65535"
  echo "stacksize 6291456"
  echo "users ${PROXY_LOGIN}:CL:${PROXY_PASSWORD}"
} >"$PROXY_CFG_PATH"

port="$START_PORT"
>"$PROXY_EXPORT_PATH"
first_entry=1

while IFS= read -r ipv6; do
  {
    if [[ "$first_entry" -eq 0 ]]; then
      echo "flush"
    fi
    echo "auth strong"
    echo "allow ${PROXY_LOGIN}"
    echo "proxy -6 -n -a -p${port} -i${PROXY_LISTEN_IPV4} -e${ipv6}"
  } >>"$PROXY_CFG_PATH"

  echo "${ENDPOINT_HOST}:${port}:${PROXY_LOGIN}:${PROXY_PASSWORD}" >>"$PROXY_EXPORT_PATH"
  first_entry=0
  ((port+=1))
done <"$ADDR_LIST_FILE"

echo "3proxy config : $PROXY_CFG_PATH"
echo "Proxy export  : $PROXY_EXPORT_PATH"
echo "First port    : $START_PORT"
