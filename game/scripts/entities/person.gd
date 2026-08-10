class_name LudusPerson
extends RefCounted

const MONTHLY_ROSTER_WORK_POLICY = preload("res://scripts/systems/monthly_roster_work_policy.gd")
const EQUIPMENT_SLOT_IDS: Array[String] = [
	"head",
	"torso",
	"right_hand",
	"left_hand",
	"lower_body",
	"accessory",
	"mount",
]
const LEGACY_RESISTANCE_BASELINE := 5

var id: String
var display_name: String
var role: String = "slave"
var job: String = "idle"
var origin: String = "Unknown"
var strength: int = 5
var agility: int = 5
var endurance: int = 5
var resistance: int = LEGACY_RESISTANCE_BASELINE
var intelligence: int = 5
var technique: int = 5
var health: int = 50
var loyalty: int = 50
var morale: int = 50
var fatigue: int = 0
var training: int = 0
var traits: Array[String] = []
var applied_trait_effects: Array[String] = []

# Legacy equipment fields remain serialized and consumed by older combat/UI
# code. The canonical seven-slot model mirrors these three fields and extends
# them without invalidating save version 14.
var equipped_weapon_id: String = ""
var equipped_armor_id: String = ""
var equipped_shield_id: String = ""
var equipped_slots: Dictionary = {}

# Save-v14 field name retained. Runtime interpretation is recovery months/turns.
var injury_severity: int = 0
var injury_days: int = 0
var injury_name: String = ""


func _init(data: Dictionary = {}) -> void:
	id = str(data.get("id", "person_%s" % Time.get_ticks_usec()))
	display_name = str(data.get("name", "Sin nombre"))
	role = str(data.get("role", "slave"))
	job = str(data.get("job", "idle"))
	origin = str(data.get("origin", "Unknown"))
	strength = int(data.get("strength", 5))
	agility = int(data.get("agility", 5))
	endurance = int(data.get("endurance", 5))
	# RES is canonical Combat V1 data. Legacy v14 people did not serialize this
	# field, so they receive one neutral compatibility baseline exactly once and
	# persist it on their next save. Endurance is deliberately not used here.
	resistance = maxi(1, int(data.get("resistance", LEGACY_RESISTANCE_BASELINE)))
	intelligence = int(data.get("intelligence", 5))
	technique = int(data.get("technique", 5))
	health = maxi(1, int(data.get("health", 50)))
	loyalty = int(data.get("loyalty", 50))
	morale = int(data.get("morale", 50))
	fatigue = clampi(int(data.get("fatigue", 0)), 0, 100)
	training = maxi(0, int(data.get("training", 0)))
	traits.assign(data.get("traits", []))
	applied_trait_effects.assign(data.get("applied_trait_effects", []))
	equipped_weapon_id = str(data.get("equipped_weapon_id", ""))
	equipped_armor_id = str(data.get("equipped_armor_id", ""))
	equipped_shield_id = str(data.get("equipped_shield_id", ""))
	_initialize_equipment_slots(data.get("equipped_slots", {}))
	injury_severity = clampi(int(data.get("injury_severity", 0)), 0, 3)
	injury_days = maxi(0, int(data.get("injury_days", 0)))
	injury_name = str(data.get("injury_name", ""))


func _initialize_equipment_slots(raw_slots: Variant = {}) -> void:
	equipped_slots.clear()
	for slot_id in EQUIPMENT_SLOT_IDS:
		equipped_slots[slot_id] = ""
	if raw_slots is Dictionary:
		for slot_id in EQUIPMENT_SLOT_IDS:
			equipped_slots[slot_id] = str((raw_slots as Dictionary).get(slot_id, ""))
	if str(equipped_slots.get("right_hand", "")).is_empty():
		equipped_slots["right_hand"] = equipped_weapon_id
	if str(equipped_slots.get("torso", "")).is_empty():
		equipped_slots["torso"] = equipped_armor_id
	if str(equipped_slots.get("left_hand", "")).is_empty():
		equipped_slots["left_hand"] = equipped_shield_id
	_sync_legacy_equipment_fields()


func set_equipped_item_id(slot_id: String, item_id: String) -> bool:
	if not EQUIPMENT_SLOT_IDS.has(slot_id):
		return false
	equipped_slots[slot_id] = item_id
	_sync_legacy_equipment_fields()
	return true


func get_equipped_item_id(slot_id: String) -> String:
	if not EQUIPMENT_SLOT_IDS.has(slot_id):
		return ""
	return str(equipped_slots.get(slot_id, ""))


func get_equipped_slots() -> Dictionary:
	return equipped_slots.duplicate(true)


func synchronize_legacy_equipment() -> void:
	if str(equipped_slots.get("right_hand", "")).is_empty() and not equipped_weapon_id.is_empty():
		equipped_slots["right_hand"] = equipped_weapon_id
	if str(equipped_slots.get("torso", "")).is_empty() and not equipped_armor_id.is_empty():
		equipped_slots["torso"] = equipped_armor_id
	if str(equipped_slots.get("left_hand", "")).is_empty() and not equipped_shield_id.is_empty():
		equipped_slots["left_hand"] = equipped_shield_id
	_sync_legacy_equipment_fields()


func _sync_legacy_equipment_fields() -> void:
	equipped_weapon_id = str(equipped_slots.get("right_hand", ""))
	equipped_armor_id = str(equipped_slots.get("torso", ""))
	equipped_shield_id = str(equipped_slots.get("left_hand", ""))


func assign_job(new_job: String) -> void:
	if injury_days > 0 and new_job != "idle":
		return
	job = new_job


func process_month() -> Dictionary:
	var policy := MONTHLY_ROSTER_WORK_POLICY.get_contract()
	var result := {
		"period": "month",
		"ore": 0,
		"food": 0,
		"security": 0,
		"intel": 0,
		"training": 0,
		"personality": {},
		"policy_status": str(policy.get("status", "")),
		"work_balance_applied": false,
		"training_balance_applied": false,
		"fatigue_balance_applied": false,
		"injury_recovery_balance_applied": false,
	}

	# Injury state remains authoritative for availability and job assignment, but
	# its countdown does not advance until a canonical monthly recovery formula is
	# frozen. This avoids treating the former daily decrement as one month.
	if injury_days > 0:
		job = "idle"

	# Personality remains a separate monthly subsystem. The monthly wrapper
	# protects disabled work/training outputs from legacy trait bonuses.
	result.personality = PersonalityManager.process_person_month(self, result)
	loyalty = clampi(loyalty, 0, 100)
	fatigue = clampi(fatigue, 0, 100)
	return result


func process_day() -> Dictionary:
	# Save-v14 / legacy caller adapter only. Never an additional simulation tick.
	return process_month()


func apply_growth(growth: Dictionary) -> void:
	strength += int(growth.get("strength", 0))
	agility += int(growth.get("agility", 0))
	endurance += int(growth.get("endurance", 0))
	resistance = maxi(1, resistance + int(growth.get("resistance", 0)))
	intelligence += int(growth.get("intelligence", 0))
	technique += int(growth.get("technique", 0))
	health = maxi(1, health + int(growth.get("health", 0)))


func apply_injury(name_value: String, severity: int, recovery_months: int) -> void:
	injury_name = name_value
	injury_severity = clampi(severity, 1, 3)
	injury_days = maxi(1, recovery_months)
	job = "idle"


func get_injury_recovery_months() -> int:
	# `injury_days` is the Save-v14 storage alias; runtime semantics are months.
	return injury_days


func is_available_for_combat() -> bool:
	# Fatigue is persisted for compatibility, but cannot affect Combat V1
	# availability until that cross-system rule is explicitly frozen.
	return role == "gladiator" and injury_days <= 0


func get_max_health() -> int:
	var penalty := injury_severity * 8
	return maxi(20, health + endurance * 2 - penalty)


func get_max_energy() -> int:
	var fatigue_penalty := floori(float(fatigue) / 5.0)
	var penalty := injury_severity * 6 + fatigue_penalty
	return maxi(20, 55 + endurance * 5 + agility * 3 - penalty)


func get_base_attack() -> int:
	return maxi(1, strength * 2 + agility + floori(float(technique) / 2.0) - injury_severity * 3)


func get_base_defense() -> int:
	return maxi(1, endurance + agility + floori(float(technique) / 2.0) - injury_severity * 2)


func get_injury_summary() -> String:
	if injury_days <= 0:
		return "Sin heridas"
	return "%s · gravedad %d · %d mes(es)" % [injury_name, injury_severity, injury_days]


func summary() -> String:
	return (
		"%s | %s | trabajo: %s | lealtad: %d | moral: %d | fatiga: %d | %s"
		% [
			display_name,
			role,
			job,
			loyalty,
			morale,
			fatigue,
			get_injury_summary(),
		]
	)
