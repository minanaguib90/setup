#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR=""
LABEL="snapshot"
USE_SUDO=1

usage() {
  cat <<'EOF'
Usage: asterisk-voip-snapshot.sh [--output DIR] [--label NAME] [--no-sudo]

Collect a bounded snapshot of Asterisk, RTP, network, and firewall state into
one directory for later analysis.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --label)
      LABEL="${2:-snapshot}"
      shift 2
      ;;
    --no-sudo)
      USE_SUDO=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

timestamp="$(date +%Y%m%d-%H%M%S)"
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$(pwd)/voip-snapshot-${LABEL}-${timestamp}"
else
  OUTPUT_DIR="${OUTPUT_DIR%/}/voip-snapshot-${LABEL}-${timestamp}"
fi

mkdir -p "$OUTPUT_DIR"

SUDO=()
if [[ "$USE_SUDO" -eq 1 ]] && command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  SUDO=(sudo)
fi

run_shell() {
  local cmd="$1"
  if [[ ${#SUDO[@]} -gt 0 ]]; then
    "${SUDO[@]}" bash -lc "$cmd"
  else
    bash -lc "$cmd"
  fi
}

capture_shell() {
  local file="$1"
  local cmd="$2"
  {
    printf '$ %s\n' "$cmd"
    run_shell "$cmd"
  } > "${OUTPUT_DIR}/${file}" 2>&1 || true
}

capture_plain() {
  local file="$1"
  shift
  {
    printf '$'
    printf ' %q' "$@"
    printf '\n'
    "$@"
  } > "${OUTPUT_DIR}/${file}" 2>&1 || true
}

{
  echo "label=${LABEL}"
  echo "timestamp=${timestamp}"
  echo "hostname=$(hostname)"
  echo "pwd=$(pwd)"
  if [[ ${#SUDO[@]} -gt 0 ]]; then
    echo "sudo=enabled"
  else
    echo "sudo=disabled"
  fi
} > "${OUTPUT_DIR}/meta.txt"

capture_plain "uname.txt" uname -a
capture_plain "date.txt" date -Is

if command -v asterisk >/dev/null 2>&1; then
  capture_plain "asterisk-version.txt" asterisk -V
  capture_shell "asterisk-uptime.txt" "asterisk -rx 'core show uptime'"
  capture_shell "asterisk-channels-concise.txt" "asterisk -rx 'core show channels concise'"
  capture_shell "pjsip-transports.txt" "asterisk -rx 'pjsip show transports'"
  capture_shell "pjsip-endpoints.txt" "asterisk -rx 'pjsip show endpoints'"
  capture_shell "pjsip-aors.txt" "asterisk -rx 'pjsip show aors'"
  capture_shell "pjsip-registrations.txt" "asterisk -rx 'pjsip show registrations'"
  capture_shell "sip-peers.txt" "asterisk -rx 'sip show peers'"
else
  echo "asterisk binary not found" > "${OUTPUT_DIR}/asterisk-version.txt"
fi

if command -v fwconsole >/dev/null 2>&1; then
  capture_plain "fwconsole-version.txt" fwconsole --version
  capture_shell "fwconsole-sip-driver.txt" "fwconsole setting SIPCHANNELDRIVER"
fi

capture_shell "ip-addr.txt" "ip addr"
capture_shell "ip-route.txt" "ip route"
capture_shell "ss-lunp.txt" "ss -lunp"
capture_shell "ss-tunp.txt" "ss -tunp"

if command -v ufw >/dev/null 2>&1; then
  capture_shell "ufw-status.txt" "ufw status verbose"
fi
if command -v iptables >/dev/null 2>&1; then
  capture_shell "iptables.txt" "iptables -S"
fi
if command -v nft >/dev/null 2>&1; then
  capture_shell "nft.txt" "nft list ruleset"
fi
if command -v firewall-cmd >/dev/null 2>&1; then
  capture_shell "firewalld.txt" "firewall-cmd --list-all"
fi

capture_shell "journalctl-asterisk.txt" "journalctl -u asterisk -n 200 --no-pager"
capture_shell "asterisk-full-tail.txt" "tail -n 400 /var/log/asterisk/full"

mkdir -p "${OUTPUT_DIR}/config"
shopt -s nullglob
for path in /etc/asterisk/pjsip*.conf /etc/asterisk/extensions*.conf /etc/asterisk/rtp*.conf; do
  capture_shell "config/$(basename "$path")" "cat '$path'"
done
shopt -u nullglob

echo "Snapshot saved to ${OUTPUT_DIR}"
