extends Node

const CANONICAL_FIELDS: Array[String] = [
	"name",
	"type",
	"slot",
	"forge_level",
	"ore",
	"denarii",
	"power",
	"defense",
	"tags",
]


func _ready() -> void:
	DataRepository.load_all()
	EquipmentManager.RECIPES.clear()

	var data_ids: Array[String] = []
	var available_tags: Array[String] = []
	for raw_entry in DataRepository.weapons:
		assert(raw_entry is Dictionary, "Equipment catalog entries must be dictionaries")
		var entry := raw_entry as Dictionary
		var equipment_id := str(entry.get("id", ""))
		assert(not equipment_id.is_empty(), "Equipment entries must have ids")
		data_ids.append(equipment_id)
		assert(not str(entry.get("name", "")).is_empty(), "%s must have a name" % equipment_id)
		assert(not str(entry.get("type", "")).is_empty(), "%s must have a type" % equipment_id)
		assert(
			not EquipmentManager.canonical_slot_id(str(entry.get("slot", ""))).is_empty(),
			"%s must use a valid equipment slot" % equipment_id
		)
		assert(
			int(entry.get("forge_level", 0)) >= 1, "%s must require a forge level" % equipment_id
		)
		assert(
			int(entry.get("ore", -1)) >= 0, "%s must have a non-negative ore cost" % equipment_id
		)
		assert(
			int(entry.get("denarii", -1)) >= 0,
			"%s must have a non-negative denarii cost" % equipment_id
		)
		assert(int(entry.get("power", -1)) >= 0, "%s must define non-negative power" % equipment_id)
		assert(
			int(entry.get("defense", -1)) >= 0, "%s must define non-negative defense" % equipment_id
		)
		assert(entry.get("tags", null) is Array, "%s must define equipment tags" % equipment_id)
		for raw_tag in entry.get("tags", []):
			var tag := str(raw_tag)
			if not tag.is_empty() and not available_tags.has(tag):
				available_tags.append(tag)

	data_ids.sort()
	var manager_ids := EquipmentManager.get_recipe_ids()
	assert(
		manager_ids == data_ids,
		"EquipmentManager recipe ids must be derived from the canonical JSON catalog"
	)

	for equipment_id in data_ids:
		var source := _get_source_entry(equipment_id)
		var recipe := EquipmentManager.get_recipe(equipment_id)
		assert(not recipe.is_empty(), "Manager must expose canonical recipe %s" % equipment_id)
		for field in CANONICAL_FIELDS:
			assert(
				recipe.get(field) == source.get(field),
				"Recipe %s diverged from canonical field %s" % [equipment_id, field]
			)

	for raw_ability in DataRepository.abilities:
		if not raw_ability is Dictionary:
			continue
		var ability := raw_ability as Dictionary
		for raw_required_tag in ability.get("required_equipment_tags", []):
			var required_tag := str(raw_required_tag)
			assert(
				available_tags.has(required_tag),
				(
					"Ability %s requires equipment tag with no canonical provider: %s"
					% [str(ability.get("id", "")), required_tag]
				)
			)

	print("Canonical equipment catalog contract: OK")
	get_tree().quit(0)


func _get_source_entry(equipment_id: String) -> Dictionary:
	for raw_entry in DataRepository.weapons:
		if raw_entry is Dictionary and str((raw_entry as Dictionary).get("id", "")) == equipment_id:
			return (raw_entry as Dictionary).duplicate(true)
	return {}
