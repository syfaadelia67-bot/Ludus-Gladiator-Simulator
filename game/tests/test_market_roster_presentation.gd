extends Node

func run() -> Dictionary:
    var errors: Array[String] = []
    var offer := {
        "role":"gladiator",
        "strength":5,
        "agility":5,
        "endurance":5,
        "intelligence":5,
        "technique":5,
        "health":50,
        "traits":["arena_lover", "mentor"]
    }
    var base_value := MarketValuation.offer_value(offer)
    var improved_offer := offer.duplicate(true)
    improved_offer["technique"] = 8
    improved_offer["health"] = 65
    var improved_value := MarketValuation.offer_value(improved_offer)
    if improved_value <= base_value:
        errors.append("La Técnica y la Vida deben aumentar el valor de mercado.")

    var trait_offer := offer.duplicate(true)
    trait_offer["traits"] = ["arena_lover", "mentor", "dreamer"]
    if MarketValuation.offer_value(trait_offer) <= base_value:
        errors.append("Los rasgos permanentes deben aumentar el valor de mercado.")

    var presentation_source := FileAccess.get_file_as_string("res://scripts/ui/roster_market_presentation.gd")
    for expected in ["person.technique", "person.health", "Rasgos permanentes", "Valor calculado", "TraitManager.get_trait_name"]:
        if not presentation_source.contains(expected):
            errors.append("La ficha visual no contiene: %s" % expected)

    var market_source := FileAccess.get_file_as_string("res://scripts/systems/market_manager.gd")
    for expected in ["\"technique\"", "\"health\"", "MarketValuation.offer_value"]:
        if not market_source.contains(expected):
            errors.append("El mercado no integra: %s" % expected)

    return {"passed":errors.is_empty(), "errors":errors}
