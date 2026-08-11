# Evaluación del pipeline Pixel 64

Este documento define la evaluación reproducible previa a adoptar una herramienta de producción para los gladiadores de combate de Ludus Gladiator Simulator.

La captura estructurada de resultados se realiza en [`pixel-pipeline-scorecard.md`](pixel-pipeline-scorecard.md). Ningún campo de esa planilla debe completarse por estimación.

## Objetivo

Comparar tres flujos con el mismo personaje, las mismas capas y las mismas animaciones:

1. Gator Sprite Studio.
2. Pixel-Prof.
3. Pixelorama + Importality.

La prueba debe determinar cuál produce sprites adultos de 64 × 64 con menor retrabajo, menor dependencia y mejor integración con Godot 4.5.2.

## Restricciones

- Ningún plugin propietario o herramienta de evaluación se versiona.
- Los plugins locales se excluyen mediante `.git/info/exclude`.
- El proyecto debe arrancar sin ninguna herramienta artística instalada.
- Solo pueden versionarse assets propios exportados, recursos Godot propios y resultados documentados.
- No se inventan tiempos, puntuaciones ni resultados de estabilidad.
- Toda puntuación debe enlazar evidencia registrada en la planilla de resultados.

## Personaje patrón

Cada herramienta debe recrear el mismo gladiador:

- lienzo real de 64 × 64;
- altura visible objetivo de 57 a 61 píxeles;
- vista tres cuartos lateral;
- proporciones adultas de aproximadamente 5,5 a 6,25 cabezas;
- cabeza pequeña, piernas largas y torso atlético;
- silueta legible antes que detalle interior;
- contorno oscuro y paleta reducida;
- prohibición expresa de estética chibi.

### Capas obligatorias

- `Body`
- `Cloth`
- `Hair`
- `Helmet`
- `Weapon`
- `Shield`
- `Effects`

### Variantes obligatorias

- casco de hierro y casco de bronce;
- espada y lanza corta;
- escudo redondo y escudo torre;
- faldellín rojo y faldellín azul.

### Animaciones

| Animación | Cuadros mínimos |
| --- | ---: |
| `idle` | 4 |
| `attack` | 5 |
| `block` | 3 |
| `hit` | 3 |
| `defeat` | 5 |

## Procedimiento por herramienta

Para cada opción se deben registrar con cronómetro:

1. instalación y configuración inicial;
2. creación del cuerpo base;
3. creación de `idle`;
4. creación de `attack`;
5. creación de una variante de casco;
6. modificación de un cuadro ya exportado;
7. reexportación y actualización en Godot.

También se deben ejecutar:

- 20 operaciones de undo consecutivas;
- 20 operaciones de redo consecutivas;
- cierre completo de la herramienta;
- reapertura del documento fuente;
- dos exportaciones consecutivas;
- comparación SHA-256 de exportaciones consecutivas sin cambios;
- sustitución de equipo sin mover el cuerpo;
- reproducción de las cinco animaciones después de sustituir equipo.

## Criterios de evaluación

| Criterio | Registro requerido |
| --- | --- |
| Tiempo de instalación | Minutos y segundos medidos |
| Tiempo del primer cuerpo | Minutos y segundos medidos |
| Tiempo de `idle` | Minutos y segundos medidos |
| Tiempo de `attack` | Minutos y segundos medidos |
| Tiempo para variante de casco | Minutos y segundos medidos |
| Tiempo de reexportación | Minutos y segundos medidos |
| Capas conservadas | Sí / No / Parcial |
| Tags conservados | Sí / No / No aplica |
| Pivotes consistentes | Sí / No |
| Undo/redo fiable | Sí / No / Incidencias |
| Reapertura fiable | Sí / No / Incidencias |
| Exportación reproducible | Sí / No, con SHA-256 |
| Integración con Godot | Descripción técnica |
| Facilidad para automatización | Baja / Media / Alta, con evidencia |
| Calidad visual resultante | Revisión comparativa, no opinión aislada |
| Licencia | Tipo y restricciones |
| Riesgo de dependencia | Bajo / Medio / Alto, con motivo |

## Prueba visual común

Los resultados independientes deben poder reproducirse en una escena comparativa sin plugins:

`game/scenes/dev/PixelPipelineComparison.tscn`

La escena deberá permitir:

- seleccionar uno de los tres pipelines;
- reproducir `idle`, `attack`, `block`, `hit` y `defeat`;
- alternar casco, arma, escudo y faldellín;
- comprobar escalas ×2, ×4 y ×6;
- alternar fondo claro y oscuro;
- mostrar una grilla de 64 × 64 y la altura visible del personaje.

La escena solo se versionará cuando no dependa de código de terceros para ejecutarse.

## Umbrales de descarte

Una herramienta se descarta como pipeline principal si ocurre cualquiera de estas condiciones:

- pérdida de capas o frames al reabrir;
- exportación no determinista en dos ejecuciones consecutivas;
- imposibilidad de conservar pivotes compartidos;
- dependencia obligatoria del plugin para ejecutar el juego;
- incompatibilidad no corregible con Godot 4.5.2;
- licencia incompatible con el repositorio o la distribución prevista;
- resultado visual persistentemente chibi después de aplicar la guía adulta.

Una condición de descarte prevalece sobre cualquier puntuación total.

## Decisión final permitida

El informe de resultados deberá elegir exactamente una conclusión:

- adoptar Gator localmente;
- adoptar Pixel-Prof;
- adoptar Pixelorama + Importality;
- mantener dos herramientas con funciones diferenciadas;
- descartar las tres y usar un flujo manual.

## Validación mínima posterior

Después de retirar o desactivar herramientas locales:

```bash
godot45 --headless --editor --path game --quit
godot45 --headless --path game --script res://tests/history_integrity_validator_test.gd
godot45 --headless --path game --script res://tests/combat_history_persistence_test.gd
godot45 --headless --path game --script res://tests/data_repository_test.gd
godot45 --headless --path game res://scenes/Main.tscn --quit
git diff --check
git status
```

El pipeline elegido no podrá fusionarse a `main` hasta que el proyecto supere esta validación sin depender de la herramienta artística instalada.

## Estado

La metodología y la planilla de captura están definidas. Las mediciones y el ganador permanecen pendientes de la prueba local controlada; no deben completarse por estimación.
