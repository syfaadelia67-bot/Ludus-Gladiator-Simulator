extends Node2D

const ASSET_ROOT := "res://assets/dev/pixel_128/adult_candidate"
const PIXEL_64_ROOT := "res://assets/dev/pixel_64/adult_candidate/v2"
const PLACEHOLDER_PATH := "res://assets/dev/pixel_64/pipeline_exports/gator/gator_adult_000.png"
const FRAME_SIZE := Vector2i(128, 128)
const GRID_ORIGIN := Vector2(585, 155)
const GRID_SCALE := 4
const CANVAS_SIZE := Vector2i(1600, 900)
const GUIDE_PIXELS := {
    "HEAD": 5,
    "SHOULDERS": 29,
    "PELVIS": 68,
    "KNEES": 94,
    "FEET": 123,
}

var equipped_texture: Texture2D
var body_texture: Texture2D
var silhouette_texture: Texture2D
var iteration_64_texture: Texture2D
var placeholder_texture: Texture2D
var animated_previews: Array[Sprite2D] = []
var light_background := false
var preview_equipped := true
var preview_scale := 4
var frame := 0
var elapsed := 0.0


func _ready() -> void:
    get_window().size = CANVAS_SIZE
    get_window().content_scale_size = CANVAS_SIZE
    equipped_texture = load(ASSET_ROOT + "/athletic_adult_128_sheet.png") as Texture2D
    body_texture = load(ASSET_ROOT + "/body_base_128_idle_sheet.png") as Texture2D
    silhouette_texture = load(
        ASSET_ROOT + "/athletic_adult_128_silhouette.png"
    ) as Texture2D
    iteration_64_texture = load(
        PIXEL_64_ROOT + "/athletic_adult_v2_sheet.png"
    ) as Texture2D
    placeholder_texture = load(PLACEHOLDER_PATH) as Texture2D

    _add_region_sprite("GridBody", body_texture, GRID_ORIGIN, GRID_SCALE, false)
    _add_region_sprite("OneToOne", equipped_texture, Vector2(60, 145), 1, false)
    var animated := _add_region_sprite(
        "AnimatedPreview", equipped_texture, Vector2(35, 245), 4, true
    )
    animated_previews.append(animated)
    _add_region_sprite("Silhouette", silhouette_texture, Vector2(370, 135), 1, false)

    _add_static_sprite("Placeholder", placeholder_texture, Vector2(1115, 180), 3)
    _add_region_sprite(
        "Iteration64", iteration_64_texture, Vector2(1325, 180), 3, false, Vector2i(64, 64)
    )
    _add_region_sprite("CandidateComparison", equipped_texture, Vector2(1210, 365), 2, false)
    var body := _add_region_sprite("BodyOnly", body_texture, Vector2(1125, 690), 1, true)
    var equipped := _add_region_sprite(
        "Equipped", equipped_texture, Vector2(1370, 690), 1, true
    )
    animated_previews.append(body)
    animated_previews.append(equipped)
    queue_redraw()

    var arguments := OS.get_cmdline_user_args()
    if arguments.has("--capture-dark"):
        light_background = false
        _capture_after_draw.call_deferred("adult_candidate_128_dark.png")
    elif arguments.has("--capture-light"):
        light_background = true
        queue_redraw()
        _capture_after_draw.call_deferred("adult_candidate_128_light.png")


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
        KEY_S:
            preview_scale = 1 if preview_scale == 4 else 4
            var preview := get_node("AnimatedPreview") as Sprite2D
            preview.scale = Vector2.ONE * preview_scale


func _draw() -> void:
    var background := Color("#eee7da") if light_background else Color("#10141c")
    var panel := Color("#d8d0c2") if light_background else Color("#202936")
    var ink := Color("#222833") if light_background else Color("#edf1f5")
    var muted := Color("#5e6670") if light_background else Color("#aeb8c4")
    draw_rect(Rect2(Vector2.ZERO, CANVAS_SIZE), background)
    draw_rect(Rect2(25, 85, 530, 790), panel)
    draw_rect(Rect2(575, 85, 510, 790), panel)
    draw_rect(Rect2(1105, 85, 470, 790), panel)
    var font := ThemeDB.fallback_font
    draw_string(
        font,
        Vector2(30, 50),
        "ATHLETIC ADULT GLADIATOR - 128x128 CANDIDATE",
        HORIZONTAL_ALIGNMENT_LEFT,
        -1,
        27,
        ink
    )
    draw_string(font, Vector2(45, 120), "READABILITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, ink)
    draw_string(font, Vector2(58, 140), "1x", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, muted)
    draw_string(font, Vector2(35, 235), "4x ANIMATED IDLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, muted)
    draw_string(font, Vector2(365, 125), "BLACK SILHOUETTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, muted)
    draw_string(font, Vector2(595, 120), "BODY ANATOMY GRID - 4x", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, ink)
    draw_string(font, Vector2(1125, 120), "PLACEHOLDER / 64x64 / 128x128", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
    draw_string(font, Vector2(1115, 170), "PLACEHOLDER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#de7373"))
    draw_string(font, Vector2(1325, 170), "64x64 ITERATION 2", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#e7a94e"))
    draw_string(font, Vector2(1210, 355), "128x128 CANDIDATE - 2x", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#72c58a"))
    draw_string(font, Vector2(1125, 680), "BODY BASE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, muted)
    draw_string(font, Vector2(1370, 680), "EQUIPPED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, muted)
    draw_string(font, Vector2(1125, 845), "122 px | 6.4 heads | 23 colors", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
    draw_string(font, Vector2(45, 850), "B background  E equipment  S 1x/4x", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
    _draw_grid(ink, muted)


func _draw_grid(ink: Color, muted: Color) -> void:
    var grid_size := Vector2(FRAME_SIZE) * GRID_SCALE
    draw_rect(Rect2(GRID_ORIGIN, grid_size), Color(0, 0, 0, 0.08), true)
    for index in range(129):
        var weight := 1.0 if index % 16 == 0 else 0.35
        var grid_color := Color(muted, 0.24 if index % 16 == 0 else 0.08)
        var x := GRID_ORIGIN.x + index * GRID_SCALE
        var y := GRID_ORIGIN.y + index * GRID_SCALE
        draw_line(
            Vector2(x, GRID_ORIGIN.y),
            Vector2(x, GRID_ORIGIN.y + grid_size.y),
            grid_color,
            weight
        )
        draw_line(
            Vector2(GRID_ORIGIN.x, y),
            Vector2(GRID_ORIGIN.x + grid_size.x, y),
            grid_color,
            weight
        )
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
    animated: bool,
    region_size: Vector2i = FRAME_SIZE
) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.name = node_name
    sprite.texture = texture
    sprite.centered = false
    sprite.region_enabled = true
    sprite.region_rect = Rect2(Vector2.ZERO, region_size)
    sprite.position = position
    sprite.scale = Vector2.ONE * pixel_scale
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(sprite)
    if animated:
        sprite.region_rect.position.x = frame * region_size.x
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
    await RenderingServer.frame_post_draw
    var image := get_viewport().get_texture().get_image()
    var error := image.save_png(ASSET_ROOT + "/" + file_name)
    print(
        "ADULT_128_CAPTURE ",
        file_name,
        " ",
        error_string(error),
        " size=",
        image.get_size()
    )
    get_tree().quit(0 if error == OK else 1)
