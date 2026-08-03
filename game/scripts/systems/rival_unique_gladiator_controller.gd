extends Node

signal rival_gladiator_progressed(gladiator_id: String, rival_id: String)

const PROFILE_KEY := "unique_gladiator_profiles"

func _ready() -> void:
    GameState.week_advanced.connect(_on_week_advanced)
    UniqueGladiatorManager.unique_gladiator_claimed_by_rival.connect(_on_claimed_by_rival)
    SaveManager.load_completed.connect(func(_path: String): call_deferred("_ensure_all_profiles"))
    call_deferred("_ensure_all_profiles")

func get_opponent_for_week(week: int, event_type: String) -> Dictionary:
    if event_type == "beast_hunt":
        return {}
    var candidates: Array[Dictionary] = []
    for rival in RivalManager.rivals:
        var rival_id := str(rival.get("id", ""))
        var profiles: Dictionary = rival.get(PROFILE_KEY, {})
        for gladiator_id in profiles.keys():
            var profile: Dictionary = profiles[gladiator_id]
            if not bool(profile.get("active", true)):
                continue
            var candidate := profile.duplicate(true)
            candidate["rival_id"] = rival_id
            candidate["rival_name"] = str(rival.get("name", "Casa rival"))
            candidates.append(candidate)
    if candidates.is_empty():
        return {}
    candidates.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("gladiator_id", "")) < str(b.get("gladiator_id", "")))
    var selection_seed := absi(hash("unique-opponent|%d|%s" % [week, event_type]))
    return candidates[selection_seed % candidates.size()].duplicate(true)

func get_profile(gladiator_id: String) -> Dictionary:
    for rival in RivalManager.rivals:
        var profiles: Dictionary = rival.get(PROFILE_KEY, {})
        if profiles.has(gladiator_id):
            var result: Dictionary = profiles[gladiator_id].duplicate(true)
            result["rival_id"] = str(rival.get("id", ""))
            result["rival_name"] = str(rival.get("name", "Casa rival"))
            return result
    return {}

func register_combat_result(gladiator_id: String, defeated_by_player: bool) -> void:
    for rival in RivalManager.rivals:
        var profiles: Dictionary = rival.get(PROFILE_KEY, {})
        if not profiles.has(gladiator_id):
            continue
        var profile: Dictionary = profiles[gladiator_id]
        profile["arena_appearances"] = int(profile.get("arena_appearances", 0)) + 1
        if defeated_by_player:
            profile["losses"] = int(profile.get("losses", 0)) + 1
        else:
            profile["wins"] = int(profile.get("wins", 0)) + 1
        profiles[gladiator_id] = profile
        rival[PROFILE_KEY] = profiles
        RivalManager.rivals_changed.emit()
        return

func _on_claimed_by_rival(gladiator_id: String, rival_id: String) -> void:
    _ensure_profile(rival_id, gladiator_id)

func _on_week_advanced(week: int) -> void:
    _ensure_all_profiles()
    for rival in RivalManager.rivals:
        var rival_id := str(rival.get("id", ""))
        var profiles: Dictionary = rival.get(PROFILE_KEY, {})
        for gladiator_id in profiles.keys():
            var profile: Dictionary = profiles[gladiator_id]
            _sanitize_profile(profile, DataRepository.get_unique_gladiator(str(gladiator_id)))
            if int(profile.get("last_progress_week", 0)) >= week:
                continue
            if int(profile.get("training_disrupted_until", 0)) >= week:
                profile["last_progress_week"] = week
                profiles[gladiator_id] = profile
                continue
            profile["experience"] = int(profile.get("experience", 0)) + 12 + int(rival.get("wealth", 50)) / 12
            while int(profile.get("experience", 0)) >= _experience_for_next_level(int(profile.get("level", 1))):
                profile["experience"] = int(profile.get("experience", 0)) - _experience_for_next_level(int(profile.get("level", 1)))
                profile["level"] = mini(10, int(profile.get("level", 1)) + 1)
            profile["last_progress_week"] = week
            profiles[gladiator_id] = profile
            rival_gladiator_progressed.emit(str(gladiator_id), rival_id)
        rival[PROFILE_KEY] = profiles
    RivalManager.rivals_changed.emit()

func _ensure_all_profiles() -> void:
    for rival in RivalManager.rivals:
        var rival_id := str(rival.get("id", ""))
        for raw_id in rival.get("unique_gladiators", []):
            _ensure_profile(rival_id, str(raw_id))

func _ensure_profile(rival_id: String, gladiator_id: String) -> void:
    var entry := DataRepository.get_unique_gladiator(gladiator_id)
    if entry.is_empty():
        return
    for rival in RivalManager.rivals:
        if str(rival.get("id", "")) != rival_id:
            continue
        var profiles: Dictionary = rival.get(PROFILE_KEY, {})
        if not profiles.has(gladiator_id):
            profiles[gladiator_id] = {
                "gladiator_id": gladiator_id,
                "name": str(entry.get("name", gladiator_id)),
                "level": 1,
                "experience": 0,
                "wins": 0,
                "losses": 0,
                "arena_appearances": 0,
                "last_progress_week": GameState.get_week(),
                "training_disrupted_until": 0,
                "loyalty": clampi(int(entry.get("loyalty", 55)), 0, 100),
                "active": true
            }
        else:
            var profile: Dictionary = profiles[gladiator_id]
            _sanitize_profile(profile, entry)
            profiles[gladiator_id] = profile
        rival[PROFILE_KEY] = profiles
        RivalManager.rivals_changed.emit()
        return

func _sanitize_profile(profile: Dictionary, entry: Dictionary) -> void:
    profile["level"] = clampi(int(profile.get("level", 1)), 1, 10)
    profile["experience"] = maxi(0, int(profile.get("experience", 0)))
    profile["wins"] = maxi(0, int(profile.get("wins", 0)))
    profile["losses"] = maxi(0, int(profile.get("losses", 0)))
    profile["arena_appearances"] = maxi(0, int(profile.get("arena_appearances", 0)))
    profile["last_progress_week"] = maxi(0, int(profile.get("last_progress_week", 0)))
    profile["training_disrupted_until"] = maxi(0, int(profile.get("training_disrupted_until", 0)))
    profile["loyalty"] = clampi(int(profile.get("loyalty", entry.get("loyalty", 55))), 0, 100)
    profile["active"] = bool(profile.get("active", true))

func _experience_for_next_level(level: int) -> int:
    return 40 + maxi(1, level) * 15
