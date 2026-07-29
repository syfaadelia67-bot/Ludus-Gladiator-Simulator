# Athletic Adult Gladiator

Primer candidato artístico para validar una figura masculina adulta real dentro de un lienzo exacto de 64×64. Es un asset de desarrollo original; no es arte comercial final.

## Métricas

| Propiedad | Resultado |
|---|---:|
| Lienzo | 64×64 px |
| Caja visible equipada | 59×61 px |
| Altura visible | 61 px |
| Cabeza anatómica estimada | 10 px / 16,4 % |
| Proporción estimada | 6,1 cabezas |
| Colores visibles | 16 |
| Paleta configurada | 19 colores |
| Frames | 4 |
| Velocidad | 8 fps / 0,125 s por frame |
| Pivote de pies | normalizado `(0.5, 0.96875)`, equivalente a `(32, 62)` |

Todos los PNG tienen fondo transparente, píxeles enteros, sin antialiasing y sin degradados automáticos. La escena fuerza filtrado nearest.

## Capas

El documento Gator local contiene siete capas:

1. `Body`
2. `Hair`
3. `Beard`
4. `Cloth`
5. `Helmet`
6. `Weapon`
7. `Shield`

Se agrupan localmente como `Anatomy`, `Clothing` y `Equipment`. El faldellín, casco, espada y escudo pueden ocultarse o sustituirse sin redibujar el cuerpo. Solo se versionan los PNG, metadatos y recursos exportados; el documento Gator y el addon permanecen locales.

## Decisiones anatómicas

- La cabeza ocupa aproximadamente una sexta parte de la altura, por debajo del límite del 18 %.
- Los hombros sobresalen claramente de la cintura y forman un torso en V.
- El pecho, caja torácica, flancos y abdominales se construyen con masas irregulares y planos de luz, no con un único rectángulo.
- Los brazos distinguen hombro, bíceps, codo, antebrazo y mano.
- Las piernas arrancan visualmente en el píxel 31 y llegan al 61; son ligeramente más largas que el conjunto cabeza-torso.
- Rodillas, pantorrillas y tobillos tienen cambios de ancho explícitos.
- Manos y pies se mantienen contenidos, sin aumentar su tamaño para “vender” detalle.
- La cabeza y la nariz apuntan a la derecha; el hombro y la pierna delanteros reciben más luz para sostener la vista de tres cuartos.
- El casco deja visible el rostro, la barba y la línea mandibular; no sustituye la masa de la cabeza.
- El sombreado usa bloques de uno a tres píxeles y una luz superior izquierda. No intenta reproducir el detalle pseudo-pixel de la referencia.

## Idle

Los cuatro frames mantienen ambos pies exactamente en la misma posición.

- Frames 1 y 2: cabeza, cuello, pecho y hombros suben un píxel.
- Espada y escudo acompañan con una variación máxima de un píxel.
- El borde inferior del faldellín cambia un píxel en un único frame.
- No hay squash-and-stretch, rebote vertical del cuerpo completo ni deformación elástica.

## Cambios frente al placeholder

- Proporción de 6,1 cabezas frente a la lectura cercana a cuatro/cinco cabezas del placeholder.
- Cabeza más pequeña, cuello visible y mandíbula seria.
- Hombros más anchos y cintura más estrecha.
- Piernas más largas, con rodillas y pantorrillas diferenciadas.
- Codos, manos, tobillos y pies dejan de ser bloques rectangulares uniformes.
- Mayor volumen corporal mediante sombra, tono medio, luz y pequeños highlights.
- Postura asimétrica de tres cuartos en lugar de una figura frontal rígida.
- Equipo modular apoyado sobre un cuerpo base legible.

La silueta negra conserva cabeza, hombros, escudo, espada y separación de piernas a escala 1×. La lámina de la escena compara directamente ambos sprites y muestra el candidato a 1× y 4×.

## Limitaciones

- A 64×64, el escudo tapa parte del brazo posterior y reduce la lectura del torso equipado.
- La mano de la espada necesita una pasada manual de artista para mejorar el agarre.
- El borde del casco y la barba compiten en dos píxeles de la mandíbula.
- La musculatura es deliberadamente simplificada; pecho y rodillas requieren una revisión de clusters para evitar ruido al crear nuevos cuerpos.
- La vista de tres cuartos funciona por iluminación y asimetría, pero un artista debería reforzar la rotación de pelvis.
- El idle está técnicamente controlado, aunque todavía necesita evaluación en contexto junto a fondos y UI finales.
- Antes de producción masiva deben revisarse el diseño de pies, el perfil del escudo y la coherencia de la fuente de luz entre todo el equipo.

## Recomendación del candidato

**Iterar.** Supera objetivamente el placeholder en proporción, silueta y anatomía, y valida que Gator puede mantener capas e idle. Todavía requiere una pasada artística humana sobre mano/arma, pelvis, casco y clusters musculares antes de declararlo estándar comercial.
