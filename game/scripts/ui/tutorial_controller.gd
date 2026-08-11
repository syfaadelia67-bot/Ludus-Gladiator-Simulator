extends Node

const MonthlyOnboardingPolicyScript = preload("res://scripts/systems/monthly_onboarding_policy.gd")

var panel: PanelContainer
var title_label: Label
var body_label: Label
var objective_label: Label
var progress_label: Label
var action_button: Button
var current_step := 0
var completed_objectives: Dictionary = {}
var modal_suspended := false
var _onboarding_policy = MonthlyOnboardingPolicyScript.new()
var _steps: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_steps = _onboarding_policy.get_steps()
	LudusOwnerManager.owner_configured.connect(
		func(_profile: Dictionary): call_deferred("_show_if_needed")
	)
	SaveManager.load_completed.connect(func(_path: String): call_deferred("_show_if_needed"))
	UniqueGladiatorManager.first_gladiator_acquired.connect(
		func(_gladiator_id: String): _mark_objective("initial_gladiator")
	)
	GameState.month_advanced.connect(func(_month: int): _mark_objective("close_month"))
	RosterManager.job_assignment_changed.connect(
		func(_person_id: String, _job_id: String): _mark_objective("assign_work")
	)
	FincaHubController.system_opened.connect(_on_system_opened)
	call_deferred("_show_if_needed")


func suspend_for_modal() -> void:
	modal_suspended = true
	_hide_panel()


func resume_after_modal() -> void:
	modal_suspended = false
	call_deferred("_show_if_needed")


func _show_if_needed() -> void:
	if modal_suspended:
		_hide_panel()
		return
	if not LudusOwnerManager.should_show_tutorial():
		_hide_panel()
		return
	var scene := get_tree().current_scene
	if scene == null or scene.name != "Main":
		return
	_restore_progress()
	_sync_world_objectives()
	if not UniqueGladiatorManager.first_purchase_completed:
		_hide_panel()
		FincaHubController.open_system("mercado")
		return
	if panel == null or not is_instance_valid(panel):
		_build_panel(scene)
	panel.visible = true
	_render_step()


func _restore_progress() -> void:
	var progress: Dictionary = LudusOwnerManager.get_tutorial_progress()
	current_step = clampi(int(progress.get("current_step", 0)), 0, _steps.size() - 1)
	var loaded_objectives: Variant = progress.get("completed_objectives", {})
	completed_objectives = (
		loaded_objectives.duplicate(true) if loaded_objectives is Dictionary else {}
	)


func _sync_world_objectives() -> void:
	if UniqueGladiatorManager.first_purchase_completed:
		_mark_objective("initial_gladiator")


func _persist_progress() -> void:
	LudusOwnerManager.update_tutorial_progress(current_step, completed_objectives)


func _build_panel(scene: Node) -> void:
	panel = PanelContainer.new()
	panel.name = "CampaignTutorial"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-434, 18)
	panel.size = Vector2(410, 330)
	panel.custom_minimum_size = Vector2(410, 330)
	panel.z_index = 80
	scene.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.add_child(progress_label)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 21)
	content.add_child(title_label)

	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body_label)

	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(objective_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(actions)

	var skip_button := Button.new()
	skip_button.text = "Saltar tutorial"
	skip_button.pressed.connect(_complete_tutorial)
	actions.add_child(skip_button)

	action_button = Button.new()
	action_button.name = "ObjectiveAction"
	action_button.pressed.connect(_on_action_pressed)
	actions.add_child(action_button)


func _render_step() -> void:
	if modal_suspended or _steps.is_empty():
		return
	var step: Dictionary = _steps[current_step]
	var objective_id := str(step.get("id", ""))
	var completed := bool(completed_objectives.get(objective_id, false))
	progress_label.text = "%d/%d" % [current_step + 1, _steps.size()]
	title_label.text = str(step.get("title", "Tutorial"))
	body_label.text = str(step.get("text", ""))
	objective_label.text = ("✓ " if completed else "Objetivo: ") + str(step.get("objective", ""))
	if objective_id == "close_month" and not completed:
		_append_month_closure_status()

	if completed:
		action_button.text = "Finalizar" if current_step == _steps.size() - 1 else "Continuar"
		action_button.disabled = false
		return

	var action := str(step.get("action", ""))
	action_button.text = str(step.get("action_label", "Continuar"))
	match action:
		"open_system", "acknowledge":
			action_button.disabled = false
		"wait_for_month_close":
			action_button.disabled = true
		_:
			action_button.disabled = true


func _append_month_closure_status() -> void:
	var closure := GameState.get_month_closure_status()
	if bool(closure.get("can_close", false)):
		objective_label.text += "\nEstado actual: el mes puede cerrarse."
		return
	var messages: Array = closure.get("messages", [])
	if messages.is_empty():
		return
	var blocker_lines: Array[String] = []
	for raw_message in messages:
		blocker_lines.append(str(raw_message))
	objective_label.text += "\nBloqueo actual: %s" % " · ".join(blocker_lines)


func _on_system_opened(system_id: String) -> void:
	match system_id:
		"barracks":
			_mark_objective("inspect_roster")
		"finca":
			_mark_objective("inspect_finca")
		"equipamiento":
			_mark_objective("inspect_equipment")


func _on_action_pressed() -> void:
	if _steps.is_empty():
		return
	var step: Dictionary = _steps[current_step]
	var objective_id := str(step.get("id", ""))
	var completed := bool(completed_objectives.get(objective_id, false))
	if completed:
		_advance_tutorial()
		return

	match str(step.get("action", "")):
		"open_system":
			FincaHubController.open_system(str(step.get("system", "")))
		"acknowledge":
			_mark_objective(objective_id)
			_advance_tutorial()


func _advance_tutorial() -> void:
	if current_step >= _steps.size() - 1:
		_complete_tutorial()
		return
	current_step += 1
	_persist_progress()
	_render_step()


func _mark_objective(objective_id: String) -> void:
	if objective_id.is_empty() or bool(completed_objectives.get(objective_id, false)):
		return
	completed_objectives[objective_id] = true
	_persist_progress()
	if (
		not modal_suspended
		and panel != null
		and is_instance_valid(panel)
		and current_step < _steps.size()
	):
		_render_step()


func _complete_tutorial() -> void:
	LudusOwnerManager.mark_tutorial_completed()
	SaveManager.save_game()
	_hide_panel()


func _hide_panel() -> void:
	if panel != null and is_instance_valid(panel):
		panel.visible = false
