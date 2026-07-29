# Dirección visual híbrida

Este documento fija la dirección visual de producción de Ludus Gladiator
Simulator. El objetivo es combinar lectura inmediata durante el combate con
retratos expresivos en las pantallas de gestión, sin exigir que ambos niveles
usen la misma resolución o técnica.

## Combate

- Cada combatiente usa un lienzo individual de **64 × 64 píxeles**.
- La altura habitual de la figura es de **46 a 56 píxeles**, reservando margen
  para armas, plumas, efectos y poses extremas.
- La cámara se mantiene lateral o en tres cuartos lateral de forma coherente
  para todos los combatientes.
- El juego escala los sprites únicamente con factores enteros y desactiva el
  filtrado de textura para conservar bordes nítidos.
- La paleta es reducida. Los cambios de material o facción deben seguir siendo
  distinguibles sin depender de gradientes finos.
- La silueta tiene prioridad sobre el detalle interior.
- Armas y escudos se sobredimensionan deliberadamente para comunicar la carga
  de equipo a escala de combate.
- Cuerpo, casco, arma, escudo, faldellín y efectos se mantienen como capas
  modulares que comparten lienzo, origen y pivote.
- Las animaciones usan pocos cuadros claramente diferenciados. Se favorecen
  poses legibles sobre movimientos largos o interpolaciones excesivas.

## Perfil del personaje

- Los retratos de producción se preparan a **256 × 256** o **512 × 512
  píxeles**.
- La referencia estilística es una ilustración de novela gráfica: contornos
  definidos, masas de color claras y luz controlada.
- El retrato no está obligado a usar pixel art.
- Casco, colores principales, rasgos faciales y cicatrices deben coincidir con
  el sprite de combate.
- La animación se limita a parpadeo, respiración, variación de luz y parallax
  sutil.
- No se usan vídeos de IA continuos, interpolación generativa ni fondos con
  parpadeo generativo. El movimiento debe proceder de capas fijas y
  deterministas dentro de Godot.

## Interfaz

- Paneles e iconos pueden inspirarse en pixel art, con bordes definidos y una
  paleta compatible con la escena de combate.
- El texto prioriza alta legibilidad y no necesita usar una fuente pixelada.
- Los paneles escalables se construyen con `NinePatchRect` para conservar
  esquinas y bordes.
- Los retratos detallados se presentan dentro de marcos coherentes con el resto
  de la interfaz y no como elementos visualmente independientes.

## Regla de coherencia

El sprite y el retrato son dos representaciones del mismo inventario y la misma
identidad. Las diferencias de detalle son deliberadas; las diferencias de
equipo, color o rasgos identificadores no lo son.
