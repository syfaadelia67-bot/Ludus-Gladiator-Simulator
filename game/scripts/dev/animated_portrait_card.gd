class_name AnimatedPortraitCard
extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
    _build_animation()
    animation_player.play("ambient")


func get_validation_state() -> Dictionary:
    var animation := animation_player.get_animation("ambient")
    return {
        "animation": animation_player.current_animation,
        "tracks": animation.get_track_count() if animation != null else 0,
        "source_size": Vector2i(512, 512),
        "layers": ["Background", "Torso", "Head", "Eyelids", "Feather", "FrontLight"],
    }


func _build_animation() -> void:
    if animation_player.has_animation_library(""):
        return
    var ambient := Animation.new()
    ambient.length = 6.0
    ambient.loop_mode = Animation.LOOP_LINEAR

    _add_track(ambient, NodePath("Background:position"), [0.0, 3.0, 6.0], [
        Vector2.ZERO, Vector2(4, -2), Vector2.ZERO
    ])
    _add_track(ambient, NodePath("Torso:scale"), [0.0, 2.0, 4.0, 6.0], [
        Vector2.ONE, Vector2(1.006, 1.012), Vector2(1.003, 1.007), Vector2.ONE
    ])
    _add_track(ambient, NodePath("Head:position"), [0.0, 2.0, 4.0, 6.0], [
        Vector2.ZERO, Vector2(0, -1.5), Vector2(0, -0.5), Vector2.ZERO
    ])
    _add_track(ambient, NodePath("Head/Eyelids:modulate"), [
        0.0, 2.72, 2.78, 2.88, 2.94, 5.42, 5.48, 5.56, 5.62, 6.0
    ], [
        Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1),
        Color(1, 1, 1, 1), Color(1, 1, 1, 0), Color(1, 1, 1, 0),
        Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0),
        Color(1, 1, 1, 0)
    ])
    _add_track(ambient, NodePath("Head/Feather:rotation"), [0.0, 2.0, 4.0, 6.0], [
        -0.012, 0.018, -0.006, -0.012
    ])
    _add_track(ambient, NodePath("FrontLight:modulate"), [0.0, 3.0, 6.0], [
        Color(1.0, 0.76, 0.48, 0.035),
        Color(1.0, 0.82, 0.58, 0.075),
        Color(1.0, 0.76, 0.48, 0.035)
    ])

    var library := AnimationLibrary.new()
    library.add_animation("ambient", ambient)
    animation_player.add_animation_library("", library)


func _add_track(animation: Animation, path: NodePath, times: Array, values: Array) -> void:
    var track := animation.add_track(Animation.TYPE_VALUE)
    animation.track_set_path(track, path)
    animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
    for index in range(times.size()):
        animation.track_insert_key(track, float(times[index]), values[index])
