extends SceneTree

func _initialize() -> void:
	var default_path: String = SaveData.PATH  # 이름 고정 테스트가 기본 경로를 봐야 하므로 바꿔 끼우기 전에 적어 둔다
	# 실제 저장 파일을 건드리면 사용자가 고른 스킨이 날아간다. 테스트 전용 경로로 바꿔 끼우고 그 파일만 지운다.
	SaveData.PATH = "user://test_save_data.cfg"
	var abs_path := ProjectSettings.globalize_path(SaveData.PATH)
	DirAccess.remove_absolute(abs_path)
	_test_default_is_empty()
	_test_persists_across_reload()
	_test_garbage_content()
	_test_wrong_type_value()
	_test_muted()
	_test_best_score()
	_test_best_time()
	_test_old_format_file_keeps_working()
	_test_names_are_pinned(default_path)
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

func _reset() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.PATH))

func _test_best_score() -> void:
	_reset()
	assert(SaveData.load_best_score() == 0, "저장한 적이 없으면 기록 없음(0)")
	assert(SaveData.save_best_score(12), "첫 기록은 저장된다")
	assert(SaveData.load_best_score() == 12, "저장한 점수를 읽는다")
	assert(not SaveData.save_best_score(12) and not SaveData.save_best_score(7), "같거나 낮은 점수는 저장하지 않는다")
	assert(SaveData.load_best_score() == 12, "나쁜 값을 넘겨도 기록이 내려가지 않는다")
	assert(SaveData.save_best_score(20) and SaveData.load_best_score() == 20, "더 높으면 갱신한다")
	assert(not SaveData.save_best_score(0) and not SaveData.save_best_score(-5), "0 이하는 저장하지 않는다")
	var cfg := ConfigFile.new()
	cfg.set_value(SaveData.SECTION, SaveData.SCORE_KEY, "많이")
	cfg.save(SaveData.PATH)
	assert(SaveData.load_best_score() == 0, "정수가 아니면 기록 없음")
	cfg.set_value(SaveData.SECTION, SaveData.SCORE_KEY, -4)
	cfg.save(SaveData.PATH)
	assert(SaveData.load_best_score() == 0, "1 미만이면 기록 없음")
	var f := FileAccess.open(SaveData.PATH, FileAccess.WRITE)
	f.store_string("{{{ 깨진 파일")
	f.close()
	assert(SaveData.load_best_score() == 0, "손상된 파일이면 기록 없음")
	assert(SaveData.save_best_score(3) and SaveData.load_best_score() == 3, "손상된 파일 위에도 다시 저장할 수 있다")

func _test_best_time() -> void:
	_reset()
	const L := "8-1-1"
	assert(SaveData.load_best_time_ms(L) == 0, "저장한 적이 없으면 기록 없음")
	assert(SaveData.save_best_time_ms(42310, L), "첫 기록은 저장된다")
	assert(SaveData.load_best_time_ms(L) == 42310, "저장한 시간을 읽는다")
	assert(not SaveData.save_best_time_ms(42310, L) and not SaveData.save_best_time_ms(50000, L), "같거나 느린 시간은 저장하지 않는다")
	assert(SaveData.load_best_time_ms(L) == 42310, "나쁜 값을 넘겨도 기록이 올라가지 않는다")
	assert(SaveData.save_best_time_ms(41800, L) and SaveData.load_best_time_ms(L) == 41800, "더 빠르면 갱신한다")
	assert(not SaveData.save_best_time_ms(0, L) and not SaveData.save_best_time_ms(-1, L), "0 이하는 저장하지 않는다")
	assert(SaveData.load_best_time_ms("8-2-1") == 0, "배치가 다르면 다른 판의 기록이라 기록 없음")
	assert(SaveData.save_best_time_ms(60000, "8-2-1") and SaveData.load_best_time_ms("8-2-1") == 60000, "다른 배치의 첫 기록은 옛 기록보다 느려도 저장된다")
	assert(SaveData.load_best_time_ms(L) == 0, "배치가 바뀌었으니 옛 배치 기록은 덮어쓰였다")
	var cfg := ConfigFile.new()
	cfg.set_value(SaveData.SECTION, SaveData.TIME_KEY, "빠름")
	cfg.set_value(SaveData.SECTION, SaveData.LAYOUT_KEY, L)
	cfg.save(SaveData.PATH)
	assert(SaveData.load_best_time_ms(L) == 0, "시간이 정수가 아니면 기록 없음")
	cfg.set_value(SaveData.SECTION, SaveData.TIME_KEY, 5000)
	cfg.set_value(SaveData.SECTION, SaveData.LAYOUT_KEY, 7)
	cfg.save(SaveData.PATH)
	assert(SaveData.load_best_time_ms(L) == 0, "배치 이름이 문자열이 아니면 기록 없음")
	var f := FileAccess.open(SaveData.PATH, FileAccess.WRITE)
	f.store_string("{{{ 깨진 파일")
	f.close()
	assert(SaveData.load_best_time_ms(L) == 0, "손상된 파일이면 기록 없음")
	assert(SaveData.save_best_time_ms(30000, L) and SaveData.load_best_time_ms(L) == 30000, "손상된 파일 위에도 다시 저장할 수 있다")

# 옛 형식 파일(스킨·소리만 있던 때)을 그대로 읽고, 기록을 써도 옛 값이 남는다. 업데이트해도 설정이 유지돼야 한다.
func _test_old_format_file_keeps_working() -> void:
	var f := FileAccess.open(SaveData.PATH, FileAccess.WRITE)
	f.store_string("[progress]\n\nworm_skin=\"block\"\nsound_muted=true\n")
	f.close()
	assert(SaveData.load_skin() == "block" and SaveData.load_muted(), "옛 형식 파일의 스킨·소리를 읽는다")
	assert(SaveData.load_best_score() == 0 and SaveData.load_best_time_ms("8-1-1") == 0, "기록 키가 없으면 기록 없음")
	assert(SaveData.save_best_score(9) and SaveData.save_best_time_ms(30500, "8-1-1"), "옛 파일에 기록을 쓴다")
	assert(SaveData.load_skin() == "block" and SaveData.load_muted(), "기록을 써도 스킨·소리가 남는다")
	assert(SaveData.load_best_score() == 9 and SaveData.load_best_time_ms("8-1-1") == 30500, "기록을 읽는다")
	SaveData.save_skin("jelly")
	SaveData.save_muted(false)
	assert(SaveData.load_best_score() == 9 and SaveData.load_best_time_ms("8-1-1") == 30500, "스킨·소리를 저장해도 기록이 남는다")
	f = FileAccess.open(SaveData.PATH, FileAccess.WRITE)
	f.store_string("[progress]\n\nworm_skin=\"jelly\"\nsound_muted=false\nbest_score=128\nbest_time_ms=42310\nbest_time_layout=\"8-1-1\"\n")
	f.close()
	assert(SaveData.load_best_score() == 128 and SaveData.load_best_time_ms("8-1-1") == 42310, "글자 그대로 적은 새 형식 파일을 읽는다")

# 저장 파일 경로·칸·키·프로젝트 이름이 바뀌면 이미 저장된 기록이 읽히지 않는다(재배포해도 기록이 사라지는 사고).
# 바꿀 일이 생기면 옛 이름을 읽어 새 이름으로 옮기는 코드를 먼저 넣고 이 테스트를 고칠 것.
func _test_names_are_pinned(default_path: String) -> void:
	assert(default_path == "user://cube_worm_save.cfg", "저장 파일 경로: %s" % default_path)
	assert(SaveData.SECTION == "progress", "저장 칸")
	assert(SaveData.SKIN_KEY == "worm_skin" and SaveData.MUTE_KEY == "sound_muted", "스킨·소리 키")
	assert(SaveData.SCORE_KEY == "best_score" and SaveData.TIME_KEY == "best_time_ms" and SaveData.LAYOUT_KEY == "best_time_layout", "기록 키")
	assert(str(ProjectSettings.get_setting("application/config/name")) == "큐브 지렁이", "프로젝트 이름(사용자 데이터 폴더가 여기서 나온다)")
