extends VBoxContainer

@onready var back_button: Button = $Navigation/BackToFinca
@onready var scroll: ScrollContainer = $Scroll
@onready var rank_label: Label = $Scroll/Content/Rank
@onready var next_rank_label: RichTextLabel = $Scroll/Content/NextRank
@onready var ending: RichTextLabel = $Scroll/Content/Ending
@onready var objectives_list: VBoxContainer = $Scroll/Content/ObjectivesList

func _ready() -> void:
    back_button.pressed.connect(_return_to_finca)
    CampaignManager.campaign_changed.connect(_refresh)
    CampaignManager.rank_promoted.connect(_on_rank_promoted)
    CampaignManager.objective_completed.connect(_on_objective_completed)
    CampaignManager.campaign_finished.connect(_on_campaign_finished)
    _refresh()

func _unhandled_key_input(event: InputEvent) -> void:
    if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
        _return_to_finca()
        get_viewport().set_input_as_handled()

func _return_to_finca() -> void:
    FincaHubController.show_finca()

func _refresh() -> void:
    var summary: Dictionary = CampaignManager.get_summary()
    var rank: Dictionary = summary.get("rank", {})
    var next_rank: Dictionary = summary.get("next_rank", {})

    rank_label.text = "%s — Victorias %d | Derrotas %d" % [
        rank.get("name", "Ludus desconocido"),
        int(summary.get("wins", 0)),
        int(summary.get("losses", 0))
    ]

    if next_rank.is_empty():
        next_rank_label.text = "[b]Rango máximo alcanzado[/b]\nEl ludus ya obtuvo el mayor rango disponible."
    else:
        next_rank_label.text = "[b]Próximo rango: %s[/b]\nRequiere %d reputación, %d victorias y %d denarios.\nDesbloqueo: %s" % [
            next_rank.get("name", "Rango"),
            int(next_rank.get("reputation", 0)),
            int(next_rank.get("wins", 0)),
            int(next_rank.get("wealth", 0)),
            next_rank.get("unlock", "Contenido")
        ]

    if bool(summary.get("campaign_over", false)):
        ending.text = "[b]%s[/b]\n%s" % [
            "CAMPAÑA COMPLETADA" if bool(summary.get("victory", false)) else "CAMPAÑA PERDIDA",
            summary.get("defeat_reason", "El ludus aseguró su legado imperial.")
        ]
    else:
        ending.text = "[b]META FINAL[/b]\n70 de reputación, 25 victorias y rango Ludus imperial."

    _rebuild_objectives()

func _rebuild_objectives() -> void:
    for child in objectives_list.get_children():
        child.free()

    var campaign_objectives: Array = CampaignManager.get_objectives()
    if campaign_objectives.is_empty():
        var empty_label := Label.new()
        empty_label.text = "No hay objetivos de campaña disponibles."
        empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        objectives_list.add_child(empty_label)
        return

    for objective_value in campaign_objectives:
        if not objective_value is Dictionary:
            continue
        _add_objective_card(objective_value as Dictionary)

func _add_objective_card(objective: Dictionary) -> void:
    var card := PanelContainer.new()
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    objectives_list.add_child(card)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_bottom", 10)
    card.add_child(margin)

    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 5)
    margin.add_child(content)

    var completed := bool(objective.get("completed", false))
    var mark := "✓" if completed else "•"

    var title := Label.new()
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title.text = "%s %s" % [mark, objective.get("title", "Objetivo")]
    title.add_theme_font_size_override("font_size", 18)
    content.add_child(title)

    var progress := Label.new()
    progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    progress.text = "Progreso: %d/%d" % [
        int(objective.get("progress", 0)),
        int(objective.get("target", 1))
    ]
    content.add_child(progress)

    var description := Label.new()
    description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.text = str(objective.get("description", ""))
    content.add_child(description)

    var reward := Label.new()
    reward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    reward.text = "Recompensa: %d denarios y %d reputación" % [
        int(objective.get("reward_denarii", 0)),
        int(objective.get("reward_reputation", 0))
    ]
    content.add_child(reward)

func _on_rank_promoted(_rank_id: String) -> void:
    _refresh()
    call_deferred("_scroll_to_top")

func _on_objective_completed(_objective: Dictionary) -> void:
    _refresh()

func _on_campaign_finished(_victory: bool, _reason: String) -> void:
    _refresh()
    call_deferred("_scroll_to_top")

func _scroll_to_top() -> void:
    if scroll != null and is_instance_valid(scroll):
        scroll.scroll_vertical = 0
