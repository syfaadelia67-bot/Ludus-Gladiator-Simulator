# Suite de pruebas

## Dos capas complementarias

El proyecto conserva dos sistemas durante la estabilización:

1. `TestRunner`, para los 90+ tests y contratos históricos;
2. GUT 9.5.0, para pruebas nuevas, fixtures, aislamiento y resultados JUnit.

GUT no reemplaza todavía al runner legacy. Las migraciones se harán cuando se modifique el sistema correspondiente y no mediante una conversión masiva.

## Convenciones del runner legacy

El ejecutor descubre de forma recursiva archivos que cumplan al menos una de estas convenciones:

- `test_*.gd`
- `*_test.gd`
- `*_contract.gd`

La convención `test_*.gd` se mantiene por compatibilidad con pruebas históricas ya existentes. No es necesario renombrarlas para que entren en CI.

Cada archivo se ejecuta en un proceso de Godot aislado para impedir que el estado global de un test contamine al siguiente.

### Tests que extienden `Node`

Se ejecutan dentro del proyecto mediante el autoload `TestRunner`, con todos los autoloads y la escena principal disponibles.

```powershell
godot --headless --path game -- --test=res://tests/example_test.gd
```

Los tests nuevos del runner legacy deben exponer un método `run()` y dejar que `TestRunner` cierre el proceso. El runner retira el nodo del árbol, elimina su script y libera todas sus referencias antes de llamar a `quit()`.

Los tests legacy que todavía llaman `get_tree().quit(0)` se adaptan en memoria. Esta compatibilidad existe para migrar pruebas históricas sin tolerar fugas; no debe usarse en pruebas nuevas.

### Tests que extienden `SceneTree`

El ejecutor los detecta por su declaración `extends SceneTree` y los lanza automáticamente mediante `--script`.

```powershell
godot --headless --path game --script res://tests/example_contract.gd
```

Los contratos que extienden `Node` deben ejecutarse mediante `TestRunner`, no mediante `--script`, para disponer de `Main.tscn`.

## Ejecución headless y MCP

El addon Godot AI continúa disponible en sesiones normales. El autoload del proyecto usa `mcp_game_helper_guard.gd`, que hereda el helper original y lo desactiva únicamente cuando `DisplayServer` es `headless`.

En CI y pruebas locales headless no se registra la captura MCP ni se crea el logger del addon.

## Suites legacy

Suite completa:

```powershell
godot --headless --path game -- --test=res://tests/...
```

Sistemas centrales:

```powershell
godot --headless --path game -- --test=res://tests/... --test-group=core
```

UI e integración:

```powershell
godot --headless --path game -- --test=res://tests/... --test-group=ui
```

## Capa GUT 9.5.0

La instalación, configuración y comandos están documentados en `res://tests/GUT.md`.

Desde `game`, en Windows:

```powershell
.\tools\run_gut.ps1
```

Las fuentes mantenidas están en `res://tests/gut_templates` como `.gd.in`. El instalador fijado a GUT 9.5.0 genera las pruebas reales en `res://tests/gut`, carpeta ignorada por Git.

Las siete familias iniciales cubren:

- guardado;
- economía;
- calendario;
- campaña;
- traducción;
- gladiadores;
- humo de escenas.

Contrato de infraestructura GUT, sin necesidad de instalar el addon:

```powershell
godot --headless --path game -- --test=res://tests/test_gut_foundation_contract.gd
```

## Clasificación legacy

Los tests con marcadores de pantalla, presenter, router, HUD, Finca, Mercado, Barracones, Arena, Relaciones, dossier, localización, resumen de campaña o recursos visuales se asignan a `ui`.

Los nombres históricos ambiguos se resuelven mediante `TEST_GROUP_OVERRIDES`. Todo test restante se asigna a `core`. No existe un estado sin grupo.

## Detección de fallos legacy

Además del código de salida del proceso hijo, la suite considera fallo:

- una assertion;
- un error de parseo o compilación;
- un timeout;
- `ObjectDB instances leaked at exit`;
- `resources still in use at exit`.

## Política GUT

GUT tiene seguimiento de errores activo. Fallan la prueba los errores del motor, errores internos de GUT y llamadas a `push_error`. Los huérfanos permanecen visibles y el resultado JUnit se escribe en `res://test-results/gut.xml`.

## Exclusiones legacy

La única exclusión inicial es `test_runner.gd`, porque es infraestructura y no un caso de prueba. Toda exclusión futura debe incluir una explicación legible en `EXCLUDED_TEST_FILES`.

## Contrato de cobertura legacy

`test_test_suite_coverage_contract.gd` protege el descubrimiento, clasificación, workflows actuales, guard MCP, liberación de nodos/scripts, adaptador legacy y detección de fugas.

```powershell
godot --headless --path game -- --test=res://tests/test_test_suite_coverage_contract.gd
```

## CI actual

El workflow `.github/workflows/godot-tests.yml` mantiene:

1. `compile`;
2. `core-systems`;
3. `ui-contracts`.

GUT todavía se valida localmente y no fue agregado al workflow. La integración definitiva con `godot-ci` y la protección de la rama estable se realizará después de ordenar GitHub. GDScript Formatter tampoco forma parte de esta etapa.
