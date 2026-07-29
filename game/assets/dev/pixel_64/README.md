# Prototipo modular Pixel 64

Este directorio contiene assets experimentales y no comerciales para evaluar
el pipeline híbrido definido en `docs/visual-direction.md`. No contiene ni
depende del plugin vectorial.

## Estructura y reglas de importación

- `body/`: cuerpo base y tonos de piel claro y oscuro.
- `helmet/`: casco de hierro con pluma y casco de bronce.
- `weapon/`: espada y lanza corta.
- `shield/`: escudo redondo azul y escudo torre rojo.
- `cloth/`: faldellín rojo y azul.
- `effects/`: destello de impacto.
- `portrait/`: retrato original 512 × 512.
- `ui/`: textura 16 × 16 para paneles `NinePatchRect`.

Los 13 PNG de combate miden exactamente 64 × 64, tienen canal alfa y comparten
el origen superior izquierdo. Sus importadores usan compresión lossless
(`compress/mode=0`) y no generan mipmaps. El rig fija `texture_filter = NEAREST`
en cada `CanvasItem`; por ello los factores ×2, ×4 y ×6 conservan bordes duros
sin depender de la configuración local del editor.

El pivote general está en los pies. Arma, escudo y faldellín tienen pivotes
locales en la empuñadura, el centro del escudo y la cintura. Las texturas
continúan alineadas a un único lienzo, por lo que sustituir equipo no requiere
reposicionarlo.

## Paleta provisional

| Uso | Color |
| --- | --- |
| Contorno | `#1D191C` |
| Piel clara | `#CD8B58` |
| Piel oscura | `#824E34` |
| Bronce | `#B17730`, `#E0AE48` |
| Hierro | `#6C747D`, `#B0B8BB` |
| Rojo | `#8E262D`, `#CA3E38` |
| Azul | `#294B77`, `#40759D` |

## Animación y modularidad

`PixelGladiatorRig.tscn` usa 12 nodos: un nodo raíz, un pivote visual, seis
capas visibles, tres pivotes locales y un `AnimationPlayer`. Las animaciones se
construyen de forma determinista al iniciar el rig:

| Animación | Poses/keys principales | Duración |
| --- | ---: | ---: |
| `idle` | 4 | 0,80 s |
| `attack` | 5 | 0,55 s |
| `block` | 3 | 0,48 s |
| `hit` | 3 | 0,42 s |
| `defeat` | 5 | 0,90 s |

Casco, arma, escudo y color del faldellín se sustituyen mediante asignación de
texturas independientes. El cambio no recrea el rig ni altera sus pivotes.

## Medición de rendimiento

Equipo: AMD Radeon 760M Graphics, OpenGL 3.3 Compatibility, Godot 4.5.2,
viewport 1280 × 720. No se ejecutaron instancias de Godot en paralelo.

Metodología: para cada cantidad se reconstruyó el grupo, se esperaron 1,5
segundos de calentamiento y se midieron 3,0 segundos (180 frames) mientras todos
los rigs reproducían `idle`. El frame time se midió alrededor de cada
`process_frame`; los draw calls y memoria estática proceden de monitores de
`Performance`. La memoria es el total estático del proceso, no el costo aislado
de los gladiadores.

| Instancias | FPS promedio | Frame promedio | Draw calls promedio/pico | Memoria estática |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 59,97 | 16,676 ms | 11 / 11 | 43,29 MiB |
| 10 | 59,98 | 16,673 ms | 11 / 11 | 43,81 MiB |
| 25 | 59,93 | 16,685 ms | 11 / 11 | 44,71 MiB |
| 50 | 59,97 | 16,676 ms | 11 / 11 | 46,16 MiB |
| 100 | 59,96 | 16,677 ms | 11 / 11 | 49,07 MiB |

Observación visual: no hubo degradación, errores de render ni pérdida de
sincronía perceptible hasta 100 instancias. Los draw calls permanecieron
constantes porque el renderer agrupó las capas 2D compatibles. No se obtuvo una
lectura de CPU aislada y fiable.

## Comparación con el prototipo vectorial

Solo se emplean datos ya reportados por el experimento vectorial anterior.
Cuando no existe una medición comparable se indica expresamente.

| Criterio | Pixel 64 | Vectorial |
| --- | --- | --- |
| Tiempo de preparación artística | No medido | No medido |
| Tiempo técnico de importación | No aislado; el escaneo completo del editor fue 5,7 s | Arranque + import del bake reportado: ~8,4 s, no aislado |
| Nodos del personaje fuente | 12 en el rig Pixel 64 | 43 en el prototipo; 11 formas vectoriales independientes |
| Nodos de versión horneada | No aplica | 7 |
| Draw calls, 1 personaje | 11 en la escena de benchmark completa | 22 reportados |
| Draw calls, 10 personajes | 11, con batching | 220 reportados |
| Assets raster del prototipo | 433.426 bytes en 14 PNG; combate sin retrato/UI: 4.366 bytes | Spritesheet horneado: 44.442 bytes; fuente aislada del personaje: no medida |
| Dependencia de tooling | Ninguna adicional | Plugin reportado de ~4,39 MiB |
| Recoloreado | Fácil con variantes de paleta o `modulate`, pero genera texturas si cambia el detalle | Edición directa de color en formas; muy flexible |
| Sustitución de equipo | Asignación de textura; origen y pivote compartidos | Sustitución de nodos/formas independientes |
| Escalado | Excelente en ×2, ×4 y ×6; pierde intención fuera de escalas enteras | Independiente de resolución antes del horneado |
| Diez gladiadores distintos | Costo de arte no medido; se reutilizan cuerpo y equipo | Costo de arte no medido |
| Dificultad de animación | Baja para poses discretas; más trabajo si cada frame exige redibujo | Mayor complejidad de rig, mejor interpolación de deformaciones |

La comparación de draw calls favorece al prototipo pixel en esta escena, pero
no constituye una comparación de gameplay completo: materiales, efectos, UI y
composición final pueden alterar el batching.

## Tamaño registrado

- 14 PNG: **433.426 bytes**.
- Capas de combate, sin retrato ni panel: **4.366 bytes**.
- Retrato 512 × 512: **428.901 bytes**.
- Panel UI 16 × 16: **159 bytes**.

Los `.import` conservan la configuración reproducible; la caché binaria
correspondiente permanece en `.godot/` y no se versiona.
