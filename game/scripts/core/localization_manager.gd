extends Node

signal locale_changed(locale: String)
signal locale_preference_changed(preference: String)
signal pseudolocalization_changed(enabled: bool)

const SETTINGS_PATH := "user://localization.cfg"
const AUTOMATIC_LOCALE := "automatic"
const DEFAULT_LOCALE := "es"
const SUPPORTED_LOCALES: Array[String] = ["es", "en", "zh_CN", "ja", "pt_BR"]
const LOCALE_LABEL_KEYS := {
    AUTOMATIC_LOCALE: "LANGUAGE_AUTOMATIC",
    "es": "LANGUAGE_SPANISH",
    "en": "LANGUAGE_ENGLISH",
    "zh_CN": "LANGUAGE_CHINESE_SIMPLIFIED",
    "ja": "LANGUAGE_JAPANESE",
    "pt_BR": "LANGUAGE_PORTUGUESE_BRAZIL"
}

var locale_preference := AUTOMATIC_LOCALE
var active_locale := DEFAULT_LOCALE
var pseudolocalization_enabled := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _load_preferences()
    _apply_locale_preference(false)
    TranslationServer.set_pseudolocalization_enabled(pseudolocalization_enabled)

func get_supported_locales() -> Array[String]:
    return SUPPORTED_LOCALES.duplicate()

func get_locale_options() -> Array[String]:
    var options: Array[String] = [AUTOMATIC_LOCALE]
    options.append_array(SUPPORTED_LOCALES)
    return options

func get_locale_preference() -> String:
    return locale_preference

func get_active_locale() -> String:
    return active_locale

func get_locale_label(locale_or_preference: String) -> String:
    var key := str(LOCALE_LABEL_KEYS.get(locale_or_preference, "LANGUAGE_SPANISH"))
    return translate_key(key)

func set_locale_preference(preference: String, persist: bool = true) -> bool:
    var normalized := preference.strip_edges()
    if normalized != AUTOMATIC_LOCALE:
        normalized = _canonical_supported_locale(normalized)
        if normalized.is_empty():
            return false
    if locale_preference == normalized:
        return true
    locale_preference = normalized
    _apply_locale_preference(persist)
    locale_preference_changed.emit(locale_preference)
    return true

func set_locale(locale: String, persist: bool = true) -> bool:
    return set_locale_preference(locale, persist)

func set_pseudolocalization_enabled(enabled: bool, persist: bool = true) -> void:
    if pseudolocalization_enabled == enabled:
        return
    pseudolocalization_enabled = enabled
    TranslationServer.set_pseudolocalization_enabled(enabled)
    if persist:
        _save_preferences()
    pseudolocalization_changed.emit(enabled)
    locale_changed.emit(active_locale)

func toggle_pseudolocalization() -> void:
    set_pseudolocalization_enabled(not pseudolocalization_enabled)

func is_pseudolocalization_enabled() -> bool:
    return pseudolocalization_enabled

func translate_key(key: String, values: Dictionary = {}) -> String:
    var translated := str(TranslationServer.translate(key))
    return translated.format(values) if not values.is_empty() else translated

func translate_plural_key(singular_key: String, plural_key: String, amount: int, values: Dictionary = {}) -> String:
    var translated := str(TranslationServer.translate_plural(singular_key, plural_key, amount))
    var merged := values.duplicate(true)
    merged["count"] = amount
    return translated.format(merged)

func refresh_system_locale() -> void:
    if locale_preference == AUTOMATIC_LOCALE:
        _apply_locale_preference(false)

func _apply_locale_preference(persist: bool) -> void:
    var resolved := _resolve_system_locale() if locale_preference == AUTOMATIC_LOCALE else _canonical_supported_locale(locale_preference)
    if resolved.is_empty():
        resolved = DEFAULT_LOCALE
    active_locale = resolved
    TranslationServer.set_locale(active_locale)
    if persist:
        _save_preferences()
    locale_changed.emit(active_locale)

func _resolve_system_locale() -> String:
    var system_locale := TranslationServer.standardize_locale(OS.get_locale(), true)
    var language := system_locale.get_slice("_", 0).to_lower()
    match language:
        "en": return "en"
        "ja": return "ja"
        "pt": return "pt_BR"
        "zh": return "zh_CN"
        "es": return "es"
        _: return DEFAULT_LOCALE

func _canonical_supported_locale(locale: String) -> String:
    var standardized := TranslationServer.standardize_locale(locale, true)
    if SUPPORTED_LOCALES.has(standardized):
        return standardized
    var language := standardized.get_slice("_", 0).to_lower()
    match language:
        "en": return "en"
        "ja": return "ja"
        "pt": return "pt_BR"
        "zh": return "zh_CN"
        "es": return "es"
        _: return ""

func _load_preferences() -> void:
    var config := ConfigFile.new()
    if config.load(SETTINGS_PATH) != OK:
        locale_preference = AUTOMATIC_LOCALE
        pseudolocalization_enabled = false
        return
    locale_preference = str(config.get_value("localization", "locale", AUTOMATIC_LOCALE))
    if locale_preference != AUTOMATIC_LOCALE and _canonical_supported_locale(locale_preference).is_empty():
        locale_preference = AUTOMATIC_LOCALE
    pseudolocalization_enabled = bool(config.get_value("localization", "pseudolocalization_enabled", false))

func _save_preferences() -> void:
    var config := ConfigFile.new()
    config.set_value("localization", "locale", locale_preference)
    config.set_value("localization", "pseudolocalization_enabled", pseudolocalization_enabled)
    var error := config.save(SETTINGS_PATH)
    if error != OK:
        push_warning("No se pudo guardar la preferencia de localización: %s" % error)

func _unhandled_key_input(event: InputEvent) -> void:
    if not OS.is_debug_build() or not event.pressed or event.echo:
        return
    if event.keycode == KEY_F8:
        toggle_pseudolocalization()
        get_viewport().set_input_as_handled()
