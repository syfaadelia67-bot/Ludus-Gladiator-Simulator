extends Node

const MAIN_SCENE_NAME := "Main"
const LOCKED_TOOLTIP := "La campaña terminó. Este control queda disponible solo durante una campaña activa."
const CONTROL_PATHS := [
    "Margin/VBox/TopButtons/AdvanceDay",
    "Margin/VBox/TopButtons/RefreshMarket",
    "Margin/VBox/Tabs/Mercado/BuyOffer",
    "Margin/VBox/Tabs/Forja/ForgePanel/CraftItem",
    "Margin/VBox/Tabs/Arena/Setup/StartDuel"
]

var banner: Label
var refresh_timer: Timer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    CampaignManager.campaign_changed.connect(_refresh)
    SaveManager.load_completed.connect(func(_path: String): call_deferred("_refresh"))
    call_deferred("_attach_when_ready")

func _attach_when_ready() -> void:
    for _attempt in range(60):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if scene != null and scene.name == MAIN_SCENE_NAME:
            _build_banner(scene)
            _build_refresh_timer()
            _refresh()
            return

func _build_banner(scene: Node) -> void:
    var top_buttons := scene.get_node_or_null("Margin/VBox/TopButtons") as HBoxContainer
    if top_buttons == null:
        return
    banner = Label.new()
    banner.name = "CompletedCampaignReadOnlyBanner"
    banner.text = "CAMPAÑA FINALIZADA · MODO CONSULTA"
    banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    banner.tooltip_text = "Podés revisar plantilla, inventario, calendario, historial y resultado final."
    top_buttons.add_child(banner)
    top_buttons.move_child(banner, 0)

func _build_refresh_timer() -> void:
    refresh_timer = Timer.new()
    refresh_timer.wait_time = 0.5
    refresh_timer.autostart = true
    refresh_timer.timeout.connect(_refresh)
    add_child(refresh_timer)

func _refresh() -> void:
    var scene := get_tree().current_scene
    if scene == null or scene.name != MAIN_SCENE_NAME:
        return
    var read_only := CampaignManager.campaign_over
    if banner != null:
        banner.visible = read_only
    for path in CONTROL_PATHS:
        var button := scene.get_node_or_null(path) as Button
        if button == null:
            continue
        button.disabled = read_only
        if read_only:
            button.tooltip_text = LOCKED_TOOLTIP
