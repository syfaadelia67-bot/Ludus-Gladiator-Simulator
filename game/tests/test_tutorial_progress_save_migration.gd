extends Node

func _ready() -> void:
    var owner_source := FileAccess.get_file_as_string("res://scripts/systems/ludus_owner_manager.gd")
    var tutorial_source := FileAccess.get_file_as_string("res://scripts/ui/tutorial_controller.gd")
    var save_source := FileAccess.get_file_as_string("res://scripts/core/save_manager.gd")

    assert(owner_source.contains("\"tutorial_progress\": {"))
    assert(owner_source.contains("clampi(current_step, 0, TUTORIAL_STEP_COUNT - 1)"))
    assert(owner_source.contains("var raw_progress: Variant = profile.get(\"tutorial_progress\", {})"))
    assert(owner_source.contains("sanitized_objectives"))
    assert(owner_source.contains("SaveManager.call_deferred(\"save_game\")"))
    assert(tutorial_source.contains("_restore_progress()"))
    assert(tutorial_source.contains("_persist_progress()"))
    assert(save_source.contains("\"owner\":LudusOwnerManager.export_state()"))
    assert(save_source.contains("LudusOwnerManager.import_state"))

    print("Tutorial progress save migration contract: OK")
    get_tree().quit()
