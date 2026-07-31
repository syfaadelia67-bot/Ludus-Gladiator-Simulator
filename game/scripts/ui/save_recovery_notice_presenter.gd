extends Node

const MAIN_SCENE_NAME := "Main"
const NOTICE_DURATION_SECONDS := 5.0

var notice_label: Label
var hide_timer: SceneTreeTimer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    SaveRecoveryCoordinator.recovery_completed.connect(_show_notice)
    SaveRecoveryCoordinator.recovery_failed.connect(_show_notice)

func _show_notice(message: String) -> void:
    if message.strip_edges().is_empty():
        return
    var scene := get_tree().current_scene
    if scene == null or scene.name != MAIN_SCENE_NAME:
        return
    _ensure_notice(scene)
    notice_label.text = message
    notice_label.visible = true
    hide_timer = get_tree().create_timer(NOTICE_DURATION_SECONDS, true, false, true)
    hide_timer.timeout.connect(_hide_notice)

func _ensure_notice(scene: Node) -> void:
    if notice_label != null and is_instance_valid(notice_label):
        return
    notice_label = Label.new()
    notice_label.name = "SaveRecoveryNotice"
    notice_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    notice_label.position = Vector2(-280, 22)
    notice_label.custom_minimum_size = Vector2(560, 54)
    notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    notice_label.z_index = 120
    notice_label.add_theme_font_size_override("font_size", 16)
    scene.add_child(notice_label)

func _hide_notice() -> void:
    if notice_label != null and is_instance_valid(notice_label):
        notice_label.visible = false
