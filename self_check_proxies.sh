#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${1:-./ipv6_pool.conf}"

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Config not found: $CONFIG_PATH" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_PATH"

if [[ ! -f "$PROXY_EXPORT_PATH" ]]; then
  echo "Proxy export file not found: $PROXY_EXPORT_PATH" >&2
  exit 1
fi

SAMPLE_SIZE="${SELF_CHECK_SAMPLE_SIZE:-10}"
TIMEOUT_SECONDS="${SELF_CHECK_TIMEOUT_SECONDS:-10}"
STARTUP_TIMEOUT_SECONDS="${SELF_CHECK_STARTUP_TIMEOUT_SECONDS:-60}"
STABLE_CHECK_COUNT="${SELF_CHECK_STABLE_CHECK_COUNT:-3}"

expected_listeners=0
if [[ -f "${PROXY_CFG_PATH:-}" ]]; then
  expected_listeners="$(grep -c '^proxy ' "$PROXY_CFG_PATH" || true)"
fi

if [[ "$expected_listeners" -gt 0 ]]; then
  deadline=$((SECONDS + STARTUP_TIMEOUT_SECONDS))
  stable_hits=0
  while (( SECONDS < deadline )); do
    current_listeners="$(ss -ltnp 2>/dev/null | grep -c 3proxy || true)"
    if [[ "$current_listeners" -ge "$expected_listeners" ]]; then
      ((stable_hits+=1))
      if [[ "$stable_hits" -ge "$STABLE_CHECK_COUNT" ]]; then
        break
      fi
    else
      stable_hits=0
    fi
    sleep 1
  done

  current_listeners="$(ss -ltnp 2>/dev/null | grep -c 3proxy || true)"
  if [[ "$current_listeners" -lt "$expected_listeners" ]]; then
    echo "Listener check: FAIL (${current_listeners}/${expected_listeners})"
    exit 1
  fi

  echo "Listener check: OK (${current_listeners}/${expected_listeners})"
fi

tmp_sample="$(mktemp)"
trap 'rm -f "$tmp_sample"' EXIT

shuf -n "$SAMPLE_SIZE" "$PROXY_EXPORT_PATH" >"$tmp_sample"

pass_count=0
fail_count=0

while IFS=: read -r host port user pass; do
  [[ -n "$host" && -n "$port" && -n "$user" && -n "$pass" ]] || continue

  output="$(curl -sS --max-time "$TIMEOUT_SECONDS" -x "http://${user}:${pass}@127.0.0.1:${port}" http://api64.ipify.org 2>&1 || true)"
  if [[ "$output" =~ ^[0-9a-fA-F:]+$ && "$output" == *:* ]]; then
    echo "${port} -> OK -> ${output}"
    ((pass_count+=1))
  else
    echo "${port} -> FAIL -> ${output:-no response}"
    ((fail_count+=1))
  fi
done <"$tmp_sample"

echo
if [[ "$fail_count" -eq 0 && "$pass_count" -gt 0 ]]; then
  echo "Self-check: PASS (${pass_count}/${pass_count})"
else
  total=$((pass_count + fail_count))
  echo "Self-check: FAIL (${pass_count}/${total})"
  exit 1
fi
