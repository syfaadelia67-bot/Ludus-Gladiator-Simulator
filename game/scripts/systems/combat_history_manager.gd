extends Node

signal history_changed

const MAX_ENTRIES: int = 60

var entries: Array[Dictionary] = []
var total_wins: int = 0
var total_losses: int = 0
var total_surrenders: int = 0
var total_rewards: int = 0
var total_reputation: int = 0

func _ready() -> void:
    call_deferred("_connect_combat_manager")

func _connect_combat_manager() -> void:
    if CombatManager == null:
        return
    if not CombatManager.combat_finished.is_connected(_on_combat_finished):
        CombatManager.combat_finished.connect(_on_combat_finished)

func _on_combat_finished(result: Dictionary) -> void:
    var victory: bool = bool(result.get("victory", false))
    var surrendered: bool = bool(result.get("surrendered", false))
    var entry: Dictionary = {
        "day": GameState.day,
        "event_type": str(result.get("event_type", "unknown")),
        "event_name": str(result.get("event_name", "Combate")),
        "fighter": str(result.get("fighter", "Gladiador")),
        "fighter_id": str(result.get("fighter_id", "")),
        "enemy": str(result.get("enemy", "Rival")),
        "enemy_kind": str(result.get("enemy_kind", "gladiator")),
        "victory": victory,
        "surrendered": surrendered,
        "rounds": int(result.get("rounds", 0)),
        "reward": int(result.get("reward", 0)),
        "reputation": int(result.get("reputation", 0)),
        "injury": str(result.get("injury", "")),
        "tactic": str(result.get("tactic", "balanced")),
        "player_health": int(result.get("player_health", 0)),
        "player_max_health": int(result.get("player_max_health", 1)),
        "technique_stats": result.get("technique_stats", {}).duplicate(true),
        "status_stats": result.get("status_stats", {}).duplicate(true)
    }
    entries.push_front(entry)
    if entries.size() > MAX_ENTRIES:
        entries.resize(MAX_ENTRIES)
    if victory:
        total_wins += 1
    elif surrendered:
        total_surrenders += 1
    else:
        total_losses += 1
    total_rewards += int(entry.reward)
    total_reputation += int(entry.reputation)
    history_changed.emit()

func get_entries() -> Array[Dictionary]:
    return entries.duplicate(true)

func get_summary() -> Dictionary:
    var total: int = total_wins + total_losses + total_surrenders
    var win_rate: float = 0.0
    if total > 0:
        win_rate = float(total_wins) / float(total) * 100.0
    return {
        "total": total,
        "wins": total_wins,
        "losses": total_losses,
        "surrenders": total_surrenders,
        "win_rate": win_rate,
        "rewards": total_rewards,
        "reputation": total_reputation
    }

func get_fighter_summary(fighter_id: String) -> Dictionary:
    var fights: int = 0
    var wins: int = 0
    var rewards: int = 0
    var injuries: int = 0
    for entry in entries:
        if str(entry.get("fighter_id", "")) != fighter_id:
            continue
        fights += 1
        if bool(entry.get("victory", false)):
            wins += 1
        rewards += int(entry.get("reward", 0))
        if not str(entry.get("injury", "")).is_empty():
            injuries += 1
    return {"fights":fights,"wins":wins,"rewards":rewards,"injuries":injuries}

func export_state() -> Dictionary:
    return {
        "entries": entries.duplicate(true),
        "total_wins": total_wins,
        "total_losses": total_losses,
        "total_surrenders": total_surrenders,
        "total_rewards": total_rewards,
        "total_reputation": total_reputation
    }

func import_state(data: Dictionary) -> void:
    entries.assign(data.get("entries", []))
    if entries.size() > MAX_ENTRIES:
        entries.resize(MAX_ENTRIES)
    total_wins = maxi(0, int(data.get("total_wins", 0)))
    total_losses = maxi(0, int(data.get("total_losses", 0)))
    total_surrenders = maxi(0, int(data.get("total_surrenders", 0)))
    total_rewards = maxi(0, int(data.get("total_rewards", 0)))
    total_reputation = int(data.get("total_reputation", 0))
    history_changed.emit()
