# Ludus Placeholder Pack 000A — Cierre de producción

Pack temporal de arte para la demo de **Ludus Gladiator Simulator**.

## Estado

- Uso: prototipado, integración visual y validación funcional.
- Calidad: placeholder controlado.
- Arte final: no.
- Reemplazo futuro: conservar nombres y rutas cuando sea posible.
- Formatos principales: PNG con transparencia y documentación Markdown/TXT.

## Contenido consolidado

### Mundo y finca
- Edificios principales del ludus.
- Terreno, caminos y agua.
- Estructuras y props ambientales.

### Interfaz
- Botones y estados.
- Paneles y barras.
- Checkboxes, slots, marcos y scrollbars.
- Cursores, navegación e iconos de acción.
- Recursos y estados generales.

### Sistemas del juego
- Equipamiento.
- Estados del gladiador.
- Acciones de gestión.
- Instalaciones.
- Relaciones, rasgos y reputación.
- Arena y combate.

## Reglas de integración

1. No considerar ningún archivo de este pack como arte definitivo.
2. Evitar renombrar assets ya conectados desde Godot.
3. Reemplazar cada PNG manteniendo ruta, nombre y dimensiones compatibles.
4. No mezclar assets sin licencia verificable.
5. Ejecutar `tools/audit_pack_000.ps1` antes de cerrar una entrega.
6. No agregar archivos `.uid` accidentalmente mediante `git add .`.

## Fuentes

- Kenney Medieval RTS — CC0.
- Kenney UI Pack — CC0.
- Kenney UI Pack RPG Expansion — CC0.
- Placeholders originales creados específicamente para Ludus Gladiator Simulator.

El paquete externo “Pack Of Medieval Tools” continúa excluido porque no se verificó una licencia dentro de su archivo distribuido.
