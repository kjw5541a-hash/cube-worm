class_name CameraRig
extends Node3D

# 화면 방향 → 월드 축 변환은 이 파일만 맡는다. 다른 파일이 따로 계산하면 맵을 돌린 뒤 조작이 어긋난다.
# 화면 방향 번호 i 는 화면 각도 30° + 60°·i (화면 오른쪽이 0°, 반시계): 0 ↗, 1 ▲, 2 ↖, 3 ↙, 4 ▼, 5 ↘.

const PITCH_DEG := -35.26439     # -atan(1/√2). 세 축이 화면에 같은 길이, 60° 간격으로 보이는 정확한 등각
const YAW_BASE_DEG := 45.0
const VIEW_WIDTH := Tuning.BOX * 1.55  # 설계 화면 폭 720px 에 담는 월드 길이. 45° 자세의 상자 폭 BOX·√2 에 여백 약 10%
const UNITS_PER_PX := VIEW_WIDTH / 720.0
const BOX_CENTER_Y_PX := 480.0   # 상자 중심을 화면 위에서 이만큼 아래에 둔다. 그 아래는 컨트롤러 자리
const AXES: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var camera := Camera3D.new()
var yaw_step := 0                # 목표 시점(0~3). 회전 버튼을 누르는 즉시 바뀐다
var _yaw_target := YAW_BASE_DEG  # 진행 중인 트윈의 중간값에 90°를 더하면 단계와 어긋나므로 따로 누적한다
var _tween: Tween = null

func _init() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	# 직교 투영이라 거리는 보이는 크기와 무관하다. 상자를 다 담을 만큼만 물러난다.
	camera.position = Vector3(0, 0, 30)
	camera.far = 60.0
	add_child(camera)
	rotation_degrees = Vector3(PITCH_DEG, YAW_BASE_DEG, 0.0)

func _ready() -> void:
	frame_box()

func _process(_delta: float) -> void:
	frame_box()

# 화면 비율이 달라도(긴 폰, 가로로 넓은 데스크톱 창) 1px 당 월드 길이를 설계 화면과 같게 두고,
# 상자 중심을 위에서 BOX_CENTER_Y_PX 자리에 둔다. 웹은 시작 뒤에 캔버스 크기가 바뀌므로 매 프레임 맞춘다.
func frame_box() -> void:
	var vp := get_viewport().get_visible_rect().size
	camera.size = vp.y * UNITS_PER_PX
	camera.v_offset = -(vp.y * 0.5 - BOX_CENTER_Y_PX) * UNITS_PER_PX

# 정사영에서 월드 방향이 화면에 비치는 벡터 (화면 오른쪽, 화면 위). 월드 1 단위 기준.
static func screen_vector(axis: Vector3, yaw_deg: float) -> Vector2:
	var b := Basis.from_euler(Vector3(deg_to_rad(PITCH_DEG), deg_to_rad(yaw_deg), 0.0))
	return Vector2(axis.dot(b.x), axis.dot(b.y))

static func axis_for(screen_dir: int, yaw_deg: float) -> Vector3i:
	var want := Vector2.from_angle(deg_to_rad(30.0 + 60.0 * screen_dir))
	var best := AXES[0]
	var best_dot := -INF
	for a in AXES:
		var s := screen_vector(Vector3(a), yaw_deg).normalized().dot(want)
		if s > best_dot:
			best_dot = s
			best = a
	return best

# 버튼을 누른 순간의 목표 시점 기준. 회전 중이면 회전이 끝난 뒤의 시점이다.
func world_dir(screen_dir: int) -> Vector3i:
	return axis_for(screen_dir, YAW_BASE_DEG + 90.0 * yaw_step)

# +1 이면 맵이 시계 방향으로 돈다(↗ 에 있던 것이 ↘ 로 간다).
func turn(dir: int) -> void:
	yaw_step = posmod(yaw_step + dir, 4)
	_yaw_target += 90.0 * dir
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "rotation_degrees:y", _yaw_target, Tuning.TURN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func is_turning() -> bool:
	return _tween != null and _tween.is_running()

# 지금 화면의 실제 각도(회전 중이면 중간 값).
func current_yaw() -> float:
	return rotation_degrees.y
