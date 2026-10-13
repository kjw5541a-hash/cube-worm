extends SceneTree

func _initialize() -> void:
	# 실제 저장 파일을 건드리면 사용자가 고른 스킨이 날아간다. 테스트 전용 경로로 바꿔 끼우고 그 파일만 지운다.
	SaveData.PATH = "user://test_save_data.cfg"
	var abs_path := ProjectSettings.globalize_path(SaveData.PATH)
	DirAccess.remove_absolute(abs_path)
	_test_default_is_empty()
	_test_persists_across_reload()
	_test_garbage_content()
	_test_wrong_type_value()
	_test_muted()
	DirAccess.remove_absolute(abs_path)
	print("test_save_data: OK")
	quit()

func _test_default_is_empty() -> void:
	assert(SaveData.load_skin() == "", "저장한 적이 없으면 빈 문자열")

func _test_persists_across_reload() -> void:
	SaveData.save_skin("ringed")
	assert(SaveData.load_skin() == "ringed", "저장한 스킨을 다시 읽을 수 있어야 한다")
	SaveData.save_skin("block")
	assert(SaveData.load_skin() == "block", "다시 저장하면 덮어쓴다")

func _test_garbage_content() -> void:
	var f := FileAccess.open(SaveData.PATH, FileAccess.WRITE)
	f.store_string("이건 ConfigFile 형식이 아니다 {{{ ???")
	f.close()
	assert(SaveData.load_skin() == "", "손상된 파일이면 빈 문자열")
	SaveData.save_skin("jelly")
	assert(SaveData.load_skin() == "jelly", "손상된 파일 위에도 다시 저장할 수 있다")

func _test_wrong_type_value() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SaveData.SECTION, SaveData.SKIN_KEY, [1, 2, 3])
	cfg.save(SaveData.PATH)
	assert(SaveData.load_skin() == "", "문자열이 아닌 값이면 빈 문자열")

func _test_muted() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.PATH))
	assert(SaveData.load_muted() == false, "저장한 적이 없으면 소리는 켜짐")
	SaveData.save_muted(true)
	assert(SaveData.load_muted() == true, "끈 상태를 다시 읽을 수 있다")
	SaveData.save_skin("block")
	assert(SaveData.load_muted() == true and SaveData.load_skin() == "block", "스킨을 저장해도 소리 값이 지워지지 않는다")
	SaveData.save_muted(false)
	assert(SaveData.load_muted() == false and SaveData.load_skin() == "block", "소리를 저장해도 스킨이 지워지지 않는다")
	var cfg := ConfigFile.new()
	cfg.set_value(SaveData.SECTION, SaveData.MUTE_KEY, "yes")
	cfg.save(SaveData.PATH)
	assert(SaveData.load_muted() == false, "값이 엉뚱한 타입이면 켜짐")
	var f := FileAccess.open(SaveData.PATH, FileAccess.WRITE)
	f.store_string("{{{ 깨진 파일")
	f.close()
	assert(SaveData.load_muted() == false, "손상된 파일이면 켜짐")
