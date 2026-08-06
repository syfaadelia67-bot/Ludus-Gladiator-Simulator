extends Control

@onready var resources_label: Label = $Margin/VBox/Resources
@onready var advance_button: Button = $Margin/VBox/TopButtons/AdvanceDay
@onready var refresh_market_button: Button = $Margin/VBox/TopButtons/RefreshMarket
@onready var capacity_label: Label = $Margin/VBox/TopButtons/Capacity

func _ready() -> void:
    advance_button.pressed.connect(_on_advance_week)
    refresh_market_button.visible = false
    refresh_market_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    GameState.resources_changed.connect(_refresh_resources)
    RosterManager.roster_changed.connect(_refresh_resources)
    _refresh_resources()

func _on_advance_week() -> void:
    GameState.advance_week()

func _refresh_resources() -> void:
    resources_label.text = GameState.get_resource_summary()
    capacity_label.text = "Capacidad: %s" % RosterManager.get_capacity_summary()
