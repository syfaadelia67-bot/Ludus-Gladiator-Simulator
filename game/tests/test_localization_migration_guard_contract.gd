extends SceneTree

const VISIBLE_LITERAL_PATTERNS: Array[String] = [
    ".text = \"",
    ".tooltip_text = \"",
    ".placeholder_text = \"",
    ".add_item(\"",
    "text = \"",
    "tooltip_text = \"",
    "placeholder_text = \""
]

func _initialize() -> void:
    var manifest_text := FileAccess.get_file_as_string("res://localization/localization_manifest.json")
    var parsed = JSON.parse_string(manifest_text)
    assert(parsed is Dictionary)
    var manifest: Dictionary = parsed
    var migrated_files: Array = manifest.get("migrated_files", [])
    assert(not migrated_files.is_empty())

    for path_value in migrated_files:
        var path := str(path_value)
        assert(FileAccess.file_exists(path))
        _assert_file_uses_translation_keys(path, FileAccess.get_file_as_string(path))

    print("Localization migrated-file literal guard contract: OK")
    quit()

func _assert_file_uses_translation_keys(path: String, source: String) -> void:
    var lines := source.split("\n")
    for line_index in range(lines.size()):
        var line := str(lines[line_index]).strip_edges()
        if line.is_empty() or line.begins_with("#") or line.contains("NO_TRANSLATE"):
            continue
        for pattern in VISIBLE_LITERAL_PATTERNS:
            if not line.contains(pattern):
                continue
            if _is_format_only_literal(line, pattern):
                continue
            push_error("Texto visible directo en %s:%d -> %s" % [path, line_index + 1, line])
            assert(false)

func _is_format_only_literal(line: String, pattern: String) -> bool:
    var start := line.find(pattern)
    if start < 0:
        return false
    start += pattern.length()
    var finish := line.find("\"", start)
    if finish < 0:
        return false
    var sanitized := line.substr(start, finish - start)
    sanitized = _strip_bbcode_tags(sanitized)
    for token in ["%s", "%d", "%f", "%+d", "%%", "\\n", "\\t", " ", "·", ":", "-", "—", "/", "(", ")", "[", "]", ",", "."]:
        sanitized = sanitized.replace(token, "")
    return sanitized.is_empty()

func _strip_bbcode_tags(value: String) -> String:
    var result := value
    while true:
        var opening := result.find("[")
        if opening < 0:
            return result
        var closing := result.find("]", opening)
        if closing < 0:
            return result
        result = result.substr(0, opening) + result.substr(closing + 1)
    return result
