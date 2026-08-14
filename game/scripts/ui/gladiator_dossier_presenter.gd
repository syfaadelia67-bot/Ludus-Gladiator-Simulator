extends Node

## Compatibility facade only.
##
## The canonical gladiator dossier is the hosted `GladiatorDossierPanel.tscn`
## opened through FincaHubController. Older presenters still reference this
## autoload by name, so the global remains available but must never search the
## old Main/Tabs/Personal node tree or build a second dossier overlay.

var overlay: ColorRect = null
var tab_container: TabContainer = null
var selected_person_id := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open_dossier(person_id: String) -> bool:
	var person = RosterManager.get_person(person_id)
	if person == null or str(person.role) != "gladiator":
		return false
	selected_person_id = person_id
	return FincaHubController.open_gladiator_dossier(person_id)


func _close() -> void:
	selected_person_id = ""
	FincaHubController.return_from_gladiator_dossier()


func get_contract() -> Dictionary:
	return {
		"status": "compatibility_facade",
		"canonical_dossier_authority": "FincaHubController_hosted_GladiatorDossierPanel",
		"legacy_node_search_allowed": false,
		"legacy_overlay_build_allowed": false,
	}
