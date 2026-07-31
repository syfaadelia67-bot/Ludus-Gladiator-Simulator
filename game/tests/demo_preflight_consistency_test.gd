extends SceneTree

const EXPECTED_ABILITIES := [
    "precise_strike",
    "feint",
    "opportunity_strike",
    "throw_sand",
    "shield_charge",
    "relentless_pursuit",
    "cast_net",
    "dance_of_two_blades"
]
const EXPECTED_SPECIALIZATIONS := ["gladiator", "murmillo", "secutor", "retiarius", "dimachaerus"]
const EXPECTED_CLASS_ABILITIES := {
    "murmillo":"shield_charge",
    "secutor":"relentless_pursuit",
    "retiarius":"cast_net",
    "dimachaerus":"dance_of_two_blades"
}

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    GladiatorProgressionManager._load_catalogs()
    TraitManager._load_catalog()

    _assert_ability_catalog()
    _assert_specialization_catalog()
    _assert_trait_catalog()
    _assert_equipment_contracts()
    _assert_migration_contracts()
    _assert_save_contract()

    print("Demo preflight consistency tests passed")
    quit(0)

func _assert_ability_catalog() -> void:
    assert(DataRepository.abilities.size() == 8, "The demo must expose exactly eight canonical abilities")
    var found: Array[String] = []
    for raw_entry in DataRepository.abilities:
        assert(raw_entry is Dictionary, "Every ability entry must be a dictionary")
        var entry: Dictionary = raw_entry
        var ability_id := str(entry.get("id", ""))
        found.append(ability_id)
        assert(int(entry.get("demo_max_level", 0)) == 2, "%s must stop at rank II in the demo" % ability_id)
        assert(int(entry.get("full_max_level", 0)) == 3, "%s must reserve rank III for the full game" % ability_id)
        var levels: Dictionary = entry.get("levels", {})
        assert(levels.has("1") and levels.has("2") and levels.has("3"), "%s must define ranks I, II and III" % ability_id)
        var third_rank: Dictionary = levels.get("3", {})
        assert(bool(third_rank.get("locked", false)), "%s rank III must remain locked" % ability_id)
        assert(str(third_rank.get("status", "")) == "coming_soon", "%s rank III must be marked coming soon" % ability_id)
    found.sort()
    var expected := EXPECTED_ABILITIES.duplicate()
    expected.sort()
    assert(found == expected, "Ability ids must match the canonical demo catalog")

func _assert_specialization_catalog() -> void:
    assert(DataRepository.specializations.size() == 5, "The canonical catalog must contain the generic class plus four specializations")
    var found: Array[String] = []
    for raw_entry in DataRepository.specializations:
        assert(raw_entry is Dictionary, "Every specialization entry must be a dictionary")
        var entry: Dictionary = raw_entry
        var specialization_id := str(entry.get("id", ""))
        found.append(specialization_id)
        var growth: Dictionary = entry.get("growth_per_level", {})
        var budget := int(growth.get("strength", 0)) + int(growth.get("agility", 0)) + int(growth.get("endurance", 0)) + int(growth.get("intelligence", 0)) + int(growth.get("technique", 0))
        budget += int(growth.get("health", 0)) / 5
        assert(budget == 12, "%s growth must respect the twelve-point budget" % specialization_id)
        if EXPECTED_CLASS_ABILITIES.has(specialization_id):
            assert(str(entry.get("class_ability", "")) == EXPECTED_CLASS_ABILITIES[specialization_id], "%s must reference its canonical class ability" % specialization_id)
    found.sort()
    var expected := EXPECTED_SPECIALIZATIONS.duplicate()
    expected.sort()
    assert(found == expected, "Specialization ids must match the canonical catalog")
    assert(GladiatorProgressionManager.canonical_specialization_id("balanced") == "gladiator", "balanced must migrate to gladiator")
    assert(GladiatorProgressionManager.canonical_specialization_id("thraex") == "dimachaerus", "thraex must migrate to dimachaerus")

func _assert_trait_catalog() -> void:
    assert(TraitManager.get_origin_trait_ids().size() == 8, "The demo must contain eight origin traits")
    assert(TraitManager.get_obtainable_trait_ids().size() == 14, "The demo must contain fourteen obtainable traits")
    var dreamer := TraitManager.get_trait("dreamer")
    assert(not dreamer.is_empty(), "Soñador must exist in the obtainable catalog")
    var effects: Dictionary = dreamer.get("permanent_effects", {})
    for stat_id in ["strength", "agility", "endurance", "intelligence", "technique"]:
        assert(int(effects.get(stat_id, 0)) == 1, "Soñador must grant +1 %s" % stat_id)

func _assert_equipment_contracts() -> void:
    var shield_charge: Dictionary = GladiatorProgressionManager.abilities.get("shield_charge", {})
    var cast_net: Dictionary = GladiatorProgressionManager.abilities.get("cast_net", {})
    var two_blades: Dictionary = GladiatorProgressionManager.abilities.get("dance_of_two_blades", {})
    assert(shield_charge.get("required_equipment_tags", []).has("shield"), "Embate del escudo must require a shield")
    assert(cast_net.get("required_equipment_tags", []).has("net"), "Red de captura must require a net")
    assert(two_blades.get("required_equipment_tags", []).has("dual_blades"), "Danza de dos filos must require dual blades")
    assert(EquipmentManager.RECIPES.has("retiarius_kit"), "The forge must define the net and trident recipe")
    assert(EquipmentManager.RECIPES.has("dual_blades"), "The forge must define the dual blades recipe")

func _assert_migration_contracts() -> void:
    assert(GladiatorProgressionManager.canonical_tactical_condition("target_defending") == "target_guarding", "Legacy defending condition must migrate")
    assert(GladiatorProgressionManager.canonical_tactical_condition("after_dodge_or_block") == "after_defense", "Legacy defense reaction condition must migrate")
    assert(GladiatorProgressionManager.canonical_tactical_condition("unknown") == "always", "Unknown conditions must fall back safely")

func _assert_save_contract() -> void:
    assert(SaveManager.SAVE_VERSION == 13, "The current save format must be version 13")
    var person = preload("res://scripts/entities/person.gd").new({
        "id":"preflight_person",
        "name":"Preflight",
        "role":"gladiator",
        "technique":7,
        "health":65,
        "traits":["arena_lover", "protector", "dreamer"],
        "applied_trait_effects":["dreamer"]
    })
    var serialized: Dictionary = SaveManager._serialize_person(person)
    assert(int(serialized.get("technique", 0)) == 7, "Technique must be serialized")
    assert(int(serialized.get("health", 0)) == 65, "Health must be serialized")
    assert(serialized.get("traits", []).has("dreamer"), "Permanent traits must be serialized")
    assert(serialized.get("applied_trait_effects", []).has("dreamer"), "Applied permanent effects must be serialized")
