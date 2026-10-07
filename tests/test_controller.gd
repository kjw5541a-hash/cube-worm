extends SceneTree

const L := Worm.Steer.LEFT
const R := Worm.Steer.RIGHT
const U := Worm.Steer.UP
const D := Worm.Steer.DOWN

var _got: Array[int] = []
var _turns: Array[int] = []

func _initialize() -> void:
	_test_pad_layout()
	_test_sectors()
	_test_dead_zone()
	_test_touch_emits_steer()
	_test_two_fingers_in_order()
	_test_drag_is_not_input()
	_test_keyboard()
	print("test_controller: OK")
	quit()

func _controller() -> Controller:
	var c := Controller.new()
	c.size = Vector2(720, Controller.HEIGHT)
	c.steer_pressed.connect(func(s: int) -> void: _got.append(s))
	c.turn_pressed.connect(func(d: int) -> void: _turns.append(d))
	return c

# 십자 패드: 화면에서 보이는 방향 그대로의 조향이어야 한다 — 오른쪽 버튼 = 오른쪽으로 꺾기, 위 버튼 = 위로.
func _test_pad_layout() -> void:
	assert(Controller.PAD == ([R, U, L, D] as Array[int]), "패드 칸 0~3 은 오른쪽·위·왼쪽·아래 순서")
	assert(Controller.button_dir(0).is_equal_approx(Vector2(1, 0)), "칸 0 은 화면 오른쪽")
	assert(Controller.button_dir(1).is_equal_approx(Vector2(0, -1)), "칸 1 은 화면 위")
	assert(Controller.button_dir(2).is_equal_approx(Vector2(-1, 0)), "칸 2 는 화면 왼쪽")
	assert(Controller.button_dir(3).is_equal_approx(Vector2(0, 1)), "칸 3 은 화면 아래")

func _test_sectors() -> void:
	var c := _controller()
	for i in 4:
		for off in [-40.0, 0.0, 40.0]:
			var a := deg_to_rad(90.0 * i + off)
			var p := Vector2(cos(a), -sin(a)) * Controller.RING
			assert(c.sector_at(p) == i, "버튼 %d 쪽 %f° 를 눌렀는데 %d" % [i, off, c.sector_at(p)])
	c.free()

func _test_dead_zone() -> void:
	var c := _controller()
	for p in [Vector2.ZERO, Vector2(30, 0), Vector2(-30, 0), Vector2(0, 30), Vector2(0, -30)]:
		assert(c.sector_at(p) == -1, "가운데 죽은 영역은 무시해야 한다: %s" % p)
	assert(c.sector_at(Vector2(0, -(Controller.DEAD + 10.0))) == 1, "죽은 영역 바로 밖 위쪽은 ▲")
	c.free()

func _test_touch_emits_steer() -> void:
	var c := _controller()
	_got.clear()
	for i in 4:
		var t := InputEventScreenTouch.new()
		t.pressed = true
		t.position = c.center() + Controller.button_dir(i) * Controller.RING
		c._gui_input(t)
	assert(_got == ([R, U, L, D] as Array[int]), "버튼마다 자기 조향: %s" % [_got])
	var inside := InputEventScreenTouch.new()
	inside.pressed = true
	inside.position = c.center()
	c._gui_input(inside)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = c.center() + Controller.button_dir(0) * Controller.RING
	c._gui_input(release)
	assert(_got.size() == 4, "가운데 터치와 손 뗌은 입력이 아니다")
	c.free()

func _test_two_fingers_in_order() -> void:
	var c := _controller()
	_got.clear()
	for pair in [[0, 2], [1, 3]]:
		var t := InputEventScreenTouch.new()
		t.index = pair[0]
		t.pressed = true
		t.position = c.center() + Controller.button_dir(pair[1]) * Controller.RING
		c._gui_input(t)
	assert(_got == ([L, D] as Array[int]), "두 손가락은 닿은 순서대로: %s" % [_got])
	c.free()

func _test_drag_is_not_input() -> void:
	var c := _controller()
	_got.clear()
	var d := InputEventScreenDrag.new()
	d.position = c.center() + Controller.button_dir(0) * Controller.RING
	c._gui_input(d)
	assert(_got.is_empty(), "누른 채 미끄러지는 것은 새 입력이 아니다")
	c.free()

func _test_keyboard() -> void:
	var c := _controller()
	_got.clear()
	_turns.clear()
	for key in [KEY_D, KEY_W, KEY_A, KEY_S, KEY_LEFT, KEY_RIGHT]:
		var k := InputEventKey.new()
		k.physical_keycode = key
		k.pressed = true
		c._unhandled_key_input(k)
	assert(_got == ([R, U, L, D] as Array[int]), "D 오른쪽, W 위, A 왼쪽, S 아래: %s" % [_got])
	assert(_turns == ([-1, 1] as Array[int]), "← 맵 반시계, → 맵 시계")
	for key in [KEY_Q, KEY_E]:
		var old := InputEventKey.new()
		old.physical_keycode = key
		old.pressed = true
		c._unhandled_key_input(old)
	assert(_got.size() == 4, "이전 육각 배치 키(Q·E)는 더 안 쓴다")
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_D
	echo.pressed = true
	echo.echo = true
	c._unhandled_key_input(echo)
	assert(_got.size() == 4, "키를 누르고 있어 반복되는 입력은 무시")
	c.free()
