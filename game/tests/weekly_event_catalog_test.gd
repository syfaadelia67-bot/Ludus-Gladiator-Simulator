extends Node

# Lightweight catalog validation that can be executed from a headless test scene.
# It avoids mutating the live campaign state.
func run() -> Array[String]:
    var failures: Array[String] = []
    var required_chapters := ["ruins", "blood_reputation", "name_of_ludus"]
    var coverage := {"ruins":0, "blood_reputation":0, "name_of_ludus":0}

    for event_id in EventManager.EVENTS.keys():
        var event: Dictionary = EventManager.EVENTS[event_id]
        if str(event.get("title", "")).is_empty():
            failures.append("%s no tiene título" % event_id)
        if event.get("choices", []).size() < 2:
            failures.append("%s debe ofrecer al menos dos decisiones" % event_id)
        if int(event.get("cooldown_weeks", 0)) < 1:
            failures.append("%s no define cooldown semanal" % event_id)
        for chapter_id in event.get("chapters", []):
            if coverage.has(chapter_id):
                coverage[chapter_id] = int(coverage[chapter_id]) + 1
            else:
                failures.append("%s referencia un capítulo inexistente: %s" % [event_id, chapter_id])
        for choice in event.get("choices", []):
            if str(choice.get("id", "")).is_empty() or str(choice.get("label", "")).is_empty():
                failures.append("%s contiene una decisión incompleta" % event_id)

    for chapter_id in required_chapters:
        if int(coverage.get(chapter_id, 0)) < 3:
            failures.append("El capítulo %s necesita al menos tres eventos elegibles" % chapter_id)

    return failures
