#!/usr/bin/env bash
set -euo pipefail

GODOT_COMMAND="${GODOT_COMMAND:-godot}"
LIMBOAI_VERSION="${LIMBOAI_VERSION:-1.6.0}"
TAG="v${LIMBOAI_VERSION}"
EXPECTED_ASSET="limboai+v1.6.0.gdextension-4.4.zip"
EXPECTED_SHA256="20e2559d4000efee4495a2e361b0c3cc1d0c51d38a9cc062d335e020de1a405f"
RELEASE_API="https://api.github.com/repos/limbonaut/limboai/releases/tags/${TAG}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_ROOT="$PROJECT_ROOT/test-results"
LOG_PATH="$RESULTS_ROOT/limboai-probe.log"
BOOTSTRAP_LOG_PATH="$RESULTS_ROOT/limboai-editor-bootstrap.log"
RELOAD_LOG_PATH="$RESULTS_ROOT/limboai-editor-reload.log"
TMP_ROOT=""

mkdir -p "$RESULTS_ROOT"
: > "$LOG_PATH"
: > "$BOOTSTRAP_LOG_PATH"
: > "$RELOAD_LOG_PATH"
exec > >(tee "$LOG_PATH") 2>&1

cleanup() {
  if [[ -n "$TMP_ROOT" && -d "$TMP_ROOT" ]]; then
    rm -rf "$TMP_ROOT"
  fi
}
trap cleanup EXIT

for command_name in curl unzip python3 sha256sum timeout; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "ERROR: falta la dependencia requerida: $command_name" >&2
    exit 2
  }
done
command -v "$GODOT_COMMAND" >/dev/null 2>&1 || {
  echo "ERROR: no se encontró Godot mediante GODOT_COMMAND=$GODOT_COMMAND" >&2
  exit 2
}

if [[ "$LIMBOAI_VERSION" != "1.6.0" ]]; then
  echo "ERROR: este probe está deliberadamente bloqueado a LimboAI 1.6.0." >&2
  exit 2
fi

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

asset_url="$(python3 - "$RELEASE_JSON" "$TAG" "$EXPECTED_ASSET" "$EXPECTED_SHA256" <<'PY'
import json
import sys

path, expected_tag, expected_name, expected_sha = sys.argv[1:]
with open(path, encoding="utf-8") as handle:
    release = json.load(handle)

if release.get("tag_name") != expected_tag:
    raise SystemExit(f"release tag inesperado: {release.get('tag_name')!r}")
if release.get("draft") or release.get("prerelease"):
    raise SystemExit("la release seleccionada no puede ser draft/prerelease")

selected = next((asset for asset in release.get("assets", []) if asset.get("name") == expected_name), None)
if selected is None:
    raise SystemExit(f"no existe el asset fijado: {expected_name}")

digest = (selected.get("digest") or "").lower()
if digest != f"sha256:{expected_sha.lower()}":
    raise SystemExit(f"digest inesperado para {expected_name}: {digest!r}")

url = selected.get("browser_download_url") or ""
if not url.startswith("https://github.com/limbonaut/limboai/releases/download/"):
    raise SystemExit(f"URL de asset inesperada: {url!r}")
print(url)
PY
)"

echo "LimboAI probe: asset=$EXPECTED_ASSET"
echo "LimboAI probe: SHA-256 fijado=$EXPECTED_SHA256"

curl --fail --location --silent --show-error "$asset_url" --output "$ARCHIVE_PATH"
echo "$EXPECTED_SHA256  $ARCHIVE_PATH" | sha256sum --check --status || {
  echo "ERROR: el SHA-256 del asset de LimboAI no coincide con el valor fijado." >&2
  exit 1
}
echo "LimboAI probe: SHA-256 verificado"

unzip -q "$ARCHIVE_PATH" -d "$EXTRACT_ROOT"
GDEXT_SOURCE="$(find "$EXTRACT_ROOT" -type f -name '*.gdextension' -path '*/addons/limboai/*' -print -quit)"
if [[ -z "$GDEXT_SOURCE" ]]; then
  echo "ERROR: el asset no contiene addons/limboai/*.gdextension" >&2
  exit 1
fi
ADDON_SOURCE="${GDEXT_SOURCE%%/addons/limboai/*}/addons/limboai"
if [[ ! -d "$ADDON_SOURCE" ]]; then
  echo "ERROR: no se pudo localizar la raíz addons/limboai dentro del asset." >&2
  exit 1
fi
cp -R "$ADDON_SOURCE" "$PROBE_PROJECT/addons/limboai"

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
    for required_class in REQUIRED_CLASSES:
        if not ClassDB.class_exists(required_class):
            push_error("LimboAI no registró la clase requerida después del reload: %s" % required_class)
            quit(1)
            return

    var action_script = load("res://probe_action.gd")
    if action_script == null or not action_script.can_instantiate():
        push_error("No se pudo compilar una BTAction personalizada en GDScript después del reload.")
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

    # BTAction y BehaviorTree son RefCounted; se liberan soltando la referencia.
    action = null
    behavior_tree = null
    # BTPlayer y LimboHSM son Nodes y sí pueden liberarse explícitamente.
    bt_player.free()
    hsm.free()
    print("LIMBOAI_RUNTIME_PROBE_OK: v${LIMBOAI_VERSION} funciona como GDExtension en runtime headless después del reload requerido.")
    quit(0)
EOF

# LimboAI documenta que una GDExtension recién instalada requiere recargar el proyecto.
# En headless, el primer ciclo puede terminar de forma no limpia mientras Godot genera
# .godot y registra la extensión. No lo consideramos PASS; solo bootstrap.
echo "LimboAI probe: bootstrap inicial del editor para registrar la GDExtension"
set +e
timeout --signal=TERM --kill-after=10s 60s \
  "$GODOT_COMMAND" --headless --editor --path "$PROBE_PROJECT" --quit \
  > "$BOOTSTRAP_LOG_PATH" 2>&1
bootstrap_exit=$?
set -e
if [[ $bootstrap_exit -eq 0 ]]; then
  echo "LimboAI probe: bootstrap inicial terminó limpio"
else
  echo "LimboAI probe: bootstrap inicial terminó con exit $bootstrap_exit; se permite solo porque ahora validaremos el proyecto tras el reload."
fi

if [[ ! -d "$PROBE_PROJECT/.godot" ]]; then
  echo "ERROR: Godot no generó .godot durante el bootstrap de la GDExtension." >&2
  tail -n 80 "$BOOTSTRAP_LOG_PATH" || true
  exit 1
fi

echo "LimboAI probe: ejecutando runtime headless DESPUÉS del reload requerido"
timeout --signal=TERM --kill-after=10s 60s \
  "$GODOT_COMMAND" --headless --path "$PROBE_PROJECT" --script res://smoke.gd

echo "LimboAI probe: RUNTIME PASS"

# Segundo ciclo del editor: diagnóstico adicional. El runtime anterior es la condición
# bloqueante para Ludus; este ciclo nos dice si además el editor headless queda estable.
echo "LimboAI probe: segundo ciclo headless-editor después del reload (diagnóstico)"
set +e
timeout --signal=TERM --kill-after=10s 60s \
  "$GODOT_COMMAND" --headless --editor --path "$PROBE_PROJECT" --quit \
  > "$RELOAD_LOG_PATH" 2>&1
reload_exit=$?
set -e
if [[ $reload_exit -eq 0 ]]; then
  echo "LimboAI probe: EDITOR RELOAD PASS"
else
  echo "LimboAI probe: EDITOR RELOAD WARNING (exit $reload_exit). Runtime ya fue validado; revisar log separado."
  tail -n 80 "$RELOAD_LOG_PATH" || true
fi

echo "LimboAI probe: PASS"
