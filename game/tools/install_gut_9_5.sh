#!/usr/bin/env bash
set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
  FORCE=1
elif [[ $# -gt 0 ]]; then
  echo "Uso: $0 [--force]" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCK_PATH="$SCRIPT_DIR/gut.lock.json"
TARGET_PATH="$PROJECT_ROOT/addons/gut"
MARKER_PATH="$TARGET_PATH/.ludus-gut-lock.json"
TEMPLATE_ROOT="$PROJECT_ROOT/tests/gut_templates"
GENERATED_ROOT="$PROJECT_ROOT/gut_tests"
TEMPORARY_ROOT=""

cleanup() {
  if [[ -n "$TEMPORARY_ROOT" && -d "$TEMPORARY_ROOT" ]]; then
    rm -rf "$TEMPORARY_ROOT"
  fi
}
trap cleanup EXIT

read_lock_value() {
  python3 - "$LOCK_PATH" "$1" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
print(data[sys.argv[2]])
PY
}

VERSION="$(read_lock_value version)"
COMMIT="$(read_lock_value commit)"
ARCHIVE_URL="$(read_lock_value archive_url)"

matching_install() {
  [[ -f "$MARKER_PATH" ]] || return 1
  python3 - "$MARKER_PATH" "$VERSION" "$COMMIT" <<'PY'
import json
import sys
try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        data = json.load(handle)
except Exception:
    raise SystemExit(1)
raise SystemExit(0 if data.get("version") == sys.argv[2] and data.get("commit") == sys.argv[3] else 1)
PY
}

install_addon() {
  if [[ -e "$TARGET_PATH" ]]; then
    if matching_install && [[ $FORCE -eq 0 ]]; then
      echo "GUT $VERSION ya está instalado desde $COMMIT."
      return
    fi
    if [[ $FORCE -eq 0 ]]; then
      echo "Existe $TARGET_PATH, pero no coincide con tools/gut.lock.json. Repetí con --force para reemplazarlo." >&2
      exit 1
    fi
    rm -rf "$TARGET_PATH"
  fi

  local archive_path extract_path archive_root source_addon
  TEMPORARY_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ludus-gut.XXXXXX")"
  archive_path="$TEMPORARY_ROOT/gut.zip"
  extract_path="$TEMPORARY_ROOT/extract"

  mkdir -p "$extract_path"
  echo "Descargando GUT $VERSION desde el commit inmutable $COMMIT..."
  curl --fail --location --silent --show-error "$ARCHIVE_URL" --output "$archive_path"
  unzip -q "$archive_path" -d "$extract_path"
  archive_root="$(find "$extract_path" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  source_addon="$archive_root/addons/gut"

  if [[ ! -f "$source_addon/plugin.cfg" ]]; then
    echo "El commit descargado no contiene addons/gut/plugin.cfg." >&2
    exit 1
  fi
  if ! grep -Fq "version=\"$VERSION\"" "$source_addon/plugin.cfg"; then
    echo "La versión declarada por plugin.cfg no coincide con $VERSION." >&2
    exit 1
  fi

  mkdir -p "$(dirname "$TARGET_PATH")"
  cp -R "$source_addon" "$TARGET_PATH"
  cp "$LOCK_PATH" "$MARKER_PATH"
  echo "GUT $VERSION instalado en $TARGET_PATH."

  cleanup
  TEMPORARY_ROOT=""
}

materialize_tests() {
  if [[ ! -d "$TEMPLATE_ROOT" ]]; then
    echo "No existe el directorio de plantillas: $TEMPLATE_ROOT" >&2
    exit 1
  fi

  rm -rf "$GENERATED_ROOT"
  mkdir -p "$GENERATED_ROOT"
  local count=0 template relative destination
  while IFS= read -r -d '' template; do
    relative="${template#"$TEMPLATE_ROOT"/}"
    destination="$GENERATED_ROOT/${relative%.in}"
    mkdir -p "$(dirname "$destination")"
    cp "$template" "$destination"
    count=$((count + 1))
  done < <(find "$TEMPLATE_ROOT" -type f -name '*.gd.in' -print0)

  if [[ $count -eq 0 ]]; then
    echo "No se encontraron plantillas GUT en $TEMPLATE_ROOT." >&2
    exit 1
  fi
  echo "$count scripts GUT materializados en $GENERATED_ROOT."
}

install_addon
materialize_tests
echo "Instalación reproducible de GUT completada."
