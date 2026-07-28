extends Control

@onready var resources_label: Label = $Margin/VBox/Resources
@onready var advance_button: Button = $Margin/VBox/AdvanceDay
@onready var roster_list: ItemList = $Margin/VBox/Columns/RosterPanel/RosterList
@onready var details: RichTextLabel = $Margin/VBox/Columns/RosterPanel/Details
@onready var job_selector: OptionButton = $Margin/VBox/Columns/RosterPanel/JobRow/JobSelector
@onready var assign_button: Button = $Margin/VBox/Columns/RosterPanel/AssignJob
@onready var log: RichTextLabel = $Margin/VBox/Columns/LogPanel/Log

var selected_person_id: String = ""
var job_ids: Array[String] = []

func _ready() -> void:
    advance_button.pressed.connect(_on_advance_day)
    roster_list.item_selected.connect(_on_person_selected)
    assign_button.pressed.connect(_on_assign_job)
    GameState.resources_changed.connect(_refresh_resources)
    GameState.day_advanced.connect(_on_day_advanced)
    GameState.daily_report.connect(_on_daily_report)
    RosterManager.roster_changed.connect(_refresh_roster)
    _populate_jobs()
    _refresh_resources()
    _refresh_roster()

func _populate_jobs() -> void:
    job_selector.clear()
    job_ids = RosterManager.get_job_ids()
    for job_id in job_ids:
        job_selector.add_item(RosterManager.get_job_name(job_id))

func _on_advance_day() -> void:
    GameState.advance_day()

func _on_person_selected(index: int) -> void:
    selected_person_id = str(roster_list.get_item_metadata(index))
    _refresh_details()

func _on_assign_job() -> void:
    if selected_person_id.is_empty() or job_selector.selected < 0:
        log.append_text("\n[color=orange]Seleccioná un personaje y un trabajo.[/color]")
        return
    var job_id := job_ids[job_selector.selected]
    if RosterManager.assign_job(selected_person_id, job_id):
        var person = RosterManager.get_person(selected_person_id)
        log.append_text("\n%s fue asignado a %s." % [person.display_name, RosterManager.get_job_name(job_id)])
        _refresh_details()

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

func _refresh_resources() -> void:
    resources_label.text = GameState.get_resource_summary()

func _refresh_roster() -> void:
    roster_list.clear()
    var selected_index := -1
    var people := RosterManager.get_people()
    for index in range(people.size()):
        var person = people[index]
        var label := "%s — %s — %s" % [
            person.display_name,
            _role_name(person.role),
            RosterManager.get_job_name(person.job)
        ]
        roster_list.add_item(label)
        roster_list.set_item_metadata(index, person.id)
        if person.id == selected_person_id:
            selected_index = index
    if selected_index >= 0:
        roster_list.select(selected_index)
    elif not people.is_empty():
        selected_person_id = people[0].id
        roster_list.select(0)
    _refresh_details()

func _refresh_details() -> void:
    var person = RosterManager.get_person(selected_person_id)
    if person == null:
        details.text = "Seleccioná un personaje."
        assign_button.disabled = true
        return
    assign_button.disabled = false
    var trait_text := ", ".join(person.traits) if not person.traits.is_empty() else "Ninguno"
    details.text = "[b]%s[/b]\nOrigen: %s | Rol: %s\nFuerza: %d | Agilidad: %d | Resistencia: %d | Inteligencia: %d\nLealtad: %d | Moral: %d | Fatiga: %d\nEntrenamiento: %d/100\nRasgos: %s" % [
        person.display_name,
        person.origin,
        _role_name(person.role),
        person.strength,
        person.agility,
        person.endurance,
        person.intelligence,
        person.loyalty,
        person.morale,
        person.fatigue,
        person.training,
        trait_text
    ]
    var current_job_index := job_ids.find(person.job)
    if current_job_index >= 0:
        job_selector.select(current_job_index)

func _role_name(role_id: String) -> String:
    match role_id:
        "slave":
            return "Esclavo"
        "gladiator":
            return "Gladiador"
        _:
            return role_id.capitalize()
