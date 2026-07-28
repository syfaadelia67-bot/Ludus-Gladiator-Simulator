extends Node

var traits: Array = []
var buildings: Array = []
var weapons: Array = []

func _ready() -> void:
    traits = _load_json_array("res://data/traits.json")
    buildings = _load_json_array("res://data/buildings.json")
    weapons = _load_json_array("res://data/weapons.json")

func _load_json_array(path: String) -> Array:
    if not FileAccess.file_exists(path):
        push_warning("No se encontró: %s" % path)
        return []

    var file := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Array:
        return parsed

    push_error("El archivo no contiene un Array válido: %s" % path)
    return []
