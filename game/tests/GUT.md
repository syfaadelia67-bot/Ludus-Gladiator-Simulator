# GUT 9.5.0 en Ludus

## Alcance de esta etapa

GUT se incorpora como una capa adicional. El `TestRunner` histórico continúa cubriendo los contratos existentes y no se reemplaza durante esta fase.

Las primeras suites GUT cubren:

- guardado v14;
- economía semanal;
- calendario y migración día/semana;
- campaña de dieciséis semanas;
- traducciones y perfiles tipográficos;
- modelo de gladiadores;
- carga e instanciación básica de escenas principales.

GDScript Formatter y la automatización definitiva con `godot-ci` quedan fuera de esta etapa. Se incorporarán después de comprobar esta base localmente.

## Dependencia fijada

La dependencia está definida en `res://tools/gut.lock.json`:

- GUT: `9.5.0`;
- commit: `8255c6305761754748f9fd641da5fd8f51c1708a`;
- instalación: `res://addons/gut`.

El repositorio no usa `latest`. Los instaladores descargan el archivo asociado al commit inmutable y verifican que `addons/gut/plugin.cfg` declare la versión `9.5.0`.

El addon no se habilita como plugin del editor. En esta etapa se utiliza únicamente mediante CLI para reducir efectos laterales sobre el proyecto.

## Por qué las pruebas están en plantillas

Los scripts reales de GUT deben declarar `extends GutTest`. Esa clase existe recién después de instalar el addon.

Para que una copia limpia del repositorio pueda seguir importándose antes de la instalación, las fuentes se guardan como:

```text
res://tests/gut_templates/**/*.gd.in
```

El instalador materializa copias `.gd` en:

```text
res://tests/gut/
```

Las carpetas generadas, el addon y los resultados XML están ignorados por Git. La fuente mantenida y revisable sigue siendo cada archivo `.gd.in`.

## Windows

Desde la carpeta `game`:

```powershell
.\tools\install_gut_9_5.ps1
```

Ejecutar todas las suites:

```powershell
.\tools\run_gut.ps1
```

Ejecutar una familia por nombre de archivo:

```powershell
.\tools\run_gut.ps1 -Select save
.\tools\run_gut.ps1 -Select economy
.\tools\run_gut.ps1 -Select scene_smoke
```

Reinstalar desde cero:

```powershell
.\tools\run_gut.ps1 -Reinstall
```

Usar un ejecutable de Godot distinto:

```powershell
.\tools\run_gut.ps1 -GodotCommand "C:\ruta\a\Godot_v4.5.2-stable_win64_console.exe"
```

## Linux o macOS

```bash
bash tools/install_gut_9_5.sh
bash tools/run_gut.sh
bash tools/run_gut.sh --select save
bash tools/run_gut.sh --reinstall
```

También puede indicarse el ejecutable:

```bash
GODOT_COMMAND=/ruta/a/godot bash tools/run_gut.sh
```

## Qué hace el launcher

`run_gut` ejecuta esta secuencia:

1. instala o valida GUT 9.5.0;
2. materializa las siete plantillas;
3. importa el proyecto en Godot 4.5.2 para registrar `GutTest` y las clases del addon;
4. ejecuta `res://tools/ludus_gut_cmdln.gd` en headless;
5. GUT descubre `res://tests/gut/unit` y `res://tests/gut/integration`;
6. genera `res://test-results/gut.xml`;
7. devuelve código `0` cuando la suite pasa y un código distinto de cero cuando falla.

El wrapper de Ludus retira solamente los autoloads de presentación durante el proceso GUT. GUT no abre `Main.tscn`; sin ese aislamiento, varios presenters esperarían una escena principal inexistente y terminarían emitiendo `push_error`. Los managers de guardado, economía, campaña, calendario, localización y gladiadores permanecen disponibles.

## Política de errores

La configuración considera fallos:

- errores del motor o de scripts;
- errores internos de GUT;
- llamadas a `push_error` durante una prueba.

Los huérfanos no están ocultos. El objetivo es que una suite aparentemente verde no tape errores de Godot ni objetos sin liberar.

## Resultados esperados

El primer run debe descubrir siete scripts. La cantidad total de funciones puede crecer, pero las siete familias deben aparecer:

```text
save_system
economy_system
calendar_system
campaign_system
localization_system
gladiator_model
scene_smoke
```

El archivo JUnit queda en:

```text
res://test-results/gut.xml
```

Todavía no se publica mediante GitHub Actions. Esa automatización se incorporará junto con la reorganización posterior de CI.

## Contrato de instalación

La infraestructura se protege con:

```powershell
godot --headless --path . -- --test=res://tests/test_gut_foundation_contract.gd
```

Ese contrato no necesita que GUT esté instalado. Verifica la versión fijada, configuración, instaladores, launchers, wrapper, exclusiones de Git y presencia de las siete plantillas.
