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
  exit 1
fi

removed=0
missing=0

while IFS= read -r ipv6; do
  if ip -6 addr show dev "$INTERFACE" | grep -Fq "inet6 ${ipv6}/64"; then
    ip -6 addr del "${ipv6}/64" dev "$INTERFACE"
    ((removed+=1))
  else
    ((missing+=1))
  fi
done <"$ADDR_LIST_FILE"

echo "Removed : $removed"
echo "Missing : $missing"
