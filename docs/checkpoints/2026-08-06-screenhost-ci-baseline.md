# Checkpoint estable — ScreenHost y CI

Fecha: 2026-08-06
Rama: `feature/demo-data-foundation`
Commit funcional validado: `88d3558fa51c3b3dfbb5d95d636e838cc031b8e6`
Motor: Godot 4.5.2

## Estado validado

Este checkpoint fija una línea base estable después de la migración de navegación hacia `ScreenHost` y de la estabilización de GitHub Actions.

Resultados confirmados en GitHub Actions:

- Compile and smoke test: verde.
- Core systems suite: 58/58.
- UI and integration contracts: 34/34.
- GUT behavior tests: 33/33.
- Total de pruebas clasificadas: 92 contratos Core/UI, más 33 pruebas GUT.

## Arquitectura vigente

- `FincaHubController` es el router principal de navegación.
- `ScreenHost` aloja las pantallas modernas.
- Finca, Barracones, Mercado, Arena, Campaña, Eventos y demás paneles hospedados se instancian bajo demanda.
- Personal, Forja y Equipamiento permanecen como pestañas heredadas de compatibilidad, ocultas para navegación directa.
- Solo una pantalla hospedada puede permanecer visible e interactiva a la vez.
- Al abrir una pestaña heredada, `ScreenHost` queda oculto e inactivo.

## Flujo funcional cubierto

La integración remota valida:

1. Apertura de `Main.tscn`.
2. Creación de campaña con nombre, título y origen.
3. Entrada automática a Finca.
4. Navegación Finca → sistema → Finca.
5. Recorrido por Barracones, Mercado, Forja, Eventos, Campaña y Arena.
6. Entrada a Forja desde el hotspot de la finca.
7. Exclusividad visual e interacción de `ScreenHost`.
8. Cierre semanal y avance exacto de una semana.
9. Guardado de campaña.
10. Regreso al menú principal.
11. Continuación de campaña guardada.

## Limpieza completada

Se eliminaron los controladores obsoletos:

- `res://scripts/ui/finca_building_navigation_controller.gd`
- `res://scripts/ui/finca_return_navigation_controller.gd`

Los contratos impiden que vuelvan a introducirse mientras la navegación dependa de `ScreenHost`.

## Compatibilidad preservada

- Versión de guardado: 14.
- Compatibilidad con guardados v12 y v13 verificada.
- Migraciones de progresión y tutorial verificadas.
- No se renombraron rutas serializadas ni campos persistentes.

## Reglas para continuar desde este checkpoint

Toda modificación posterior debe:

- mantener verdes los cuatro jobs de CI;
- preservar el esquema de guardado v14;
- evitar nuevas dependencias sobre rutas visibles de `TabContainer` para pantallas modernas;
- añadir o actualizar contratos cuando cambie navegación, persistencia o flujo semanal;
- no reintroducir los dos controladores de Finca eliminados.

## Riesgos técnicos pendientes

- Personal, Forja y Equipamiento todavía dependen de pestañas heredadas y rutas fijas dentro de `Main.tscn`.
- La validación visual real en ventana sigue siendo recomendable antes de publicar una build, aunque el flujo headless ya está cubierto.
- Los cambios de layout, escalado, foco y navegación por teclado requieren revisión específica cuando se trabaje nuevamente con el editor.
