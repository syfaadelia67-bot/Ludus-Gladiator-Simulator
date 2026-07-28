extends VBoxContainer

@onready var summary_label: RichTextLabel = $Summary
@onready var history_list: ItemList = $HistoryList
@onready var details_label: RichTextLabel = $Details

var visible_entries: Array[Dictionary] = []

func _ready() -> void:
    history_list.item_selected.connect(_on_entry_selected)
    CombatHistoryManager.history_changed.connect(refresh)
    refresh()

func refresh() -> void:
    var summary: Dictionary = CombatHistoryManager.get_summary()
    summary_label.text = "[b]RESUMEN DE LA ARENA[/b]\nCombates: %d | Victorias: %d | Derrotas: %d | Rendiciones: %d | Efectividad: %.1f%%\nPremios acumulados: %d denarios | Reputación obtenida: %+d" % [
        int(summary.get("total", 0)),
        int(summary.get("wins", 0)),
        int(summary.get("losses", 0)),
        int(summary.get("surrenders", 0)),
        float(summary.get("win_rate", 0.0)),
        int(summary.get("rewards", 0)),
        int(summary.get("reputation", 0))
    ]
    visible_entries = CombatHistoryManager.get_entries()
    history_list.clear()
    for entry in visible_entries:
        var result_text: String = "Victoria" if bool(entry.get("victory", false)) else ("Rendición" if bool(entry.get("surrendered", false)) else "Derrota")
        history_list.add_item("Día %d · %s · %s contra %s · %s" % [
            int(entry.get("day", 0)),
            str(entry.get("event_name", "Combate")),
            str(entry.get("fighter", "Gladiador")),
            str(entry.get("enemy", "Rival")),
            result_text
        ])
    if visible_entries.is_empty():
        details_label.text = "Todavía no hay combates registrados."
    else:
        history_list.select(0)
        _show_entry(0)

func _on_entry_selected(index: int) -> void:
    _show_entry(index)

func _show_entry(index: int) -> void:
    if index < 0 or index >= visible_entries.size():
        return
    var entry: Dictionary = visible_entries[index]
    var status: String = "VICTORIA" if bool(entry.get("victory", false)) else ("RENDICIÓN" if bool(entry.get("surrendered", false)) else "DERROTA")
    var max_health: int = maxi(1, int(entry.get("player_max_health", 1)))
    var health_percent: float = float(int(entry.get("player_health", 0))) / float(max_health) * 100.0
    var injury: String = str(entry.get("injury", ""))
    var lines: Array[String] = [
        "[b]%s — %s[/b]" % [entry.get("event_name", "Combate"), status],
        "Día %d | %s contra %s" % [int(entry.get("day", 0)), entry.get("fighter", "Gladiador"), entry.get("enemy", "Rival")],
        "Rondas: %d | Vida restante: %.0f%%" % [int(entry.get("rounds", 0)), health_percent],
        "Premio: %d denarios | Reputación: %+d" % [int(entry.get("reward", 0)), int(entry.get("reputation", 0))],
        "Herida: %s" % (injury if not injury.is_empty() else "Ninguna")
    ]
    var technique_stats: Dictionary = entry.get("technique_stats", {})
    if not technique_stats.is_empty():
        lines.append("[b]Técnicas[/b]")
        for value in technique_stats.values():
            var technique: Dictionary = value
            lines.append("• %s: %d uso(s), %d daño" % [technique.get("name", "Técnica"), int(technique.get("uses", 0)), int(technique.get("damage", 0))])
    details_label.text = "\n".join(lines)
