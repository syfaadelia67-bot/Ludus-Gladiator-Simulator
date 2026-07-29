extends Node2D

const ANIMATIONS := [&"idle", &"attack", &"block", &"hit", &"defeat"]

@export var auto_cycle := true
@export_range(1.0, 10.0, 0.25) var cycle_seconds := 2.5

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var status_label: Label = $UI/Status

var _animation_index := 0
var _elapsed := 0.0


func _ready() -> void:
	play_animation(ANIMATIONS[_animation_index])
	print("VECTOR_PROTOTYPE_READY plugin=2.27.3 animation=%s" % ANIMATIONS[_animation_index])


func _process(delta: float) -> void:
	if not auto_cycle:
		return
	_elapsed += delta
	if _elapsed >= cycle_seconds:
		_elapsed = 0.0
		_animation_index = (_animation_index + 1) % ANIMATIONS.size()
		play_animation(ANIMATIONS[_animation_index])


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	var key_index: int = int(event.keycode - KEY_1)
	if key_index >= 0 and key_index < ANIMATIONS.size():
		_animation_index = key_index
		_elapsed = 0.0
		play_animation(ANIMATIONS[_animation_index])


func play_animation(animation_name: StringName) -> void:
	if not animation_player.has_animation(animation_name):
		push_error("Vector prototype animation missing: %s" % animation_name)
		return
	animation_player.play(&"RESET")
	animation_player.seek(0.0, true)
	animation_player.play(animation_name)
	status_label.text = "Animación: %s · teclas 1–5" % animation_name
	print("VECTOR_ANIMATION %s" % animation_name)


func set_equipment_colors(sword_color: Color, shield_color: Color) -> void:
	$Gladiator/WeaponArm/Sword/Fill.color = sword_color
	$Gladiator/ShieldArm/Shield/Fill.color = shield_color
