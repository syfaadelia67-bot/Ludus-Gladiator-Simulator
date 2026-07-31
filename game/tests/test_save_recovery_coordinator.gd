extends Node

func _ready() -> void:
    var source := FileAccess.get_file_as_string("res://scripts/core/save_recovery_coordinator.gd")
    var notice_source := FileAccess.get_file_as_string("res://scripts/ui/save_recovery_notice_presenter.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")

    assert(source.contains("signal recovery_completed"))
    assert(source.contains("signal recovery_failed"))
    assert(source.contains("SaveManager.load_completed.connect"))
    assert(source.contains("CURRENT_SAVE_VERSION := 14"))
    assert(source.contains("loaded_path == BACKUP_PATH"))
    assert(source.contains("source_version < CURRENT_SAVE_VERSION"))
    assert(source.contains("DirAccess.remove_absolute"))
    assert(source.contains("call_deferred(\"_rewrite_loaded_campaign\")"))
    assert(source.contains("SaveManager.save_game()"))
    assert(source.contains("Campaña recuperada correctamente"))
    assert(source.contains("Campaña anterior actualizada correctamente"))

    assert(notice_source.contains("SaveRecoveryCoordinator.recovery_completed.connect"))
    assert(notice_source.contains("SaveRecoveryCoordinator.recovery_failed.connect"))
    assert(notice_source.contains("NOTICE_DURATION_SECONDS := 5.0"))
    assert(notice_source.contains("SaveRecoveryNotice"))
    assert(notice_source.contains("create_timer"))

    assert(project.contains("SaveRecoveryCoordinator=\"*res://scripts/core/save_recovery_coordinator.gd\""))
    assert(project.contains("SaveRecoveryNoticePresenter=\"*res://scripts/ui/save_recovery_notice_presenter.gd\""))
    assert(project.find("SaveManager=") < project.find("SaveRecoveryCoordinator="))
    assert(project.find("SaveRecoveryCoordinator=") < project.find("SaveRecoveryNoticePresenter="))

    print("Save recovery coordinator contract: OK")
    get_tree().quit()
