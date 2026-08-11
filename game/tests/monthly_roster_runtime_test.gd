extends Node

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")


func _ready() -> void:
	DataRepository.load_all()
	var previous_people: Array = RosterManager.people.duplicate()
	var previous_month := GameState.day
	var previous_last_processed := RosterManager.last_processed_month
	var previous_last_result := RosterManager.last_monthly_result.duplicate(true)
	var previous_security := RosterManager.security_score
	var previous_intel := RosterManager.intelligence_points
	var previous_personality := PersonalityManager.export_state()
	var previous_relationships := RelationshipManager.export_state()
	var previous_progression := GladiatorProgressionManager.export_state()

	GameState.day = 4
	RosterManager.people.clear()
	RosterManager.security_score = 0
	RosterManager.intelligence_points = 0
	RosterManager.reset_monthly_runtime_state()

	var miner = PERSON_SCRIPT.new(
		{
			"id": "monthly_miner",
			"name": "Miner",
			"role": "slave",
			"job": "mining",
			"strength": 9,
			"endurance": 9,
			"fatigue": 41,
			"traits": [],
		}
	)
	var trainee = PERSON_SCRIPT.new(
		{
			"id": "monthly_trainee",
			"name": "Trainee",
			"role": "slave",
			"job": "training",
			"training": 99,
			"fatigue": 50,
			"traits": [],
		}
	)
	var fighter = PERSON_SCRIPT.new(
		{
			"id": "monthly_fighter",
			"name": "Fighter",
			"role": "gladiator",
			"job": "training",
			"training": 20,
			"fatigue": 100,
			"traits": [],
		}
	)
	var injured = PERSON_SCRIPT.new(
		{
			"id": "monthly_injured",
			"name": "Injured",
			"role": "gladiator",
			"job": "training",
			"fatigue": 70,
			"injury_name": "Herida de prueba",
			"injury_severity": 2,
			"injury_days": 3,
			"traits": [],
		}
	)
	RosterManager.people.assign([miner, trainee, fighter, injured])

	var first := RosterManager.process_month()
	assert(first.get("period") == "month")
	assert(first.get("month") == 4)
	assert(first.get("duplicate_call_ignored") == false)
	assert(first.get("work_balance_applied") == true)
	assert(first.get("training_balance_applied") == true)
	assert(first.get("fatigue_balance_applied") == true)
	assert(first.get("injury_recovery_balance_applied") == true)
	assert(int(first.get("ore", 0)) == 13)
	assert(int(first.get("training", 0)) > 0)
	assert(miner.fatigue == 49)
	assert(trainee.training > 99)
	assert(trainee.role == "gladiator")
	assert(str(trainee.job) == "idle")
	assert(trainee.fatigue > 50)
	assert(fighter.training > 20)
	assert(fighter.fatigue == 100)
	assert(not fighter.is_available_for_combat())
	assert(injured.injury_days < 3)
	assert(injured.fatigue < 70)
	assert(injured.job == "idle")
	assert(not injured.is_available_for_combat())
	assert((first.get("promotions", []) as Array).has("monthly_trainee"))

	var miner_fatigue_after := miner.fatigue
	var trainee_training_after := trainee.training
	var injured_recovery_after := injured.injury_days
	var duplicate := RosterManager.process_day()
	assert(duplicate.get("duplicate_call_ignored") == true)
	assert(RosterManager.last_processed_month == 4)
	assert(miner.fatigue == miner_fatigue_after)
	assert(trainee.training == trainee_training_after)
	assert(injured.injury_days == injured_recovery_after)

	var save_source := FileAccess.get_file_as_string("res://scripts/core/save_manager_demo.gd")
	assert(save_source.contains('roster_data["last_processed_month"]'))
	assert(save_source.contains('roster_data["last_monthly_result"]'))
	var reset_source := FileAccess.get_file_as_string(
		"res://scripts/core/new_campaign_coordinator.gd"
	)
	assert(reset_source.contains('"last_processed_month": 0'))
	assert(reset_source.contains('"last_monthly_result": {}'))

	RosterManager.people = previous_people
	GameState.day = previous_month
	RosterManager.last_processed_month = previous_last_processed
	RosterManager.last_monthly_result = previous_last_result
	RosterManager.security_score = previous_security
	RosterManager.intelligence_points = previous_intel
	PersonalityManager.import_state(previous_personality)
	RelationshipManager.import_state(previous_relationships)
	GladiatorProgressionManager.import_state(previous_progression)
	RosterManager.roster_changed.emit()
	print("Monthly roster authored runtime and idempotency: OK")
	get_tree().quit(0)
