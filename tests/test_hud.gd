extends SceneTree

func _initialize() -> void:
	await _test_pop_rises_and_disappears()
	_test_sound_button()
	_test_mode_display()
	_test_menu_button()
	_test_header_layout()
	_test_combo_line()
	print("test_hud: OK")
	quit()

# 먹은 점수 "+N" 은 위로 떠오르며 사라지고, 다 사라지면 스스로 지워진다.
func _test_pop_rises_and_disappears() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	await process_frame
	var label := hud.pop("+3", Vector2(360, 400), Color.RED)
	assert(label.text == "+3" and label.get_theme_color("font_color") == Color.RED, "점수 글자와 색")
	var y0 := label.position.y
	await create_timer(Tuning.POP_TIME * 0.5).timeout
	assert(label.position.y < y0 - 10.0, "위로 떠오른다: %f → %f" % [y0, label.position.y])
	await create_timer(Tuning.POP_TIME * 0.5 + 0.3).timeout
	assert(not is_instance_valid(label), "다 떠오르면 사라진다")
	hud.queue_free()

func _test_sound_button() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	var got: Array[bool] = []
	hud.sound_toggled.connect(func(m: bool) -> void: got.append(m))
	assert(hud.sound_button != null and not hud.sound_button.muted, "처음에는 소리 켜짐")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	hud.sound_button._gui_input(tap)
	assert(hud.sound_button.muted and got == [true], "누르면 꺼지고 신호가 한 번 온다")
	hud.sound_button._gui_input(tap)
	assert(not hud.sound_button.muted and got == [true, false], "다시 누르면 켜진다")
	hud.set_muted(true)
	assert(hud.sound_button.muted and got == [true, false], "set_muted 는 신호를 내지 않는다(저장된 값을 반영할 때 쓴다)")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	hud.sound_button._gui_input(release)
	assert(hud.sound_button.muted, "손가락을 뗄 때는 바뀌지 않는다")
	var turn_xs: Array = hud.get_children().filter(func(n: Node) -> bool: return n is Hud.TurnButton).map(func(b: Control) -> float: return b.position.x)
	assert(turn_xs.size() == 2 and hud.sound_button.position.x < turn_xs.min(), "소리 버튼은 회전 버튼들 왼쪽에 있다")
	hud.queue_free()

# 방식별 표시: 기존 방식은 점수와 레벨, 타임어택은 타이머·남은 벌레·최고 시간.
func _test_mode_display() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	hud.set_mode(Title.Mode.CLASSIC)
	assert(hud.score_label.visible and not hud.timer_label.visible and not hud.bugs_label.visible, "기존 방식은 점수만 보인다")
	hud.set_level(3)
	assert(hud.level_label.text == "레벨 3", "레벨 글자")
	hud.set_best_score(128)
	assert(hud.best_label.text == "최고 128", "최고 점수")
	hud.set_best_score(0)
	assert(hud.best_label.text == "최고 --", "기록이 없으면 최고 --")
	hud.set_mode(Title.Mode.TIME_ATTACK)
	assert(not hud.score_label.visible and hud.timer_label.visible and hud.bugs_label.visible, "타임어택은 타이머와 남은 벌레가 보이고 점수는 숨는다")
	assert(hud.level_label.text == "타임어택", "가운데 글자")
	hud.set_timer(12.34)
	assert(hud.timer_label.text == "12.3", "타이머는 소수 첫째 자리: %s" % hud.timer_label.text)
	hud.set_timer(0.0)
	assert(hud.timer_label.text == "0.0", "출발 전 타이머")
	hud.set_bugs_left(6)
	assert(hud.bugs_label.text == "남은 벌레 6", "남은 벌레")
	hud.set_best_time(42310)
	assert(hud.best_label.text == "최고 42.31초", "최고 시간은 소수 둘째 자리")
	hud.set_best_time(0)
	assert(hud.best_label.text == "최고 --", "기록이 없으면 최고 --")
	hud.set_clear_text("a\nb")
	assert(hud.clear_label.text == "a\nb", "클리어 문구를 바꾼다")
	hud.set_mode(Title.Mode.CLASSIC)
	assert(hud.clear_label.text == Hud.CLEAR_TEXT and hud.score_label.visible and not hud.timer_label.visible, "기존 방식으로 돌아오면 클리어 문구와 점수가 돌아온다")
	assert(hud.level_label.position.x == Hud.HEADER_X and hud.best_label.position.x == Hud.HEADER_X, "가운데 글자는 점수·타이머와 오른쪽 버튼 사이에 놓는다")
	hud.queue_free()

func _test_menu_button() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	var got := [0]
	hud.menu_pressed.connect(func() -> void: got[0] += 1)
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	hud.menu_button._gui_input(tap)
	assert(got[0] == 1, "메뉴 버튼을 누르면 신호가 온다")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	hud.menu_button._gui_input(release)
	assert(got[0] == 1, "손가락을 뗄 때는 신호가 없다")
	assert(hud.menu_button.position.x < 100.0 and hud.menu_button.position.y > hud.score_label.position.y + 100.0, "메뉴 버튼은 왼쪽 위, 점수 아래에 있다")
	hud.queue_free()

# 왼쪽 위 빌드 문구(info)는 길어서 가운데 글자 자리까지 뻗는다. 가운데 레벨·최고 글자는 세로로 비켜 겹치지 않아야 하고,
# 왼쪽 열(빌드 문구 → 남은 벌레 → 메뉴 버튼)도 위아래로 이어져야 한다. 라벨 상자 높이로 잰다(상자 안 여백만큼 2~6px 겹침은 눈에 안 띈다).
func _test_header_layout() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	hud.set_level(5)
	hud.set_mode(Title.Mode.TIME_ATTACK)
	hud.set_best_time(42310)
	hud.set_bugs_left(9)
	hud._process(0.0)  # 빌드 문구를 채운다
	var level_bottom: float = hud.level_label.position.y + hud.level_label.get_combined_minimum_size().y
	var best_bottom: float = hud.best_label.position.y + hud.best_label.get_combined_minimum_size().y
	var info_bottom: float = hud.info_label.position.y + hud.info_label.get_combined_minimum_size().y
	var bugs_bottom: float = hud.bugs_label.position.y + hud.bugs_label.get_combined_minimum_size().y
	assert(level_bottom <= hud.best_label.position.y + 6.0, "레벨 글자 아래 끝(%f)이 최고 글자 위(%f) 바로 위에 이어진다" % [level_bottom, hud.best_label.position.y])
	assert(best_bottom <= hud.info_label.position.y + 2.0, "최고 글자 아래 끝(%f)이 빌드 문구 위(%f)보다 위에 있다" % [best_bottom, hud.info_label.position.y])
	assert(hud.bugs_label.position.y >= info_bottom - 4.0, "남은 벌레(위 %f)는 빌드 문구(아래 끝 %f) 아래" % [hud.bugs_label.position.y, info_bottom])
	assert(hud.menu_button.position.y >= bugs_bottom - 4.0, "메뉴 버튼(위 %f)은 남은 벌레(아래 끝 %f) 아래" % [hud.menu_button.position.y, bugs_bottom])
	hud.set_mode(Title.Mode.CLASSIC)
	hud.set_combo(5, 1.0)
	var combo_size: Vector2 = hud.combo_label.get_combined_minimum_size()
	var combo_bottom: float = hud.combo_label.position.y + combo_size.y
	assert(hud.combo_label.position.y >= info_bottom - 4.0, "콤보 줄(위 %f)은 빌드 문구(아래 끝 %f) 아래" % [hud.combo_label.position.y, info_bottom])
	assert(hud.menu_button.position.y >= combo_bottom - 4.0, "메뉴 버튼(위 %f)은 콤보 줄(아래 끝 %f) 아래" % [hud.menu_button.position.y, combo_bottom])
	assert(hud.combo_bar.position.y >= hud.combo_label.position.y and hud.combo_bar.position.y + hud.combo_bar.size.y <= combo_bottom, "막대는 글자 높이 안에 들어간다")
	assert(hud.combo_bar.position.x >= hud.combo_label.position.x + combo_size.x, "막대는 글자 오른쪽에 있다")
	hud.queue_free()

# 콤보 줄: 다음 벌레에 붙을 배율 글자와 남은 시간 막대. 시간이 없으면 숨고, 방식을 바꿀 때도 숨은 채로 시작한다.
func _test_combo_line() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	assert(not hud.combo_label.visible and not hud.combo_bar.visible, "처음에는 콤보 줄이 숨어 있다")
	assert(hud.combo_bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "막대는 터치를 막지 않는다")
	hud.set_combo(2, 1.0)
	assert(hud.combo_label.visible and hud.combo_bar.visible and hud.combo_label.text == "×2", "배율 글자: %s" % hud.combo_label.text)
	assert(is_equal_approx(hud.combo_bar.size.x, Hud.COMBO_BAR_W), "시간이 꽉 차면 막대도 꽉 찬다")
	hud.set_combo(5, 0.25)
	assert(hud.combo_label.text == "×5" and is_equal_approx(hud.combo_bar.size.x, Hud.COMBO_BAR_W * 0.25), "막대 폭이 남은 시간을 따른다")
	hud.set_combo(3, 1.7)
	assert(is_equal_approx(hud.combo_bar.size.x, Hud.COMBO_BAR_W), "비율이 1 을 넘어도 막대는 넘치지 않는다")
	hud.set_combo(3, 0.0)
	assert(not hud.combo_label.visible and not hud.combo_bar.visible, "시간이 다하면 숨긴다")
	hud.set_combo(2, 0.5)
	hud.set_mode(Title.Mode.TIME_ATTACK)
	assert(not hud.combo_label.visible and not hud.combo_bar.visible, "타임어택으로 바꾸면 숨긴 채로 시작한다")
	hud.set_combo(2, 0.5)
	hud.set_mode(Title.Mode.CLASSIC)
	assert(not hud.combo_label.visible and not hud.combo_bar.visible, "기존 방식으로 바꿔도 숨긴 채로 시작한다")
	hud.queue_free()
