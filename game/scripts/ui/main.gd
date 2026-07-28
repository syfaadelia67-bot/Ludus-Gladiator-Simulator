extends Control

@onready var resources_label: Label = $Margin/VBox/Resources
@onready var advance_button: Button = $Margin/VBox/AdvanceDay
@onready var roster: RichTextLabel = $Margin/VBox/Columns/RosterPanel/Roster
@onready var log: RichTextLabel = $Margin/VBox/Columns/LogPanel/Log

func _ready() -> void:
    advance_button.pressed.connect(_on_advance_day)
    GameState.resources_changed.connect(_refresh)
    GameState.day_advanced.connect(_on_day_advanced)
    GameState.daily_report.connect(_on_daily_report)
    RosterManager.roster_changed.connect(_refresh_roster)
    _refresh()
    _refresh_roster()

func _on_advance_day() -> void:
    GameState.advance_day()

func _on_day_advanced(day: int) -> void:
    log.append_text("\n\n[b]Día %d[/b]" % day)

func _on_daily_report(report: Dictionary) -> void:
    log.append_text("\nMineral producido: %d" % int(report.get("ore", 0)))
    log.append_text("\nSeguridad generada: %d" % int(report.get("security", 0)))
    log.append_text("\nInformación obtenida: %d" % int(report.get("intel", 0)))
    log.append_text("\nEntrenamiento total: %d" % int(report.get("training", 0)))
    var promotions: Array = report.get("promotions", [])
    for person_name in promotions:
        log.append_text("\n[color=gold]%s completó su formación y ahora es gladiador.[/color]" % person_name)

func _refresh() -> void:
    resources_label.text = GameState.get_resource_summary()

func _refresh_roster() -> void:
    roster.text = RosterManager.get_roster_summary()
