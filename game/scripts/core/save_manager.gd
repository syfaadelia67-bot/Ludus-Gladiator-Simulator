extends Node

signal save_completed(path: String)
signal load_completed(path: String)
signal save_failed(reason: String)
signal load_failed(reason: String)

const SAVE_VERSION := 14
const SAVE_PATH := "user://ludus_save.json"
const BACKUP_PATH := "user://ludus_save.backup.json"
const TEMP_PATH := "user://ludus_save.tmp.json"
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
    return not _read_payload(SAVE_PATH).is_empty() or not _read_payload(BACKUP_PATH).is_empty()

func get_save_metadata() -> Dictionary:
    var data: Dictionary = _read_payload(SAVE_PATH)
    if data.is_empty():
        data = _read_payload(BACKUP_PATH)
    if data.is_empty():
        return {}
    var owner_profile: Dictionary = data.get("owner", {}).get("profile", {})
    return {
        "version": int(data.get("version", 0)),
        "saved_at_unix": int(data.get("saved_at_unix", 0)),
        "day": int(data.get("game_state", {}).get("day", 1)),
        "week": int(data.get("game_state", {}).get("week", data.get("game_state", {}).get("day", 1))),
        "owner_name": str(owner_profile.get("display_name", "")),
        "owner_title": str(owner_profile.get("title", "dominus"))
    }

func save_game() -> bool:
    var payload: Dictionary = _build_payload()
    if not _validate_payload(payload):
        save_failed.emit("Los datos actuales no superaron la validación de guardado.")
        return false
    if not _write_payload(TEMP_PATH, payload):
        save_failed.emit("No se pudo escribir el archivo temporal de guardado.")
        return false
    var verification: Dictionary = _read_payload(TEMP_PATH)
    if verification.is_empty():
        _remove_file(TEMP_PATH)
        save_failed.emit("El archivo temporal no pudo verificarse y no se reemplazó la partida anterior.")
        return false
    if FileAccess.file_exists(SAVE_PATH):
        _copy_file(SAVE_PATH, BACKUP_PATH)
    if not _copy_file(TEMP_PATH, SAVE_PATH):
        _remove_file(TEMP_PATH)
        save_failed.emit("No se pudo reemplazar el guardado principal.")
        return false
    _remove_file(TEMP_PATH)
    save_completed.emit(SAVE_PATH)
    return true

func load_game() -> bool:
    var data: Dictionary = _read_payload(SAVE_PATH)
    var loaded_path: String = SAVE_PATH
    if data.is_empty():
        data = _read_payload(BACKUP_PATH)
        loaded_path = BACKUP_PATH
    if data.is_empty():
        load_failed.emit("No existe una partida válida para cargar.")
        return false
    if int(data.get("version", 0)) > SAVE_VERSION:
        load_failed.emit("La partida fue creada con una versión más nueva del juego.")
        return false
    if not _apply_payload(data):
        load_failed.emit("No se pudo restaurar la partida.")
        return false
    load_completed.emit(loaded_path)
    return true

func delete_save() -> bool:
    var success := true
    for path in [SAVE_PATH, BACKUP_PATH, TEMP_PATH]:
        if FileAccess.file_exists(path):
            success = _remove_file(path) and success
    LudusOwnerManager.reset_profile()
    return success

func _read_payload(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not parsed is Dictionary:
        return {}
    var payload: Dictionary = parsed
    return payload if _validate_payload(payload) else {}

func _write_payload(path: String, payload: Dictionary) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(payload, "  "))
    file.flush()
    file.close()
    return FileAccess.file_exists(path)

func _validate_payload(payload: Dictionary) -> bool:
    if int(payload.get("version", 0)) <= 0:
        return false
    var game_data: Variant = payload.get("game_state", null)
    var roster_data: Variant = payload.get("roster", null)
    if not game_data is Dictionary or not roster_data is Dictionary:
        return false
    if int(game_data.get("day", game_data.get("week", 0))) < 1:
        return false
    if int(game_data.get("denarii", -1)) < 0 or int(game_data.get("food", -1)) < 0 or int(game_data.get("ore", -1)) < 0:
        return false
    var people_data: Variant = roster_data.get("people", null)
    if not people_data is Array:
        return false
    var known_ids: Dictionary = {}
    for person_data in people_data:
        if not person_data is Dictionary:
            return false
        var person_id: String = str(person_data.get("id", ""))
        if person_id.is_empty() or known_ids.has(person_id):
            return false
        known_ids[person_id] = true
    var history_data: Variant = payload.get("combat_history", {})
    if not history_data is Dictionary or not history_data.get("entries", []) is Array:
        return false
    var owner_data: Variant = payload.get("owner", {})
    if not owner_data is Dictionary:
        return false
    var owner_profile: Variant = owner_data.get("profile", {})
    return owner_profile is Dictionary

func _build_payload() -> Dictionary:
    var people_data: Array = []
    for person in RosterManager.get_people():
        people_data.append(_serialize_person(person))
    return {
        "version": SAVE_VERSION,
        "saved_at_unix": int(Time.get_unix_time_from_system()),
        "game_state":{"day":GameState.day,"week":GameState.get_week(),"denarii":GameState.denarii,"food":GameState.food,"ore":GameState.ore,"reputation":GameState.reputation},
        "owner":LudusOwnerManager.export_state(),
        "roster":{"people":people_data,"capacity":RosterManager.capacity,"security_score":RosterManager.security_score,"intelligence_points":RosterManager.intelligence_points},
        "estate":{"levels":EstateManager.export_levels()},
        "equipment":{"inventory":EquipmentManager.inventory.duplicate(true),"serial":EquipmentManager.serial},
        "market":{
            "offers":MarketManager.offers.duplicate(true),
            "serial":MarketManager._serial,
            "equipment_offers":MarketManager.equipment_offers.duplicate(true),
            "equipment_offer_serial":MarketManager._equipment_offer_serial,
            "last_auto_refresh_week":MarketManager.last_auto_refresh_week
        },
        "rivals":{"entries":RivalManager.rivals.duplicate(true),"hostility_heat":RivalManager.hostility_heat,"operations_completed":RivalManager.operations_completed,"operations_detected":RivalManager.operations_detected},
        "combat":{"last_combat_day":CombatManager.last_combat_day,"last_result":CombatManager.last_result.duplicate(true),"next_battle_config":CombatManager.next_battle_config.duplicate(true)},
        "combat_history":CombatHistoryManager.export_state(),
        "events":EventManager.export_state(),
        "economy":EconomyManager.export_state(),
        "tournaments":TournamentManager.export_state(),
        "campaign":CampaignManager.export_state(),
        "personality":PersonalityManager.export_state(),
        "relationships":RelationshipManager.export_state(),
        "gladiator_progression":GladiatorProgressionManager.export_state(),
        "traits":TraitManager.export_state(),
        "transfers":TransferManager.export_state()
    }

func _apply_payload(data: Dictionary) -> bool:
    var game_data: Dictionary = data.get("game_state", {})
    var roster_data: Dictionary = data.get("roster", {})
    var estate_data: Dictionary = data.get("estate", {})
    var equipment_data: Dictionary = data.get("equipment", {})
    var market_data: Dictionary = data.get("market", {})
    var rival_data: Dictionary = data.get("rivals", {})
    var combat_data: Dictionary = data.get("combat", {})

    GameState.day = maxi(1, int(game_data.get("week", game_data.get("day", 1))))
    GameState.denarii = maxi(0, int(game_data.get("denarii", 500)))
    GameState.food = maxi(0, int(game_data.get("food", 100)))
    GameState.ore = maxi(0, int(game_data.get("ore", 20)))
    GameState.reputation = int(game_data.get("reputation", 0))

    RosterManager.people.clear()
    for person_data in roster_data.get("people", []):
        if person_data is Dictionary:
            RosterManager.people.append(_deserialize_person(person_data))
    if RosterManager.people.is_empty():
        RosterManager._seed_initial_roster()
    RosterManager.capacity = maxi(1, int(roster_data.get("capacity", 8)))
    RosterManager.security_score = maxi(0, int(roster_data.get("security_score", 0)))
    RosterManager.intelligence_points = maxi(0, int(roster_data.get("intelligence_points", 0)))

    var loaded_levels: Variant = estate_data.get("levels", {})
    EstateManager.import_levels(loaded_levels if loaded_levels is Dictionary else {})

    EquipmentManager.inventory.assign(equipment_data.get("inventory", []))
    EquipmentManager.serial = maxi(0, int(equipment_data.get("serial", 0)))

    MarketManager.offers.clear()
    for raw_offer in market_data.get("offers", []):
        if raw_offer is Dictionary:
            MarketManager.offers.append(_migrate_market_offer(raw_offer))
    MarketManager._serial = maxi(0, int(market_data.get("serial", 0)))

    MarketManager.equipment_offers.clear()
    for raw_equipment_offer in market_data.get("equipment_offers", []):
        if raw_equipment_offer is Dictionary:
            MarketManager.equipment_offers.append(_migrate_equipment_market_offer(raw_equipment_offer))
    MarketManager._equipment_offer_serial = maxi(0, int(market_data.get("equipment_offer_serial", 0)))
    MarketManager.last_auto_refresh_week = maxi(1, int(market_data.get("last_auto_refresh_week", GameState.get_week())))

    if MarketManager.offers.is_empty():
        MarketManager.refresh_market(false)
    if MarketManager.equipment_offers.is_empty():
        MarketManager.refresh_equipment_market(false)

    RivalManager.rivals.assign(rival_data.get("entries", []))
    if RivalManager.rivals.is_empty():
        RivalManager._seed_rivals()
    RivalManager.hostility_heat = maxi(0, int(rival_data.get("hostility_heat", 0)))
    RivalManager.operations_completed = maxi(0, int(rival_data.get("operations_completed", 0)))
    RivalManager.operations_detected = maxi(0, int(rival_data.get("operations_detected", 0)))

    CombatManager.last_combat_day = int(combat_data.get("last_combat_day", -1))
    CombatManager.last_result = combat_data.get("last_result", {}).duplicate(true)
    CombatManager.next_battle_config = _migrate_battle_config(combat_data.get("next_battle_config", {}))
    CombatHistoryManager.import_state(data.get("combat_history", {}))
    EventManager.import_state(data.get("events", {}))
    EconomyManager.import_state(data.get("economy", {}))
    TournamentManager.import_state(data.get("tournaments", {}))
    CampaignManager.import_state(data.get("campaign", {}))
    PersonalityManager.import_state(data.get("personality", {}))
    RelationshipManager.import_state(data.get("relationships", {}))
    GladiatorProgressionManager.import_state(data.get("gladiator_progression", {}))
    TraitManager.import_state(data.get("traits", {}))
    TransferManager.import_state(data.get("transfers", {}))
    LudusOwnerManager.import_state(data.get("owner", LudusOwnerManager.export_state()))

    GameState.resources_changed.emit()
    RosterManager.roster_changed.emit()
    EquipmentManager.inventory_changed.emit()
    MarketManager.market_changed.emit()
    MarketManager.equipment_market_changed.emit()
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
        "technique":person.technique,"health":person.health,
        "loyalty":person.loyalty,"morale":person.morale,"fatigue":person.fatigue,"training":person.training,
        "traits":person.traits.duplicate(),"applied_trait_effects":person.applied_trait_effects.duplicate(),
        "equipped_weapon_id":person.equipped_weapon_id,"equipped_armor_id":person.equipped_armor_id,
        "equipped_shield_id":person.equipped_shield_id,"injury_severity":person.injury_severity,"injury_days":person.injury_days,"injury_name":person.injury_name
    }

func _deserialize_person(data: Dictionary):
    var migrated_data := data.duplicate(true)
    migrated_data["technique"] = int(migrated_data.get("technique", 5))
    migrated_data["health"] = maxi(1, int(migrated_data.get("health", 50)))
    migrated_data["traits"] = _unique_strings(migrated_data.get("traits", []))
    migrated_data["applied_trait_effects"] = _unique_strings(migrated_data.get("applied_trait_effects", []))
    var person = PERSON_SCRIPT.new(migrated_data)
    person.fatigue = clampi(int(migrated_data.get("fatigue", 0)), 0, 100)
    person.training = maxi(0, int(migrated_data.get("training", 0)))
    person.equipped_weapon_id = str(migrated_data.get("equipped_weapon_id", ""))
    person.equipped_armor_id = str(migrated_data.get("equipped_armor_id", ""))
    person.equipped_shield_id = str(migrated_data.get("equipped_shield_id", ""))
    person.injury_severity = clampi(int(migrated_data.get("injury_severity", 0)), 0, 3)
    person.injury_days = maxi(0, int(migrated_data.get("injury_days", 0)))
    person.injury_name = str(migrated_data.get("injury_name", ""))
    return person

func _migrate_market_offer(raw_offer: Dictionary) -> Dictionary:
    var offer := raw_offer.duplicate(true)
    offer["technique"] = int(offer.get("technique", 5))
    offer["health"] = maxi(1, int(offer.get("health", 50)))
    offer["traits"] = _unique_strings(offer.get("traits", []))
    while offer["traits"].size() > 2:
        offer["traits"].pop_back()
    offer["price"] = MarketValuation.value_offer(offer)
    return offer

func _migrate_equipment_market_offer(raw_offer: Dictionary) -> Dictionary:
    var offer := raw_offer.duplicate(true)
    var recipe_id := str(offer.get("recipe_id", ""))
    var recipe := EquipmentManager.get_recipe(recipe_id)
    offer["name"] = str(offer.get("name", recipe.get("name", "Objeto")))
    offer["type"] = str(offer.get("type", recipe.get("type", "weapon")))
    offer["quality"] = str(offer.get("quality", "Común"))
    offer["power"] = int(offer.get("power", recipe.get("power", 0)))
    offer["defense"] = int(offer.get("defense", recipe.get("defense", 0)))
    offer["tags"] = _unique_strings(offer.get("tags", recipe.get("tags", [])))
    offer["price"] = maxi(1, int(offer.get("price", recipe.get("denarii", 20))))
    return offer

func _migrate_battle_config(raw_config: Dictionary) -> Dictionary:
    var config := {
        "energy_rule":"balanced",
        "surrender_threshold":20,
        "allow_finisher":true,
        "fighter_id":"",
        "abilities":[],
        "tactical_plan":[]
    }
    config.merge(raw_config, true)
    var migrated_plan: Array = []
    for order in config.get("tactical_plan", []):
        if not order is Dictionary or migrated_plan.size() >= 4:
            continue
        migrated_plan.append({
            "ability_id":str(order.get("ability_id", "")),
            "condition":GladiatorProgressionManager.canonical_tactical_condition(str(order.get("condition", "always")))
        })
    config["tactical_plan"] = migrated_plan
    config.erase("techniques")
    return config

func _unique_strings(values: Variant) -> Array[String]:
    var result: Array[String] = []
    if not values is Array:
        return result
    for value in values:
        var text := str(value)
        if not text.is_empty() and not result.has(text):
            result.append(text)
    return result

func _copy_file(source_path: String, target_path: String) -> bool:
    var source := FileAccess.open(source_path, FileAccess.READ)
    if source == null:
        return false
    var contents := source.get_buffer(source.get_length())
    source.close()
    var target := FileAccess.open(target_path, FileAccess.WRITE)
    if target == null:
        return false
    target.store_buffer(contents)
    target.flush()
    target.close()
    return FileAccess.file_exists(target_path)

func _remove_file(path: String) -> bool:
    if not FileAccess.file_exists(path):
        return true
    return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
