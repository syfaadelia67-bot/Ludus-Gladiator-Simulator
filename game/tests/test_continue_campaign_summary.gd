extends Node

func run() -> void:
    var source := FileAccess.get_file_as_string("res://scripts/ui/start_screen_controller.gd")

    assert(source.contains("func _format_save_summary"))
    assert(source.contains("owner_name"))
    assert(source.contains("owner_title"))
    assert(source.contains("START_ACTIVE_CAMPAIGN_SUMMARY"))
    assert(source.contains("START_CAMPAIGN_FINISHED_SUMMARY"))
    assert(source.contains("START_RESULT_VICTORY"))
    assert(source.contains("START_RESULT_DEFEAT"))
    assert(source.contains("CHAPTER_1_NAME"))
    assert(source.contains("CHAPTER_2_NAME"))
    assert(source.contains("CHAPTER_3_NAME"))
    assert(source.contains("BATTLE_DEMO_FINAL"))
    assert(source.contains("BATTLE_OFFICIAL_TOURNAMENT"))
    assert(source.contains("BATTLE_BEAST_HUNT"))
    assert(source.contains("BATTLE_UNDERGROUND"))
    assert(source.contains("BATTLE_WEEKLY_EXHIBITION"))
    assert(source.contains("SAVE_COMPATIBILITY_INSPECTOR"))
    assert(source.contains("func _inspect_save"))
    assert(source.contains("save_inspection.get(\"loadable\""))
    assert(source.contains("save_inspection.get(\"message\""))
    assert(source.contains("save_inspection.get(\"metadata\""))

    print("Continue campaign summary contract: OK")
