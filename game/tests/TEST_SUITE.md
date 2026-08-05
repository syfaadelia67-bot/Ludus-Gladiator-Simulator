# Suite de pruebas

## Convenciones reconocidas

El ejecutor descubre de forma recursiva archivos que cumplan al menos una de estas convenciones:

- `test_*.gd`
- `*_test.gd`
- `*_contract.gd`

La convención `test_*.gd` se mantiene por compatibilidad con pruebas históricas ya existentes. No es necesario renombrarlas para que entren en CI.

Cada archivo se ejecuta en un proceso de Godot aislado para impedir que el estado global de un test contamine al siguiente.

## Modos compatibles

### Tests que extienden `Node`

Se ejecutan dentro del proyecto mediante el autoload `TestRunner`, con todos los autoloads y la escena principal disponibles.

```powershell
godot --headless --path game -- --test=res://tests/example_test.gd
```

Los tests nuevos deben exponer un método `run()` y dejar que `TestRunner` cierre el proceso. El runner retira el nodo del árbol, elimina su script y libera todas sus referencias antes de llamar a `quit()`.

Los tests legacy que todavía llaman `get_tree().quit(0)` se adaptan en memoria. El runner reemplaza ese cierre por una notificación controlada, libera el nodo y el `GDScript` adaptado y recién entonces termina el proceso. Esta compatibilidad existe para migrar pruebas históricas sin tolerar fugas; no debe usarse en tests nuevos.

### Tests que extienden `SceneTree`

El ejecutor los detecta por su declaración `extends SceneTree` y los lanza automáticamente mediante `--script`.

También pueden ejecutarse directamente:

```powershell
godot --headless --path game --script res://tests/example_contract.gd
```

Los contratos que extienden `Node` deben ejecutarse mediante `TestRunner`, no mediante `--script`, para disponer de `Main.tscn` y evitar mensajes falsos de presenters sin escena principal.

## Ejecución headless y MCP

El addon Godot AI continúa instalado y disponible en sesiones normales. El autoload del proyecto usa `mcp_game_helper_guard.gd`, que hereda el helper original y lo desactiva únicamente cuando `DisplayServer` es `headless`.

En CI y pruebas locales headless no se registra la captura MCP ni se crea el `Logger` del addon. Esto evita dejar un `Logger` y su script precargado vivos durante la limpieza global de Godot. En una partida iniciada desde el editor se ejecuta `super._ready()` y el comportamiento MCP original se conserva.

## Suites

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

## Clasificación

Los tests con marcadores de pantalla, presenter, router, HUD, Finca, Mercado, Barracones, Arena, Relaciones, dossier, localización, resumen de campaña o recursos visuales se asignan a `ui`.

Los nombres históricos ambiguos se resuelven mediante `TEST_GROUP_OVERRIDES`. Actualmente el flujo completo de campaña y el resumen de continuar campaña pertenecen explícitamente a `ui`.

Todo test restante se asigna a `core`. No existe un estado sin grupo.

La clasificación afecta únicamente la distribución del CI; no cambia cómo se ejecuta el test.

## Detección de fallos

Además del código de salida del proceso hijo, la suite revisa la salida de Godot. Un test se considera fallido si emite:

- una assertion;
- un error de parseo o compilación;
- un timeout del runner;
- `ObjectDB instances leaked at exit`;
- `resources still in use at exit`.

Esto impide falsos positivos de pruebas históricas que imprimían `OK` después de una assertion abortada y evita aceptar procesos que finalizan con objetos o recursos vivos.

## Exclusiones

La única exclusión inicial es:

- `test_runner.gd`: orquestador autoload de la suite; no contiene un caso de prueba.

Toda exclusión futura debe agregarse a `EXCLUDED_TEST_FILES` dentro de `test_runner.gd` con una explicación legible.

## Regla de cobertura

`test_test_suite_coverage_contract.gd` falla cuando:

- aparece un `.gd` de prueba en `game/tests/` que no sigue una convención reconocida;
- una exclusión no tiene justificación;
- desaparece alguno de los tres bloques del workflow;
- el runner deja de reconocer tests o contratos;
- el CI deja de ejecutar las suites `core` y `ui`;
- se retira el guard headless del helper MCP;
- el runner deja de liberar nodos y scripts;
- desaparece el adaptador legacy;
- los leaks de `ObjectDB` o recursos dejan de tratarse como fallos.

El propio contrato extiende `Node` y debe ejecutarse así:

```powershell
godot --headless --path game -- --test=res://tests/test_test_suite_coverage_contract.gd
```

## CI

El workflow `.github/workflows/godot-tests.yml` se divide en:

1. `compile`: importación, compilación y smoke test de `Main.tscn`;
2. `core-systems`: suite automática de sistemas centrales;
3. `ui-contracts`: suite automática de UI e integración.

No se instala ningún plugin durante estas tareas. Se utiliza Godot 4.5.2.
