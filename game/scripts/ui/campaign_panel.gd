extends VBoxContainer

@onready var rank_label: Label = $Rank
@onready var next_rank_label: RichTextLabel = $NextRank
@onready var objectives: RichTextLabel = $Objectives
@onready var ending: RichTextLabel = $Ending

func _ready() -> void:
    CampaignManager.campaign_changed.connect(_refresh)
    CampaignManager.rank_promoted.connect(_on_rank_promoted)
    CampaignManager.objective_completed.connect(_on_objective_completed)
    CampaignManager.campaign_finished.connect(_on_campaign_finished)
    _refresh()

func _refresh() -> void:
    var summary := CampaignManager.get_summary()
    var rank: Dictionary = summary.get("rank", {})
    var next_rank: Dictionary = summary.get("next_rank", {})
    rank_label.text = "%s — Victorias %d | Derrotas %d" % [rank.get("name", "Ludus"), int(summary.get("wins", 0)), int(summary.get("losses", 0))]
    if next_rank.is_empty():
        next_rank_label.text = "[b]Rango máximo alcanzado[/b]"
    else:
        next_rank_label.text = "[b]Próximo rango: %s[/b]\nRequiere %d reputación, %d victorias y %d denarios.\nDesbloqueo: %s" % [next_rank.get("name", "Rango"), int(next_rank.get("reputation", 0)), int(next_rank.get("wins", 0)), int(next_rank.get("wealth", 0)), next_rank.get("unlock", "Contenido")]
    var lines: Array[String] = ["[b]Objetivos de campaña[/b]"]
    for objective in CampaignManager.get_objectives():
        var mark := "✓" if bool(objective.get("completed", false)) else "•"
        lines.append("%s %s — %d/%d\n  %s\n  Recompensa: %d denarios y %d reputación" % [mark, objective.get("title", "Objetivo"), int(objective.get("progress", 0)), int(objective.get("target", 1)), objective.get("description", ""), int(objective.get("reward_denarii", 0)), int(objective.get("reward_reputation", 0))])
    objectives.text = "\n\n".join(lines)
    if bool(summary.get("campaign_over", false)):
        ending.text = "[b]%s[/b]\n%s" % ["CAMPAÑA COMPLETADA" if bool(summary.get("victory", false)) else "CAMPAÑA PERDIDA", summary.get("defeat_reason", "El ludus aseguró su legado imperial.")]
    else:
        ending.text = "Meta final: 70 de reputación, 25 victorias y rango Ludus imperial."

func _on_rank_promoted(_rank_id: String) -> void:
    _refresh()

func _on_objective_completed(_objective: Dictionary) -> void:
    _refresh()

func _on_campaign_finished(_victory: bool, _reason: String) -> void:
    _refresh()