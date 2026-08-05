# Suite de pruebas

## Convenciones reconocidas

El ejecutor descubre de forma recursiva archivos con alguno de estos sufijos:

- `*_test.gd`
- `*_contract.gd`

Cada archivo se ejecuta en un proceso de Godot aislado para impedir que el estado global de un test contamine al siguiente.

## Modos compatibles

### Tests que extienden `Node`

Se ejecutan dentro del proyecto mediante el autoload `TestRunner`, con todos los autoloads del juego disponibles.

```powershell
godot --headless --path game -- --test=res://tests/example_test.gd
```

### Tests que extienden `SceneTree`

El ejecutor los detecta por su declaración `extends SceneTree` y los lanza automáticamente mediante `--script`.

También pueden ejecutarse directamente:

```powershell
godot --headless --path game --script res://tests/example_contract.gd
```

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

Los tests con marcadores de pantalla, router, HUD, Finca, Mercado, Barracones, Arena, Relaciones, dossier o localización se asignan a `ui`.

Todo test restante se asigna a `core`. No existe un estado sin grupo.

La clasificación afecta únicamente la distribución del CI; no cambia cómo se ejecuta el test.

## Exclusiones

La única exclusión inicial es:

- `test_runner.gd`: orquestador autoload de la suite; no contiene un caso de prueba.

Toda exclusión futura debe agregarse a `EXCLUDED_TEST_FILES` dentro de `test_runner.gd` con una explicación legible.

## Regla de cobertura

`test_test_suite_coverage_contract.gd` falla cuando:

- aparece un `.gd` en `game/tests/` que no sigue una convención reconocida;
- una exclusión no tiene justificación;
- desaparece alguno de los tres bloques del workflow;
- el runner deja de reconocer tests o contratos;
- el CI deja de ejecutar las suites `core` y `ui`.

## CI

El workflow `.github/workflows/godot-tests.yml` se divide en:

1. `compile`: importación, compilación y smoke test de `Main.tscn`;
2. `core-systems`: suite automática de sistemas centrales;
3. `ui-contracts`: suite automática de UI e integración.

No se instala ningún plugin durante estas tareas. Se utiliza Godot 4.5.2.
