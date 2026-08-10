extends SceneTree

const REQUIRED_ARENA_ASSETS := [
	"combat_attack",
	"combat_beast",
	"combat_bleeding",
	"combat_critical",
	"combat_crowd",
	"combat_defeat",
	"combat_defense",
	"combat_dodge",
	"combat_initiative",
	"combat_stun",
	"combat_tactic",
	"combat_victory",
]


func _initialize() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var arena_scene := FileAccess.get_file_as_string("res://scenes/ArenaScreen.tscn")
	var arena_controller := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
	var registry := FileAccess.get_file_as_string("res://scripts/ui/pack_000_asset_registry.gd")

	assert(not project.contains("PlaceholderAssetIntegrator="))
	assert(project.contains('Pack000Assets="*res://scripts/ui/pack_000_asset_registry.gd"'))
	assert(registry.contains('PACK_ROOT := "res://assets/placeholders/pack_000"'))
	assert(registry.contains("_scan_directory"))
	assert(registry.contains("ResourceLoader.exists"))
	assert(registry.contains("get_texture_count"))

	for asset_name in REQUIRED_ARENA_ASSETS:
		var path := "res://assets/placeholders/pack_000/ui/arena_combat/%s.png" % asset_name
		assert(FileAccess.file_exists(path))

	assert(arena_controller.contains("CombatV1ArenaRuntimeScript"))
	assert(not arena_controller.contains("Pack000Assets"))
	assert(not arena_controller.contains("CombatManager"))
	assert(arena_scene.contains('name="PlayerFighter"') or arena_scene.contains('name = "PlayerFighter"'))
	assert(arena_scene.contains('name="EnemyFighter"') or arena_scene.contains('name = "EnemyFighter"'))
	assert(arena_scene.contains('name="EffectIcon"') or arena_scene.contains('name = "EffectIcon"'))
	assert(arena_scene.contains('name="StatusIcons"') or arena_scene.contains('name = "StatusIcons"'))
	assert(arena_scene.contains('name="EquipmentIcons"') or arena_scene.contains('name = "EquipmentIcons"'))
	assert(arena_scene.contains('name="ResultEffects"') or arena_scene.contains('name = "ResultEffects"'))

	assert(load("res://scenes/ArenaScreen.tscn") is PackedScene)
	assert(load("res://scripts/ui/pack_000_asset_registry.gd") != null)
	print("Pack 000 availability and Combat V1 Arena decoupling contract: OK")
	quit()
