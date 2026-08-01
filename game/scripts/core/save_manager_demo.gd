extends "res://scripts/core/save_manager.gd"

## Demo save extension. Keeps SAVE_VERSION 14 compatible while explicitly
## persisting unique-gladiator ownership, market windows and acquisition weeks.

func _build_payload() -> Dictionary:
    var payload := super._build_payload()
    payload["unique_gladiators"] = UniqueGladiatorManager.export_state()
    return payload

func _apply_payload(data: Dictionary) -> bool:
    if not super._apply_payload(data):
        return false
    var unique_data: Variant = data.get("unique_gladiators", null)
    if unique_data is Dictionary and not unique_data.is_empty():
        UniqueGladiatorManager.import_state(unique_data)
    else:
        # Older v14 saves reconstruct ownership from roster, rival houses and
        # saved market offers without being rejected.
        UniqueGladiatorManager.reconcile_from_world()
    MarketManager.sync_unique_offers()
    return true
