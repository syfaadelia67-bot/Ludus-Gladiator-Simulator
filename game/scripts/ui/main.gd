extends Control

@onready var resources_label: Label = $Margin/VBox/Resources
@onready var advance_button: Button = $Margin/VBox/AdvanceDay
@onready var log: RichTextLabel = $Margin/VBox/Log

func _ready() -> void:
    advance_button.pressed.connect(_on_advance_day)
    GameState.resources_changed.connect(_refresh)
    GameState.day_advanced.connect(_on_day_advanced)
    _refresh()

func _on_advance_day() -> void:
    GameState.advance_day()

func _on_day_advanced(day: int) -> void:
    log.append_text("\nDía %d: se completaron las tareas de la finca." % day)

func _refresh() -> void:
    resources_label.text = GameState.get_resource_summary()
