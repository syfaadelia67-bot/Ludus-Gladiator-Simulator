extends Node

func _ready() -> void:
    var save_source := FileAccess.get_file_as_string("res://scripts/core/save_manager.gd")
    var owner_source := FileAccess.get_file_as_string("res://scripts/systems/ludus_owner_manager.gd")

    assert(save_source.contains("const SAVE_VERSION := 14"))
    assert(save_source.contains("\"owner\":LudusOwnerManager.export_state()"))
    assert(save_source.contains("LudusOwnerManager.import_state"))
    assert(save_source.contains("\"owner_name\""))
    assert(save_source.contains("\"owner_title\""))
    assert(save_source.contains("LudusOwnerManager.reset_profile()"))

    assert(owner_source.contains("LEGACY_PROFILE_PATH"))
    assert(owner_source.contains("_import_legacy_profile_once"))
    assert(not owner_source.contains("func _save_local_profile"))
    assert(not owner_source.contains("PROFILE_PATH :="))
    assert(owner_source.contains("SaveManager.call_deferred(\"save_game\")"))

    print("Unified owner save contract: OK")
    get_tree().quit()
