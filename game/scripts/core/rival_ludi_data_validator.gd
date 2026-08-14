extends RefCounted

const CANONICAL_RIVAL_LUDI := {
	"aurelius": "Ludus Aurelius",
	"cassianus": "Ludus Cassianus",
	"drusus": "Ludus Drusus",
	"flavianus": "Ludus Flavianus",
	"marcellus": "Ludus Marcellus",
	"severus": "Ludus Severus",
	"varro": "Ludus Varro",
}
const FORBIDDEN_RUNTIME_FIELDS: Array[String] = [
	"wealth",
	"security",
	"prestige",
	"relation",
	"intel",
	"suspicion",
	"gladiator_power",
	"points",
	"wins",
	"stats",
	"combat_stats",
]


func validate_repository(repository) -> Array[String]:
	return validate_entries(repository.rival_ludi)


func validate_entries(entries: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not entries is Array:
		return ["rival_ludi must be an Array"]
	var typed_entries := entries as Array
	if typed_entries.size() != CANONICAL_RIVAL_LUDI.size():
		errors.append("Rival Ludus identity catalog must contain exactly seven entries")

	var seen: Dictionary = {}
	for raw_entry in typed_entries:
		if not raw_entry is Dictionary:
			errors.append("rival_ludi contains a non-Dictionary entry")
			continue
		var entry := raw_entry as Dictionary
		var rival_id := str(entry.get("id", ""))
		if not CANONICAL_RIVAL_LUDI.has(rival_id):
			errors.append("Unknown canonical rival Ludus id: %s" % rival_id)
			continue
		if seen.has(rival_id):
			errors.append("Duplicate canonical rival Ludus id: %s" % rival_id)
		seen[rival_id] = true
		if str(entry.get("name", "")) != str(CANONICAL_RIVAL_LUDI[rival_id]):
			errors.append("Rival Ludus %s has a non-canonical name" % rival_id)
		for field_name in FORBIDDEN_RUNTIME_FIELDS:
			if entry.has(field_name):
				errors.append(
					(
						"Rival Ludus identity %s must not define runtime field %s"
						% [rival_id, field_name]
					)
				)

	for rival_id in CANONICAL_RIVAL_LUDI.keys():
		if not seen.has(rival_id):
			errors.append("Missing canonical rival Ludus id: %s" % rival_id)
	return errors


func get_canonical_ids() -> Array[String]:
	var ids: Array[String] = []
	for rival_id in CANONICAL_RIVAL_LUDI.keys():
		ids.append(str(rival_id))
	ids.sort()
	return ids
