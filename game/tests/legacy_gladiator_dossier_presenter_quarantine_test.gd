extends Node


func run() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var personal := FileAccess.get_file_as_string("res://scripts/ui/personal_screen.gd")
	var router := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

	assert(
		not project.contains(
			'GladiatorDossierPresenter="*res://scripts/ui/gladiator_dossier_presenter.gd"'
		)
	)
	assert(personal.contains("FincaHubController.open_gladiator_dossier("))
	assert(
		router.contains('"gladiator_dossier": "res://scenes/GladiatorDossierPanel.tscn"')
	)
	assert(router.contains("func open_gladiator_dossier("))
	assert(router.contains("screen.call(\"open_gladiator\""))

	print("Legacy gladiator dossier presenter quarantine: OK")
