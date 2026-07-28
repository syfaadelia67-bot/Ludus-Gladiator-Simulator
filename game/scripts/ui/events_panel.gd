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
    _refresh()

func _refresh(_unused = null) -> void:
    _refresh_pending_event()
    _refresh_effects()
    _refresh_history()

func _refresh_pending_event() -> void:
    for child in choices.get_children():
        child.queue_free()
    var event := EventManager.get_pending_event()
    if event.is_empty():
        event_title.text = "No hay decisiones pendientes"
        event_text.text = "Los acontecimientos aparecerán al avanzar los días."
        return
    event_title.text = str(event.get("title", "Evento"))
    event_text.text = str(event.get("text", ""))
    for choice in event.get("choices", []):
        var button := Button.new()
        var choice_id := str(choice.get("id", ""))
        var unmet := EventManager.get_unmet_requirements(choice)
        button.text = str(choice.get("label", choice_id))
        button.disabled = not unmet.is_empty()
        button.tooltip_text = unmet if not unmet.is_empty() else _describe_effects(choice.get("effects", {}))
        button.pressed.connect(_on_choice_pressed.bind(choice_id))
        choices.add_child(button)

func _refresh_effects() -> void:
    var active := EventManager.get_active_effects()
    summary.text = "%d efecto(s) activo(s)" % active.size()
    if active.is_empty():
        effects.text = "Ninguno"
        return
    var lines: Array[String] = []
    for effect in active:
        lines.append("• [b]%s[/b] — %d día(s)" % [effect.get("name", "Efecto"), int(effect.get("days", 0))])
    effects.text = "\n".join(lines)

func _refresh_history() -> void:
    if EventManager.history.is_empty():
        history.text = "Todavía no se tomaron decisiones."
        return
    var lines: Array[String] = []
    var start := maxi(0, EventManager.history.size() - 8)
    for index in range(EventManager.history.size() - 1, start - 1, -1):
        var entry: Dictionary = EventManager.history[index]
        lines.append("[b]Día %d · %s[/b]\n%s\n%s" % [int(entry.get("day", 0)), entry.get("title", "Evento"), entry.get("choice_label", "Decisión"), entry.get("result", "")])
    history.text = "\n\n".join(lines)

func _on_choice_pressed(choice_id: String) -> void:
    var result := EventManager.resolve_choice(choice_id)
    if not bool(result.get("success", false)):
        event_text.text = "[color=orange]%s[/color]" % result.get("reason", "No se pudo aplicar la decisión.")
    _refresh()

func _on_event_resolved(result: Dictionary) -> void:
    event_title.text = str(result.get("title", "Evento resuelto"))
    event_text.text = "[color=gold]%s[/color]" % result.get("result", "La decisión fue aplicada.")

func _on_effect_expired(effect: Dictionary) -> void:
    event_text.append_text("\n[color=gray]Terminó el efecto: %s.[/color]" % effect.get("name", "Efecto"))

func _describe_effects(effect_data: Dictionary) -> String:
    var descriptions: Array[String] = []
    for key in ["denarii", "food", "ore", "reputation", "intelligence", "morale_all", "loyalty_all", "training_all"]:
        var value := int(effect_data.get(key, 0))
        if value != 0:
            descriptions.append("%s: %+d" % [key.capitalize(), value])
    var timed = effect_data.get("timed", {})
    if timed is Dictionary and not timed.is_empty():
        descriptions.append("Efecto temporal: %s (%d días)" % [timed.get("name", "Efecto"), int(timed.get("days", 0))])
    return "\n".join(descriptions) if not descriptions.is_empty() else "Sin costo ni efecto directo"
