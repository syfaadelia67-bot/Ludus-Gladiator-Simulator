extends VBoxContainer

@onready var summary: Label = $Header/Summary
@onready var event_title: Label = $EventTitle
@onready var event_text: RichTextLabel = $EventText
@onready var choices: VBoxContainer = $Choices
@onready var effects: RichTextLabel = $Effects
@onready var history: RichTextLabel = $History

func _ready() -> void:
    EventManager.event_started.connect(_refresh)
    EventManager.event_resolved.connect(_on_event_resolved)
    EventManager.events_changed.connect(_refresh)
    EventManager.effect_expired.connect(_on_effect_expired)
    GameState.week_advanced.connect(_on_week_advanced)
    _refresh()

func _refresh(_unused = null) -> void:
    _refresh_pending_event()
    _refresh_effects()
    _refresh_history()

func _refresh_pending_event() -> void:
    for child in choices.get_children():
        child.free()
    var event := EventManager.get_pending_event()
    if event.is_empty():
        event_title.text = "Semana %d · Sin decisiones pendientes" % GameState.get_week()
        event_text.text = "El próximo acontecimiento principal aparecerá al cerrar la semana."
        return

    var chapter := CampaignManager.get_chapter_for_week(int(event.get("week", GameState.get_week())))
    event_title.text = "Semana %d · %s" % [int(event.get("week", GameState.get_week())), str(event.get("title", "Evento"))]
    event_text.text = "[color=gray]%s[/color]\n\n%s" % [str(chapter.get("title", "Campaña")), str(event.get("text", ""))]

    for choice in event.get("choices", []):
        if not choice is Dictionary:
            continue
        var choice_id := str(choice.get("id", ""))
        var unmet := EventManager.get_unmet_requirements(choice)
        var row := VBoxContainer.new()
        row.name = "Choice_%s" % choice_id

        var button := Button.new()
        button.text = str(choice.get("label", choice_id))
        button.disabled = not unmet.is_empty()
        button.tooltip_text = unmet if not unmet.is_empty() else "Aplicar esta decisión"
        button.pressed.connect(_on_choice_pressed.bind(choice_id))
        row.add_child(button)

        var consequence := Label.new()
        consequence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        consequence.text = ("Requisito: %s" % unmet) if not unmet.is_empty() else _describe_effects(choice.get("effects", {}))
        consequence.modulate = Color(0.75, 0.75, 0.75) if unmet.is_empty() else Color(1.0, 0.72, 0.38)
        row.add_child(consequence)
        choices.add_child(row)

func _refresh_effects() -> void:
    var active := EventManager.get_active_effects()
    summary.text = "Semana %d · %d efecto(s) activo(s)" % [GameState.get_week(), active.size()]
    if active.is_empty():
        effects.text = "Ninguno"
        return
    var lines: Array[String] = []
    for effect in active:
        lines.append("• [b]%s[/b] — %d semana(s) restante(s)" % [effect.get("name", "Efecto"), int(effect.get("weeks", 0))])
    effects.text = "\n".join(lines)

func _refresh_history() -> void:
    var event_history := EventManager.get_history()
    if event_history.is_empty():
        history.text = "Todavía no se tomaron decisiones."
        return
    var lines: Array[String] = []
    var start := maxi(0, event_history.size() - 8)
    for index in range(event_history.size() - 1, start - 1, -1):
        var entry: Dictionary = event_history[index]
        lines.append("[b]Semana %d · %s[/b]\n%s\n%s" % [int(entry.get("week", 1)), entry.get("title", "Evento"), entry.get("choice_label", "Decisión"), entry.get("result", "")])
    history.text = "\n\n".join(lines)

func _on_choice_pressed(choice_id: String) -> void:
    var result := EventManager.resolve_choice(choice_id)
    if not bool(result.get("success", false)):
        event_text.text = "[color=orange]%s[/color]" % result.get("reason", "No se pudo aplicar la decisión.")
        return
    _refresh()

func _on_event_resolved(result: Dictionary) -> void:
    event_title.text = "Semana %d · %s" % [int(result.get("week", GameState.get_week())), str(result.get("title", "Evento resuelto"))]
    event_text.text = "[color=gold]%s[/color]" % result.get("result", "La decisión fue aplicada.")

func _on_effect_expired(effect: Dictionary) -> void:
    event_text.append_text("\n[color=gray]Terminó el efecto: %s.[/color]" % effect.get("name", "Efecto"))

func _on_week_advanced(_week: int) -> void:
    _refresh()

func _describe_effects(effect_data: Dictionary) -> String:
    var names := {
        "denarii":"Denarios", "food":"Comida", "ore":"Mineral", "reputation":"Reputación",
        "intelligence":"Inteligencia", "security":"Seguridad", "morale_all":"Moral de todos",
        "loyalty_all":"Lealtad de todos", "training_all":"Entrenamiento de todos"
    }
    var descriptions: Array[String] = []
    for key in names.keys():
        var value := int(effect_data.get(key, 0))
        if value != 0:
            descriptions.append("%s: %+d" % [names[key], value])
    var timed = effect_data.get("timed", {})
    if timed is Dictionary and not timed.is_empty():
        descriptions.append("Efecto temporal: %s (%d semana(s))" % [timed.get("name", "Efecto"), int(timed.get("weeks", 0))])
    return "Consecuencias: %s" % ", ".join(descriptions) if not descriptions.is_empty() else "Sin costo ni efecto directo"
