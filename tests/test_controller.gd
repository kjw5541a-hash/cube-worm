extends SceneTree

var _got: Array[int] = []
var _turns: Array[int] = []

func _initialize() -> void:
	_test_sectors()
	_test_dead_zone()
	_test_touch_emits_direction()
	_test_two_fingers_in_order()
	_test_drag_is_not_input()
	_test_keyboard_hexagon()
	await _test_diamond_matches_box_top()
	print("test_controller: OK")
	quit()

func _controller() -> Controller:
	var c := Controller.new()
	c.size = Vector2(720, Controller.HEIGHT)
	c.direction_pressed.connect(func(i: int) -> void: _got.append(i))
	c.turn_pressed.connect(func(d: int) -> void: _turns.append(d))
	return c

func _test_sectors() -> void:
	var c := _controller()
	for i in 6:
		for off in [-25.0, 0.0, 25.0]:
			var a := deg_to_rad(30.0 + 60.0 * i + off)
			var p := Vector2(cos(a), -sin(a)) * Controller.RING
			assert(c.sector_at(p) == i, "버튼 %d 쪽 %f° 를 눌렀는데 %d" % [i, off, c.sector_at(p)])
	c.free()

func _test_dead_zone() -> void:
	var c := _controller()
	for p in [Vector2.ZERO, Vector2(60, 0), Vector2(-60, 0), Vector2(0, 40), Vector2(0, -40)]:
		assert(c.sector_at(p) == -1, "마름모 안은 무시해야 한다: %s" % p)
	assert(c.sector_at(Vector2(0, -120)) == 1, "마름모 바로 위는 ▲")
	c.free()

func _test_touch_emits_direction() -> void:
	var c := _controller()
	_got.clear()
	for i in 6:
		var t := InputEventScreenTouch.new()
		t.pressed = true
		t.position = c.center() + Controller.button_dir(i) * Controller.RING
		c._gui_input(t)
	assert(_got == ([0, 1, 2, 3, 4, 5] as Array[int]), "버튼마다 자기 방향: %s" % [_got])
	var inside := InputEventScreenTouch.new()
	inside.pressed = true
	inside.position = c.center()
	c._gui_input(inside)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = c.center() + Controller.button_dir(0) * Controller.RING
	c._gui_input(release)
	assert(_got.size() == 6, "마름모 안 터치와 손 뗌은 입력이 아니다")
	c.free()

func _test_two_fingers_in_order() -> void:
	var c := _controller()
	_got.clear()
	for pair in [[0, 3], [1, 5]]:
		var t := InputEventScreenTouch.new()
		t.index = pair[0]
		t.pressed = true
		t.position = c.center() + Controller.button_dir(pair[1]) * Controller.RING
		c._gui_input(t)
	assert(_got == ([3, 5] as Array[int]), "두 손가락은 닿은 순서대로: %s" % [_got])
	c.free()

func _test_drag_is_not_input() -> void:
	var c := _controller()
	_got.clear()
	var d := InputEventScreenDrag.new()
	d.position = c.center() + Controller.button_dir(0) * Controller.RING
	c._gui_input(d)
	assert(_got.is_empty(), "누른 채 미끄러지는 것은 새 입력이 아니다")
	c.free()

func _test_keyboard_hexagon() -> void:
	var c := _controller()
	_got.clear()
	_turns.clear()
	for key in [KEY_E, KEY_W, KEY_Q, KEY_A, KEY_S, KEY_D, KEY_LEFT, KEY_RIGHT]:
		var k := InputEventKey.new()
		k.physical_keycode = key
		k.pressed = true
		c._unhandled_key_input(k)
	assert(_got == ([0, 1, 2, 3, 4, 5] as Array[int]), "QWE/ASD 육각 배치: %s" % [_got])
	assert(_turns == ([-1, 1] as Array[int]), "← 반시계, → 시계")
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_E
	echo.pressed = true
	echo.echo = true
	c._unhandled_key_input(echo)
	assert(_got.size() == 6, "키를 누르고 있어 반복되는 입력은 무시")
	c.free()

# 마름모가 실제 카메라로 본 상자 윗면과 같은 모양인지(배율만 다름) 회전 4단계 모두 본다.
func _test_diamond_matches_box_top() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	root.add_child(view)
	var rig := CameraRig.new()
	rig.position = Vector3(4, 4, 4)
	view.add_child(rig)
	rig.camera.make_current()
	var c := _controller()
	c.rig = rig
	var top := Vector3(4, 8, 4)
	for step in 4:
		rig.rotation_degrees.y = CameraRig.YAW_BASE_DEG + 90.0 * step
		await process_frame
		var o := rig.camera.unproject_position(top)
		var d := c.diamond()
		var signs := [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]
		var scale := -1.0
		for k in 4:
			var q := rig.camera.unproject_position(top + Vector3(4 * signs[k].x, 0, 4 * signs[k].y)) - o
			assert(q.normalized().distance_to(d[k].normalized()) < 0.01, "시점 %d 꼭짓점 %d 방향이 다르다: %s vs %s" % [step, k, q, d[k]])
			var r := q.length() / d[k].length()
			if scale < 0.0:
				scale = r
			assert(absf(r - scale) < 0.01 * scale, "마름모 비율이 상자 윗면과 다르다")
	view.queue_free()
	c.free()
