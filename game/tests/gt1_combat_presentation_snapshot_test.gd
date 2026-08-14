extends Node

const GT1CombatPresentationSnapshotScript = preload(
	"res://scripts/combat/gt1_combat_presentation_snapshot.gd"
)


func run() -> void:
	var presenter = GT1CombatPresentationSnapshotScript.new()
	var session := {
		"status": "combat_running",
		"month": 13,
		"encounter": 1,
		"format": "1v1",
		"bout_index": 1,
		"completed_bouts": 1,
		"player_wins": 1,
		"player_points": 3,
		"last_intent_providers": {"player": "player", "rival": "limboai"},
		"active_loop":
		{
			"state":
			{
				"format": "1v1",
				"fighters":
				[
					{
						"id": "player",
						"team": "alpha",
						"stats": {"PV": 100},
						"current_pv": 72,
						"stamina": 61.5,
					},
					{
						"id": "rival",
						"team": "beta",
						"stats": {"PV": 90},
						"current_pv": 0,
						"stamina": 12.0,
					},
				],
			},
		},
	}
	var original := session.duplicate(true)
	var summary := {
		"player_points": 6,
		"player_bouts": 2,
		"encounter_progress": {"13": 2, "16": 0, "20": 0},
	}
	var snapshot: Dictionary = presenter.build(session, summary)
	assert(snapshot.get("status") == "ready")
	assert(snapshot.get("bout_number") == 2)
	assert(snapshot.get("encounter_progress") == 2)
	assert(snapshot.get("tournament_points") == 6)
	assert(snapshot.get("combat_authority") == "combat_simulator")
	assert(snapshot.get("scoring_authority") == "tournament_manager")
	assert(snapshot.get("presentation_may_mutate_combat") == false)
	var fighters := snapshot.get("fighters", []) as Array
	assert(fighters.size() == 2)
	assert(int((fighters[0] as Dictionary).get("current_pv", -1)) == 72)
	assert((fighters[1] as Dictionary).get("knocked_out") == true)
	assert(session == original, "Presentation snapshot must not mutate authoritative session")
	assert(
		presenter.get_contract().get("output") == "read_only_ui_snapshot",
		"Presentation layer must remain explicitly read-only"
	)
	print("GT I read-only combat presentation snapshot: OK")
