#!/usr/bin/env bash
set -euo pipefail

GODOT_COMMAND="${GODOT_COMMAND:-godot}"
LIMBOAI_VERSION="${LIMBOAI_VERSION:-1.6.0}"
TAG="v${LIMBOAI_VERSION}"
RELEASE_API="https://api.github.com/repos/limbonaut/limboai/releases/tags/${TAG}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_ROOT="$PROJECT_ROOT/test-results"
LOG_PATH="$RESULTS_ROOT/limboai-probe.log"
TMP_ROOT=""

mkdir -p "$RESULTS_ROOT"
: > "$LOG_PATH"
exec > >(tee "$LOG_PATH") 2>&1

cleanup() {
  if [[ -n "$TMP_ROOT" && -d "$TMP_ROOT" ]]; then
    rm -rf "$TMP_ROOT"
  fi
}
trap cleanup EXIT

for command_name in curl unzip python3 sha256sum; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "ERROR: falta la dependencia requerida: $command_name" >&2
    exit 2
  }
done
command -v "$GODOT_COMMAND" >/dev/null 2>&1 || {
  echo "ERROR: no se encontró Godot mediante GODOT_COMMAND=$GODOT_COMMAND" >&2
  exit 2
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ludus-limboai-probe.XXXXXX")"
RELEASE_JSON="$TMP_ROOT/release.json"
ARCHIVE_PATH="$TMP_ROOT/limboai.zip"
EXTRACT_ROOT="$TMP_ROOT/extract"
PROBE_PROJECT="$TMP_ROOT/project"
mkdir -p "$EXTRACT_ROOT" "$PROBE_PROJECT/addons"

curl_args=(
  --fail
  --location
  --silent
  --show-error
  -H "Accept: application/vnd.github+json"
  -H "X-GitHub-Api-Version: 2022-11-28"
)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_args+=( -H "Authorization: Bearer ${GITHUB_TOKEN}" )
fi

printf 'LimboAI probe: Godot=' 
"$GODOT_COMMAND" --version
printf 'LimboAI probe: release=%s\n' "$TAG"

curl "${curl_args[@]}" "$RELEASE_API" --output "$RELEASE_JSON"

asset_record="$(python3 - "$RELEASE_JSON" "$LIMBOAI_VERSION" <<'PY'
import json
import re
import sys

path, version = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as handle:
    release = json.load(handle)

expected_tag = f"v{version}"
if release.get("tag_name") != expected_tag:
    raise SystemExit(f"release tag inesperado: {release.get('tag_name')!r}")
if release.get("draft") or release.get("prerelease"):
    raise SystemExit("la release seleccionada no puede ser draft/prerelease")

assets = {asset.get("name", ""): asset for asset in release.get("assets", [])}
preferred = [
    f"limboai+v{version}.gdextension-4.5.zip",
    f"limboai+v{version}.gdextension-4.4.zip",
]
selected = next((assets[name] for name in preferred if name in assets), None)
if selected is None:
    candidates = sorted(name for name in assets if re.search(r"\.gdextension-4\.[45]\.zip$", name))
    raise SystemExit(
        "no se encontró un GDExtension compatible con Godot 4.5; candidatos=" + repr(candidates)
    )

digest = selected.get("digest") or ""
if not re.fullmatch(r"sha256:[0-9a-fA-F]{64}", digest):
    raise SystemExit(f"GitHub no publicó un digest SHA-256 utilizable para {selected.get('name')}: {digest!r}")
url = selected.get("browser_download_url") or ""
if not url.startswith("https://github.com/limbonaut/limboai/releases/download/"):
    raise SystemExit(f"URL de asset inesperada: {url!r}")

print("\t".join([selected["name"], url, digest.lower()]))
PY
)"

IFS=$'\t' read -r ASSET_NAME ASSET_URL ASSET_DIGEST <<< "$asset_record"
echo "LimboAI probe: asset=$ASSET_NAME"
echo "LimboAI probe: digest=$ASSET_DIGEST"

curl --fail --location --silent --show-error "$ASSET_URL" --output "$ARCHIVE_PATH"
echo "${ASSET_DIGEST#sha256:}  $ARCHIVE_PATH" | sha256sum --check --status || {
  echo "ERROR: el SHA-256 del asset de LimboAI no coincide con el digest publicado por GitHub." >&2
  exit 1
}
echo "LimboAI probe: SHA-256 verificado"

unzip -q "$ARCHIVE_PATH" -d "$EXTRACT_ROOT"
GDEXT_SOURCE="$(find "$EXTRACT_ROOT" -type f -name '*.gdextension' -path '*/addons/limboai/*' -print -quit)"
if [[ -z "$GDEXT_SOURCE" ]]; then
  echo "ERROR: el asset no contiene addons/limboai/*.gdextension" >&2
  exit 1
fi
ADDON_SOURCE="$(dirname "$(dirname "$GDEXT_SOURCE")")/limboai"
if [[ ! -d "$ADDON_SOURCE" ]]; then
  ADDON_SOURCE="$(dirname "$GDEXT_SOURCE")"
fi
cp -R "$ADDON_SOURCE" "$PROBE_PROJECT/addons/limboai"

GDEXT_INSTALLED="$(find "$PROBE_PROJECT/addons/limboai" -type f -name '*.gdextension' -print -quit)"
if [[ -z "$GDEXT_INSTALLED" ]]; then
  echo "ERROR: no se pudo materializar la GDExtension en el proyecto aislado." >&2
  exit 1
fi
GDEXT_RELATIVE="${GDEXT_INSTALLED#"$PROBE_PROJECT/"}"

cat > "$PROBE_PROJECT/project.godot" <<'EOF'
config_version=5

[application]
config/name="Ludus LimboAI Compatibility Probe"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
EOF

cat > "$PROBE_PROJECT/probe_action.gd" <<'EOF'
extends BTAction

func _tick(_delta):
    return SUCCESS
EOF

cat > "$PROBE_PROJECT/smoke.gd" <<EOF
extends SceneTree

const REQUIRED_CLASSES := [
    "BehaviorTree",
    "BTPlayer",
    "BTAction",
    "Blackboard",
    "LimboHSM",
    "LimboState"
]

func _initialize() -> void:
    var extension_resource = load("res://${GDEXT_RELATIVE}")
    if extension_resource == null:
        push_error("No se pudo cargar la GDExtension de LimboAI.")
        quit(1)
        return

    for class_name in REQUIRED_CLASSES:
        if not ClassDB.class_exists(class_name):
            push_error("LimboAI no registró la clase requerida: %s" % class_name)
            quit(1)
            return

    var action_script = load("res://probe_action.gd")
    if action_script == null or not action_script.can_instantiate():
        push_error("No se pudo compilar una BTAction personalizada en GDScript.")
        quit(1)
        return
    var action = action_script.new()
    if action == null:
        push_error("No se pudo instanciar la BTAction personalizada.")
        quit(1)
        return

    var bt_player = ClassDB.instantiate("BTPlayer")
    var behavior_tree = ClassDB.instantiate("BehaviorTree")
    var hsm = ClassDB.instantiate("LimboHSM")
    if bt_player == null or behavior_tree == null or hsm == null:
        push_error("No se pudieron instanciar las clases principales BT/HSM de LimboAI.")
        quit(1)
        return

    action.free()
    bt_player.free()
    behavior_tree.free()
    hsm.free()
    print("LIMBOAI_PROBE_OK: v${LIMBOAI_VERSION} funciona como GDExtension bajo este Godot.")
    quit(0)
EOF

echo "LimboAI probe: importando proyecto aislado"
timeout --signal=TERM --kill-after=10s 120s \
  "$GODOT_COMMAND" --headless --editor --path "$PROBE_PROJECT" --quit

echo "LimboAI probe: ejecutando smoke de clases BT/HSM"
timeout --signal=TERM --kill-after=10s 60s \
  "$GODOT_COMMAND" --headless --path "$PROBE_PROJECT" --script res://smoke.gd

echo "LimboAI probe: PASS"
