extends RefCounted

const GT1BeastReadinessContractScript = preload(
	"res://scripts/combat/gt1_beast_readiness_contract.gd"
)

const GT1_MONTHS := [13, 16, 20]
const BOUT_COUNT := 3

var _beast_readiness = GT1BeastReadinessContractScript.new()


func validate_selection(
	month: int, player_ids_by_bout: Array, available_gladiator_ids: Array[String]
) -> Array[String]:
	var errors: Array[String] = []
	if not GT1_MONTHS.has(month):
		errors.append("GT I roster selection requires month 13, 16 or 20")
	if player_ids_by_bout.size() != BOUT_COUNT:
		errors.append("GT I roster selection requires exactly three bout selections")
	if not errors.is_empty():
		return errors

	var normalized: Array[Array] = []
	var expected_size := 2 if month == 20 else 1
	for index in range(player_ids_by_bout.size()):
		if not player_ids_by_bout[index] is Array:
			errors.append("GT I bout %d roster selection must be an Array" % [index + 1])
			continue
		var ids: Array[String] = []
		for raw_id in player_ids_by_bout[index] as Array:
			var fighter_id := str(raw_id)
			if fighter_id.is_empty():
				errors.append("GT I bout %d contains an empty gladiator id" % [index + 1])
				continue
			if ids.has(fighter_id):
				errors.append("GT I bout %d cannot select the same gladiator twice" % [index + 1])
				continue
			if not available_gladiator_ids.has(fighter_id):
				errors.append(
					"GT I bout %d selected unavailable gladiator %s" % [index + 1, fighter_id]
				)
			ids.append(fighter_id)
		ids.sort()
		if ids.size() != expected_size:
			errors.append(
				"GT I bout %d requires exactly %d player gladiator(s)" % [index + 1, expected_size]
			)
		normalized.append(ids)

	if not errors.is_empty():
		return errors
	if month == 13:
		_validate_month_13(normalized, errors)
	elif month == 20:
		_validate_month_20(normalized, errors)
	return errors


func get_month_16_beast_readiness(beasts: Array, runtime_adapter_ready: bool = false) -> Dictionary:
	return _beast_readiness.evaluate(beasts, runtime_adapter_ready)


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"month_13": "same_single_gladiator_all_three_bouts",
		"month_16_frozen_design": "one_available_gladiator_per_independent_bout_against_human_or_beast",
		"month_16_current_selection": "human_or_canonical_beast_opponents",
		"month_16_beast_readiness": "gt1_beast_readiness_contract",
		"month_16_beast_adapter": "combat_beast_fighter_adapter",
		"month_20": "same_pair_with_at_most_one_single_fighter_substitution",
		"selection_source": "available_player_gladiator_ids",
		"beast_data_source": "DataRepository.beasts",
		"combat_stats_authority": "separate_combat_fighter_adapters",
		"invent_beast_stats_allowed": false,
	}


func _validate_month_13(selections: Array[Array], errors: Array[String]) -> void:
	var baseline := selections[0]
	for index in range(1, selections.size()):
		if selections[index] != baseline:
			errors.append("GT I month XIII requires the same gladiator in all three bouts")
			return


func _validate_month_20(selections: Array[Array], errors: Array[String]) -> void:
	var previous := selections[0]
	var substitutions := 0
	for index in range(1, selections.size()):
		var current := selections[index]
		if current == previous:
			continue
		var shared := 0
		for fighter_id in previous:
			if current.has(fighter_id):
				shared += 1
		if shared != 1:
			errors.append("GT I month XX substitution must replace exactly one gladiator")
			return
		substitutions += 1
		previous = current
	if substitutions > 1:
		errors.append("GT I month XX allows at most one unilateral player substitution")
