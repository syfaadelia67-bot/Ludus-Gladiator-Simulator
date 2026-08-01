extends Node

const CombatHistoryManagerScript = preload("res://scripts/systems/combat_history_manager.gd")

func _ready() -> void:
    var manager = CombatHistoryManagerScript.new()
    var signal_state: Dictionary = {"count": 0}
    manager.history_changed.connect(func() -> void:
        signal_state["count"] = int(signal_state["count"]) + 1
    )

    var official_win: Dictionary = _make_entry(
        1, "official", "Official rival", true, false, 10, 2
    )
    official_win["flawless"] = true

    var beast_win: Dictionary = _make_entry(
        2, "beast_hunt", "Arena beast", true, false, 20, 3
    )
    beast_win["enemy_kind"] = "beast"

    var underground_win: Dictionary = _make_entry(
        3, "underground", "Hidden rival", true, false, 30, 4
    )
    var loss: Dictionary = _make_entry(
        4, "official", "Winning rival", false, false, 0, -1
    )
    var surrender: Dictionary = _make_entry(
        5, "official", "Overwhelming rival", false, true, 0, -2
    )

    var raw_entries: Array = [
        official_win,
        official_win.duplicate(true),
        {"day": 0, "fighter": "", "enemy": "", "rounds": -1},
        "corrupt history entry",
        _make_entry(99, "official", "Future rival", true, false, 500, 50),
        beast_win,
        underground_win,
        loss,
        surrender
    ]
    for day: int in range(6, 61):
        raw_entries.append(_make_entry(
            day,
            "training",
            "Training rival %d" % day,
            false,
            false,
            0,
            0
        ))

    manager.import_state({
        "entries": raw_entries,
        "current_win_streak": 4,
        "best_win_streak": 7
    }, 60)

    var imported_entries: Array[Dictionary] = manager.get_entries()
    var summary: Dictionary = manager.get_summary()

    assert(imported_entries.size() == 60, "History must be limited to 60 valid entries")
    assert(_count_enemy(imported_entries, "Official rival") == 1, "Duplicates must be removed")
    assert(_count_enemy(imported_entries, "Future rival") == 0, "Future fights must be discarded")
    assert(_all_entries_valid(imported_entries), "Corrupt entries must be removed")
    assert(int(signal_state["count"]) == 1, "Import must emit history_changed exactly once")

    assert(int(summary.get("wins", -1)) == 3, "Wins must be rebuilt")
    assert(int(summary.get("losses", -1)) == 56, "Losses must be rebuilt")
    assert(int(summary.get("surrenders", -1)) == 1, "Surrenders must be rebuilt")
    assert(int(summary.get("rewards", -1)) == 60, "Rewards must be rebuilt")
    assert(int(summary.get("reputation", -1)) == 6, "Reputation must be rebuilt")
    assert(int(summary.get("flawless_wins", -1)) == 1, "Flawless wins must be rebuilt")
    assert(int(summary.get("beast_wins", -1)) == 1, "Beast wins must be rebuilt")
    assert(int(summary.get("official_wins", -1)) == 1, "Official wins must be rebuilt")
    assert(int(summary.get("underground_wins", -1)) == 1, "Underground wins must be rebuilt")
    assert(int(summary.get("current_streak", -1)) == 4, "Current win streak must be preserved")
    assert(int(summary.get("best_streak", -1)) == 7, "Best win streak must be preserved")

    manager.free()
    print("CombatHistoryManager persistence tests passed")
    get_tree().quit(0)

func _make_entry(
    day: int,
    event_type: String,
    enemy: String,
    victory: bool,
    surrendered: bool,
    reward: int,
    reputation: int
) -> Dictionary:
    return {
        "day": day,
        "event_type": event_type,
        "event_name": "Test fight %d" % day,
        "fighter": "Marcus",
        "fighter_id": "gladiator_1",
        "enemy": enemy,
        "enemy_kind": "gladiator",
        "victory": victory,
        "surrendered": surrendered,
        "rounds": 3,
        "reward": reward,
        "reputation": reputation,
        "injury": "",
        "flawless": false
    }

func _count_enemy(history: Array[Dictionary], enemy: String) -> int:
    var count: int = 0
    for entry: Dictionary in history:
        if str(entry.get("enemy", "")) == enemy:
            count += 1
    return count

func _all_entries_valid(history: Array[Dictionary]) -> bool:
    for entry: Dictionary in history:
        if int(entry.get("day", 0)) <= 0:
            return false
        if str(entry.get("fighter", "")).is_empty():
            return false
        if str(entry.get("enemy", "")).is_empty():
            return false
        if int(entry.get("rounds", -1)) < 0:
            return false
    return true
