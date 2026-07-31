extends Node

func run() -> void:
    assert(CampaignManager.CHAPTERS.size() == 3)
    assert(str(CampaignManager.get_chapter_for_week(1).get("id", "")) == "ruins")
    assert(str(CampaignManager.get_chapter_for_week(6).get("id", "")) == "blood_reputation")
    assert(str(CampaignManager.get_chapter_for_week(12).get("id", "")) == "name_of_ludus")
    assert(str(CampaignManager.get_chapter_for_week(16).get("id", "")) == "name_of_ludus")
    assert(CampaignManager.DEMO_FINAL_WEEK == 16)

    for chapter in CampaignManager.CHAPTERS:
        var chapter_id := str(chapter.get("id", ""))
        assert(not chapter_id.is_empty())
        assert(CampaignManager.get_objectives(chapter_id).size() == 3)

    print("weekly_campaign_chapters_test: OK")