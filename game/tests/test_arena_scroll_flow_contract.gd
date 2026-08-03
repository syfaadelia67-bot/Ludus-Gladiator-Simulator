extends SceneTree

func _initialize() -> void:
    var project := FileAccess.get_file_as_string("res://project.godot")
    var controller_text := FileAccess.get_file_as_string("res://scripts/ui/arena_experience_controller.gd")
    var bootstrap_text := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")
    var preview_text := FileAccess.get_file_as_string("res://scripts/ui/arena_opponent_preview_presenter.gd")
    var placeholder_text := FileAccess.get_file_as_string("res://scripts/ui/placeholder_asset_integrator.gd")

    assert(not project.contains("ArenaCombatResultPresenter="))
    assert(not FileAccess.file_exists("res://scripts/ui/arena_combat_result_presenter.gd"))

    assert(controller_text.contains("ScrollContainer.new()"))
    assert(controller_text.contains("ArenaScroll"))
    assert(controller_text.contains("ArenaContent"))
    assert(controller_text.contains("_disconnect_legacy_combat_result_handler"))
    assert(controller_text.contains("CombatManager.combat_finished.disconnect"))
    assert(controller_text.contains("_render_base_result(result)"))
    assert(controller_text.contains("REPETICIÓN MANUAL"))
    assert(controller_text.contains("call_deferred(\"_scroll_to_result\")"))
    assert(not controller_text.contains("_render_report(result)\n    _start_replay()"))

    assert(bootstrap_text.contains("BackToFinca"))
    assert(bootstrap_text.contains("BackToPersonal"))
    assert(preview_text.contains("ArenaScroll/ArenaContent"))

    assert(not placeholder_text.contains("HudVisualSkinControllerScript"))
    assert(not placeholder_text.contains("hud_visual_skin_controller.gd"))
    assert(placeholder_text.contains("if tree == null:"))
    assert(placeholder_text.contains("if not is_inside_tree():"))

    var controller_script := load("res://scripts/ui/arena_experience_controller.gd")
    var main_scene := load("res://scenes/Main.tscn")
    assert(controller_script != null)
    assert(main_scene is PackedScene)

    print("Arena scroll flow contract: OK")
    quit()
