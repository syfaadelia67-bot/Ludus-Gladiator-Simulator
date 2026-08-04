extends Node

signal pack_loaded(texture_count: int)

const PACK_ROOT := "res://assets/placeholders/pack_000"

var textures: Dictionary = {}
var categories: Dictionary = {}
var loaded := false

func _ready() -> void:
    _load_pack()

func _load_pack() -> void:
    if loaded:
        return
    textures.clear()
    categories.clear()
    _scan_directory(PACK_ROOT)
    loaded = true
    pack_loaded.emit(textures.size())

func _scan_directory(path: String) -> void:
    var directory := DirAccess.open(path)
    if directory == null:
        push_warning("No se pudo abrir el Pack 000: %s" % path)
        return

    directory.list_dir_begin()
    var entry := directory.get_next()
    while not entry.is_empty():
        if entry.begins_with("."):
            entry = directory.get_next()
            continue
        var full_path := path.path_join(entry)
        if directory.current_is_dir():
            _scan_directory(full_path)
        elif entry.to_lower().ends_with(".png") and ResourceLoader.exists(full_path):
            var texture := load(full_path) as Texture2D
            if texture != null:
                var relative := full_path.trim_prefix(PACK_ROOT + "/").trim_suffix(".png")
                textures[relative] = texture
                var category := relative.get_slice("/", 0)
                if not categories.has(category):
                    categories[category] = []
                categories[category].append(relative)
        entry = directory.get_next()
    directory.list_dir_end()

func get_texture(asset_id: String) -> Texture2D:
    if not loaded:
        _load_pack()
    var normalized := asset_id.trim_prefix(PACK_ROOT + "/").trim_suffix(".png")
    return textures.get(normalized) as Texture2D

func has_texture(asset_id: String) -> bool:
    if not loaded:
        _load_pack()
    var normalized := asset_id.trim_prefix(PACK_ROOT + "/").trim_suffix(".png")
    return textures.has(normalized)

func get_category(category: String) -> Array:
    if not loaded:
        _load_pack()
    return (categories.get(category, []) as Array).duplicate()

func get_texture_count() -> int:
    if not loaded:
        _load_pack()
    return textures.size()
