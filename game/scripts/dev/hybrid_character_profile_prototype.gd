extends Node2D

@onready var rig: PixelGladiatorRig = $PixelPanel/PixelGladiatorRig
@onready var equipment_label: Label = $Information/Equipment


func _ready() -> void:
    rig.set_pixel_scale(4)
    rig.loadout_changed.connect(_update_equipment)
    $Information/Buttons/Helmet.pressed.connect(func() -> void: cycle_equipment("helmet"))
    $Information/Buttons/Weapon.pressed.connect(func() -> void: cycle_equipment("weapon"))
    $Information/Buttons/Shield.pressed.connect(func() -> void: cycle_equipment("shield"))
    _update_equipment(rig.get_loadout_summary())


func cycle_equipment(slot: String) -> void:
    match slot:
        "helmet":
            rig.cycle_helmet()
        "weapon":
            rig.cycle_weapon()
        "shield":
            rig.cycle_shield()
        _:
            push_warning("Unknown hybrid profile equipment slot: %s" % slot)


func get_validation_state() -> Dictionary:
    return {
        "sprite": rig.get_validation_state(),
        "portrait": $PortraitPanel/AnimatedPortraitCard.get_validation_state(),
        "equipment_label": equipment_label.text,
        "portrait_updates_with_equipment": false,
    }


func _update_equipment(summary: String) -> void:
    equipment_label.text = "Equipo actual\n%s" % summary
