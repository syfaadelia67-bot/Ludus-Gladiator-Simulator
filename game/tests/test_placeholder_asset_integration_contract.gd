extends SceneTree

func _initialize() -> void:
    var project := FileAccess.get_file_as_string("res://project.godot")
    var arena_scene := FileAccess.get_file_as_string("res://scenes/ArenaScreen.tscn")

    assert(not project.contains("PlaceholderAssetIntegrator="))
    assert(arena_scene.contains("combat_attack.png"))
    assert(arena_scene.contains("combat_defense.png"))
    assert(arena_scene.contains("combat_victory.png"))
    assert(arena_scene.contains("name=\"StartCombat\"") or arena_scene.contains("name = \"StartCombat\""))
    assert(arena_scene.contains("name=\"PlayerCard\"") or arena_scene.contains("name = \"PlayerCard\""))
    assert(arena_scene.contains("name=\"EnemyCard\"") or arena_scene.contains("name = \"EnemyCard\""))

    var packed := load("res://scenes/ArenaScreen.tscn")
    assert(packed is PackedScene)
    var instance := (packed as PackedScene).instantiate()
    assert(instance.get_node_or_null("Body/CenterPanel/Margin/Content/PreparationView/ArenaVisual/Margin/VisualContent/Stage/PlayerCard/Portrait") != null)
    assert(instance.get_node_or_null("Body/CenterPanel/Margin/Content/PreparationView/ArenaVisual/Margin/VisualContent/Stage/EnemyCard/Portrait") != null)
    assert(instance.get_node_or_null("Body/CenterPanel/Margin/Content/ResultView/ResultHeader/Icon") != null)
    instance.free()

    print("Placeholder asset integration contract: OK")
    quit()
