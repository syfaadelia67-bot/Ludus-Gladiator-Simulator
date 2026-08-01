extends Node

signal rivalry_changed(person_id: String, opponent_id: String)
signal rivalry_intensified(person_id: String, opponent_id: String, intensity: int)

const MAX_RECENT_ENCOUNTERS := 8

func _ready() -> void:
    CombatManager.combat_finished.connect(_on_combat_finished)
    SaveManager.load_completed.connect(func(_path: String): _sanitize_all())
    RosterManager.roster_changed.connect(_sanitize_all)
    call_deferred("_sanitize_all")

func get_rivalry(person_id: String, opponent_id: String) -> Dictionary:
    var record := GladiatorProgressionManager.ensure_record(person_id)
    _sanitize_record(record)
    return record.get("rivalries", {}).get(opponent_id, {}).duplicate(true)

func get_rivalries(person_id: String) -> Array[Dictionary]:
    var record := GladiatorProgressionManager.ensure_record(person_id)
    _sanitize_record(record)
    var result: Array[Dictionary] = []
    for opponent_id in record.get("rivalries", {}).keys():
        var rivalry: Dictionary = record["rivalries"][opponent_id].duplicate(true)
        rivalry["opponent_id"] = str(opponent_id)
        result.append(rivalry)
    result.sort_custom(func(a: Dictionary, b: Dictionary):
        var intensity_a := int(a.get("intensity", 0))
        var intensity_b := int(b.get("intensity", 0))
        if intensity_a == intensity_b:
            return int(a.get("last_week", 0)) > int(b.get("last_week", 0))
        return intensity_a > intensity_b
    )
    return result

func get_summary(person_id: String) -> Dictionary:
    var rivalries := get_rivalries(person_id)
    var total_encounters := 0
    var total_wins := 0
    var total_losses := 0
    var strongest: Dictionary = {}
    for rivalry in rivalries:
        total_encounters += int(rivalry.get("encounters", 0))
        total_wins += int(rivalry.get("wins", 0))
        total_losses += int(rivalry.get("losses", 0))
        if strongest.is_empty() or int(rivalry.get("intensity", 0)) > int(strongest.get("intensity", 0)):
            strongest = rivalry.duplicate(true)
    return {
        "count": rivalries.size(),
        "encounters": total_encounters,
        "wins": total_wins,
        "losses": total_losses,
        "strongest": strongest
    }

func get_intensity_label(intensity: int) -> String:
    if intensity >= 80:
        return "Enemistad legendaria"
    if intensity >= 55:
        return "Rivalidad feroz"
    if intensity >= 30:
        return "Rivalidad consolidada"
    if intensity >= 12:
        return "Tensión creciente"
    return "Primer enfrentamiento"

func _on_combat_finished(result: Dictionary) -> void:
    var person_id := str(result.get("fighter_id", ""))
    var opponent_id := str(result.get("enemy_unique_gladiator_id", ""))
    if person_id.is_empty() or opponent_id.is_empty():
        return
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator":
        return

    var record := GladiatorProgressionManager.ensure_record(person_id)
    _sanitize_record(record)
    var rivalries: Dictionary = record.get("rivalries", {})
    var rivalry: Dictionary = rivalries.get(opponent_id, _new_rivalry(opponent_id, str(result.get("enemy_rival_id", ""))))
    var old_intensity := int(rivalry.get("intensity", 0))
    var victory := bool(result.get("victory", false))
    var surrendered := bool(result.get("surrendered", false))

    rivalry["encounters"] = int(rivalry.get("encounters", 0)) + 1
    rivalry["wins"] = int(rivalry.get("wins", 0)) + (1 if victory else 0)
    rivalry["losses"] = int(rivalry.get("losses", 0)) + (0 if victory else 1)
    rivalry["last_week"] = GameState.get_week()
    rivalry["rival_id"] = str(result.get("enemy_rival_id", rivalry.get("rival_id", "")))
    rivalry["last_result"] = "victoria" if victory else ("rendición" if surrendered else "derrota")

    var streak := int(rivalry.get("streak", 0))
    var streak_owner := str(rivalry.get("streak_owner", ""))
    var winner_id := person_id if victory else opponent_id
    if streak_owner == winner_id:
        streak += 1
    else:
        streak = 1
        streak_owner = winner_id
    rivalry["streak"] = streak
    rivalry["streak_owner"] = streak_owner

    var intensity_gain := 10 + mini(12, int(result.get("rounds", 0)))
    if surrendered:
        intensity_gain += 5
    if int(rivalry.get("encounters", 0)) >= 3:
        intensity_gain += 5
    rivalry["intensity"] = clampi(old_intensity + intensity_gain, 0, 100)

    var recent: Array = rivalry.get("recent", [])
    recent.push_front({
        "week": GameState.get_week(),
        "result": rivalry["last_result"],
        "rounds": maxi(0, int(result.get("rounds", 0))),
        "event": str(result.get("event_name", "Arena"))
    })
    if recent.size() > MAX_RECENT_ENCOUNTERS:
        recent.resize(MAX_RECENT_ENCOUNTERS)
    rivalry["recent"] = recent
    rivalries[opponent_id] = rivalry
    record["rivalries"] = rivalries

    var opponent := DataRepository.get_unique_gladiator(opponent_id)
    var opponent_name := str(opponent.get("name", opponent_id))
    GladiatorCareerJournalController.add_event(person_id, "rivalry", "Rivalidad con %s" % opponent_name, "%s se enfrentó a %s. Marcador personal: %d-%d." % [person.display_name, opponent_name, int(rivalry.get("wins", 0)), int(rivalry.get("losses", 0))], {"opponent_id": opponent_id, "intensity": rivalry["intensity"]})
    rivalry_changed.emit(person_id, opponent_id)
    if int(rivalry.get("intensity", 0)) / 25 > old_intensity / 25:
        rivalry_intensified.emit(person_id, opponent_id, int(rivalry.get("intensity", 0)))
    GladiatorProgressionManager.progression_changed.emit()

func _new_rivalry(opponent_id: String, rival_id: String) -> Dictionary:
    return {
        "opponent_id": opponent_id,
        "rival_id": rival_id,
        "encounters": 0,
        "wins": 0,
        "losses": 0,
        "streak": 0,
        "streak_owner": "",
        "intensity": 0,
        "last_week": 0,
        "last_result": "",
        "recent": []
    }

func _sanitize_all() -> void:
    for person in RosterManager.get_people():
        if person.role == "gladiator":
            _sanitize_record(GladiatorProgressionManager.ensure_record(person.id))

func _sanitize_record(record: Dictionary) -> void:
    var raw_rivalries = record.get("rivalries", {})
    var clean: Dictionary = {}
    if raw_rivalries is Dictionary:
        for raw_id in raw_rivalries.keys():
            var opponent_id := str(raw_id)
            if DataRepository.get_unique_gladiator(opponent_id).is_empty():
                continue
            var raw = raw_rivalries[raw_id]
            var rivalry: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
            var recent: Array = []
            if rivalry.get("recent", []) is Array:
                for entry in rivalry.get("recent", []):
                    if not entry is Dictionary or recent.size() >= MAX_RECENT_ENCOUNTERS:
                        continue
                    recent.append({
                        "week": maxi(1, int(entry.get("week", 1))),
                        "result": str(entry.get("result", "derrota")),
                        "rounds": maxi(0, int(entry.get("rounds", 0))),
                        "event": str(entry.get("event", "Arena"))
                    })
            clean[opponent_id] = {
                "opponent_id": opponent_id,
                "rival_id": str(rivalry.get("rival_id", "")),
                "encounters": maxi(0, int(rivalry.get("encounters", 0))),
                "wins": maxi(0, int(rivalry.get("wins", 0))),
                "losses": maxi(0, int(rivalry.get("losses", 0))),
                "streak": maxi(0, int(rivalry.get("streak", 0))),
                "streak_owner": str(rivalry.get("streak_owner", "")),
                "intensity": clampi(int(rivalry.get("intensity", 0)), 0, 100),
                "last_week": maxi(0, int(rivalry.get("last_week", 0))),
                "last_result": str(rivalry.get("last_result", "")),
                "recent": recent
            }
    record["rivalries"] = clean
