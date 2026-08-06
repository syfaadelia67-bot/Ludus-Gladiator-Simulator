extends Node

func run() -> void:
    var inspector := FileAccess.get_file_as_string("res://scripts/core/save_compatibility_inspector.gd")
    var start_screen := FileAccess.get_file_as_string("res://scripts/ui/start_screen_controller.gd")

    for field in ["campaign_over", "victory", "wins", "losses", "defeat_reason"]:
        assert(inspector.contains('"%s"' % field))
    assert(start_screen.contains("START_VIEW_FINAL_RESULT"))
    assert(start_screen.contains("START_CAMPAIGN_FINISHED_SUMMARY"))
    assert(start_screen.contains("START_RESULT_VICTORY"))
    assert(start_screen.contains("START_RESULT_DEFEAT"))
    assert(start_screen.contains('metadata.get("campaign_over", false)'))
    assert(start_screen.contains('metadata.get("wins", 0)'))
    assert(start_screen.contains('metadata.get("losses", 0)'))
    print("Localized completed campaign summary contract: OK")
