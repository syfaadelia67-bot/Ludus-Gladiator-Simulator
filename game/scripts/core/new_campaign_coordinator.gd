extends Node

signal campaign_reset_completed
signal campaign_reset_failed(reason: String)

var reset_in_progress: bool = false

func reset_campaign_state() -> bool:
    if reset_in_progress:
        campaign_reset_failed.emit("Ya se está preparando una nueva campaña.")
        return false

    reset_in_progress = true
    var previous_autosave := SaveManager.autosave_enabled
    SaveManager.autosave_enabled = false

    if not SaveManager.delete_save():
        SaveManager.autosave_enabled = previous_autosave
        reset_in_progress = false
        campaign_reset_failed.emit("No se pudieron limpiar los archivos de la campaña anterior.")
        return false

    var reset_payload := {
        "version": SaveManager.SAVE_VERSION,
        "saved_at_unix": 0,
        "game_state": {
            "day": 1,
            "week": 1,
            "denarii": 500,
            "food": 100,
            "ore": 20,
            "reputation": 0
        },
        "owner": LudusOwnerManager.export_state(),
        "roster": {
            "people": [],
            "capacity": 8,
            "security_score": 0,
            "intelligence_points": 0
        },
        "estate": {"levels": {}},
        "equipment": {"inventory": [], "serial": 0},
        "market": {"offers": [], "serial": 0},
        "rivals": {
            "entries": [],
            "hostility_heat": 0,
            "operations_completed": 0,
            "operations_detected": 0
        },
        "combat": {
            "last_combat_day": -1,
            "last_result": {},
            "next_battle_config": {}
        },
        "combat_history": {"entries": []},
        "events": {},
        "economy": {},
        "tournaments": {},
        "campaign": {},
        "personality": {},
        "relationships": {},
        "gladiator_progression": {},
        "traits": {},
        "transfers": {}
    }

    var applied := SaveManager._apply_payload(reset_payload)
    SaveManager.autosave_enabled = previous_autosave
    reset_in_progress = false
    if not applied:
        campaign_reset_failed.emit("No se pudo restaurar el estado inicial de la nueva campaña.")
        return false

    campaign_reset_completed.emit()
    return true
