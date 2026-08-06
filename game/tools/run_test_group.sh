#!/usr/bin/env bash
set -euo pipefail

GROUP="${1:-}"
GODOT_COMMAND="${GODOT_COMMAND:-godot}"
TEST_TIMEOUT_SECONDS="${TEST_TIMEOUT_SECONDS:-90}"
SCENETREE_QUIT_AFTER_ITERATIONS="${SCENETREE_QUIT_AFTER_ITERATIONS:-600}"

case "$GROUP" in
  core|ui)
    ;;
  *)
    echo "Uso: $0 <core|ui>" >&2
    exit 2
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_ROOT="$PROJECT_ROOT/test-results"
LIST_LOG="$RESULTS_ROOT/${GROUP}-list.log"
SUITE_LOG="$RESULTS_ROOT/${GROUP}-suite.log"
CASE_ROOT="$RESULTS_ROOT/${GROUP}-tests"

mkdir -p "$RESULTS_ROOT"
rm -rf "$CASE_ROOT"
mkdir -p "$CASE_ROOT"
: > "$LIST_LOG"
: > "$SUITE_LOG"
cd "$PROJECT_ROOT"

set +e
"$GODOT_COMMAND" \
  --headless \
  --path "$PROJECT_ROOT" \
  --script res://tools/list_test_group.gd \
  -- "--test-group=$GROUP" \
  > "$LIST_LOG" 2>&1
list_exit=$?
set -e

cat "$LIST_LOG" | tee -a "$SUITE_LOG"
if [[ $list_exit -ne 0 ]]; then
  echo "ERROR: no se pudo enumerar el grupo $GROUP (exit $list_exit)." | tee -a "$SUITE_LOG" >&2
  exit "$list_exit"
fi

mapfile -t TEST_PATHS < <(sed -n 's/^TEST_PATH: //p' "$LIST_LOG")
if [[ ${#TEST_PATHS[@]} -eq 0 ]]; then
  echo "ERROR: el enumerador no devolvió pruebas para el grupo $GROUP." | tee -a "$SUITE_LOG" >&2
  exit 1
fi

echo "SUITE START: ${#TEST_PATHS[@]} test(s) · group=$GROUP · timeout=${TEST_TIMEOUT_SECONDS}s/test" | tee -a "$SUITE_LOG"

failures=()
passed=0
index=0
for test_path in "${TEST_PATHS[@]}"; do
  index=$((index + 1))
  source_path="$PROJECT_ROOT/${test_path#res://}"
  case_log="$CASE_ROOT/$(printf '%03d' "$index")-$(basename "$test_path" .gd).log"
  : > "$case_log"

  echo "SUITE RUN: [$index/${#TEST_PATHS[@]}] $test_path" | tee -a "$SUITE_LOG"

  arguments=(--headless --path "$PROJECT_ROOT")
  if grep -Eq '^[[:space:]]*extends[[:space:]]+SceneTree([[:space:]]|$)' "$source_path"; then
    # SceneTree assertions abort _initialize() before the script can call quit().
    # Bound the engine loop so CI can inspect the assertion and fail promptly
    # instead of waiting for the outer wall-clock timeout.
    arguments+=(--quit-after "$SCENETREE_QUIT_AFTER_ITERATIONS" --script "$test_path")
  else
    arguments+=(-- "--test=$test_path")
  fi

  set +e
  timeout --signal=TERM --kill-after=10s "${TEST_TIMEOUT_SECONDS}s" \
    "$GODOT_COMMAND" "${arguments[@]}" \
    > "$case_log" 2>&1
  exit_code=$?
  set -e

  cat "$case_log" | tee -a "$SUITE_LOG"

  if [[ $exit_code -eq 124 || $exit_code -eq 137 || $exit_code -eq 143 ]]; then
    echo "SUITE TIMEOUT: $test_path superó ${TEST_TIMEOUT_SECONDS}s." | tee -a "$SUITE_LOG" >&2
    failures+=("$test_path (timeout)")
    break
  fi

  reported_failure=0
  if grep -Eiq \
    'SCRIPT ERROR: Assertion failed|SCRIPT ERROR: Parse Error|SCRIPT ERROR: Compile Error|ERROR: Test did not complete or call get_tree\(\)\.quit\(\)|ERROR: Test emitted a failure or resource leak despite exit code 0|ObjectDB instances leaked at exit|resources still in use at exit' \
    "$case_log"; then
    reported_failure=1
  fi

  if [[ $exit_code -ne 0 || $reported_failure -ne 0 ]]; then
    echo "SUITE FAIL: $test_path (exit $exit_code, reported_failure=$reported_failure)" | tee -a "$SUITE_LOG" >&2
    failures+=("$test_path (exit $exit_code)")
  else
    passed=$((passed + 1))
    echo "SUITE PASS: $test_path" | tee -a "$SUITE_LOG"
  fi
done

if [[ ${#failures[@]} -gt 0 ]]; then
  printf 'SUITE FAILED: %s\n' "${failures[*]}" | tee -a "$SUITE_LOG" >&2
  exit 1
fi

echo "SUITE COMPLETED: $passed/${#TEST_PATHS[@]} passed · group=$GROUP" | tee -a "$SUITE_LOG"
