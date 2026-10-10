extends SceneTree

var _got: Array[int] = []

func _initialize() -> void:
	await _test_sits_above_the_controller()
	_test_change_wraps_and_announces()
	_test_set_index_is_silent_and_updates_the_label()
	_test_touch_zones()
	_test_keyboard_only_when_visible()
	print("test_skin_picker: OK")
	quit()

func _picker() -> SkinPicker:
	var p := SkinPicker.new()
	p.skin_changed.connect(func(i: int) -> void: _got.append(i))
	return p

func _host() -> Control:
	var host := Control.new()
	host.size = Vector2(720, 1280)
	root.add_child(host)
	return host

# 컨트롤러 영역(아래 400px) 바로 위에, 겹치지 않고 놓인다.
func _test_sits_above_the_controller() -> void:
	var host := _host()
	var p := _picker()
	host.add_child(p)
	await process_frame
	var r := p.get_rect()
	assert(absf(r.end.y - (1280.0 - Controller.HEIGHT - SkinPicker.GAP)) < 1.0, "컨트롤러 위 간격: %s" % r)
	assert(r.end.y <= 1280.0 - Controller.HEIGHT, "컨트롤러 영역과 겹치면 안 된다")
	assert(absf(r.size.y - SkinPicker.HEIGHT) < 1.0 and absf(r.size.x - (720.0 - 2.0 * SkinPicker.MARGIN)) < 1.0, "크기: %s" % r)
	host.queue_free()

func _test_change_wraps_and_announces() -> void:
	var p := _picker()
	_got.clear()
	p.change(1)
	p.change(1)
	p.change(1)
	assert(p.index == 0 and _got == ([1, 2, 0] as Array[int]), "다음으로 돌리면 끝에서 처음으로 이어진다: %s" % [_got])
	p.change(-1)
	assert(p.index == 2 and _got.back() == 2, "처음에서 이전으로 가면 끝으로")
	p.free()

func _test_set_index_is_silent_and_updates_the_label() -> void:
	var host := _host()
	var p := _picker()
	host.add_child(p)
	_got.clear()
	p.set_index(1)
	assert(_got.is_empty(), "set_index 는 신호가 없다")
	assert(p._label.text.contains(Skins.WORMS[1]["name"]), "이름이 보인다: %s" % p._label.text)
	p.set_index(4)
	assert(p.index == 1, "범위를 넘으면 돌려서 맞춘다")
	host.queue_free()

# 왼쪽 버튼 폭 안은 이전, 나머지(이름 자리와 오른쪽 버튼)는 다음.
func _test_touch_zones() -> void:
	var p := _picker()
	_got.clear()
	p.set_index(1)
	for x in [50.0, 620.0, 360.0]:
		var t := InputEventScreenTouch.new()
		t.pressed = true
		t.position = Vector2(x, 50)
		p._gui_input(t)
	assert(_got == ([0, 1, 2] as Array[int]), "왼쪽 이전, 오른쪽 다음, 가운데 다음: %s" % [_got])
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = Vector2(620, 50)
	p._gui_input(release)
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(620, 50)
	p._gui_input(drag)
	assert(_got.size() == 3, "손 뗌과 미끄러짐은 입력이 아니다")
	p.free()

func _test_keyboard_only_when_visible() -> void:
	var host := _host()
	var p := _picker()
	host.add_child(p)
	_got.clear()
	p.set_index(1)
	for key in [KEY_E, KEY_Q]:
		var k := InputEventKey.new()
		k.physical_keycode = key
		k.pressed = true
		p._unhandled_key_input(k)
	assert(_got == ([2, 1] as Array[int]), "E 다음, Q 이전: %s" % [_got])
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_E
	echo.pressed = true
	echo.echo = true
	p._unhandled_key_input(echo)
	assert(_got.size() == 2, "키 반복은 무시")
	p.visible = false
	var k2 := InputEventKey.new()
	k2.physical_keycode = KEY_E
	k2.pressed = true
	p._unhandled_key_input(k2)
	assert(_got.size() == 2, "줄이 안 보이면 키를 듣지 않는다")
	host.queue_free()
