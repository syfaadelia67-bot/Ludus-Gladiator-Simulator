extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var file := FileAccess.open("res://scripts/ui/arena_experience_controller.gd", FileAccess.READ)
    assert(file != null, "The arena tactical controller must exist")
    var source := file.get_as_text()
    file.close()

    assert(source.contains("TACTICAL_CONDITIONS"), "The arena must expose tactical conditions")
    assert(source.contains("MAX_TACTICAL_ORDERS := 4"), "The demo must limit tactical plans to four orders")
    assert(source.contains("GladiatorProgressionManager.get_tactical_plan"), "The arena must load the saved gladiator plan")
    assert(source.contains("GladiatorProgressionManager.set_tactical_plan"), "The arena must persist the confirmed plan")
    assert(source.contains("target_vulnerable"), "The vulnerable target condition must be available")
    assert(source.contains("self_low_health"), "The low health condition must be available")
    assert(source.contains("after_dodge_or_block"), "The reaction condition must be available")
    assert(source.contains("\"tactical_plan\":draft_plan.duplicate(true)"), "The confirmed plan must be passed to combat configuration")
    assert(source.contains("\"abilities\":prepared_abilities"), "Prepared canonical abilities must be passed to combat")
    assert(not source.contains("selected_techniques"), "The arena must no longer use the legacy equipped-techniques list")
    assert(not source.contains("Equipar técnica"), "The arena must use tactical orders rather than legacy technique equipment")

    print("Tactical plan UI contract tests passed")
    quit(0)
