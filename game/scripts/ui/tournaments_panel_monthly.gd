extends "res://scripts/ui/tournaments_panel.gd"

var _second_fighter_selector: OptionButton
var _second_fighter_label: Label


func _ready() -> void:
	super._ready()
	_install_team_selector()
	_refresh_all()


func _install_team_selector() -> void:
	if _second_fighter_selector != null:
		return
	_second_fighter_label = Label.new()
	_second_fighter_label.text = "Segundo gladiador (2v2)"
	_second_fighter_selector = OptionButton.new()
	_second_fighter_selector.name = "SecondFighterSelector"
	var parent := fighter_selector.get_parent()
	parent.add_child(_second_fighter_label)
	parent.add_child(_second_fighter_selector)
	var fighter_index := fighter_selector.get_index()
	parent.move_child(_second_fighter_label, fighter_index + 1)
	parent.move_child(_second_fighter_selector, fighter_index + 2)
	_second_fighter_selector.item_selected.connect(func(_index: int): _refresh_details())
	_refresh_second_fighter_selector()


func _refresh_fighters() -> void:
	super._refresh_fighters()
	_refresh_second_fighter_selector()


func _refresh_second_fighter_selector() -> void:
	if _second_fighter_selector == null or not is_instance_valid(_second_fighter_selector):
		return
	var previous_id := ""
	if (
		_second_fighter_selector.selected >= 0
		and _second_fighter_selector.selected < fighter_ids.size()
	):
		previous_id = fighter_ids[_second_fighter_selector.selected]
	_second_fighter_selector.clear()
	for fighter_id in fighter_ids:
		var person = RosterManager.get_person(fighter_id)
		var label := fighter_id if person == null else str(person.display_name)
		_second_fighter_selector.add_item(label)
	if fighter_ids.is_empty():
		return
	var selected_index := fighter_ids.find(previous_id)
	if selected_index < 0:
		selected_index = 1 if fighter_ids.size() > 1 else 0
	_second_fighter_selector.select(selected_index)


func _refresh_details() -> void:
	super._refresh_details()
	if _second_fighter_selector == null or not is_instance_valid(_second_fighter_selector):
		return
	var selected := _selected_event()
	var requires_team := bool(selected.get("requires_team_selection", false))
	_second_fighter_label.visible = requires_team
	_second_fighter_selector.visible = requires_team
	if not requires_team:
		return
	accept_button.disabled = fighter_ids.size() < 2 or selected_event_id.is_empty()
	if fighter_ids.size() < 2:
		details.text += "\n[color=orange]El 2v2 requiere dos gladiadores disponibles.[/color]"


func _on_accept() -> void:
	var selected := _selected_event()
	if not bool(selected.get("requires_team_selection", false)):
		super._on_accept()
		return
	if fighter_selector.selected < 0 or fighter_selector.selected >= fighter_ids.size():
		status.text = "Seleccioná el primer gladiador."
		return
	if (
		_second_fighter_selector == null
		or _second_fighter_selector.selected < 0
		or _second_fighter_selector.selected >= fighter_ids.size()
	):
		status.text = "Seleccioná el segundo gladiador."
		return
	var first_id := fighter_ids[fighter_selector.selected]
	var second_id := fighter_ids[_second_fighter_selector.selected]
	if first_id == second_id:
		status.text = "El 2v2 requiere dos gladiadores distintos."
		return
	TournamentManager.accept_event_team(selected_event_id, [first_id, second_id])


func _selected_event() -> Dictionary:
	for raw_event in TournamentManager.get_available_events():
		if not raw_event is Dictionary:
			continue
		var event := raw_event as Dictionary
		if str(event.get("id", "")) == selected_event_id:
			return event
	return {}


func get_ui_contract() -> Dictionary:
	return {
		"status": "frozen",
		"period": "month",
		"competition_source": "TournamentManager canonical monthly schedule",
		"single_fighter_formats": ["1v1", "1v2"],
		"team_format": "2v2",
		"team_selection": "two_distinct_available_gladiators",
		"accept_team_authority": "TournamentManager.accept_event_team",
		"save_version_change_required": false,
	}
