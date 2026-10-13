extends SceneTree

func _initialize() -> void:
	await _test_pop_rises_and_disappears()
	_test_sound_button()
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
