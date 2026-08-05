extends SceneTree

const LOCALES: Array[String] = ["es", "en", "zh_CN", "ja", "pt_BR"]
const LOCALE_FILES := {
    "es": "res://localization/es.po",
    "en": "res://localization/en.po",
    "zh_CN": "res://localization/zh_CN.po",
    "ja": "res://localization/ja.po",
    "pt_BR": "res://localization/pt_BR.po"
}

func _initialize() -> void:
    var project_text := FileAccess.get_file_as_string("res://project.godot")
    var manager_text := FileAccess.get_file_as_string("res://scripts/core/localization_manager.gd")
    var start_text := FileAccess.get_file_as_string("res://scripts/ui/start_screen_controller.gd")
    var theme_text := FileAccess.get_file_as_string("res://assets/placeholders/pack_000/ui/pack_000_theme.tres")
    var pot_text := FileAccess.get_file_as_string("res://localization/messages.pot")
    var shared_text := FileAccess.get_file_as_string("res://localization/shared.es.po")
    var manifest_text := FileAccess.get_file_as_string("res://localization/localization_manifest.json")
    var save_text := FileAccess.get_file_as_string("res://scripts/core/save_manager_demo.gd")

    assert(project_text.contains("[internationalization]"))
    assert(project_text.contains("locale/fallback=\"es\""))
    assert(project_text.contains("LocalizationManager=\"*res://scripts/core/localization_manager.gd\""))
    assert(project_text.find("LocalizationManager=") < project_text.find("StartScreenController="))
    assert(project_text.contains("pseudolocalization/use_pseudolocalization=false"))
    assert(project_text.contains("pseudolocalization/expansion_ratio=0.3"))
    for locale in LOCALES:
        assert(project_text.contains(str(LOCALE_FILES[locale]).trim_prefix("res://")) or project_text.contains(str(LOCALE_FILES[locale])))

    assert(manager_text.contains("const SETTINGS_PATH := \"user://localization.cfg\""))
    assert(manager_text.contains("const SUPPORTED_LOCALES: Array[String] = [\"es\", \"en\", \"zh_CN\", \"ja\", \"pt_BR\"]"))
    assert(manager_text.contains("TranslationServer.set_locale(active_locale)"))
    assert(manager_text.contains("TranslationServer.set_pseudolocalization_enabled"))
    assert(manager_text.contains("func translate_plural_key"))
    assert(manager_text.contains("func _apply_typography_for_locale"))
    assert(manager_text.contains("Noto Sans CJK SC"))
    assert(manager_text.contains("Noto Serif CJK JP"))
    assert(manager_text.contains("typography_profile_changed"))

    assert(start_text.contains("LocalizationManager.translate_key"))
    assert(start_text.contains("func _add_language_controls"))
    assert(start_text.contains("LocalizationManager.get_locale_options()"))
    assert(start_text.contains("LocalizationManager.set_locale_preference"))
    assert(start_text.contains("LocalizationManager.set_pseudolocalization_enabled"))
    assert(start_text.contains("func _capture_owner_draft"))
    assert(start_text.contains("func _restore_owner_draft"))
    assert(start_text.contains("theme_type_variation = &\"TitleLabel\""))
    for forbidden in [
        "button.text = \"Nueva campaña\"",
        "button.text = \"Continuar campaña\"",
        "button.text = \"Salir\"",
        "status_label.text = \"Cargando campaña...\"",
        "name_input.placeholder_text = \"Nombre del propietario o propietaria\""
    ]:
        assert(not start_text.contains(forbidden))

    for variation in ["TitleLabel", "HeadingLabel", "BodyLabel", "CompactLabel"]:
        assert(theme_text.contains("%s/base_type = &\"Label\"" % variation))
        assert(theme_text.contains("%s/font_sizes/font_size" % variation))

    var template_keys := _po_keys(pot_text)
    assert(template_keys.has("START_BRAND"))
    assert(template_keys.has("LANGUAGE_LABEL"))
    assert(template_keys.has("START_ACTIVE_CAMPAIGN_SUMMARY"))
    assert(template_keys.size() >= 40)
    for key in template_keys:
        assert(_valid_key(key))

    var required_locale_keys := template_keys.duplicate()
    required_locale_keys.erase("START_BRAND")
    for locale in LOCALES:
        var path := str(LOCALE_FILES[locale])
        assert(FileAccess.file_exists(path))
        var catalog_text := FileAccess.get_file_as_string(path)
        assert(catalog_text.contains("Language: %s\\n" % locale))
        var translations := _po_translations(catalog_text)
        for key in required_locale_keys:
            assert(translations.has(key))
            assert(not str(translations[key]).is_empty())
    var shared_translations := _po_translations(shared_text)
    assert(str(shared_translations.get("START_BRAND", "")) == "LUDUS")

    var manifest_value = JSON.parse_string(manifest_text)
    assert(manifest_value is Dictionary)
    var manifest: Dictionary = manifest_value
    assert(str(manifest.get("source_locale", "")) == "es")
    assert(str(manifest.get("save_version_impact", "")) == "none")
    assert((manifest.get("supported_locales", []) as Array).size() == 5)
    assert((manifest.get("migrated_files", []) as Array).has("res://scripts/ui/start_screen_controller.gd"))
    assert((manifest.get("migration_order", []) as Array).size() >= 6)

    assert(save_text.contains("const SAVE_VERSION := 14"))
    assert(load("res://scripts/core/localization_manager.gd") != null)
    assert(load("res://scripts/ui/start_screen_controller.gd") != null)
    assert(load("res://assets/placeholders/pack_000/ui/pack_000_theme.tres") is Theme)

    call_deferred("_run_runtime_checks")

func _run_runtime_checks() -> void:
    await process_frame
    var manager := get_root().get_node_or_null("LocalizationManager")
    assert(manager != null)
    var original_preference := str(manager.call("get_locale_preference"))
    var original_pseudo := bool(manager.call("is_pseudolocalization_enabled"))

    assert(bool(manager.call("set_locale_preference", "en", false)))
    assert(str(TranslationServer.translate("START_NEW_CAMPAIGN")) == "New campaign")
    assert(str(TranslationServer.translate("START_BRAND")) == "LUDUS")
    assert(str(manager.call("get_typography_profile")) == "latin")

    assert(bool(manager.call("set_locale_preference", "zh_CN", false)))
    assert(str(TranslationServer.translate("START_NEW_CAMPAIGN")) == "新战役")
    assert(str(manager.call("get_typography_profile")) == "cjk_sc")

    assert(bool(manager.call("set_locale_preference", "ja", false)))
    assert(str(TranslationServer.translate("START_NEW_CAMPAIGN")) == "新しいキャンペーン")
    assert(str(manager.call("get_typography_profile")) == "cjk_jp")

    manager.call("set_pseudolocalization_enabled", true, false)
    assert(TranslationServer.is_pseudolocalization_enabled())
    manager.call("set_pseudolocalization_enabled", original_pseudo, false)
    manager.call("set_locale_preference", original_preference, false)

    print("Localization foundation, five locales and CJK typography contract: OK")
    quit()

func _po_keys(text: String) -> Array[String]:
    var keys: Array[String] = []
    for raw_line in text.split("\n"):
        var line := str(raw_line).strip_edges()
        if not line.begins_with("msgid \"") or line == "msgid \"\"":
            continue
        var key := line.trim_prefix("msgid \"").trim_suffix("\"")
        if not key.is_empty() and not keys.has(key):
            keys.append(key)
    return keys

func _po_translations(text: String) -> Dictionary:
    var result: Dictionary = {}
    var current_key := ""
    for raw_line in text.split("\n"):
        var line := str(raw_line).strip_edges()
        if line.begins_with("msgid \""):
            current_key = line.trim_prefix("msgid \"").trim_suffix("\"")
        elif line.begins_with("msgstr \"") and not current_key.is_empty():
            result[current_key] = line.trim_prefix("msgstr \"").trim_suffix("\"")
            current_key = ""
    return result

func _valid_key(key: String) -> bool:
    if key.is_empty() or not key[0].to_upper() == key[0]:
        return false
    for character in key:
        var code := character.unicode_at(0)
        var is_upper := code >= 65 and code <= 90
        var is_digit := code >= 48 and code <= 57
        if not is_upper and not is_digit and character != "_":
            return false
    return true
