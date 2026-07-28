extends Node

signal save_completed(path: String)
signal load_completed(path: String)
signal save_failed(reason: String)
signal load_failed(reason: String)

const SAVE_VERSION := 9
const SAVE_PATH := "user://ludus_save.json"
const BACKUP_PATH := "user://ludus_save.backup.json"
const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")

var autosave_enabled: bool = true

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    GameState.day_advanced.connect(_on_day_advanced)

func _unhandled_key_input(event: InputEvent) -> void:
    if not event.pressed or event.echo:
        return
    if event.keycode == KEY_F5:
        save_game()
        get_viewport().set_input_as_handled()
    elif event.keycode == KEY_F9:
        load_game()
        get_viewport().set_input_as_handled()

func _on_day_advanced(_day: int) -> void:
    if autosave_enabled:
        call_deferred("save_game")

func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

func get_save_metadata() -> Dictionary:
    var data := _read_payload(SAVE_PATH)
    if data.is_empty():
        return {}
    return {"version":int(data.get("version",0)),"saved_at_unix":int(data.get("saved_at_unix",0)),"day":int(data.get("game_state",{}).get("day",1))}

func save_game() -> bool:
    var payload := _build_payload()
    var json_text := JSON.stringify(payload, "  ")
    if FileAccess.file_exists(SAVE_PATH):
        _copy_file(SAVE_PATH, BACKUP_PATH)
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        save_failed.emit("No se pudo abrir el archivo de guardado.")
        return false
    file.store_string(json_text)
    file.close()
    save_completed.emit(SAVE_PATH)
    return true

func load_game() -> bool:
    var data := _read_payload(SAVE_PATH)
    if data.is_empty() and FileAccess.file_exists(BACKUP_PATH):
        data = _read_payload(BACKUP_PATH)
    if data.is_empty():
        load_failed.emit("No existe una partida válida para cargar.")
        return false
    if int(data.get("version", 0)) > SAVE_VERSION:
        load_failed.emit("La partida fue creada con una versión más nueva del juego.")
        return false
    if not _apply_payload(data):
        load_failed.emit("No se pudo restaurar la partida.")
        return false
    load_completed.emit(SAVE_PATH)
    return true

func delete_save() -> bool:
    var success := true
    for path in [SAVE_PATH, BACKUP_PATH]:
        if FileAccess.file_exists(path):
            success = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK and success
    return success

func _read_payload(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null: return {}
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    return parsed if parsed is Dictionary else {}

func _build_payload() -> Dictionary:
    var people_data: Array = []
    for person in RosterManager.get_people(): people_data.append(_serialize_person(person))
    return {
        "version": SAVE_VERSION,
        "saved_at_unix": int(Time.get_unix_time_from_system()),
        "game_state":{"day":GameState.day,"denarii":GameState.denarii,"food":GameState.food,"ore":GameState.ore,"reputation":GameState.reputation},
        "roster":{"people":people_data,"capacity":RosterManager.capacity,"security_score":RosterManager.security_score,"intelligence_points":RosterManager.intelligence_points},
        "estate":{"levels":EstateManager.levels.duplicate(true)},
        "equipment":{"inventory":EquipmentManager.inventory.duplicate(true),"serial":EquipmentManager.serial},
        "market":{"offers":MarketManager.offers.duplicate(true),"serial":MarketManager._serial},
        "rivals":{"entries":RivalManager.rivals.duplicate(true),"hostility_heat":RivalManager.hostility_heat,"operations_completed":RivalManager.operations_completed,"operations_detected":RivalManager.operations_detected},
        "events":EventManager.export_state(),
        "economy":EconomyManager.export_state(),
        "tournaments":TournamentManager.export_state(),
        "campaign":CampaignManager.export_state(),
        "personality":PersonalityManager.export_state(),
        "relationships":RelationshipManager.export_state(),
        "gladiator_progression":GladiatorProgressionManager.export_state(),
        "transfers":TransferManager.export_state()
    }

func _apply_payload(data: Dictionary) -> bool:
    var game_data: Dictionary = data.get("game_state", {})
    var roster_data: Dictionary = data.get("roster", {})
    var estate_data: Dictionary = data.get("estate", {})
    var equipment_data: Dictionary = data.get("equipment", {})
    var market_data: Dictionary = data.get("market", {})
    var rival_data: Dictionary = data.get("rivals", {})

    GameState.day = maxi(1, int(game_data.get("day", 1)))
    GameState.denarii = maxi(0, int(game_data.get("denarii", 500)))
    GameState.food = maxi(0, int(game_data.get("food", 100)))
    GameState.ore = maxi(0, int(game_data.get("ore", 20)))
    GameState.reputation = int(game_data.get("reputation", 0))

    RosterManager.people.clear()
    for person_data in roster_data.get("people", []):
        if person_data is Dictionary: RosterManager.people.append(_deserialize_person(person_data))
    if RosterManager.people.is_empty(): RosterManager._seed_initial_roster()
    RosterManager.capacity = maxi(1, int(roster_data.get("capacity", 8)))
    RosterManager.security_score = maxi(0, int(roster_data.get("security_score", 0)))
    RosterManager.intelligence_points = maxi(0, int(roster_data.get("intelligence_points", 0)))

    var loaded_levels = estate_data.get("levels", {})
    if loaded_levels is Dictionary:
        for building_id in EstateManager.BUILDINGS.keys():
            EstateManager.levels[building_id] = clampi(int(loaded_levels.get(building_id, 1)), 1, int(EstateManager.BUILDINGS[building_id].max_level))
    EstateManager._apply_global_effects()

    EquipmentManager.inventory.assign(equipment_data.get("inventory", []))
    EquipmentManager.serial = maxi(0, int(equipment_data.get("serial", 0)))
    MarketManager.offers.assign(market_data.get("offers", []))
    MarketManager._serial = maxi(0, int(market_data.get("serial", 0)))
    if MarketManager.offers.is_empty(): MarketManager.refresh_market(false)

    RivalManager.rivals.assign(rival_data.get("entries", []))
    if RivalManager.rivals.is_empty(): RivalManager._seed_rivals()
    RivalManager.hostility_heat = maxi(0, int(rival_data.get("hostility_heat", 0)))
    RivalManager.operations_completed = maxi(0, int(rival_data.get("operations_completed", 0)))
    RivalManager.operations_detected = maxi(0, int(rival_data.get("operations_detected", 0)))

    EventManager.import_state(data.get("events", {}))
    EconomyManager.import_state(data.get("economy", {}))
    TournamentManager.import_state(data.get("tournaments", {}))
    CampaignManager.import_state(data.get("campaign", {}))
    PersonalityManager.import_state(data.get("personality", {}))
    RelationshipManager.import_state(data.get("relationships", {}))
    GladiatorProgressionManager.import_state(data.get("gladiator_progression", {}))
    TransferManager.import_state(data.get("transfers", {}))

    GameState.resources_changed.emit()
    RosterManager.roster_changed.emit()
    EstateManager.estate_changed.emit()
    EquipmentManager.inventory_changed.emit()
    MarketManager.market_changed.emit()
    RivalManager.rivals_changed.emit()
    EventManager.events_changed.emit()
    EconomyManager.economy_changed.emit()
    TournamentManager.calendar_changed.emit()
    CampaignManager.campaign_changed.emit()
    PersonalityManager.personality_changed.emit("")
    RelationshipManager.relationships_changed.emit()
    GladiatorProgressionManager.progression_changed.emit()
    TransferManager.transfers_changed.emit()
    return true

func _serialize_person(person) -> Dictionary:
    return {
        "id":person.id,"name":person.display_name,"role":person.role,"job":person.job,"origin":person.origin,
        "strength":person.strength,"agility":person.agility,"endurance":person.endurance,"intelligence":person.intelligence,
        "loyalty":person.loyalty,"morale":person.morale,"fatigue":person.fatigue,"training":person.training,
        "traits":person.traits.duplicate(),"equipped_weapon_id":person.equipped_weapon_id,"equipped_armor_id":person.equipped_armor_id,
        "equipped_shield_id":person.equipped_shield_id,"injury_severity":person.injury_severity,"injury_days":person.injury_days,"injury_name":person.injury_name
    }

func _deserialize_person(data: Dictionary):
    var person = PERSON_SCRIPT.new(data)
    person.fatigue = clampi(int(data.get("fatigue", 0)), 0, 100)
    person.training = maxi(0, int(data.get("training", 0)))
    person.equipped_weapon_id = str(data.get("equipped_weapon_id", ""))
    person.equipped_armor_id = str(data.get("equipped_armor_id", ""))
    person.equipped_shield_id = str(data.get("equipped_shield_id", ""))
    person.injury_severity = clampi(int(data.get("injury_severity", 0)), 0, 3)
    person.injury_days = maxi(0, int(data.get("injury_days", 0)))
    person.injury_name = str(data.get("injury_name", ""))
    return person

func _copy_file(source_path: String, target_path: String) -> void:
    var source := FileAccess.open(source_path, FileAccess.READ)
    if source == null: return
    var contents := source.get_buffer(source.get_length())
    source.close()
    var target := FileAccess.open(target_path, FileAccess.WRITE)
    if target == null: return
    target.store_buffer(contents)
    target.close()