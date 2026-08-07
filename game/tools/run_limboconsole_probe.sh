#!/usr/bin/env bash
set -euo pipefail

GODOT_COMMAND="${GODOT_COMMAND:-godot}"
LIMBO_CONSOLE_COMMIT="119834b392e116d35b5fa2b275e4601e326dcb52"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_ROOT="$PROJECT_ROOT/test-results"
LOG_PATH="$RESULTS_ROOT/limboconsole-probe.log"
TMP_ROOT=""

mkdir -p "$RESULTS_ROOT"
: > "$LOG_PATH"
exec > >(tee "$LOG_PATH") 2>&1

cleanup() {
  if [[ -n "$TMP_ROOT" && -d "$TMP_ROOT" ]]; then rm -rf "$TMP_ROOT"; fi
}
trap cleanup EXIT

for cmd in git timeout grep; do command -v "$cmd" >/dev/null || { echo "ERROR: falta $cmd"; exit 2; }; done
command -v "$GODOT_COMMAND" >/dev/null || { echo "ERROR: no se encontró Godot"; exit 2; }

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ludus-limboconsole-probe.XXXXXX")"
SOURCE="$TMP_ROOT/source"
PROBE="$TMP_ROOT/project"
mkdir -p "$SOURCE" "$PROBE/addons/limbo_console" "$PROBE/build"

git -C "$SOURCE" init -q
git -C "$SOURCE" remote add origin https://github.com/limbonaut/limbo_console.git
git -C "$SOURCE" fetch -q --depth=1 origin "$LIMBO_CONSOLE_COMMIT"
git -C "$SOURCE" checkout -q --detach FETCH_HEAD
ACTUAL_COMMIT="$(git -C "$SOURCE" rev-parse HEAD)"
[[ "$ACTUAL_COMMIT" == "$LIMBO_CONSOLE_COMMIT" ]] || { echo "ERROR: commit inesperado $ACTUAL_COMMIT"; exit 1; }
echo "LimboConsole probe: commit fijado=$ACTUAL_COMMIT"

find "$SOURCE" -maxdepth 1 -type f \( -name '*.gd' -o -name '*.uid' -o -name 'plugin.cfg' -o -name 'LICENSE.md' \) -exec cp {} "$PROBE/addons/limbo_console/" \;
cp -R "$SOURCE/res" "$PROBE/addons/limbo_console/res"

cat > "$PROBE/addons/limbo_console.cfg" <<'EOF'
[main]
disable_in_release_build=true
print_to_stdout=true
pause_when_open=false
commands_disabled_in_release=["eval", "exec", "quit", "alias", "unalias"]

[greet]
greet_user=false

[history]
persist_history=false
history_lines=0

[autoexec]
autoexec_script=""
autoexec_auto_create=false
EOF

cat > "$PROBE/project.godot" <<'EOF'
config_version=5

[application]
config/name="Ludus LimboConsole Probe"
run/main_scene="res://main.tscn"

[autoload]
LimboConsole="*res://addons/limbo_console/limbo_console.gd"

[editor_plugins]
enabled=PackedStringArray("res://addons/limbo_console/plugin.cfg")

[display]
window/size/viewport_width=640
window/size/viewport_height=360

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
EOF

cat > "$PROBE/main.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource path="res://main.gd" type="Script" id="1"]

[node name="Main" type="Node"]
script = ExtResource("1")
EOF

cat > "$PROBE/main.gd" <<'EOF'
extends Node

var ping_value: int = 0

func _ready() -> void:
    if OS.is_debug_build():
        LimboConsole.register_command(_dev_ping, "ludus_ping", "DEV-only probe command")
        if not LimboConsole.has_command("ludus_ping"):
            _fail("DEV command was not registered in debug build")
            return
        LimboConsole.execute_command("ludus_ping 7", true)
        if ping_value != 7:
            _fail("DEV command did not execute correctly")
            return
        print("LIMBOCONSOLE_DEBUG_OK")
        get_tree().quit(0)
        return

    if LimboConsole.enabled:
        _fail("Console UI/input is enabled in release build")
        return
    for forbidden in ["eval", "exec", "quit", "alias", "unalias", "ludus_ping"]:
        if LimboConsole.has_command(forbidden):
            _fail("Forbidden command present in release: %s" % forbidden)
            return
    print("LIMBOCONSOLE_RELEASE_OK")
    get_tree().quit(0)

func _dev_ping(value: int) -> void:
    if not OS.is_debug_build():
        return
    ping_value = value

func _fail(message: String) -> void:
    push_error(message)
    print("LIMBOCONSOLE_PROBE_FAIL: " + message)
    get_tree().quit(1)
EOF

cat > "$PROBE/export_presets.cfg" <<'EOF'
[preset.0]
name="Linux"
platform="Linux"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="addons/limbo_console.cfg"
exclude_filter=""
export_path="build/limboconsole_probe.x86_64"
script_export_mode=2

[preset.0.options]
custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=0
binary_format/embed_pck=false
binary_format/architecture="x86_64"
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
ssh_remote_deploy/enabled=false
EOF

echo "LimboConsole probe: Godot=$($GODOT_COMMAND --version)"
echo "LimboConsole probe: import/editor compatibility"
timeout 90s "$GODOT_COMMAND" --headless --editor --path "$PROBE" --quit

echo "LimboConsole probe: debug runtime"
DEBUG_OUT="$TMP_ROOT/debug.log"
timeout 60s "$GODOT_COMMAND" --headless --path "$PROBE" >"$DEBUG_OUT" 2>&1
cat "$DEBUG_OUT"
grep -q "LIMBOCONSOLE_DEBUG_OK" "$DEBUG_OUT" || { echo "ERROR: debug marker ausente"; exit 1; }

echo "LimboConsole probe: release export"
timeout 120s "$GODOT_COMMAND" --headless --path "$PROBE" --export-release Linux "$PROBE/build/limboconsole_probe.x86_64"
[[ -x "$PROBE/build/limboconsole_probe.x86_64" ]] || chmod +x "$PROBE/build/limboconsole_probe.x86_64"

echo "LimboConsole probe: release runtime security"
RELEASE_OUT="$TMP_ROOT/release.log"
timeout 60s "$PROBE/build/limboconsole_probe.x86_64" --headless >"$RELEASE_OUT" 2>&1
cat "$RELEASE_OUT"
grep -q "LIMBOCONSOLE_RELEASE_OK" "$RELEASE_OUT" || { echo "ERROR: release marker ausente"; exit 1; }

if grep -q "LIMBOCONSOLE_PROBE_FAIL" "$DEBUG_OUT" "$RELEASE_OUT"; then
  echo "ERROR: probe reportó fallo"
  exit 1
fi

echo "LIMBOCONSOLE_PROBE_OK"
