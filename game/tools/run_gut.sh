#!/usr/bin/env bash
set -euo pipefail

GODOT_COMMAND="${GODOT_COMMAND:-godot}"
SELECT=""
REINSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --select)
      SELECT="${2:-}"
      shift 2
      ;;
    --reinstall)
      REINSTALL=1
      shift
      ;;
    *)
      echo "Uso: $0 [--select texto] [--reinstall]" >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ $REINSTALL -eq 1 ]]; then
  "$SCRIPT_DIR/install_gut_9_5.sh" --force
else
  "$SCRIPT_DIR/install_gut_9_5.sh"
fi

mkdir -p "$PROJECT_ROOT/test-results"
ARGS=(
  --headless
  -d
  --path "$PROJECT_ROOT"
  -s addons/gut/gut_cmdln.gd
  -gconfig=res://.gutconfig.json
  -gexit
)
if [[ -n "$SELECT" ]]; then
  ARGS+=("-gselect=$SELECT")
fi

cd "$PROJECT_ROOT"
LUDUS_GUT_MODE=1 "$GODOT_COMMAND" "${ARGS[@]}"
