class_name WormView
extends Node3D

# 지렁이 그리기: 머리 메시 + 몸 MultiMesh. 매 프레임 게임 상태로 마디 변환을 다시 계산한다.
# 3단계는 임시 도형(상자)이다. 5단계에서 Blender 에셋으로 바꾼다.

const SHADER := preload("res://shaders/worm.gdshader")
const XRAY := preload("res://shaders/xray.gdshader")

var game: Game
var head := MeshInstance3D.new()
var body := MultiMeshInstance3D.new()
var _time := 0.0
var _glance := 0.0
var _glance_dir := Vector3.ZERO

# 공용 셰이더 재질. xray 면 가려진 부분이 비쳐 보이는 두 번째 패스를 붙인다.
static func material(color: Color, emission := 0.0, xray := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("emission", emission)
	m.set_shader_parameter("box_height", float(Tuning.BOX))
	m.set_shader_parameter("min_bright", Tuning.DEPTH_MIN_BRIGHT)
	if xray:
		var x := ShaderMaterial.new()
		x.shader = XRAY
		m.next_pass = x
	return m

# 꼬리 끝에서 k 번째(마지막 = 0) 마디의 크기 배율. k = -1 은 막 돋아나는 마디(크기 0).
# k 가 실수여도 이어지게 보간한다. 자라는 걸음 동안 k 가 1 씩 밀리는 것을 부드럽게 넘긴다.
static func tail_scale(k: float) -> float:
	if k <= -1.0:
		return 0.0
	if k >= Tuning.TAIL_TAPER.size():
		return 1.0
	var pts: Array = [0.0] + Tuning.TAIL_TAPER + [1.0]
	var i := int(floor(k)) + 1
	return lerpf(pts[i], pts[i + 1], k - floor(k))

func _init() -> void:
	var hm := BoxMesh.new()
	hm.size = Vector3.ONE * Tuning.HEAD_SIZE
	head.mesh = hm
	head.material_override = material(Color(0.92, 0.42, 0.48), 0.0, true)
	# 눈: 진행 방향이 읽히게. 얇게 둬서 비침 패스의 당김(0.05)보다 덜 튀어나오게 한다.
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(0.2, 0.2, 0.04)
		eye.mesh = em
		eye.position = Vector3(0.22 * side, 0.16, -Tuning.HEAD_SIZE * 0.5)
		eye.material_override = material(Color(1, 1, 1))
		head.add_child(eye)
	add_child(head)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * Tuning.SEGMENT_SIZE
	mm.mesh = bm
	mm.instance_count = Tuning.BOX * Tuning.BOX * Tuning.BOX
	mm.visible_instance_count = 0
	body.multimesh = mm
	body.material_override = material(Color(0.95, 0.6, 0.62))
	add_child(body)

func setup(g: Game) -> void:
	game = g
	_glance = 0.0
	_update(0.0)

func _process(delta: float) -> void:
	_time += delta
	_update(delta)

# 몸 마디 j(1 이상)를 그릴 변환. 위치·자세는 경로를 그대로 따르고, 크기는 꼬리 배율 × 꿈틀거림이다.
static func body_transform(g: Game, j: int, time: float) -> Transform3D:
	var t := WormPath.segment(g.worm, j, g.alpha)
	# 자라는 걸음 동안에는 꼬리 쪽 번호가 한 칸씩 밀리는 것을 진행률로 이어 준다. 새 꼬리는 크기 0 에서 시작한다.
	var grow := 1.0 - g.alpha if g.just_grew else 0.0
	var s := tail_scale(float(g.worm.length() - 1 - j) - grow)
	# 꿈틀거림: 머리에서 꼬리로 흐르는 굵기 파동. 길이 방향(Z)은 두고 단면만 바꾼다.
	var wave := 1.0 + Tuning.WOBBLE_AMP * sin(TAU * (Tuning.WOBBLE_HZ * time - j / Tuning.WOBBLE_WAVELENGTH))
	t.basis = t.basis * Basis.from_scale(Vector3(s * wave, s * wave, s))
	return t

func _update(delta: float) -> void:
	if game == null:
		return
	var n := game.worm.length()
	var mm := body.multimesh
	mm.visible_instance_count = n - 1
	for j in range(1, n):
		mm.set_instance_transform(j - 1, body_transform(game, j, _time))
	head.transform = _head_transform(delta)

# 예고 동작: 큐의 다음 방향으로 고개를 살짝 미리 돌린다. 실제로 꺾이기 시작하면 경로 자세로 합쳐진다.
func _head_transform(delta: float) -> Transform3D:
	var t := WormPath.segment(game.worm, 0, game.alpha)
	var want := 0.0
	if game.state == Game.State.RUNNING and not game.queue.is_empty():
		want = 1.0
		_glance_dir = Vector3(game.queued_exit())
	_glance = move_toward(_glance, want, delta * 8.0)
	var axis := (-t.basis.z).cross(_glance_dir)
	if _glance > 0.0 and axis.length() > 0.01:
		t.basis = Basis(axis.normalized(), deg_to_rad(Tuning.GLANCE_DEG) * _glance) * t.basis
	return t
