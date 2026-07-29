# Athletic Adult Gladiator

Candidato técnico original para validar una figura masculina adulta en pixel art
dentro de un lienzo corporal de 64×64. La iteración 2 refina la misma base
aprobada en `554d172`; no reconstruye el personaje ni pretende ser arte comercial
final.

## Versiones conservadas

- Los archivos `athletic_adult_*`, `body_base_*`, las láminas
  `adult_candidate_dark.png` y `adult_candidate_light.png` son la primera
  iteración y se conservan sin cambios como evidencia.
- La segunda iteración está bajo `v2/`. La escena experimental compara directamente
  ambas versiones.
- El documento Gator y el generador permanecen locales. Godot solo necesita los
  PNG, metadatos, `SpriteFrames` y la escena exportados.

## Métricas invariantes

| Propiedad | Iteración 1 | Iteración 2 |
|---|---:|---:|
| Lienzo corporal | 64×64 px | 64×64 px |
| Caja visible equipada | 59×61 px | 59×61 px |
| Altura visible | 61 px | 61 px |
| Cabeza anatómica | 10 px / 16,4 % | 10 px / 16,4 % |
| Proporción estimada | 6,1 cabezas | 6,1 cabezas |
| Colores visibles | 16 | 16 |
| Paleta configurada | 19 | 19 |
| Frames de idle | 4 | 4 |
| Velocidad | 8 fps | 8 fps |
| Pivote de pies | `(32, 62)` | `(32, 62)` |

Todos los PNG tienen fondo transparente, píxeles enteros, sin antialiasing ni
degradados automáticos. La escena fuerza filtrado nearest.

## Capas

El documento Gator local conserva las siete capas de la primera versión:

1. `Body`
2. `Hair`
3. `Beard`
4. `Cloth`
5. `Helmet`
6. `Weapon`
7. `Shield`

Se agrupan como `Anatomy`, `Clothing` y `Equipment`. Faldellín, casco, espada y
escudo se exportan en sheets independientes y pueden sustituirse sin redibujar el
cuerpo.

## Cambios anatómicos de la iteración 2

- La línea de hombros pasa de casi horizontal a una diagonal: el hombro posterior
  parte alrededor de `(27, 16)` y el hombro de espada se proyecta desde
  `(42, 13)`.
- El pectoral posterior se comprime y oscurece; el pectoral delantero gana anchura
  y luz. El esternón y el ombligo dejan de estar centrados.
- Los clusters rectangulares del abdomen se sustituyen por oblicuos y planos
  asimétricos de tres o cuatro píxeles.
- La pelvis ocupa una masa oblicua entre `y=29` y `y=38`, girada en sentido
  contrario a los hombros. Ya no es una banda rectangular.
- La pierna delantera cargada mantiene una línea más vertical entre cadera,
  rodilla y tobillo, con pie plantado entre `x=37` y `x=51`.
- La pierna retrasada se inclina hacia `x=18`, muestra menos luz y termina en un
  talón elevado visualmente. Ambas plantas permanecen inmóviles.
- Los brazos ahora separan hombro, bíceps, codo, antebrazo y mano mediante cambios
  de ancho. El brazo de espada avanza; el del escudo queda más bajo y atrás.
- La mano de espada envuelve el mango entre `x=53..56`, y la guarda cruza la mano
  en vez de flotar delante de ella.
- El casco baja su masa lateral y termina alrededor de `y=13`; deja más mandíbula
  visible. La barba se reduce a un cluster mandibular más corto.
- El escudo pasa de centro `(17, 27)` y radio exterior `12×14` a centro aproximado
  `(14, 28)` y radio `9×13`. Su masa sigue siendo legible, pero deja visible la
  transición del brazo posterior.
- La postura reparte el peso sobre la pierna adelantada y crea una silueta
  asimétrica de combate, en lugar de una figura frontal sosteniendo objetos.

La lámina anatómica usa deliberadamente el cuerpo sin equipo en la grilla de 6×.
Así el escudo no puede ocultar errores de hombro, cintura, pelvis o piernas.

## Idle, segunda pasada

El ciclo mantiene cuatro poses a 8 fps:

1. **Neutral:** caja torácica relajada, escudo y espada en apoyo.
2. **Inhalación:** hombros tensan un píxel y la espada inicia una elevación mínima.
3. **Pico:** pecho y hombros sostienen la tensión; escudo y faldellín responden un
   píxel.
4. **Liberación:** el arma y el escudo descienden hacia la pose neutral.

No hay traslación vertical general, rebote, squash-and-stretch ni deformación
elástica. Cabeza, pelvis y pies mantienen su referencia espacial. La comparación
RGBA exacta entre frames equipados produjo:

| Transición | Píxeles diferentes |
|---|---:|
| 0 → 1 | 168 |
| 1 → 2 | 219 |
| 2 → 3 | 229 |
| 3 → 0 | 156 |

La última transición no introduce un salto excepcional: es la menor diferencia
del ciclo. La zona corporal `y=54..63` es idéntica en las cuatro poses.

## Margen para animaciones futuras

La caja equipada `x=5..63`, `y=1..61` ocupa todo el margen derecho. Es correcta
para idle, pero no puede contener con seguridad un arco de espada, una lanza, un
retroceso amplio o una caída horizontal.

Se evaluaron cuatro estrategias sin cambiar todavía el formato de producción:

### Armas externas al lienzo corporal

Es la recomendación principal. Cuerpo y ropa mantienen frames de 64×64 y el pivote
de pies; espada, lanza, escudo y efectos se reproducen como sprites o capas
separadas con el mismo origen. Permite ataques amplios y sustitución de equipo sin
reducir al gladiador.

### Frames de combate mayores

Son adecuados como excepción para una caída horizontal o una pose extrema. Un
frame de 96×64 podría contener `defeat`; ataques muy amplios podrían usar 96×96.
El coste es mayor memoria de atlas y más disciplina de pivotes.

### Regiones variables

Ahorran espacio, pero trasladan complejidad a importación, offsets y validación de
pivotes. No se recomiendan como formato principal.

### Menor ocupación del personaje

Dejaría margen dentro de 64×64, pero reduciría la lectura anatómica a 1× y
desaprovecharía la altura adulta aprobada. Se descarta para el cuerpo base.

### Decisión recomendada

Usar un enfoque híbrido:

- cuerpo, cabello y ropa en 64×64;
- armas y efectos externos anclados al pivote de pies/manos;
- regiones mayores solo para caída o poses corporales extremas;
- conservar offsets explícitos y comunes para todos los tipos de equipo.

Aplicado a casos futuros:

- espada y lanza: sprites externos;
- impacto: cuerpo 64×64 más efecto externo y desplazamiento del nodo;
- caída: región excepcional de 96×64;
- efectos: nodos independientes, nunca recortados por el lienzo corporal.

Esta recomendación queda documentada, pero no modifica aún el formato de
producción ni añade animaciones de combate.

## Evidencia y limitaciones

La escena muestra iteración 1, iteración 2, cuerpo sin equipo, equipado, silueta,
escala 1× y 4×, fondos claro y oscuro, y guías de cabeza, hombros, pelvis,
rodillas y pies.

La segunda iteración mejora orientación del pecho, contrapposto, agarre, pelvis,
transiciones articulares y visibilidad del brazo posterior. Todavía conviene una
revisión humana de clusters faciales, mano/guarda, forma del pie retrasado y
coherencia de volumen entre escudo y cuerpo.

## Recomendación

**Solicitar intervención manual de artista.** La base técnica y anatómica ya es
estable y la segunda iteración corrige los problemas estructurales principales.
Una tercera pasada generada de forma procedimental tendría rendimiento decreciente;
el siguiente salto de calidad debe venir de limpieza manual de clusters, no de
otra reconstrucción automática.
