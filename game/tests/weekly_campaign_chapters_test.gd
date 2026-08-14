extends Node


func run() -> void:
	assert(CampaignManager.CHAPTERS.size() == 3)
	assert(str(CampaignManager.get_chapter_for_month(1).get("id", "")) == "ruins")
	assert(str(CampaignManager.get_chapter_for_month(6).get("id", "")) == "ruins")
	assert(str(CampaignManager.get_chapter_for_month(7).get("id", "")) == "blood_reputation")
	assert(str(CampaignManager.get_chapter_for_month(12).get("id", "")) == "blood_reputation")
	assert(str(CampaignManager.get_chapter_for_month(13).get("id", "")) == "name_of_ludus")
	assert(str(CampaignManager.get_chapter_for_month(20).get("id", "")) == "name_of_ludus")
	assert(CampaignManager.DEMO_FINAL_MONTH == 20)
	assert(CampaignManager.DEMO_FINAL_WEEK == CampaignManager.DEMO_FINAL_MONTH)
	assert(CampaignManager.get_chapter_for_week(13) == CampaignManager.get_chapter_for_month(13))

	var expected_active_objectives := {
		"ruins": ["basic_preparation"],
		"blood_reputation": ["recognized_house", "trained_roster"],
		"name_of_ludus": ["demo_finale", "gt1_medal", "provincial_house"],
	}
	for chapter in CampaignManager.CHAPTERS:
		var chapter_id := str(chapter.get("id", ""))
		assert(not chapter_id.is_empty())
		var actual_ids: Array[String] = []
		for objective in CampaignManager.get_objectives(chapter_id):
			actual_ids.append(str(objective.get("id", "")))
		actual_ids.sort()
		var expected := expected_active_objectives.get(chapter_id, []) as Array
		expected.sort()
		assert(actual_ids == expected)

	print("monthly_campaign_chapters_test: OK")
