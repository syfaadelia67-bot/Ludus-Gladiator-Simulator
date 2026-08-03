# Reparación del cierre del Pack 000

Esta reparación reemplaza siete archivos que tenían extensión `.png` pero contenido inválido:

- buildings/building_market.png
- buildings/building_private_arena.png
- terrain/terrain_grass.png
- terrain/terrain_road_straight.png
- ui/bars/ui_bar_health_mid.png
- ui/buttons/ui_button_secondary.png
- ui/panels/ui_panel_brown.png

También actualiza el auditor:

- solo aplica la regla de minúsculas a archivos PNG;
- mantiene los duplicados como advertencias informativas;
- utiliza mensajes ASCII para evitar texto mal codificado en Windows PowerShell.
