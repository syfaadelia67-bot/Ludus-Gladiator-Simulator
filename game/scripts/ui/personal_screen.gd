extends HSplitContainer

@onready var back_to_finca: Button = $Left/Header/BackToFinca
@onready var roster_list: ItemList = $Left/RosterList
@onready var details: RichTextLabel = $Left/Details
@onready var job_selector: OptionButton = $Left/JobRow/JobSelector
@onready var assign_button: Button = $Left/JobRow/AssignJob
@onready var open_dossier_button: Button = $Left/OpenDossier
@onready var activity_log: RichTextLabel = $Log

var selected_person_id := ""
var job_ids: Array[String] = []

func _ready() -> void:
    back_to_finca.pressed.connect(_return_to_finca)
    roster_list.item_selected.connect(_on_person_selected)
    roster_list.item_activated.connect(_on_person_activated)
    assign_button.pressed.connect(_on_assign_job)
    open_dossier_button.pressed.connect(_open_selected_dossier)
    RosterManager.roster_changed.connect(_refresh_roster)
    GameState.week_advanced.connect(_on_week_advanced)
    GameState.weekly_report.connect(_on_weekly_report)
    _populate_jobs()
    _refresh_roster()

func _unhandled_key_input(event: InputEvent) -> void:
    if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
        _return_to_finca()
        get_viewport().set_input_as_handled()

func restore_context(context: Dictionary) -> void:
    var person_id := str(context.get("selected_id", ""))
    if not person_id.is_empty() and RosterManager.get_person(person_id) != null:
        selected_person_id = person_id
    _refresh_roster()

func _return_to_finca() -> void:
    FincaHubController.show_finca()

func _populate_jobs() -> void:
    job_selector.clear()
    job_ids = RosterManager.get_job_ids()
    for job_id in job_ids:
        job_selector.add_item(RosterManager.get_job_name(job_id))

func _refresh_roster() -> void:
    roster_list.clear()
    var people := RosterManager.get_people()
    for index in range(people.size()):
        var person = people[index]
        roster_list.add_item("%s — %s — %s" % [person.display_name, _role_name(person.role), RosterManager.get_job_name(person.job)])
        roster_list.set_item_metadata(index, person.id)
    if people.is_empty():
        selected_person_id = ""
    elif RosterManager.get_person(selected_person_id) == null:
        selected_person_id = str(people[0].id)
    for index in range(people.size()):
        if str(people[index].id) == selected_person_id:
            roster_list.select(index)
            break
    _refresh_details()

func _on_person_selected(index: int) -> void:
    if index < 0 or index >= roster_list.item_count:
        return
    selected_person_id = str(roster_list.get_item_metadata(index))
    _refresh_details()

func _on_person_activated(index: int) -> void:
    _on_person_selected(index)
    _open_selected_dossier()

func _refresh_details() -> void:
    var person = RosterManager.get_person(selected_person_id)
    if person == null:
        details.text = "Seleccioná un personaje."
        assign_button.disabled = true
        open_dossier_button.disabled = true
        return
    assign_button.disabled = false
    open_dossier_button.disabled = str(person.role) != "gladiator"
    var trait_text := ", ".join(person.traits) if not person.traits.is_empty() else "Ninguno"
    details.text = "[b]%s[/b]\nOrigen: %s | Rol: %s\nFuerza: %d | Agilidad: %d | Resistencia: %d | Inteligencia: %d\nLealtad: %d | Moral: %d | Fatiga: %d\nEntrenamiento: %d/100\nAtaque: %d | Defensa: %d | Vida: %d | Energía: %d\nRasgos: %s" % [person.display_name, person.origin, _role_name(person.role), person.strength, person.agility, person.endurance, person.intelligence, person.loyalty, person.morale, person.fatigue, person.training, person.get_base_attack(), person.get_base_defense(), person.get_max_health(), person.get_max_energy(), trait_text]
    var current_job_index := job_ids.find(str(person.job))
    if current_job_index >= 0:
        job_selector.select(current_job_index)

func _on_assign_job() -> void:
    if selected_person_id.is_empty() or job_selector.selected < 0 or job_selector.selected >= job_ids.size():
        _append_warning("Seleccioná un personaje y un trabajo.")
        return
    var job_id := job_ids[job_selector.selected]
    if RosterManager.assign_job(selected_person_id, job_id):
        var person = RosterManager.get_person(selected_person_id)
        activity_log.append_text("\n%s fue asignado a %s." % [person.display_name, RosterManager.get_job_name(job_id)])

func _open_selected_dossier() -> void:
    var person = RosterManager.get_person(selected_person_id)
    if person == null or str(person.role) != "gladiator":
        _append_warning("Solo los gladiadores tienen ficha individual.")
        return
    FincaHubController.open_gladiator_dossier(selected_person_id, {
        "system_id": "personal",
        "selected_id": selected_person_id,
        "callback": "restore_context"
    })

func _on_week_advanced(week: int) -> void:
    activity_log.append_text("\n\n[b]Semana %d[/b]" % week)

func _on_weekly_report(report: Dictionary) -> void:
    activity_log.append_text("\nMineral producido: %d" % int(report.get("ore", 0)))
    activity_log.append_text("\nSeguridad generada: %d" % int(report.get("security", 0)))
    activity_log.append_text("\nInformación obtenida: %d" % int(report.get("intel", 0)))
    activity_log.append_text("\nEntrenamiento total: %d" % int(report.get("training", 0)))
    for person_name in report.get("promotions", []):
        activity_log.append_text("\n[color=gold]%s completó su formación y ahora es gladiador.[/color]" % str(person_name))

func _append_warning(text: String) -> void:
    activity_log.append_text("\n[color=orange]%s[/color]" % text)

func _role_name(role: String) -> String:
    return "Gladiador" if role == "gladiator" else "Esclavo"
