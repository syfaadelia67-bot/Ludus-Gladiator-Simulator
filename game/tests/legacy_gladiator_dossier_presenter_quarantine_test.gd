extends Node


func run() -> void:
	var facade := get_node_or_null("/root/GladiatorDossierPresenter")
	var presenter := FileAccess.get_file_as_string(
		"res://scripts/ui/gladiator_dossier_presenter.gd"
	)
	var personal := FileAccess.get_file_as_string("res://scripts/ui/personal_screen.gd")
	var router := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

	assert(facade != null, "GladiatorDossierPresenter compatibility facade must be autoloaded")
	assert(facade.has_method("open_dossier"))
	assert(facade.has_method("get_contract"))
	assert(not facade.has_method("_attach_when_ready"))
	var contract := facade.get_contract() as Dictionary
	assert(contract.get("status") == "compatibility_facade")
	assert(
		contract.get("canonical_dossier_authority")
		== "FincaHubController_hosted_GladiatorDossierPanel"
	)
	assert(contract.get("legacy_node_search_allowed") == false)
	assert(contract.get("legacy_overlay_build_allowed") == false)

	assert(presenter.contains("Compatibility facade only."))
	assert(presenter.contains("FincaHubController.open_gladiator_dossier(person_id)"))
	assert(not presenter.contains("ROSTER_LIST_PATH"))
	assert(not presenter.contains("_attach_when_ready"))
	assert(not presenter.contains("No se pudo conectar la ficha del gladiador"))

	assert(personal.contains("FincaHubController.open_gladiator_dossier("))
	assert(router.contains('"gladiator_dossier": "res://scenes/GladiatorDossierPanel.tscn"'))
	assert(router.contains("func open_gladiator_dossier("))
	assert(router.contains('screen.call("open_gladiator"'))

	print("Gladiator dossier compatibility facade runtime: OK")
