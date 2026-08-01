extends Node

var traits: Array = []
var buildings: Array = []
var weapons: Array = []
var abilities: Array = []
var specializations: Array = []

func _ready() -> void:
    load_all()

func load_all() -> void:
    traits = _load_json_array("res://data/traits.json")
    buildings = _load_json_array("res://data/buildings.json")
    weapons = _load_json_array("res://data/weapons.json")
    abilities = _load_json_array("res://data/abilities.json")
    specializations = _load_json_array("res://data/specializations.json")

func _load_json_array(path: String) -> Array:
    if not FileAccess.file_exists(path):
        print_verbose("No se encontró: %s" % path)
        return []

    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        print_verbose("No se pudo abrir: %s" % path)
        return []

    var json := JSON.new()
    var parse_error: Error = json.parse(file.get_as_text())
    if parse_error == OK and json.data is Array:
        return json.data

    print_verbose("El archivo no contiene un Array válido: %s" % path)
    return []
