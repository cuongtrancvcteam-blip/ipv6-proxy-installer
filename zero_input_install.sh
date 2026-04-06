#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo/root." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="${CONFIG_PATH:-${SCRIPT_DIR}/ipv6_pool.auto.conf}"

bash "${SCRIPT_DIR}/auto_detect_config.sh" "$CONFIG_PATH"
echo
echo "Starting zero-input install..."
echo
bash "${SCRIPT_DIR}/install_all.sh" "$CONFIG_PATH"
