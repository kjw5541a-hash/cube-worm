extends SceneTree

# 시작 화면: 첫 터치로 방식 선택이 열리고, 버튼을 누르면 방식이 정해지며 사라진다.
func _initialize() -> void:
	assert(Title.Mode.CLASSIC == 0 and Title.Mode.TIME_ATTACK == 1, "버튼 순서가 열거 값과 같다")
	var title := Title.new()
	root.add_child(title)
	assert(title.visible and not title.in_menu and title.image.texture != null, "처음에는 그림만 보인다")
	assert(title.image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "그림이 화면을 채운다(비율 유지)")
	assert(title.buttons.size() == 2 and not title.box.visible and not title.shade.visible, "버튼과 어두운 띠는 아직 숨어 있다")
	var started := [0]
	var chosen: Array[int] = []
	title.started.connect(func() -> void: started[0] += 1)
	title.mode_chosen.connect(func(m: int) -> void: chosen.append(m))
	var release := InputEventScreenTouch.new()
	release.pressed = false
	title.image._gui_input(release)
	assert(started[0] == 0 and not title.in_menu, "손가락을 뗄 때는 시작하지 않는다")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	title.image._gui_input(tap)
	assert(title.visible and title.in_menu and started[0] == 1, "첫 터치로 방식 선택이 열리고 시작 신호가 한 번 온다")
	assert(title.box.visible and title.shade.visible, "방식 버튼과 어두운 띠가 보인다")
	title.image._gui_input(tap)
	assert(started[0] == 1 and chosen.is_empty(), "방식 선택 중 그림을 다시 터치해도 아무 일 없다")
	title.buttons[Title.Mode.TIME_ATTACK]._gui_input(release)
	assert(chosen.is_empty(), "버튼도 손가락을 뗄 때는 반응하지 않는다")
	title.buttons[Title.Mode.TIME_ATTACK]._gui_input(tap)
	assert(chosen == [Title.Mode.TIME_ATTACK] and not title.visible, "버튼을 누르면 그 방식이 정해지고 화면이 사라진다")
	title.show_menu()
	assert(title.visible and title.in_menu and started[0] == 1, "메뉴로 돌아오면 방식 선택이 다시 열린다(시작 신호는 다시 오지 않는다)")
	title.buttons[Title.Mode.CLASSIC]._gui_input(tap)
	assert(chosen == [Title.Mode.TIME_ATTACK, Title.Mode.CLASSIC], "다시 고를 수 있다")
	title.set_records(128, 42310)
	assert(title.buttons[Title.Mode.CLASSIC].record.text == "최고 점수 128", "기존 방식 버튼에 최고 점수")
	assert(title.buttons[Title.Mode.TIME_ATTACK].record.text == "최고 기록 42.31초", "타임어택 버튼에 최고 기록")
	title.set_records(0, 0)
	assert(title.buttons[Title.Mode.CLASSIC].record.text == "기록 없음" and title.buttons[Title.Mode.TIME_ATTACK].record.text == "기록 없음", "기록이 없으면 기록 없음")
	print("test_title: OK")
	quit()
