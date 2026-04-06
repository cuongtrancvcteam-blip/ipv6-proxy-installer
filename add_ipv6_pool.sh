#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${1:-./ipv6_pool.conf}"

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Config not found: $CONFIG_PATH" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_PATH"

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this script with sudo/root." >&2
    exit 1
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

generate_addresses() {
  python3 - "$IPV6_SUBNET" "$COUNT" "$RANDOM_SEED" "$PRIMARY_IPV6" <<'PY'
import hashlib
import ipaddress
import sys

subnet = ipaddress.IPv6Network(sys.argv[1], strict=False)
count = int(sys.argv[2])
seed = sys.argv[3]
primary = sys.argv[4].strip()

if subnet.prefixlen != 64:
    raise SystemExit("This script expects a routed /64 subnet.")

reserved = {subnet.network_address}
if primary:
    reserved.add(ipaddress.IPv6Address(primary))

generated = []
seen = set(reserved)
index = 0

while len(generated) < count:
    digest = hashlib.sha256(f"{seed}:{index}".encode()).digest()
    host_bits = int.from_bytes(digest[:8], "big")
    address = ipaddress.IPv6Address(int(subnet.network_address) | host_bits)
    index += 1
    if address in seen:
        continue
    seen.add(address)
    generated.append(address)

for address in generated:
    print(address)
PY
}

require_root
require_cmd ip
require_cmd python3

mkdir -p "$STATE_DIR"
tmp_list="$(mktemp)"
trap 'rm -f "$tmp_list"' EXIT

generate_addresses >"$tmp_list"

added=0
skipped=0

while IFS= read -r ipv6; do
  if ip -6 addr show dev "$INTERFACE" | grep -Fq "inet6 ${ipv6}/64"; then
    ((skipped+=1))
    continue
  fi

  ip -6 addr add "${ipv6}/64" dev "$INTERFACE" nodad valid_lft forever preferred_lft forever
  ((added+=1))
done <"$tmp_list"

install -m 600 "$tmp_list" "$ADDR_LIST_FILE"

echo "Interface : $INTERFACE"
echo "Subnet    : $IPV6_SUBNET"
echo "Added     : $added"
echo "Skipped   : $skipped"
echo "Saved list: $ADDR_LIST_FILE"
