extends Node

signal history_changed

const MAX_ENTRIES: int = 60

var entries: Array[Dictionary] = []
var total_wins: int = 0
var total_losses: int = 0
var total_surrenders: int = 0
var total_rewards: int = 0
var total_reputation: int = 0
var current_win_streak: int = 0
var best_win_streak: int = 0
var flawless_wins: int = 0
var beast_wins: int = 0
var underground_wins: int = 0
var official_wins: int = 0

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
    var event_type: String = str(result.get("event_type", "unknown"))
    var enemy_kind: String = str(result.get("enemy_kind", "gladiator"))
    var player_health: int = int(result.get("player_health", 0))
    var player_max_health: int = maxi(1, int(result.get("player_max_health", 1)))
    var health_ratio: float = float(maxi(0, player_health)) / float(player_max_health)
    var technique_stats: Dictionary = result.get("technique_stats", {}) as Dictionary
    var status_stats: Dictionary = result.get("status_stats", {}) as Dictionary
    var entry: Dictionary = {
        "day": GameState.day,
        "event_type": event_type,
        "event_name": str(result.get("event_name", "Combate")),
        "fighter": str(result.get("fighter", "Gladiador")),
        "fighter_id": str(result.get("fighter_id", "")),
        "enemy": str(result.get("enemy", "Rival")),
        "enemy_kind": enemy_kind,
        "victory": victory,
        "surrendered": surrendered,
        "rounds": int(result.get("rounds", 0)),
        "reward": int(result.get("reward", 0)),
        "reputation": int(result.get("reputation", 0)),
        "injury": str(result.get("injury", "")),
        "tactic": str(result.get("tactic", "balanced")),
        "player_health": player_health,
        "player_max_health": player_max_health,
        "technique_stats": technique_stats.duplicate(true),
        "status_stats": status_stats.duplicate(true),
        "flawless": victory and health_ratio >= 0.75 and str(result.get("injury", "")).is_empty()
    }
    entries.push_front(entry)
    if entries.size() > MAX_ENTRIES:
        entries.resize(MAX_ENTRIES)

    if victory:
        total_wins += 1
        current_win_streak += 1
        best_win_streak = maxi(best_win_streak, current_win_streak)
        if bool(entry.get("flawless", false)):
            flawless_wins += 1
        if enemy_kind == "beast" or event_type == "beast_hunt":
            beast_wins += 1
        if event_type == "underground":
            underground_wins += 1
        if event_type == "official":
            official_wins += 1
    elif surrendered:
        total_surrenders += 1
        current_win_streak = 0
    else:
        total_losses += 1
        current_win_streak = 0

    total_rewards += int(entry.get("reward", 0))
    total_reputation += int(entry.get("reputation", 0))
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
        "reputation": total_reputation,
        "current_streak": current_win_streak,
        "best_streak": best_win_streak,
        "flawless_wins": flawless_wins,
        "beast_wins": beast_wins,
        "official_wins": official_wins,
        "underground_wins": underground_wins,
        "titles": get_unlocked_titles()
    }

func get_unlocked_titles() -> Array[String]:
    var titles: Array[String] = []
    if total_wins >= 1:
        titles.append("Debutante victorioso")
    if total_wins >= 10:
        titles.append("Veterano de la arena")
    if best_win_streak >= 3:
        titles.append("Imparable")
    if best_win_streak >= 7:
        titles.append("Invicto")
    if flawless_wins >= 3:
        titles.append("Intocable")
    if beast_wins >= 3:
        titles.append("Cazador de bestias")
    if official_wins >= 5:
        titles.append("Favorito del público")
    if underground_wins >= 5:
        titles.append("Rey del bajo mundo")
    return titles

func get_next_milestones() -> Array[String]:
    var milestones: Array[String] = []
    if total_wins < 10:
        milestones.append("%d victoria(s) para Veterano de la arena" % (10 - total_wins))
    if best_win_streak < 3:
        milestones.append("Racha de %d victoria(s) para Imparable" % maxi(0, 3 - current_win_streak))
    if flawless_wins < 3:
        milestones.append("%d victoria(s) impecable(s) para Intocable" % (3 - flawless_wins))
    if beast_wins < 3:
        milestones.append("%d bestia(s) para Cazador de bestias" % (3 - beast_wins))
    var limited: Array[String] = []
    for index: int in range(mini(3, milestones.size())):
        limited.append(milestones[index])
    return limited

func get_fighter_summary(fighter_id: String) -> Dictionary:
    var fights: int = 0
    var wins: int = 0
    var rewards: int = 0
    var injuries: int = 0
    var flawless: int = 0
    for entry: Dictionary in entries:
        if str(entry.get("fighter_id", "")) != fighter_id:
            continue
        fights += 1
        if bool(entry.get("victory", false)):
            wins += 1
        if bool(entry.get("flawless", false)):
            flawless += 1
        rewards += int(entry.get("reward", 0))
        if not str(entry.get("injury", "")).is_empty():
            injuries += 1
    return {"fights":fights,"wins":wins,"rewards":rewards,"injuries":injuries,"flawless":flawless}

func export_state() -> Dictionary:
    return {
        "entries": entries.duplicate(true),
        "total_wins": total_wins,
        "total_losses": total_losses,
        "total_surrenders": total_surrenders,
        "total_rewards": total_rewards,
        "total_reputation": total_reputation,
        "current_win_streak": current_win_streak,
        "best_win_streak": best_win_streak,
        "flawless_wins": flawless_wins,
        "beast_wins": beast_wins,
        "underground_wins": underground_wins,
        "official_wins": official_wins
    }

func import_state(data: Dictionary) -> void:
    entries.clear()
    var saved_entries: Array = data.get("entries", []) as Array
    for value: Variant in saved_entries:
        if value is Dictionary:
            entries.append((value as Dictionary).duplicate(true))
    if entries.size() > MAX_ENTRIES:
        entries.resize(MAX_ENTRIES)
    total_wins = maxi(0, int(data.get("total_wins", 0)))
    total_losses = maxi(0, int(data.get("total_losses", 0)))
    total_surrenders = maxi(0, int(data.get("total_surrenders", 0)))
    total_rewards = maxi(0, int(data.get("total_rewards", 0)))
    total_reputation = int(data.get("total_reputation", 0))
    current_win_streak = maxi(0, int(data.get("current_win_streak", 0)))
    best_win_streak = maxi(current_win_streak, int(data.get("best_win_streak", 0)))
    flawless_wins = maxi(0, int(data.get("flawless_wins", 0)))
    beast_wins = maxi(0, int(data.get("beast_wins", 0)))
    underground_wins = maxi(0, int(data.get("underground_wins", 0)))
    official_wins = maxi(0, int(data.get("official_wins", 0)))
    history_changed.emit()
