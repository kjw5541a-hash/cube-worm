extends SceneTree

func _initialize() -> void:
	_test_files_exist_and_load()
	_test_combo_pitch()
	_test_steer_id()
	_test_play_and_mute()
	_test_pool_overflow()
	_test_eat_combo()
	_test_music()
	print("test_audio: OK")
	quit()

func _sfx() -> Sfx:
	var s := Sfx.new()
	root.add_child(s)
	return s

func _test_files_exist_and_load() -> void:
	var names: Array[String] = []
	names.append_array(Sfx.NAMES)
	names.append(Sfx.MUSIC)
	assert(names.size() == 12, "효과음 11개 + BGM")
	for n in names:
		assert(load("res://assets/audio/%s.ogg" % n) is AudioStreamOggVorbis, "소리 파일이 불러와진다: %s" % n)

func _test_combo_pitch() -> void:
	assert(Sfx.combo_pitch(0) == 1.0, "0 단계는 원래 음")
	assert(is_equal_approx(Sfx.combo_pitch(1), pow(2.0, 2.0 / 12.0)), "한 단계는 온음(반음 두 개) 위")
	assert(Sfx.combo_pitch(2) > Sfx.combo_pitch(1), "단계가 오를수록 높다")
	assert(Sfx.combo_pitch(99) == Sfx.combo_pitch(Sfx.COMBO_MAX), "최대 단계에서 멈춘다")
	assert(Sfx.combo_pitch(-3) == 1.0, "음수 단계는 원래 음")

func _test_steer_id() -> void:
	assert(Sfx.steer_id(Worm.Steer.LEFT) == "turn" and Sfx.steer_id(Worm.Steer.RIGHT) == "turn")
	assert(Sfx.steer_id(Worm.Steer.UP) == "up" and Sfx.steer_id(Worm.Steer.DOWN) == "down")

func _test_play_and_mute() -> void:
	var s := _sfx()
	s.play("turn")
	assert(s.plays == 1 and s.last_id == "turn" and s.last_pitch == 1.0, "켜짐 상태에서는 재생 기록이 남는다")
	s.set_muted(true)
	s.play("turn")
	s.play_eat(0)
	s.start_music()
	assert(s.plays == 1 and not s.music_active, "꺼짐 상태에서는 아무 소리도 내지 않는다(오류도 없다)")
	s.queue_free()

func _test_pool_overflow() -> void:
	var s := _sfx()
	for i in Sfx.POOL * 3:
		s.play("eat_0")
	assert(s.plays == Sfx.POOL * 3, "풀보다 많이 연달아 불러도 오류 없이 돌려 쓴다")
	s.queue_free()

func _test_eat_combo() -> void:
	var s := _sfx()
	s.play_eat(1, 100.0)
	assert(s.last_id == "eat_1" and s.last_pitch == 1.0, "첫 먹기는 원래 음")
	s.play_eat(1, 101.0)
	assert(is_equal_approx(s.last_pitch, Sfx.combo_pitch(1)), "2초 안에 이어 먹으면 한 단계 위")
	s.play_eat(2, 102.5)
	assert(is_equal_approx(s.last_pitch, Sfx.combo_pitch(2)) and s.last_id == "eat_2", "계속 이으면 한 단계 더(종류는 그대로 따른다)")
	for i in 10:
		s.play_eat(0, 103.0 + i)
	assert(is_equal_approx(s.last_pitch, Sfx.combo_pitch(Sfx.COMBO_MAX)), "최대 단계를 넘지 않는다")
	s.play_eat(0, 200.0)
	assert(s.last_pitch == 1.0, "2초 넘게 쉬면 처음으로 돌아간다")
	s.queue_free()

func _test_music() -> void:
	var s := _sfx()
	s.start_music()
	assert(s.music_active and s.music.stream.loop, "BGM 이 시작되고 반복한다")
	var count := s.music_starts
	s.start_music()
	assert(s.music_starts == count, "이미 재생 중이면 다시 시작하지 않는다")
	s.set_muted(true)
	assert(not s.music_active, "끄면 BGM 이 멈춘다")
	s.set_muted(false)
	assert(s.music_active, "켜면 BGM 이 이어서 시작한다")
	s.duck(true)
	var ducked := s.music.volume_db
	s.duck(false)
	assert(ducked < s.music.volume_db, "죽은 뒤에는 BGM 이 작아진다")
	s.queue_free()
