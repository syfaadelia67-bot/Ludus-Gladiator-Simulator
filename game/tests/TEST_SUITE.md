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

### Tests que extienden `SceneTree`

El ejecutor los detecta por su declaración `extends SceneTree` y los lanza automáticamente mediante `--script`.

También pueden ejecutarse directamente:

```powershell
godot --headless --path game --script res://tests/example_contract.gd
```

Los contratos que extienden `Node` deben ejecutarse mediante `TestRunner`, no mediante `--script`, para disponer de `Main.tscn` y evitar mensajes falsos de presenters sin escena principal.

## Detección real de fallos

El código de salida del proceso sigue siendo la primera fuente de verdad. Además, el runner inspecciona la salida del proceso y convierte en fallo cualquier ejecución que emita:

- `SCRIPT ERROR: Assertion failed`;
- errores de parseo;
- errores de compilación;
- timeout por no finalizar el test.

Esto evita falsos positivos de tests históricos que ejecutaban una assertion, imprimían luego un mensaje `OK` y terminaban con código 0.

Los avisos de `ObjectDB instances leaked` y `resources still in use at exit` no se interpretan por sí solos como assertion fallida; deben limpiarse progresivamente, pero no sustituyen el resultado funcional del test.

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

Los tests relacionados con pantallas, presenters, layouts, router, HUD, Finca, Mercado, Barracones, Arena, Relaciones, dossier, menús o localización se asignan a `ui`.

Todo test restante se asigna a `core`. No existe un estado sin grupo.

La clasificación afecta únicamente la distribución del CI; no cambia cómo se ejecuta el test.

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
- deja de detectar assertions y fallos de compilación;
- el CI deja de ejecutar las suites `core` y `ui`.

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
