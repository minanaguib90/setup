#!/usr/bin/env bash
set -euo pipefail

IFACE="any"
HOST_FILTER=""
DURATION=45
OUTPUT=""
SIP_PORT=5060
SIP_TLS_PORT=5061
RTP_START=10000
RTP_END=20000
USE_SUDO=1

usage() {
  cat <<'EOF'
Usage: capture-sip-rtp-trace.sh [options]

Options:
  --iface IFACE         Interface to capture on (default: any)
  --host IP_OR_HOST     Optional host filter
  --duration SECONDS    Capture duration (default: 45)
  --output FILE         Output pcap path (default: ./sip-rtp-TIMESTAMP.pcap)
  --sip-port PORT       SIP UDP port (default: 5060)
  --sip-tls-port PORT   SIP TLS port (default: 5061)
  --rtp-start PORT      RTP range start (default: 10000)
  --rtp-end PORT        RTP range end (default: 20000)
  --no-sudo             Do not try sudo
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iface)
      IFACE="${2:-}"
      shift 2
      ;;
    --host)
      HOST_FILTER="${2:-}"
      shift 2
      ;;
    --duration)
      DURATION="${2:-45}"
      shift 2
      ;;
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    --sip-port)
      SIP_PORT="${2:-5060}"
      shift 2
      ;;
    --sip-tls-port)
      SIP_TLS_PORT="${2:-5061}"
      shift 2
      ;;
    --rtp-start)
      RTP_START="${2:-10000}"
      shift 2
      ;;
    --rtp-end)
      RTP_END="${2:-20000}"
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

if ! command -v tcpdump >/dev/null 2>&1; then
  echo "tcpdump is required" >&2
  exit 1
fi

if ! command -v timeout >/dev/null 2>&1; then
  echo "timeout is required for bounded capture" >&2
  exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
if [[ -z "$OUTPUT" ]]; then
  OUTPUT="$(pwd)/sip-rtp-${timestamp}.pcap"
fi

mkdir -p "$(dirname "$OUTPUT")"

SUDO=()
if [[ "$USE_SUDO" -eq 1 ]] && command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  SUDO=(sudo)
fi

FILTER="(udp port ${SIP_PORT} or tcp port ${SIP_TLS_PORT} or portrange ${RTP_START}-${RTP_END})"
if [[ -n "$HOST_FILTER" ]]; then
  FILTER="host ${HOST_FILTER} and ${FILTER}"
fi

META_FILE="${OUTPUT%.pcap}.txt"
{
  echo "timestamp=${timestamp}"
  echo "interface=${IFACE}"
  echo "duration=${DURATION}"
  echo "output=${OUTPUT}"
  echo "filter=${FILTER}"
  if [[ ${#SUDO[@]} -gt 0 ]]; then
    echo "sudo=enabled"
  else
    echo "sudo=disabled"
  fi
} > "$META_FILE"

CMD="timeout ${DURATION}s tcpdump -ni '${IFACE}' -s 0 -w '${OUTPUT}' ${FILTER}"
echo "$CMD" | tee -a "$META_FILE"

if [[ ${#SUDO[@]} -gt 0 ]]; then
  "${SUDO[@]}" bash -lc "$CMD"
else
  bash -lc "$CMD"
fi

echo "Capture saved to ${OUTPUT}"
echo "Metadata saved to ${META_FILE}"
