class_name Controller
extends Control

# 화면 아래 십자 조향 패드: ◀ ▶ ▲ ▼ 4버튼과 키보드. 지렁이 기준으로 꺾는 버튼이라 맵을 돌려도 의미가 같다.
# 맵 회전은 HUD 버튼과 ← → 키(turn_pressed)가 맡는다.

signal steer_pressed(steer: int)  # Worm.Steer
signal turn_pressed(dir: int)  # 맵 회전: -1 반시계, +1 시계

const HEIGHT := 400.0      # 컨트롤러 영역 높이(px)
const RING := 130.0        # 가운데에서 버튼 중심까지
const BUTTON := 62.0       # 버튼 반지름
const DEAD := 50.0         # 가운데 죽은 영역 반지름. 버튼 사이 가운데를 스치는 오입력을 막는다
const FLASH := 0.15        # 누른 버튼이 빛나는 시간(초)
# 칸 번호 0~3 은 화면의 오른쪽·위·왼쪽·아래(반시계 순). 판정은 칸마다 90° 부채꼴이다.
const PAD: Array[int] = [Worm.Steer.RIGHT, Worm.Steer.UP, Worm.Steer.LEFT, Worm.Steer.DOWN]
# D 오른쪽, W 위, A 왼쪽, S 아래. 물리 키 위치라 한/영 상태와 무관하다. 값은 칸 번호.
const KEYS := {KEY_D: 0, KEY_W: 1, KEY_A: 2, KEY_S: 3}

var _flash: Array[float] = [0.0, 0.0, 0.0, 0.0]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -HEIGHT
	mouse_filter = Control.MOUSE_FILTER_STOP

func center() -> Vector2:
	return size * 0.5

# 칸 i 가 화면에서 놓인 방향(단위 벡터, 아래가 +y).
static func button_dir(i: int) -> Vector2:
	var a := deg_to_rad(90.0 * i)
	return Vector2(cos(a), -sin(a))

# 가운데 기준 위치 p 의 칸 번호. 가운데 죽은 영역이면 -1.
func sector_at(p: Vector2) -> int:
	if p.length() < DEAD:
		return -1
	var ang := fposmod(rad_to_deg(atan2(-p.y, p.x)), 360.0)
	return int((ang + 45.0) / 90.0) % 4

func _gui_input(event: InputEvent) -> void:
	var t := event as InputEventScreenTouch
	if t == null or not t.pressed:
		return
	var i := sector_at(t.position - center())
	if i >= 0:
		_press(i)
	accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if KEYS.has(k.physical_keycode):
		_press(KEYS[k.physical_keycode])
	elif k.physical_keycode == KEY_LEFT:
		turn_pressed.emit(-1)
	elif k.physical_keycode == KEY_RIGHT:
		turn_pressed.emit(1)

func _press(i: int) -> void:
	_flash[i] = FLASH
	steer_pressed.emit(PAD[i])

func _process(delta: float) -> void:
	for i in 4:
		_flash[i] = maxf(0.0, _flash[i] - delta)
	queue_redraw()

func _draw() -> void:
	var c := center()
	for i in 4:
		var dir := button_dir(i)
		var p := c + dir * RING
		var lit := _flash[i] > 0.0
		draw_circle(p, BUTTON, Color(1, 0.85, 0.5, 0.55) if lit else Color(1, 1, 1, 0.12))
		draw_arc(p, BUTTON, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 2.0, true)
		# 대가 달린 화살표. 삼각형만 그리면 작은 화면에서 어느 쪽을 가리키는지 흐릿하다.
		var side := Vector2(-dir.y, dir.x)
		draw_line(p - dir * 24.0, p + dir * 4.0, Color(1, 1, 1, 0.9), 8.0, true)
		draw_colored_polygon(PackedVector2Array([p + dir * 28.0, p + dir * 2.0 + side * 16.0, p + dir * 2.0 - side * 16.0]), Color(1, 1, 1, 0.9))
