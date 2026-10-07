extends SceneTree

# 웹 빌드에는 시스템 폰트가 없고 Godot 내장 폰트에는 한글이 없다. 프로젝트 폰트에 없는 글자는
# 폰에서 네모로 나온다(데스크톱은 OS 폰트로 대체돼 드러나지 않는다). 화면에 나갈 만한 글자를 전부 훑는다.
func _initialize() -> void:
	var path := str(ProjectSettings.get_setting("gui/theme/custom_font", ""))
	assert(path != "" and ResourceLoader.exists(path), "gui/theme/custom_font 가 비었거나 파일이 없다: %s" % path)
	var font: Font = load(path)
	var missing := {}
	for dir in ["res://scenes", "res://scripts"]:
		for name in DirAccess.get_files_at(dir):
			if not (name.ends_with(".tscn") or name.ends_with(".gd")):
				continue
			for c in _literal_chars("%s/%s" % [dir, name]):
				if not font.has_char(c.unicode_at(0)):
					missing[c] = name
	assert(missing.is_empty(), "폰트에 없는 글자가 문자열에 있다(네모로 나온다): %s" % missing)
	print("test_font: OK")
	quit()

# 큰따옴표 안의 글자만 모은다. 주석 줄은 화면에 나가지 않으므로 건너뛴다.
func _literal_chars(path: String) -> Dictionary:
	var out := {}
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var s := line.strip_edges()
		if s.begins_with("#") or s.begins_with(";"):
			continue
		var parts := line.split("\"")
		for i in range(1, parts.size(), 2):
			for c in parts[i]:
				out[c] = true
	return out
