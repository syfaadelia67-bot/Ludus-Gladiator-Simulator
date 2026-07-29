extends Node2D

const ANIMATIONS := ["idle", "attack", "block", "hit", "defeat"]
const SCALES := [2, 4, 6]

@onready var rig: PixelGladiatorRig = $PixelGladiatorRig
@onready var loadout_label: Label = $DevelopmentPanel/Margin/VBox/Loadout
@onready var animation_selector: OptionButton = $DevelopmentPanel/Margin/VBox/AnimationRow/Animation
@onready var scale_selector: OptionButton = $DevelopmentPanel/Margin/VBox/ScaleRow/Scale


func _ready() -> void:
    for animation_name in ANIMATIONS:
        animation_selector.add_item(animation_name)
    for multiplier in SCALES:
        scale_selector.add_item("×%d" % multiplier, multiplier)
    scale_selector.select(1)
    rig.set_pixel_scale(4)
    rig.loadout_changed.connect(_update_loadout)
    rig.animation_changed.connect(_update_animation_caption)
    $DevelopmentPanel/Margin/VBox/Equipment/Helmet.pressed.connect(_cycle_helmet)
    $DevelopmentPanel/Margin/VBox/Equipment/Weapon.pressed.connect(_cycle_weapon)
    $DevelopmentPanel/Margin/VBox/Equipment/Shield.pressed.connect(_cycle_shield)
    $DevelopmentPanel/Margin/VBox/Equipment/Cloth.pressed.connect(_cycle_cloth)
    animation_selector.item_selected.connect(_select_animation)
    scale_selector.item_selected.connect(_select_scale)
    _update_loadout(rig.get_loadout_summary())


func set_animation(animation_name: String) -> void:
    var index := ANIMATIONS.find(animation_name)
    if index >= 0:
        animation_selector.select(index)
        rig.play_animation(animation_name)


func set_scale_multiplier(multiplier: int) -> void:
    var index := SCALES.find(multiplier)
    if index >= 0:
        scale_selector.select(index)
        rig.set_pixel_scale(multiplier)
        $DevelopmentPanel/Margin/VBox/ScaleRow/ScaleValue.text = "Escala actual: ×%d" % multiplier


func cycle_equipment(slot: String) -> void:
    match slot:
        "helmet":
            _cycle_helmet()
        "weapon":
            _cycle_weapon()
        "shield":
            _cycle_shield()
        "cloth":
            _cycle_cloth()


func get_validation_state() -> Dictionary:
    return rig.get_validation_state()


func _cycle_helmet() -> void:
    rig.cycle_helmet()


func _cycle_weapon() -> void:
    rig.cycle_weapon()


func _cycle_shield() -> void:
    rig.cycle_shield()


func _cycle_cloth() -> void:
    rig.cycle_cloth()


func _select_animation(index: int) -> void:
    rig.play_animation(ANIMATIONS[index])


func _select_scale(index: int) -> void:
    set_scale_multiplier(SCALES[index])


func _update_loadout(summary: String) -> void:
    loadout_label.text = summary


func _update_animation_caption(animation_name: String) -> void:
    $DevelopmentPanel/Margin/VBox/AnimationRow/AnimationValue.text = "Activa: %s" % animation_name
