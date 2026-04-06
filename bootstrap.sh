#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo/root." >&2
  exit 1
fi

DEFAULT_PACK_URL="https://github.com/cuongtrancvcteam-blip/ipv6-proxy-installer/archive/refs/heads/main.tar.gz"
PACK_URL="${PACK_URL:-$DEFAULT_PACK_URL}"
INSTALL_DIR="${INSTALL_DIR:-/root/vultr_ipv6}"
TMP_TARBALL="/tmp/vultr_ipv6_pack.tar.gz"

apt-get update
apt-get install -y curl tar

mkdir -p "$INSTALL_DIR"
curl -fsSL "$PACK_URL" -o "$TMP_TARBALL"
tar -xzf "$TMP_TARBALL" -C "$INSTALL_DIR" --strip-components=1

shopt -s nullglob
top_level_scripts=("$INSTALL_DIR"/*.sh)
if (( ${#top_level_scripts[@]} > 0 )); then
  chmod +x "${top_level_scripts[@]}"
fi
shopt -u nullglob

echo "Installed pack to: $INSTALL_DIR"
echo
TARGET_DIR="$INSTALL_DIR"

if [[ -d "$INSTALL_DIR/vultr_ipv6" ]]; then
  shopt -s nullglob
  nested_scripts=("$INSTALL_DIR"/vultr_ipv6/*.sh)
  if (( ${#nested_scripts[@]} > 0 )); then
    chmod +x "${nested_scripts[@]}"
  fi
  shopt -u nullglob
  TARGET_DIR="$INSTALL_DIR/vultr_ipv6"
fi

if [[ "${INSTALL_MODE:-auto}" == "interactive" ]]; then
  if [[ -f "$TARGET_DIR/quick_setup.sh" ]]; then
    bash "$TARGET_DIR/quick_setup.sh"
  else
    echo "quick_setup.sh not found after extraction." >&2
    exit 1
  fi
elif [[ -f "$TARGET_DIR/zero_input_install.sh" ]]; then
  bash "$TARGET_DIR/zero_input_install.sh"
else
  echo "zero_input_install.sh not found after extraction." >&2
  exit 1
fi
