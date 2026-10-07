class_name Controller
extends Control

# 화면 아래 컨트롤러: 가운데 마름모(상자 윗면과 같은 모양) + 둘레 6방향 버튼, 그리고 키보드.
# 방향은 화면 방향 번호(CameraRig 주석)로만 내보낸다. 월드 축으로 바꾸는 건 CameraRig 몫이다.

signal direction_pressed(screen_dir: int)
signal turn_pressed(dir: int)

const HEIGHT := 400.0      # 컨트롤러 영역 높이(px)
const RING := 150.0        # 가운데에서 버튼 중심까지
const BUTTON := 54.0       # 버튼 반지름
const FACE := 80.0         # 마름모: 월드 1 단위를 이 픽셀로 그린 상자 윗면(가운데에서 각 축 ±1)
const FLASH := 0.15        # 누른 버튼이 빛나는 시간(초)
# QWE / ASD 가 컨트롤러와 같은 육각 배치. 물리 키 위치라 한/영 상태와 무관하다.
const KEYS := {KEY_E: 0, KEY_W: 1, KEY_Q: 2, KEY_A: 3, KEY_S: 4, KEY_D: 5}

var rig: CameraRig
var _flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -HEIGHT
	mouse_filter = Control.MOUSE_FILTER_STOP

func center() -> Vector2:
	return size * 0.5

static func button_dir(i: int) -> Vector2:
	var a := deg_to_rad(30.0 + 60.0 * i)
	return Vector2(cos(a), -sin(a))

# 상자 윗면의 네 꼭짓점(가운데 기준, 화면 픽셀, 아래가 +y). 지금 화면 각도로 계산하므로
# 맵이 도는 동안에는 마름모도 상자 윗면을 따라 돈다.
func diamond() -> PackedVector2Array:
	var yaw := rig.current_yaw() if rig != null else CameraRig.YAW_BASE_DEG
	var ax := CameraRig.screen_vector(Vector3.RIGHT, yaw)
	var az := CameraRig.screen_vector(Vector3.BACK, yaw)
	var fx := Vector2(ax.x, -ax.y) * FACE
	var fz := Vector2(az.x, -az.y) * FACE
	return PackedVector2Array([fx + fz, fx - fz, -fx - fz, -fx + fz])

# 가운데 기준 위치 p 의 화면 방향 번호. 60° 부채꼴 6개로 나눈다. 마름모 안이면 -1.
func sector_at(p: Vector2) -> int:
	if Geometry2D.is_point_in_polygon(p, diamond()):
		return -1
	var ang := fposmod(rad_to_deg(atan2(-p.y, p.x)), 360.0)
	return int(ang / 60.0) % 6

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
	direction_pressed.emit(i)

func _process(delta: float) -> void:
	for i in 6:
		_flash[i] = maxf(0.0, _flash[i] - delta)
	queue_redraw()

func _draw() -> void:
	var c := center()
	var pts := PackedVector2Array()
	for p in diamond():
		pts.append(c + p)
	draw_colored_polygon(pts, Color(0.95, 0.75, 0.5, 0.18))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.95, 0.8, 0.6, 0.7), 3.0, true)
	for i in 6:
		var dir := button_dir(i)
		var p := c + dir * RING
		var lit := _flash[i] > 0.0
		draw_circle(p, BUTTON, Color(1, 0.85, 0.5, 0.55) if lit else Color(1, 1, 1, 0.12))
		draw_arc(p, BUTTON, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 2.0, true)
		# 대가 달린 화살표. 삼각형만 그리면 작은 화면에서 대각선 버튼이 안쪽을 가리키는 것처럼 읽힌다.
		var side := Vector2(-dir.y, dir.x)
		draw_line(p - dir * 20.0, p + dir * 4.0, Color(1, 1, 1, 0.9), 7.0, true)
		draw_colored_polygon(PackedVector2Array([p + dir * 24.0, p + dir * 2.0 + side * 13.0, p + dir * 2.0 - side * 13.0]), Color(1, 1, 1, 0.9))
