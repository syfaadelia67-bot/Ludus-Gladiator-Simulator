extends SceneTree

const ASSET_ROOT := "res://assets/dev/pixel_64"
const TRANSPARENT := Color(0, 0, 0, 0)
const OUTLINE := Color8(29, 25, 28)
const SKIN_LIGHT := Color8(205, 139, 88)
const SKIN_DARK := Color8(130, 78, 52)
const BRONZE := Color8(177, 119, 48)
const BRONZE_LIGHT := Color8(224, 174, 72)
const IRON := Color8(108, 116, 125)
const IRON_LIGHT := Color8(176, 184, 187)
const RED := Color8(142, 38, 45)
const RED_LIGHT := Color8(202, 62, 56)
const BLUE := Color8(41, 75, 119)
const BLUE_LIGHT := Color8(64, 117, 157)


func _initialize() -> void:
    _ensure_directories()
    _save_body("body/body_base.png", SKIN_LIGHT)
    _save_body("body/body_light.png", SKIN_LIGHT)
    _save_body("body/body_dark.png", SKIN_DARK)
    _save_helmet("helmet/helmet_bronze.png", BRONZE, BRONZE_LIGHT, false)
    _save_helmet("helmet/helmet_iron.png", IRON, IRON_LIGHT, true)
    _save_sword()
    _save_spear()
    _save_round_shield()
    _save_tower_shield()
    _save_cloth("cloth/cloth_red.png", RED, RED_LIGHT)
    _save_cloth("cloth/cloth_blue.png", BLUE, BLUE_LIGHT)
    _save_hit_effect()
    _save_ui_panel()
    _prepare_portrait()
    print("PIXEL64_ASSETS_OK: combat layers generated on aligned 64x64 canvases")
    quit()


func _ensure_directories() -> void:
    for directory in ["body", "helmet", "weapon", "shield", "cloth", "effects", "portrait", "ui"]:
        DirAccess.make_dir_recursive_absolute(
            ProjectSettings.globalize_path("%s/%s" % [ASSET_ROOT, directory])
        )


func _new_image(size := Vector2i(64, 64)) -> Image:
    var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
    image.fill(TRANSPARENT)
    return image


func _save(image: Image, relative_path: String) -> void:
    var error := image.save_png(ProjectSettings.globalize_path("%s/%s" % [ASSET_ROOT, relative_path]))
    if error != OK:
        push_error("Could not save %s (error %d)" % [relative_path, error])


func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
    for y in range(maxi(0, rect.position.y), mini(image.get_height(), rect.end.y)):
        for x in range(maxi(0, rect.position.x), mini(image.get_width(), rect.end.x)):
            image.set_pixel(x, y, color)


func _outlined_rect(image: Image, rect: Rect2i, fill: Color) -> void:
    _fill_rect(image, rect, OUTLINE)
    _fill_rect(image, Rect2i(rect.position + Vector2i.ONE, rect.size - Vector2i(2, 2)), fill)


func _line(image: Image, start: Vector2i, end: Vector2i, color: Color, width := 1) -> void:
    var x0 := start.x
    var y0 := start.y
    var x1 := end.x
    var y1 := end.y
    var dx := absi(x1 - x0)
    var sx := 1 if x0 < x1 else -1
    var dy := -absi(y1 - y0)
    var sy := 1 if y0 < y1 else -1
    var error := dx + dy
    while true:
        _fill_rect(image, Rect2i(x0 - width / 2, y0 - width / 2, width, width), color)
        if x0 == x1 and y0 == y1:
            break
        var doubled := 2 * error
        if doubled >= dy:
            error += dy
            x0 += sx
        if doubled <= dx:
            error += dx
            y0 += sy


func _save_body(relative_path: String, skin: Color) -> void:
    var image := _new_image()
    _outlined_rect(image, Rect2i(29, 14, 13, 14), skin)
    _outlined_rect(image, Rect2i(27, 27, 18, 18), Color8(105, 56, 42))
    _outlined_rect(image, Rect2i(23, 29, 7, 18), skin)
    _outlined_rect(image, Rect2i(43, 28, 7, 18), skin)
    _outlined_rect(image, Rect2i(28, 43, 8, 15), skin)
    _outlined_rect(image, Rect2i(38, 43, 8, 15), skin)
    _fill_rect(image, Rect2i(31, 18, 2, 2), OUTLINE)
    _fill_rect(image, Rect2i(38, 18, 2, 2), OUTLINE)
    _fill_rect(image, Rect2i(34, 23, 4, 1), Color8(104, 56, 42))
    _save(image, relative_path)


func _save_helmet(relative_path: String, metal: Color, highlight: Color, plume: bool) -> void:
    var image := _new_image()
    _outlined_rect(image, Rect2i(27, 10, 18, 14), metal)
    _fill_rect(image, Rect2i(29, 11, 14, 3), highlight)
    _fill_rect(image, Rect2i(28, 21, 5, 9), metal)
    _fill_rect(image, Rect2i(41, 21, 5, 9), metal)
    _line(image, Vector2i(33, 15), Vector2i(33, 24), OUTLINE, 2)
    _line(image, Vector2i(40, 15), Vector2i(40, 24), OUTLINE, 2)
    if plume:
        _line(image, Vector2i(29, 9), Vector2i(43, 5), OUTLINE, 4)
        _line(image, Vector2i(29, 8), Vector2i(43, 4), RED, 2)
    _save(image, relative_path)


func _save_sword() -> void:
    var image := _new_image()
    _line(image, Vector2i(44, 34), Vector2i(58, 10), OUTLINE, 5)
    _line(image, Vector2i(44, 34), Vector2i(58, 10), IRON_LIGHT, 3)
    _line(image, Vector2i(57, 11), Vector2i(60, 7), IRON_LIGHT, 2)
    _line(image, Vector2i(40, 32), Vector2i(48, 37), BRONZE_LIGHT, 3)
    _line(image, Vector2i(41, 38), Vector2i(46, 31), Color8(88, 51, 34), 3)
    _save(image, "weapon/sword.png")


func _save_spear() -> void:
    var image := _new_image()
    _line(image, Vector2i(40, 42), Vector2i(57, 7), OUTLINE, 4)
    _line(image, Vector2i(40, 42), Vector2i(57, 7), Color8(128, 78, 41), 2)
    _line(image, Vector2i(57, 7), Vector2i(61, 2), IRON_LIGHT, 4)
    _line(image, Vector2i(57, 7), Vector2i(53, 7), IRON_LIGHT, 3)
    _save(image, "weapon/spear_short.png")


func _save_round_shield() -> void:
    var image := _new_image()
    for y in range(21, 50):
        for x in range(8, 34):
            var nx := (float(x) - 21.0) / 13.0
            var ny := (float(y) - 35.0) / 15.0
            var distance := nx * nx + ny * ny
            if distance <= 1.0:
                image.set_pixel(x, y, OUTLINE if distance > 0.78 else BLUE)
    _fill_rect(image, Rect2i(18, 25, 5, 21), BLUE_LIGHT)
    _fill_rect(image, Rect2i(11, 33, 20, 5), BLUE_LIGHT)
    _outlined_rect(image, Rect2i(18, 32, 7, 7), BRONZE_LIGHT)
    _save(image, "shield/shield_round.png")


func _save_tower_shield() -> void:
    var image := _new_image()
    _outlined_rect(image, Rect2i(9, 18, 23, 37), RED)
    _fill_rect(image, Rect2i(12, 21, 17, 4), RED_LIGHT)
    _fill_rect(image, Rect2i(18, 22, 5, 29), BRONZE)
    _outlined_rect(image, Rect2i(17, 33, 7, 7), BRONZE_LIGHT)
    _save(image, "shield/shield_tower.png")


func _save_cloth(relative_path: String, base: Color, highlight: Color) -> void:
    var image := _new_image()
    _outlined_rect(image, Rect2i(27, 39, 19, 9), base)
    _line(image, Vector2i(30, 46), Vector2i(31, 54), OUTLINE, 4)
    _line(image, Vector2i(37, 46), Vector2i(37, 55), OUTLINE, 4)
    _line(image, Vector2i(44, 46), Vector2i(43, 53), OUTLINE, 4)
    _fill_rect(image, Rect2i(30, 41, 13, 2), highlight)
    _save(image, relative_path)


func _save_hit_effect() -> void:
    var image := _new_image()
    var gold := Color8(255, 211, 91)
    _line(image, Vector2i(48, 20), Vector2i(61, 14), OUTLINE, 4)
    _line(image, Vector2i(48, 20), Vector2i(61, 14), gold, 2)
    _line(image, Vector2i(50, 23), Vector2i(62, 28), OUTLINE, 4)
    _line(image, Vector2i(50, 23), Vector2i(62, 28), gold, 2)
    _line(image, Vector2i(50, 17), Vector2i(55, 6), OUTLINE, 4)
    _line(image, Vector2i(50, 17), Vector2i(55, 6), gold, 2)
    _save(image, "effects/hit_flash.png")


func _save_ui_panel() -> void:
    var image := _new_image(Vector2i(16, 16))
    _fill_rect(image, Rect2i(0, 0, 16, 16), Color8(22, 25, 32))
    _fill_rect(image, Rect2i(1, 1, 14, 14), BRONZE)
    _fill_rect(image, Rect2i(3, 3, 10, 10), Color8(38, 42, 50))
    _fill_rect(image, Rect2i(4, 4, 8, 8), Color8(27, 30, 38))
    _save(image, "ui/panel_16.png")


func _prepare_portrait() -> void:
    var source_path := "%s/portrait/gladiator_portrait_source.png" % ASSET_ROOT
    if not FileAccess.file_exists(source_path):
        print("PIXEL64_PORTRAIT_SKIPPED: source image not present")
        return
    var source := Image.load_from_file(source_path)
    if source == null or source.is_empty():
        push_error("Could not load the generated portrait source")
        return
    source.resize(512, 512, Image.INTERPOLATE_LANCZOS)
    _save(source, "portrait/gladiator_portrait_512.png")
