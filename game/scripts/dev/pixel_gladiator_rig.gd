class_name PixelGladiatorRig
extends Node2D

signal loadout_changed(summary: String)
signal animation_changed(animation_name: String)

const HELMETS: Array[Texture2D] = [
    preload("res://assets/dev/pixel_64/helmet/helmet_iron.png"),
    preload("res://assets/dev/pixel_64/helmet/helmet_bronze.png"),
]
const HELMET_NAMES := ["Casco de hierro", "Casco de bronce"]
const WEAPONS: Array[Texture2D] = [
    preload("res://assets/dev/pixel_64/weapon/sword.png"),
    preload("res://assets/dev/pixel_64/weapon/spear_short.png"),
]
const WEAPON_NAMES := ["Espada", "Lanza corta"]
const SHIELDS: Array[Texture2D] = [
    preload("res://assets/dev/pixel_64/shield/shield_round.png"),
    preload("res://assets/dev/pixel_64/shield/shield_tower.png"),
]
const SHIELD_NAMES := ["Escudo redondo", "Escudo torre"]
const CLOTHS: Array[Texture2D] = [
    preload("res://assets/dev/pixel_64/cloth/cloth_red.png"),
    preload("res://assets/dev/pixel_64/cloth/cloth_blue.png"),
]
const CLOTH_NAMES := ["Rojo", "Azul"]

@onready var body: Sprite2D = $Visual/Body
@onready var helmet: Sprite2D = $Visual/Helmet
@onready var weapon: Sprite2D = $Visual/WeaponPivot/Weapon
@onready var shield: Sprite2D = $Visual/ShieldPivot/Shield
@onready var cloth: Sprite2D = $Visual/ClothPivot/Cloth
@onready var effects: Sprite2D = $Visual/Effects
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var helmet_index := 0
var weapon_index := 0
var shield_index := 0
var cloth_index := 0
var current_animation := "idle"


func _ready() -> void:
    _build_animation_library()
    _apply_loadout()
    play_animation("idle")


func cycle_helmet() -> void:
    helmet_index = (helmet_index + 1) % HELMETS.size()
    _apply_loadout()


func cycle_weapon() -> void:
    weapon_index = (weapon_index + 1) % WEAPONS.size()
    _apply_loadout()


func cycle_shield() -> void:
    shield_index = (shield_index + 1) % SHIELDS.size()
    _apply_loadout()


func cycle_cloth() -> void:
    cloth_index = (cloth_index + 1) % CLOTHS.size()
    _apply_loadout()


func set_pixel_scale(multiplier: int) -> void:
    var safe_multiplier := clampi(multiplier, 1, 8)
    scale = Vector2(safe_multiplier, safe_multiplier)


func play_animation(animation_name: String) -> void:
    if not animation_player.has_animation(animation_name):
        push_warning("Unknown pixel prototype animation: %s" % animation_name)
        return
    animation_player.play("RESET")
    animation_player.advance(0.0)
    current_animation = animation_name
    animation_player.play(animation_name)
    animation_changed.emit(animation_name)


func get_loadout_summary() -> String:
    return "%s · %s · %s · faldellín %s" % [
        HELMET_NAMES[helmet_index],
        WEAPON_NAMES[weapon_index],
        SHIELD_NAMES[shield_index],
        CLOTH_NAMES[cloth_index],
    ]


func get_validation_state() -> Dictionary:
    return {
        "helmet": HELMET_NAMES[helmet_index],
        "weapon": WEAPON_NAMES[weapon_index],
        "shield": SHIELD_NAMES[shield_index],
        "cloth": CLOTH_NAMES[cloth_index],
        "animation": current_animation,
        "scale": scale.x,
        "animation_count": animation_player.get_animation_list().size(),
    }


func _apply_loadout() -> void:
    helmet.texture = HELMETS[helmet_index]
    weapon.texture = WEAPONS[weapon_index]
    shield.texture = SHIELDS[shield_index]
    cloth.texture = CLOTHS[cloth_index]
    loadout_changed.emit(get_loadout_summary())


func _build_animation_library() -> void:
    if animation_player.has_animation_library(""):
        return
    var library := AnimationLibrary.new()
    library.add_animation("RESET", _make_reset())
    library.add_animation("idle", _make_idle())
    library.add_animation("attack", _make_attack())
    library.add_animation("block", _make_block())
    library.add_animation("hit", _make_hit())
    library.add_animation("defeat", _make_defeat())
    animation_player.add_animation_library("", library)


func _make_reset() -> Animation:
    var animation := Animation.new()
    animation.length = 0.0
    _add_track(animation, NodePath("Visual:position"), [0.0], [Vector2.ZERO])
    _add_track(animation, NodePath("Visual:rotation"), [0.0], [0.0])
    _add_track(animation, NodePath("Visual/WeaponPivot:position"), [0.0], [Vector2(8, -22)])
    _add_track(animation, NodePath("Visual/WeaponPivot:rotation"), [0.0], [0.0])
    _add_track(animation, NodePath("Visual/ShieldPivot:position"), [0.0], [Vector2(-15, -21)])
    _add_track(animation, NodePath("Visual/ShieldPivot:rotation"), [0.0], [0.0])
    _add_track(animation, NodePath("Visual/Helmet:position"), [0.0], [Vector2(-36, -56)])
    _add_track(animation, NodePath("Visual/ClothPivot:scale"), [0.0], [Vector2.ONE])
    _add_track(animation, NodePath("Visual/Effects:modulate"), [0.0], [Color(1, 1, 1, 0)])
    return animation


func _make_idle() -> Animation:
    var animation := Animation.new()
    animation.length = 0.8
    animation.loop_mode = Animation.LOOP_LINEAR
    _add_track(animation, NodePath("Visual:position"), [0.0, 0.2, 0.4, 0.6], [
        Vector2(0, 0), Vector2(0, -1), Vector2(0, -1), Vector2(0, 0)
    ])
    _add_track(animation, NodePath("Visual/WeaponPivot:rotation"), [0.0, 0.2, 0.4, 0.6], [
        0.0, -0.025, -0.04, -0.015
    ])
    _add_track(animation, NodePath("Visual/ClothPivot:scale"), [0.0, 0.2, 0.4, 0.6], [
        Vector2(1, 1), Vector2(1, 1.02), Vector2(1, 1.03), Vector2(1, 1.01)
    ])
    return animation


func _make_attack() -> Animation:
    var animation := Animation.new()
    animation.length = 0.55
    _add_track(animation, NodePath("Visual:position"), [0.0, 0.1, 0.2, 0.32, 0.5], [
        Vector2.ZERO, Vector2(-2, 0), Vector2(4, 0), Vector2(7, 0), Vector2.ZERO
    ])
    _add_track(animation, NodePath("Visual/WeaponPivot:rotation"), [0.0, 0.1, 0.2, 0.32, 0.5], [
        0.0, -0.65, -1.0, 0.65, 0.0
    ])
    _add_track(animation, NodePath("Visual/WeaponPivot:position"), [0.0, 0.1, 0.2, 0.32, 0.5], [
        Vector2(8, -22), Vector2(6, -23), Vector2(4, -24), Vector2(12, -21), Vector2(8, -22)
    ])
    return animation


func _make_block() -> Animation:
    var animation := Animation.new()
    animation.length = 0.48
    _add_track(animation, NodePath("Visual/ShieldPivot:position"), [0.0, 0.16, 0.38], [
        Vector2(-15, -21), Vector2(-10, -26), Vector2(-11, -25)
    ])
    _add_track(animation, NodePath("Visual/ShieldPivot:rotation"), [0.0, 0.16, 0.38], [
        0.0, -0.12, -0.08
    ])
    _add_track(animation, NodePath("Visual:position"), [0.0, 0.16, 0.38], [
        Vector2.ZERO, Vector2(-2, 1), Vector2(-1, 0)
    ])
    return animation


func _make_hit() -> Animation:
    var animation := Animation.new()
    animation.length = 0.42
    _add_track(animation, NodePath("Visual:position"), [0.0, 0.14, 0.34], [
        Vector2.ZERO, Vector2(-6, 1), Vector2.ZERO
    ])
    _add_track(animation, NodePath("Visual:rotation"), [0.0, 0.14, 0.34], [
        0.0, -0.08, 0.0
    ])
    _add_track(animation, NodePath("Visual/Effects:modulate"), [0.0, 0.14, 0.34], [
        Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)
    ])
    return animation


func _make_defeat() -> Animation:
    var animation := Animation.new()
    animation.length = 0.9
    _add_track(animation, NodePath("Visual:position"), [0.0, 0.18, 0.38, 0.62, 0.86], [
        Vector2.ZERO, Vector2(-2, 2), Vector2(-5, 7), Vector2(-8, 14), Vector2(-10, 20)
    ])
    _add_track(animation, NodePath("Visual:rotation"), [0.0, 0.18, 0.38, 0.62, 0.86], [
        0.0, -0.08, -0.25, -0.65, -1.15
    ])
    _add_track(animation, NodePath("Visual/WeaponPivot:rotation"), [0.0, 0.18, 0.38, 0.62, 0.86], [
        0.0, 0.1, 0.45, 0.8, 1.1
    ])
    return animation


func _add_track(animation: Animation, path: NodePath, times: Array, values: Array) -> void:
    var track := animation.add_track(Animation.TYPE_VALUE)
    animation.track_set_path(track, path)
    animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
    for index in range(times.size()):
        animation.track_insert_key(track, float(times[index]), values[index])
