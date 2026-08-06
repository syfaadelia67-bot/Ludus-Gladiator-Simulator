#!/usr/bin/env bash
set -euo pipefail

GODOT_COMMAND="${GODOT_COMMAND:-godot}"
IMPORT_TIMEOUT_SECONDS="${IMPORT_TIMEOUT_SECONDS:-180}"
GUT_TIMEOUT_SECONDS="${GUT_TIMEOUT_SECONDS:-300}"
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
RESULTS_ROOT="$PROJECT_ROOT/test-results"
INSTALL_STDOUT="$RESULTS_ROOT/gut-install.stdout.log"
INSTALL_STDERR="$RESULTS_ROOT/gut-install.stderr.log"
IMPORT_STDOUT="$RESULTS_ROOT/gut-import.stdout.log"
IMPORT_STDERR="$RESULTS_ROOT/gut-import.stderr.log"
GUT_STDOUT="$RESULTS_ROOT/gut.stdout.log"
GUT_STDERR="$RESULTS_ROOT/gut.stderr.log"
COMBINED_LOG="$RESULTS_ROOT/gut-console.log"
JUNIT_XML="$RESULTS_ROOT/gut.xml"

mkdir -p "$RESULTS_ROOT"
: > "$INSTALL_STDOUT"
: > "$INSTALL_STDERR"
: > "$IMPORT_STDOUT"
: > "$IMPORT_STDERR"
: > "$GUT_STDOUT"
: > "$GUT_STDERR"
: > "$COMBINED_LOG"
rm -f "$JUNIT_XML"
cd "$PROJECT_ROOT"

write_combined_log() {
  {
    echo "===== GUT INSTALL STDOUT ====="
    cat "$INSTALL_STDOUT"
    echo "===== GUT INSTALL STDERR ====="
    cat "$INSTALL_STDERR"
    echo "===== GUT IMPORT STDOUT ====="
    cat "$IMPORT_STDOUT"
    echo "===== GUT IMPORT STDERR ====="
    cat "$IMPORT_STDERR"
    echo "===== GUT TEST STDOUT ====="
    cat "$GUT_STDOUT"
    echo "===== GUT TEST STDERR ====="
    cat "$GUT_STDERR"
  } > "$COMBINED_LOG"
}

show_result() {
  local exit_code="$1"
  write_combined_log
  echo
  echo "Resumen de GUT (últimas líneas relevantes):"
  grep -Eai "SCRIPT ERROR|ERROR:|FAILED|FAIL:|FAILURES|PASSING|PENDING|ORPHAN|TESTS|ASSERT|SUMMARY|TOTALS|PARSE ERROR|COMPILE ERROR|TIMEOUT|RUNNER FAILURE" \
    "$INSTALL_STDOUT" "$INSTALL_STDERR" "$IMPORT_STDOUT" "$IMPORT_STDERR" "$GUT_STDOUT" "$GUT_STDERR" | tail -n 120 || true
  echo
  echo "Código de salida GUT: $exit_code"
  echo "Log completo: $COMBINED_LOG"
  echo "JUnit XML: $JUNIT_XML"
}

INSTALL_ARGS=()
if [[ $REINSTALL -eq 1 ]]; then
  INSTALL_ARGS+=(--force)
fi

set +e
bash "$SCRIPT_DIR/install_gut_9_5.sh" "${INSTALL_ARGS[@]}" \
  > "$INSTALL_STDOUT" 2> "$INSTALL_STDERR"
install_exit=$?
set -e

if [[ $install_exit -ne 0 ]]; then
  write_combined_log
  cat "$INSTALL_STDOUT"
  cat "$INSTALL_STDERR" >&2
  echo "La instalación reproducible de GUT falló con código $install_exit." >&2
  exit "$install_exit"
fi

reported_failure=0

set +e
LUDUS_GUT_MODE=1 timeout --signal=TERM --kill-after=10s "${IMPORT_TIMEOUT_SECONDS}s" \
  "$GODOT_COMMAND" --headless --import --path "$PROJECT_ROOT" \
  > "$IMPORT_STDOUT" 2> "$IMPORT_STDERR"
import_exit=$?
set -e

if [[ $import_exit -ne 0 ]]; then
  if [[ $import_exit -eq 124 ]]; then
    echo "TIMEOUT: la importación de Godot superó ${IMPORT_TIMEOUT_SECONDS} segundos." >> "$IMPORT_STDERR"
  fi
  write_combined_log
  cat "$IMPORT_STDOUT"
  cat "$IMPORT_STDERR" >&2
  echo "La importación de Godot falló con código $import_exit." >&2
  exit "$import_exit"
fi

ARGS=(
  --headless
  --path "$PROJECT_ROOT"
  -s tools/ludus_gut_cmdln.gd
  -gconfig=res://.gutconfig.json
  -gexit
)
if [[ -n "$SELECT" ]]; then
  ARGS+=("-gselect=$SELECT")
fi

set +e
LUDUS_GUT_MODE=1 timeout --signal=TERM --kill-after=10s "${GUT_TIMEOUT_SECONDS}s" \
  "$GODOT_COMMAND" "${ARGS[@]}" \
  > "$GUT_STDOUT" 2> "$GUT_STDERR"
gut_exit=$?
set -e

if [[ $gut_exit -eq 124 ]]; then
  echo "TIMEOUT: GUT superó ${GUT_TIMEOUT_SECONDS} segundos." >> "$GUT_STDERR"
fi

if grep -Eiq '^[[:space:]]*Failing Tests[[:space:]]+[1-9][0-9]*[[:space:]]*$' "$GUT_STDOUT" "$GUT_STDERR"; then
  reported_failure=1
fi
if grep -Eiq '^[[:space:]]*\[Failed\]:' "$GUT_STDOUT" "$GUT_STDERR"; then
  reported_failure=1
fi
if grep -Eiq '^----[[:space:]]*[1-9][0-9]*[[:space:]]+failing tests?[[:space:]]+----' "$GUT_STDOUT" "$GUT_STDERR"; then
  reported_failure=1
fi

if [[ -s "$JUNIT_XML" ]]; then
  xml_result="$(python3 - "$JUNIT_XML" <<'PY'
import sys
import xml.etree.ElementTree as ET

try:
    root = ET.parse(sys.argv[1]).getroot()
except Exception as exc:
    print(f"invalid:{exc}")
    raise SystemExit(0)

failures = 0
errors = 0
for element in root.iter():
    failures += int(element.attrib.get("failures", 0) or 0)
    errors += int(element.attrib.get("errors", 0) or 0)
print("failed" if failures + errors > 0 else "passed")
PY
)"
  case "$xml_result" in
    failed)
      reported_failure=1
      ;;
    invalid:*)
      echo "RUNNER WARNING: no se pudo analizar gut.xml: ${xml_result#invalid:}" >> "$GUT_STDERR"
      ;;
  esac
else
  reported_failure=1
  echo "RUNNER FAILURE: GUT no generó el informe JUnit esperado en $JUNIT_XML." >> "$GUT_STDERR"
fi

exit_code=$gut_exit
if [[ $exit_code -eq 0 && $reported_failure -eq 1 ]]; then
  exit_code=1
  echo "RUNNER FAILURE: GUT reportó pruebas fallidas aunque Godot devolvió código 0." >> "$GUT_STDERR"
fi

show_result "$exit_code"
exit "$exit_code"
