# Athletic Adult Gladiator — 128×128 Candidate

Experimento aislado para comprobar si un lienzo de 128×128 permite resolver mejor
la anatomía adulta, la pose y la legibilidad del equipo que el candidato de
64×64. No cambia el estándar oficial del proyecto ni sustituye los assets de
64×64.

La escena y los recursos exportados funcionan sin Gator instalado. El documento
fuente y el generador permanecen locales; el runtime solo utiliza PNG, JSON,
`SpriteFrames` y recursos propios de Godot.

## Métricas

| Propiedad | Resultado |
|---|---:|
| Lienzo por frame | 128×128 px |
| Caja visible equipada | 121×122 px |
| Altura visible | 122 px |
| Cabeza anatómica | 19 px / 15,6 % |
| Proporción estimada | 6,4 cabezas |
| Colores visibles | 23 |
| Paleta configurada | 24 |
| Frames de idle | 4 |
| Velocidad | 8 fps |
| Pivote de pies | `(64, 125)` |

La caja visible ocupa `x=7..127` y `y=3..124`. Todos los PNG tienen fondo
transparente, píxeles enteros, sin antialiasing ni degradados automáticos. La
escena fuerza filtrado nearest.

## Capas modulares

El asset se exportó en siete capas sustituibles:

1. `Body`
2. `Hair`
3. `Beard`
4. `Cloth`
5. `Helmet`
6. `Weapon`
7. `Shield`

También existen grupos auxiliares de autoría (`Anatomy`, `Clothing` y
`Equipment`). Las hojas de cada capa están en `layers/`; faldellín, casco,
espada y escudo pueden cambiarse sin redibujar el cuerpo.

## Decisiones anatómicas y de pose

- La cabeza se mantiene por debajo del 18 % de la altura y el cuello permanece
  visible aun con el casco.
- La línea de hombros gira hacia la derecha: el hombro de espada se proyecta y
  el posterior se comprime.
- El esternón, el ombligo y los pectorales son asimétricos para evitar un torso
  frontal construido como rectángulos.
- La cintura se estrecha antes de una pelvis oblicua, girada en oposición leve a
  los hombros.
- La pierna delantera soporta el peso con una planta ancha; la retrasada tiene
  menos luz, menor masa aparente y un ángulo de salida distinto.
- Hombro, bíceps, codo, antebrazo, mano, rodilla, pantorrilla y tobillo tienen
  cambios de ancho propios.
- El escudo se desplaza hacia el exterior y deja leer parte del brazo posterior.
- La espada sale de una mano cerrada y conserva un eje diagonal independiente.
- El rostro usa ceja, nariz, mandíbula y barba compactas para mantener una
  expresión seria a escala 1×.

La grilla anatómica de la lámina muestra el cuerpo sin equipo para que casco,
escudo y arma no oculten la evaluación.

## Idle

El ciclo usa cuatro poses:

1. **Neutral:** caja torácica y equipo en apoyo.
2. **Inhalación:** hombros tensan un píxel; espada y escudo inician una variación
   mínima.
3. **Pico:** el pecho sostiene la tensión, sin trasladar pelvis ni pies.
4. **Liberación:** torso y equipo vuelven progresivamente a neutral.

No hay rebote general, squash-and-stretch ni desplazamiento vertical de los
pies. La zona `y=112..127` es idéntica en los cuatro frames. La comparación RGBA
exacta produjo:

| Transición | Píxeles diferentes |
|---|---:|
| 0 → 1 | 413 |
| 1 → 2 | 800 |
| 2 → 3 | 535 |
| 3 → 0 | 674 |

Todas las transiciones tienen movimiento perceptible y el cierre del loop queda
por debajo de la transición de máxima tensión. La revisión visual no muestra un
salto al volver al primer frame.

## Comparación objetiva

| Criterio | Iteración 2 de 64×64 | Candidato 128×128 |
|---|---|---|
| Pose | La torsión existe, pero varios planos convergen en pocos píxeles. | Hombros, pelvis y apoyo de piernas se separan con mayor claridad. |
| Cabeza | 10 px, 16,4 % y 6,1 cabezas. | 19 px, 15,6 % y 6,4 cabezas; la proporción adulta se lee mejor. |
| Torso | Los clusters simplificados aún sugieren bloques geométricos. | Pectorales, oblicuos y cintura permiten planos asimétricos más orgánicos. |
| Piernas y pelvis | La pierna retrasada pierde volumen y la pelvis tiene poco margen. | Cadera, rodillas, pantorrillas y pies admiten siluetas distintas. |
| Equipo | El escudo compite con brazo y torso. | Escudo y arma son más legibles y ocultan menos anatomía. |
| Idle | Sobrio y estable, con cambios muy concentrados. | La respiración puede repartirse entre hombros, pecho, arma y escudo. |
| Lectura 1× | Funcional, pero algunos detalles anatómicos colapsan. | La pose y las articulaciones sobreviven mejor sin ampliación. |

La mejora no consiste únicamente en agregar detalle: la resolución adicional
permite corregir negativos de silueta, rotación, reparto de peso y transiciones
articulares. Aun así, este candidato es técnico, no arte comercial final.

## Coste de producción

- Cada frame y cada capa contienen cuatro veces los píxeles de un frame 64×64.
- Aumentan memoria de texturas, tamaño de atlas, tiempo de autoría, limpieza y
  control de consistencia entre animaciones.
- Manos, rostro y equipo aceptan más detalle, pero también hacen más visibles las
  inconsistencias entre artistas y frames.
- Una migración directa exigiría rehacer el catálogo de animaciones y revisar
  escalas, cámaras, colisiones visuales y densidad de pantalla.
- El tiempo artístico no crece necesariamente cuatro veces, pero se estima entre
  dos y cuatro veces por pose terminada según equipo y animación. Esta es una
  estimación de producción, no una medición cronometrada.

## Limitaciones

- La mano de espada y el agarre requieren limpieza subpixel manual por un artista.
- La pierna retrasada y su pie todavía se sienten más delgados que la pierna
  cargada.
- La transición casco, cabello y sien necesita una jerarquía de clusters más
  refinada.
- Los planos musculares son legibles, pero el sombreado procedural todavía no
  alcanza una dirección artística comercial coherente.
- Faltan pruebas con ataques, bloqueos, impactos, caídas y armas largas.
- No se ha medido aún el coste real de producir un set completo de animaciones.

## Recomendación

**Seguir en 64×64, pero usar 128×128 como base de trabajo y luego simplificar.**

El 128×128 mejora realmente el objetivo artístico —pose, proporciones, volumen y
equipo—, pero una migración inmediata del combate no está justificada con un solo
idle. Conviene usarlo como master anatómico para definir poses y clusters, y
crear después una simplificación manual a 64×64; reducir automáticamente con
nearest no sustituye esa intervención. Si un set completo conserva la mejora tras
esa simplificación, el proyecto mantiene el coste y la densidad visual actuales.

## Evidencia

- `adult_candidate_128_dark.png`: fondo oscuro, 1×, 4×, silueta, grilla y
  comparación.
- `adult_candidate_128_light.png`: la misma revisión sobre fondo claro.
- `athletic_adult_128_sheet.png`: idle equipado.
- `body_base_128_idle_sheet.png`: idle anatómico sin equipo.
- `layers/`: hojas modulares por pieza.
- `athletic_adult_128_metadata.json`: frames, velocidad y pivotes.
