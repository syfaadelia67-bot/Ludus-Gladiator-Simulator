extends Node

const MAIN_SCENE_NAME := "Main"
const ARENA_PATH := "Margin/VBox/Tabs/Arena"

const ATTACK_ICON_PATH := "res://assets/placeholders/pack_000/ui/arena_combat/combat_attack.png"
const DEFENSE_ICON_PATH := "res://assets/placeholders/pack_000/ui/arena_combat/combat_defense.png"
const VICTORY_ICON_PATH := "res://assets/placeholders/pack_000/ui/arena_combat/combat_victory.png"

var _mounted_scene_id: int = 0

func _ready() -> void:
    call_deferred("_attach_when_ready")

func _attach_when_ready() -> void:
    while is_inside_tree():
        var tree := get_tree()
        if tree == null:
            return
        await tree.process_frame
        if not is_inside_tree():
            return
        tree = get_tree()
        if tree == null:
            return
        var scene := tree.current_scene
        if scene == null or scene.name != MAIN_SCENE_NAME:
            continue
        var scene_id := scene.get_instance_id()
        if scene_id == _mounted_scene_id:
            return
        if _integrate_scene(scene):
            _mounted_scene_id = scene_id
            return

func _integrate_scene(scene: Node) -> bool:
    var arena := scene.get_node_or_null(ARENA_PATH) as VBoxContainer
    if arena == null:
        return false
    var root := arena.get_node_or_null("ArenaScroll/ArenaContent")
    if root == null:
        root = arena

    var start_duel := root.get_node_or_null("Setup/StartDuel") as Button
    var player_body := root.get_node_or_null("Stage/PlayerCard/Body") as Control
    var enemy_body := root.get_node_or_null("Stage/EnemyCard/Body") as Control
    if start_duel == null or player_body == null or enemy_body == null:
        return false

    var attack_icon := _load_texture(ATTACK_ICON_PATH)
    var defense_icon := _load_texture(DEFENSE_ICON_PATH)
    var victory_icon := _load_texture(VICTORY_ICON_PATH)

    if attack_icon != null:
        start_duel.icon = attack_icon
        start_duel.expand_icon = true
    _mount_texture(player_body, "PlaceholderCombatAttack", attack_icon)
    _mount_texture(enemy_body, "PlaceholderCombatDefense", defense_icon)

    if victory_icon != null:
        arena.set_meta("placeholder_victory_icon", victory_icon)
    return true

func _mount_texture(host: Control, node_name: String, texture: Texture2D) -> void:
    if texture == null:
        return
    var existing := host.get_node_or_null(node_name) as TextureRect
    if existing != null:
        existing.texture = texture
        return
    var rect := TextureRect.new()
    rect.name = node_name
    rect.texture = texture
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    host.add_child(rect)

func _load_texture(path: String) -> Texture2D:
    if not ResourceLoader.exists(path):
        push_warning("Placeholder asset missing: %s" % path)
        return null
    return load(path) as Texture2D
