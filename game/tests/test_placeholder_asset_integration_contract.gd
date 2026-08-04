extends SceneTree

const REQUIRED_ARENA_ASSETS := [
    "ui/arena_combat/combat_attack",
    "ui/arena_combat/combat_beast",
    "ui/arena_combat/combat_bleeding",
    "ui/arena_combat/combat_critical",
    "ui/arena_combat/combat_crowd",
    "ui/arena_combat/combat_defeat",
    "ui/arena_combat/combat_defense",
    "ui/arena_combat/combat_dodge",
    "ui/arena_combat/combat_initiative",
    "ui/arena_combat/combat_stun",
    "ui/arena_combat/combat_tactic",
    "ui/arena_combat/combat_victory"
]

func _initialize() -> void:
    var project := FileAccess.get_file_as_string("res://project.godot")
    var arena_scene := FileAccess.get_file_as_string("res://scenes/ArenaScreen.tscn")
    var arena_controller := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
    var registry := FileAccess.get_file_as_string("res://scripts/ui/pack_000_asset_registry.gd")

    assert(not project.contains("PlaceholderAssetIntegrator="))
    assert(project.contains("Pack000Assets=\"*res://scripts/ui/pack_000_asset_registry.gd\""))
    assert(registry.contains("PACK_ROOT := \"res://assets/placeholders/pack_000\""))
    assert(registry.contains("_scan_directory"))
    assert(registry.contains("ResourceLoader.exists"))
    assert(registry.contains("load(full_path) as Texture2D"))
    assert(registry.contains("get_texture_count"))

    for asset_id in REQUIRED_ARENA_ASSETS:
        assert(arena_controller.contains(asset_id))

    for asset_id in [
        "ui/gladiator_status/status_health",
        "ui/gladiator_status/status_fatigue",
        "ui/gladiator_status/status_morale",
        "ui/gladiator_status/status_injury",
        "ui/gladiator_status/status_rivalry",
        "ui/equipment/equipment_weapon_sword",
        "ui/equipment/equipment_torso_armor",
        "ui/equipment/equipment_shield",
        "ui/equipment/equipment_head_helmet",
        "ui/equipment/equipment_feet_boots",
        "ui/equipment/equipment_additional_net",
        "buildings/building_private_arena"
    ]:
        assert(arena_controller.contains(asset_id))

    assert(arena_scene.contains("name=\"PlayerFighter\"") or arena_scene.contains("name = \"PlayerFighter\""))
    assert(arena_scene.contains("name=\"EnemyFighter\"") or arena_scene.contains("name = \"EnemyFighter\""))
    assert(arena_scene.contains("name=\"EffectIcon\"") or arena_scene.contains("name = \"EffectIcon\""))
    assert(arena_scene.contains("name=\"StatusIcons\"") or arena_scene.contains("name = \"StatusIcons\""))
    assert(arena_scene.contains("name=\"EquipmentIcons\"") or arena_scene.contains("name = \"EquipmentIcons\""))
    assert(arena_scene.contains("name=\"ResultEffects\"") or arena_scene.contains("name = \"ResultEffects\""))

    var packed := load("res://scenes/ArenaScreen.tscn")
    var registry_script := load("res://scripts/ui/pack_000_asset_registry.gd")
    assert(packed is PackedScene)
    assert(registry_script != null)
    var instance := (packed as PackedScene).instantiate()
    assert(instance.get_node_or_null("Body/CenterPanel/Margin/Scroll/Content/PreparationView/ArenaVisual/Margin/VisualContent/Battlefield/PlayerFighter") != null)
    assert(instance.get_node_or_null("Body/CenterPanel/Margin/Scroll/Content/PreparationView/ArenaVisual/Margin/VisualContent/Battlefield/EnemyFighter") != null)
    assert(instance.get_node_or_null("Body/CenterPanel/Margin/Scroll/Content/PreparationView/ArenaVisual/Margin/VisualContent/Battlefield/EffectIcon") != null)
    assert(instance.get_node_or_null("Body/CenterPanel/Margin/Scroll/Content/ResultView/ResultHeader/ResultIcon") != null)
    instance.free()

    print("Complete Pack 000 and arena asset integration contract: OK")
    quit()
