# Localización de Ludus Gladiator Simulator

## Idiomas iniciales

- `es`: Español, idioma fuente y fallback.
- `en`: Inglés.
- `zh_CN`: Chino simplificado.
- `ja`: Japonés.
- `pt_BR`: Portugués de Brasil.

La preferencia del jugador se guarda en `user://localization.cfg`. No forma parte del guardado de campaña y no modifica `SAVE_VERSION`.

## Regla obligatoria

Todo texto nuevo visible para el jugador debe nacer como una clave semántica traducible.

Correcto:

```gdscript
button.text = tr("MARKET_BUY_ITEM")
label.text = LocalizationManager.translate_key("DOSSIER_HEALTH_FORMAT", {
    "current": current_health,
    "maximum": maximum_health
})
```

Incorrecto:

```gdscript
button.text = "Comprar"
label.text = "Salud " + str(current_health)
```

## Convención de claves

Formato: `SISTEMA_SECCION_CONCEPTO` en mayúsculas, números y guion bajo.

Ejemplos:

- `HUD_CLOSE_WEEK`
- `DOSSIER_TAB_EQUIPMENT`
- `EQUIPMENT_SLOT_RIGHT_HAND`
- `RELATIONSHIP_STATE_RIVALRY`
- `ABILITY_PRECISE_STRIKE_NAME`

No usar una frase española o inglesa como clave.

## Datos de juego

Los catálogos JSON deben migrar progresivamente a campos de clave:

```json
{
  "id": "precise_strike",
  "name_key": "ABILITY_PRECISE_STRIKE_NAME",
  "description_key": "ABILITY_PRECISE_STRIKE_DESCRIPTION"
}
```

Durante la transición se mantiene compatibilidad con:

```json
{
  "name": "Golpe preciso",
  "description": "Ataque controlado con alta precisión."
}
```

La clave traducible es la fuente principal; el texto heredado es solo fallback.

## Frases dinámicas

Traducir la frase completa usando placeholders. No concatenar fragmentos porque el orden gramatical cambia entre idiomas.

```gdscript
LocalizationManager.translate_key("START_ACTIVE_CAMPAIGN_SUMMARY", {
    "owner": owner_name,
    "week": week,
    "chapter": chapter,
    "chapter_name": chapter_name,
    "battle": battle_name
})
```

Para cantidades, usar `translate_plural_key()` o `tr_n()`.

## Tipografía

El tema define cuatro roles:

- `TitleLabel`: títulos principales.
- `HeadingLabel`: encabezados de panel.
- `BodyLabel`: texto normal.
- `CompactLabel`: HUD, contadores y textos secundarios.

`LocalizationManager` aplica perfiles de fuentes del sistema:

- `latin`: español, inglés y portugués.
- `cjk_sc`: chino simplificado.
- `cjk_jp`: japonés.

Esta selección es una base temporal. Cuando se incorporen fuentes licenciadas dentro del proyecto, se reemplazarán las familias del sistema sin cambiar las pantallas.

## Pseudolocalización

En compilaciones de desarrollo puede activarse desde la pantalla inicial o con `F8`.

Se utiliza para detectar:

- botones demasiado pequeños;
- textos recortados;
- cadenas sin traducir;
- placeholders dañados;
- layouts dependientes de la longitud española.

Debe permanecer desactivada en producción.

## Flujo de traducción

1. Agregar la clave a `messages.pot`.
2. Agregar una traducción a cada archivo `.po`.
3. Usar la clave desde escena, script o catálogo.
4. Ejecutar `test_localization_foundation_contract.gd`.
5. Probar español, inglés, chino, japonés, portugués y pseudolocalización.

## Migración actual

La pantalla inicial y creación de campaña ya usan claves. El orden de migración restante está definido en `localization_manifest.json`.
