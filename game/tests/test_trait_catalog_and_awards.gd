extends Node

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")

const NORMAL_TRAIT_IDS: Array[String] = [
	"beast_hunter",
	"calculating",
	"colossus",
	"disciplined",
	"impulsive",
	"intimidating",
	"lone_fighter",
	"loyal",
	"natural_talent",
	"opportunist",
	"protector",
	"prudent",
	"reckless",
	"showman",
	"tenacious",
	"vigilant",
]


func _ready() -> void:
	var normal_ids := TraitManager.get_normal_trait_ids()
	assert(normal_ids == NORMAL_TRAIT_IDS)
	assert(TraitManager.get_origin_trait_ids().is_empty())
	assert(TraitManager.get_obtainable_trait_ids().is_empty())

	var gladiator = PERSON_SCRIPT.new(
		{
			"id": "trait_contract_gladiator",
			"name": "Gladiador de contrato",
			"origin": "Roma",
			"role": "gladiator",
			"strength": 7,
			"agility": 6,
			"endurance": 8,
			"intelligence": 5,
			"technique": 6,
			"health": 50,
			"traits": [],
		}
	)
	assert(RosterManager.add_person(gladiator))
	TraitManager.ensure_gladiator_origin_traits(gladiator)
	assert(gladiator.traits.is_empty(), "The frozen trait model must not auto-assign origin traits")

	assert(TraitManager.award_trait(gladiator.id, "disciplined"))
	assert(not TraitManager.award_trait(gladiator.id, "disciplined"), "Duplicate traits must be rejected")
	assert(
		not TraitManager.award_trait(gladiator.id, "impulsive"),
		"Disciplinado and Impulsivo must be mutually exclusive"
	)

	assert(TraitManager.award_trait(gladiator.id, "reckless"))
	assert(
		not TraitManager.award_trait(gladiator.id, "prudent"),
		"Temerario and Prudente must be mutually exclusive"
	)

	assert(TraitManager.award_trait(gladiator.id, "protector"))
	assert(gladiator.traits.size() == 3)
	assert(
		not TraitManager.award_trait(gladiator.id, "vigilant"),
		"A gladiator must not exceed three normal traits"
	)
	assert(not TraitManager.award_trait(gladiator.id, "dreamer"), "Removed legacy traits must be inert")

	print("Frozen normal trait catalog and award contract: OK")
	get_tree().quit()
