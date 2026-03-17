#!/usr/bin/env bash
set -euo pipefail

TERM=""
CONTEXT=4
USE_SUDO=1
declare -a LOGS=()

usage() {
  cat <<'EOF'
Usage: call-timeline.sh --term SEARCH_TERM [--log FILE] [--context N] [--no-sudo]

Extract a call-centered timeline from Asterisk or system logs using grep or rg.
Repeat --log to search multiple files. If omitted, common defaults are used.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --term)
      TERM="${2:-}"
      shift 2
      ;;
    --log)
      LOGS+=("${2:-}")
      shift 2
      ;;
    --context)
      CONTEXT="${2:-4}"
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

if [[ -z "$TERM" ]]; then
  echo "--term is required" >&2
  exit 1
fi

if [[ ${#LOGS[@]} -eq 0 ]]; then
  for candidate in /var/log/asterisk/full /var/log/messages /var/log/syslog; do
    [[ -f "$candidate" ]] && LOGS+=("$candidate")
  done
fi

if [[ ${#LOGS[@]} -eq 0 ]]; then
  echo "No log files found to search" >&2
  exit 1
fi

SUDO=()
if [[ "$USE_SUDO" -eq 1 ]] && command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  SUDO=(sudo)
fi

search_file() {
  local file="$1"
  echo "===== ${file} ====="
  if command -v rg >/dev/null 2>&1; then
    if [[ ${#SUDO[@]} -gt 0 ]]; then
      "${SUDO[@]}" rg -n -i -C "$CONTEXT" -- "$TERM" "$file" || true
    else
      rg -n -i -C "$CONTEXT" -- "$TERM" "$file" || true
    fi
  else
    if [[ ${#SUDO[@]} -gt 0 ]]; then
      "${SUDO[@]}" grep -n -i -C "$CONTEXT" -- "$TERM" "$file" || true
    else
      grep -n -i -C "$CONTEXT" -- "$TERM" "$file" || true
    fi
  fi
  echo
}

for log_file in "${LOGS[@]}"; do
  search_file "$log_file"
done
