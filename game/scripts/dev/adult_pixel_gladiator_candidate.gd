extends Node2D

const ASSET_ROOT := "res://assets/dev/pixel_64/adult_candidate"
const V2_ROOT := ASSET_ROOT + "/v2"
const FRAME_SIZE := Vector2i(64, 64)
const GRID_ORIGIN := Vector2(420, 148)
const GRID_SCALE := 6
const GUIDE_PIXELS := {
    "HEAD": 2,
    "SHOULDERS": 14,
    "PELVIS": 34,
    "KNEES": 44,
    "FEET": 61,
}

var equipped_texture: Texture2D
var body_texture: Texture2D
var silhouette_texture: Texture2D
var previous_texture: Texture2D
var animated_previews: Array[Sprite2D] = []
var light_background := false
var preview_equipped := true
var preview_scale := 4
var frame := 0
var elapsed := 0.0


func _ready() -> void:
    equipped_texture = load(V2_ROOT + "/athletic_adult_v2_sheet.png") as Texture2D
    body_texture = load(V2_ROOT + "/body_base_v2_idle_sheet.png") as Texture2D
    silhouette_texture = load(V2_ROOT + "/athletic_adult_v2_silhouette.png") as Texture2D
    previous_texture = load(ASSET_ROOT + "/athletic_adult_sheet.png") as Texture2D
    _add_region_sprite("GridCandidate", body_texture, GRID_ORIGIN, GRID_SCALE, false)
    _add_region_sprite("OneToOne", equipped_texture, Vector2(58, 145), 1, false)
    var animated := _add_region_sprite(
        "AnimatedPreview", equipped_texture, Vector2(100, 245), preview_scale, true
    )
    animated_previews.append(animated)
    _add_region_sprite("Silhouette", silhouette_texture, Vector2(105, 520), 2, false)
    _add_region_sprite("PreviousCandidate", previous_texture, Vector2(840, 235), 3, false)
    _add_region_sprite("NewComparison", equipped_texture, Vector2(1040, 235), 3, false)
    var body := _add_region_sprite("BodyOnly", body_texture, Vector2(870, 505), 2, true)
    var equipped := _add_region_sprite(
        "Equipped", equipped_texture, Vector2(1080, 505), 2, true
    )
    animated_previews.append(body)
    animated_previews.append(equipped)
    queue_redraw()
    var arguments := OS.get_cmdline_user_args()
    if arguments.has("--capture-dark"):
        light_background = false
        _capture_after_draw.call_deferred("adult_candidate_v2_dark.png")
    elif arguments.has("--capture-light"):
        light_background = true
        queue_redraw()
        _capture_after_draw.call_deferred("adult_candidate_v2_light.png")


func _process(delta: float) -> void:
    elapsed += delta
    if elapsed < 0.125:
        return
    elapsed -= 0.125
    frame = (frame + 1) % 4
    for sprite in animated_previews:
        sprite.region_rect.position.x = frame * FRAME_SIZE.x


func _unhandled_key_input(event: InputEvent) -> void:
    if not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_B:
            light_background = not light_background
            queue_redraw()
        KEY_E:
            preview_equipped = not preview_equipped
            var preview := get_node("AnimatedPreview") as Sprite2D
            preview.texture = equipped_texture if preview_equipped else body_texture
            queue_redraw()
        KEY_S:
            preview_scale = 1 if preview_scale == 4 else 4
            var preview := get_node("AnimatedPreview") as Sprite2D
            preview.scale = Vector2.ONE * preview_scale
            queue_redraw()


func _draw() -> void:
    var background := Color("#eee7da") if light_background else Color("#10141c")
    var panel := Color("#d8d0c2") if light_background else Color("#202936")
    var ink := Color("#222833") if light_background else Color("#edf1f5")
    var muted := Color("#5e6670") if light_background else Color("#aeb8c4")
    draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), background)
    draw_rect(Rect2(24, 92, 350, 590), panel)
    draw_rect(Rect2(398, 92, 410, 590), panel)
    draw_rect(Rect2(832, 92, 424, 590), panel)
    var font := ThemeDB.fallback_font
    draw_string(font, Vector2(28, 48), "ATHLETIC ADULT GLADIATOR - ANATOMY ITERATION 2", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, ink)
    draw_string(font, Vector2(44, 122), "READABILITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
    draw_string(font, Vector2(56, 210), "1x", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, muted)
    draw_string(font, Vector2(96, 230), "4x animated idle", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, muted)
    draw_string(font, Vector2(74, 502), "BLACK SILHOUETTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, muted)
    draw_string(font, Vector2(418, 122), "BODY ANATOMY GRID - 6x", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
    draw_string(font, Vector2(844, 122), "ITERATION 1 vs ITERATION 2", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
    draw_string(font, Vector2(844, 205), "ITERATION 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#de7373"))
    draw_string(font, Vector2(1046, 205), "ITERATION 2", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#72c58a"))
    draw_string(font, Vector2(870, 488), "BODY BASE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, muted)
    draw_string(font, Vector2(1080, 488), "EQUIPPED", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, muted)
    draw_string(font, Vector2(870, 665), "61 px | 6.1 heads | 16 colors", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
    draw_string(font, Vector2(42, 665), "B background  E equipment  S 1x/4x", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
    _draw_grid(ink, muted)


func _draw_grid(ink: Color, muted: Color) -> void:
    var grid_size := Vector2(FRAME_SIZE) * GRID_SCALE
    draw_rect(Rect2(GRID_ORIGIN, grid_size), Color(0, 0, 0, 0.08), true)
    for index in range(65):
        var weight := 1.0 if index % 8 == 0 else 0.35
        var grid_color := Color(muted, 0.24 if index % 8 == 0 else 0.10)
        var x := GRID_ORIGIN.x + index * GRID_SCALE
        var y := GRID_ORIGIN.y + index * GRID_SCALE
        draw_line(Vector2(x, GRID_ORIGIN.y), Vector2(x, GRID_ORIGIN.y + grid_size.y), grid_color, weight)
        draw_line(Vector2(GRID_ORIGIN.x, y), Vector2(GRID_ORIGIN.x + grid_size.x, y), grid_color, weight)
    var font := ThemeDB.fallback_font
    for guide_name in GUIDE_PIXELS:
        var pixel: int = GUIDE_PIXELS[guide_name]
        var guide_y := GRID_ORIGIN.y + pixel * GRID_SCALE
        draw_line(
            Vector2(GRID_ORIGIN.x - 8, guide_y),
            Vector2(GRID_ORIGIN.x + grid_size.x + 8, guide_y),
            Color("#e7a94e"),
            1.5
        )
        draw_string(
            font,
            Vector2(GRID_ORIGIN.x + 4, guide_y - 3),
            "%s %d" % [guide_name, pixel],
            HORIZONTAL_ALIGNMENT_LEFT,
            -1,
            11,
            ink
        )


func _add_region_sprite(
    node_name: String,
    texture: Texture2D,
    position: Vector2,
    pixel_scale: int,
    animated: bool
) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.name = node_name
    sprite.texture = texture
    sprite.centered = false
    sprite.region_enabled = true
    sprite.region_rect = Rect2(Vector2.ZERO, FRAME_SIZE)
    sprite.position = position
    sprite.scale = Vector2.ONE * pixel_scale
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(sprite)
    if animated:
        sprite.region_rect.position.x = frame * FRAME_SIZE.x
    return sprite


func _add_static_sprite(
    node_name: String,
    texture: Texture2D,
    position: Vector2,
    pixel_scale: int
) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.name = node_name
    sprite.texture = texture
    sprite.centered = false
    sprite.position = position
    sprite.scale = Vector2.ONE * pixel_scale
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(sprite)
    return sprite


func _capture_after_draw(file_name: String) -> void:
    await RenderingServer.frame_post_draw
    var image := get_viewport().get_texture().get_image()
    var error := image.save_png(V2_ROOT + "/" + file_name)
    print("ADULT_CANDIDATE_CAPTURE ", file_name, " ", error_string(error))
    get_tree().quit(0 if error == OK else 1)
