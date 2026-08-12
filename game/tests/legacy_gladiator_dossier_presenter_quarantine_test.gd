extends Node


func run() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var presenter := FileAccess.get_file_as_string(
		"res://scripts/ui/gladiator_dossier_presenter.gd"
	)
	var personal := FileAccess.get_file_as_string("res://scripts/ui/personal_screen.gd")
	var router := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

	assert(
		project.contains(
			'GladiatorDossierPresenter="*res://scripts/ui/gladiator_dossier_presenter.gd"'
		)
	)
	assert(presenter.contains("Compatibility facade only."))
	assert(presenter.contains("FincaHubController.open_gladiator_dossier(person_id)"))
	assert(presenter.contains('"legacy_node_search_allowed": false'))
	assert(presenter.contains('"legacy_overlay_build_allowed": false'))
	assert(not presenter.contains("ROSTER_LIST_PATH"))
	assert(not presenter.contains("_attach_when_ready"))
	assert(not presenter.contains("No se pudo conectar la ficha del gladiador"))

	assert(personal.contains("FincaHubController.open_gladiator_dossier("))
	assert(router.contains('"gladiator_dossier": "res://scenes/GladiatorDossierPanel.tscn"'))
	assert(router.contains("func open_gladiator_dossier("))
	assert(router.contains('screen.call("open_gladiator"'))

	print("Legacy gladiator dossier presenter compatibility facade: OK")
