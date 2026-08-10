extends RefCounted

const PROCESSING_ORDER := [
	"roster",
	"rivals",
	"economy",
	"tournaments",
	"advance_clock",
	"events",
	"food",
]

const BLOCKER_CAMPAIGN_OVER := "campaign_over"
const BLOCKER_EVENT_PENDING := "event_pending"
const BLOCKER_GT1_INCOMPLETE := "gt1_encounter_incomplete"


func evaluate(
	month: int,
	campaign_over: bool,
	pending_event: Dictionary,
	gt1_encounter: Dictionary,
	gt1_summary: Dictionary,
) -> Dictionary:
	var resolved_month := maxi(1, month)
	var blocker_details: Array[Dictionary] = []
	var fight := _build_fight_status(resolved_month, gt1_encounter, gt1_summary)
	var event_pending := not pending_event.is_empty()

	if campaign_over:
		(
			blocker_details
			. append(
				_blocker(
					BLOCKER_CAMPAIGN_OVER,
					"La campaña terminó. La partida permanece disponible en modo de consulta.",
				)
			)
		)
	if event_pending:
		(
			blocker_details
			. append(
				_blocker(
					BLOCKER_EVENT_PENDING,
					"Hay un evento mensual pendiente de resolución.",
				)
			)
		)
	if bool(fight.get("pending", false)):
		(
			blocker_details
			. append(
				_blocker(
					BLOCKER_GT1_INCOMPLETE,
					"El encuentro del Gran Torneo de este mes todavía no fue completado.",
				)
			)
		)

	var blocker_messages: Array[String] = []
	for blocker in blocker_details:
		blocker_messages.append(str(blocker.get("reason", "")))

	return {
		"period": "month",
		"month": resolved_month,
		"event_pending": event_pending,
		"fight": fight,
		"fight_pending": bool(fight.get("pending", false)),
		"blockers": blocker_messages,
		"blocker_details": blocker_details.duplicate(true),
		"can_close": blocker_details.is_empty(),
		"non_gt_combat_required": false,
		"warnings_block_closure": false,
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"period": "month",
		"canonical_blocker_codes":
		[
			BLOCKER_CAMPAIGN_OVER,
			BLOCKER_EVENT_PENDING,
			BLOCKER_GT1_INCOMPLETE,
		],
		"non_gt_combat_required": false,
		"legacy_combat_schedule_allowed": false,
		"warnings_block_closure": false,
		"processing_order": PROCESSING_ORDER.duplicate(),
		"save_version_change_required": false,
	}


func _build_fight_status(
	month: int, gt1_encounter: Dictionary, gt1_summary: Dictionary
) -> Dictionary:
	if gt1_encounter.is_empty():
		return {
			"month": month,
			"required": false,
			"pending": false,
			"name": "Gestión del ludus",
			"completed_bouts": 0,
			"required_bouts": 0,
		}

	var fight := gt1_encounter.duplicate(true)
	var progress: Dictionary = gt1_summary.get("encounter_progress", {})
	var required_bouts := maxi(1, int(fight.get("series_bouts", 0)))
	var completed_bouts := clampi(int(progress.get(str(month), 0)), 0, required_bouts)
	fight["required"] = true
	fight["completed_bouts"] = completed_bouts
	fight["required_bouts"] = required_bouts
	fight["pending"] = completed_bouts < required_bouts
	return fight


func _blocker(code: String, reason: String) -> Dictionary:
	return {
		"code": code,
		"reason": reason,
	}
