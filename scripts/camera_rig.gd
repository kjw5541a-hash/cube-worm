class_name CameraRig
extends Node3D

# 등각 직교 카메라와 맵 회전(상자 중심을 도는 90° 단위 시점). 조향은 지렁이 기준이라 화면 방향 → 월드 축 변환은 없다.

const PITCH_DEG := -35.26439     # -atan(1/√2). 세 축이 화면에 같은 길이, 60° 간격으로 보이는 정확한 등각
const YAW_BASE_DEG := 45.0
const VIEW_WIDTH := Tuning.BOX * 1.55  # 설계 화면 폭 720px 에 담는 월드 길이. 45° 자세의 상자 폭 BOX·√2 에 여백 약 10%
const UNITS_PER_PX := VIEW_WIDTH / 720.0
const BOX_CENTER_Y_PX := 480.0   # 상자 중심을 화면 위에서 이만큼 아래에 둔다. 그 아래는 컨트롤러 자리

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
