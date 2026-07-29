extends Node2D

const FRAME_SIZE := Vector2i(64, 64)
const PIPELINE_ROOT := "res://assets/dev/pixel_64/pipeline_exports"
const LAYERS := [
    "body", "cloth_red", "cloth_blue", "hair", "helmet_iron",
    "helmet_bronze", "weapon_sword", "weapon_spear", "shield_round",
    "shield_tower", "effects",
]
const ANIMATIONS := {
    "idle": Vector2i(0, 4),
    "attack": Vector2i(4, 5),
    "block": Vector2i(9, 3),
    "hit": Vector2i(12, 3),
    "defeat": Vector2i(15, 5),
}
const COLUMN_X := {"gator": 205.0, "pixelorama": 995.0}

var animation_name := "idle"
var animation_frame := 0
var elapsed := 0.0
var display_scale := 4
var light_background := false
var bronze_helmet := false
var spear_weapon := false
var tower_shield := false
var blue_cloth := false
var pipeline_layers: Dictionary = {}


func _ready() -> void:
    for pipeline in COLUMN_X:
        pipeline_layers[pipeline] = {}
        for layer_name in LAYERS:
            var sprite := Sprite2D.new()
            sprite.name = "%s_%s" % [pipeline, layer_name]
            sprite.texture = load(
                "%s/%s/layers/%s.png" % [PIPELINE_ROOT, pipeline, layer_name]
            ) as Texture2D
            sprite.region_enabled = true
            sprite.region_rect = Rect2(Vector2.ZERO, FRAME_SIZE)
            sprite.position = Vector2(COLUMN_X[pipeline], 420.0)
            sprite.scale = Vector2.ONE * display_scale
            sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            add_child(sprite)
            pipeline_layers[pipeline][layer_name] = sprite
    _apply_variants()
    queue_redraw()
    if OS.get_cmdline_user_args().has("--capture-pipeline"):
        _capture_after_draw.call_deferred()


func _process(delta: float) -> void:
    elapsed += delta
    if elapsed < 0.125:
        return
    elapsed -= 0.125
    var animation: Vector2i = ANIMATIONS[animation_name]
    animation_frame += 1
    if animation_frame >= animation.y:
        animation_frame = animation.y - 1 if animation_name == "defeat" else 0
    _apply_frame()


func _unhandled_key_input(event: InputEvent) -> void:
    if not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_1:
            _play("idle")
        KEY_2:
            _play("attack")
        KEY_3:
            _play("block")
        KEY_4:
            _play("hit")
        KEY_5:
            _play("defeat")
        KEY_H:
            bronze_helmet = not bronze_helmet
            _apply_variants()
        KEY_W:
            spear_weapon = not spear_weapon
            _apply_variants()
        KEY_D:
            tower_shield = not tower_shield
            _apply_variants()
        KEY_C:
            blue_cloth = not blue_cloth
            _apply_variants()
        KEY_S:
            display_scale = 2 if display_scale == 6 else display_scale + 2
            _apply_scale()
        KEY_B:
            light_background = not light_background
            queue_redraw()


func _play(value: String) -> void:
    animation_name = value
    animation_frame = 0
    elapsed = 0.0
    _apply_frame()
    queue_redraw()


func _apply_frame() -> void:
    var global_frame: int = ANIMATIONS[animation_name].x + animation_frame
    for pipeline in pipeline_layers:
        for sprite: Sprite2D in pipeline_layers[pipeline].values():
            sprite.region_rect.position.x = global_frame * FRAME_SIZE.x


func _apply_variants() -> void:
    for pipeline in pipeline_layers:
        var sprites: Dictionary = pipeline_layers[pipeline]
        sprites["cloth_red"].visible = not blue_cloth
        sprites["cloth_blue"].visible = blue_cloth
        sprites["helmet_iron"].visible = not bronze_helmet
        sprites["helmet_bronze"].visible = bronze_helmet
        sprites["weapon_sword"].visible = not spear_weapon
        sprites["weapon_spear"].visible = spear_weapon
        sprites["shield_round"].visible = not tower_shield
        sprites["shield_tower"].visible = tower_shield
    queue_redraw()


func _apply_scale() -> void:
    for pipeline in pipeline_layers:
        for sprite: Sprite2D in pipeline_layers[pipeline].values():
            sprite.scale = Vector2.ONE * display_scale
    queue_redraw()


func _draw() -> void:
    var background := Color("#ede7dc") if light_background else Color("#11151d")
    var panel := Color("#d5cec1") if light_background else Color("#202936")
    var ink := Color("#17202b") if light_background else Color("#e9edf2")
    draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), background)
    for index in range(3):
        draw_rect(Rect2(index * 400 + 10, 85, 380, 510), panel, true)
    var font := ThemeDB.fallback_font
    draw_string(font, Vector2(32, 48), "PIXEL 64 — PIPELINE COMPARISON", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ink)
    draw_string(font, Vector2(115, 125), "Gator Sprite Studio", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
    draw_string(font, Vector2(510, 125), "Pixel-Prof", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
    draw_string(font, Vector2(865, 125), "Pixelorama + Importality", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
    draw_string(font, Vector2(475, 310), "NO REPRODUCIBLE BUILD", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#e06767"))
    draw_string(font, Vector2(480, 340), "Official pinned archive: 404", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
    draw_string(font, Vector2(36, 630), "1–5 animation  H helmet  W weapon  D shield  C cloth  S scale  B background", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
    var state := "%s  frame %d/%d  scale ×%d  %s / %s / %s / %s" % [
        animation_name,
        animation_frame + 1,
        ANIMATIONS[animation_name].y,
        display_scale,
        "bronze" if bronze_helmet else "iron",
        "spear" if spear_weapon else "sword",
        "tower" if tower_shield else "round",
        "blue" if blue_cloth else "red",
    ]
    draw_string(font, Vector2(36, 674), state, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)


func _capture_after_draw() -> void:
    await RenderingServer.frame_post_draw
    var image := get_viewport().get_texture().get_image()
    var error := image.save_png(
        "res://assets/dev/pixel_64/pixel_pipeline_comparison.png"
    )
    print("PIXEL_PIPELINE_CAPTURE ", error_string(error))
    get_tree().quit(0 if error == OK else 1)
