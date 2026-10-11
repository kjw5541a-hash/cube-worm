class_name WormView
extends Node3D

# 지렁이 그리기: 머리 메시 + 몸 MultiMesh. 모양은 스킨(GLB)이 정하고, 매 프레임 게임 상태로 마디 변환을 다시 계산한다.

const SHADER := preload("res://shaders/worm.gdshader")
const XRAY := preload("res://shaders/xray.gdshader")
const LINK_THICKNESS := 0.92  # 연결부 단면 배율(마디보다 살짝 잘록)
const BAND_INDEX := 3  # 머리 = 0 부터 센 마디 번호. 이 마디가 밝은 띠(지렁이 환대)다

var game: Game
var head := MeshInstance3D.new()
var body := MultiMeshInstance3D.new()
var links := MultiMeshInstance3D.new()  # 마디 사이를 메우는 연결부
var skin_index := -1
var _time := 0.0
var _glance := 0.0
var _glance_dir := Vector3.ZERO
var _dead_time := 0.0

# 공용 셰이더 재질. xray 면 가려진 부분이 비쳐 보이는 두 번째 패스를 붙인다. band 는 밝은 띠 마디의 색.
static func material(color: Color, emission := 0.0, xray := false, band := Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("band_color", band)
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

# MultiMesh 인스턴스 i 의 색. 알파 0 이 밝은 띠 마디다(마디 j 는 인스턴스 j-1).
static func instance_color(i: int) -> Color:
	return Color(1, 1, 1, 0.0 if i == BAND_INDEX - 1 else 1.0)

# 먹은 덩어리가 마디 j 를 부풀리는 배율. pos 는 덩어리의 위치(머리에서 마디 수로 센 거리)다.
static func bulge_scale(j: float, pos: float) -> float:
	var d := absf(j - pos) / Tuning.BULGE_WIDTH
	if d >= 1.0:
		return 1.0
	return 1.0 + Tuning.BULGE_PEAK * 0.5 * (1.0 + cos(PI * d))

# 죽은 뒤 time 초가 지났을 때 머리의 앞뒤 길이 비율(1 → DEATH_SQUASH). 앞면은 장애물에 붙은 채 줄어든다.
static func death_squash(time: float) -> float:
	var t := clampf(time / Tuning.DEATH_SQUASH_TIME, 0.0, 1.0)
	return lerpf(1.0, Tuning.DEATH_SQUASH, 1.0 - (1.0 - t) * (1.0 - t))

# 먹은 덩어리들이 마디 j 에 주는 배율의 최댓값. 덩어리는 먹은 걸음에서 진행값 차이만큼 몸을 따라 흘러갔다.
static func _bump(g: Game, j: float) -> float:
	var out := 1.0
	for e in g.eat_steps:
		out = maxf(out, bulge_scale(j, g.progress() - float(e)))
	return out

# 몸 마디 j(1 이상)를 그릴 변환. 위치·자세는 경로를 그대로 따르고, 크기는 꼬리 배율 × 꿈틀거림 × 먹은 덩어리다.
static func body_transform(g: Game, j: int, time: float) -> Transform3D:
	var t := WormPath.segment(g.worm, j, g.alpha)
	# 자라는 걸음 동안에는 꼬리 쪽 번호가 한 칸씩 밀리는 것을 진행률로 이어 준다. 새 꼬리는 크기 0 에서 시작한다.
	var grow := 1.0 - g.alpha if g.just_grew else 0.0
	var s := tail_scale(float(g.worm.length() - 1 - j) - grow)
	# 꿈틀거림: 머리에서 꼬리로 흐르는 굵기 파동. 길이 방향(Z)은 두고 단면만 바꾼다.
	var wave := 1.0 + Tuning.WOBBLE_AMP * sin(TAU * (Tuning.WOBBLE_HZ * time - j / Tuning.WOBBLE_WAVELENGTH))
	var thick := s * wave * _bump(g, float(j))
	t.basis = t.basis * Basis.from_scale(Vector3(thick, thick, s))
	return t

# 마디 j 와 j+1 을 잇는 연결부의 변환. 두 마디의 한가운데에 두고, 단면을 조금 줄여 잘록하게 보이게 한다.
# 마디 크기(0.86)가 칸 간격(1.0)보다 작아 생기던 틈을 메워 지렁이가 하나로 이어져 보인다.
static func link_transform(g: Game, j: int, time: float) -> Transform3D:
	var a := WormPath.segment(g.worm, 0, g.alpha) if j == 0 else body_transform(g, j, time)
	var t := a.interpolate_with(body_transform(g, j + 1, time), 0.5)
	t.basis = t.basis * Basis.from_scale(Vector3(LINK_THICKNESS, LINK_THICKNESS, 1.0))
	return t

func _init() -> void:
	add_child(head)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = Tuning.BOX * Tuning.BOX * Tuning.BOX
	mm.visible_instance_count = 0
	for i in mm.instance_count:
		mm.set_instance_color(i, instance_color(i))
	body.multimesh = mm
	add_child(body)
	var lm := MultiMesh.new()
	lm.transform_format = MultiMesh.TRANSFORM_3D
	lm.instance_count = mm.instance_count
	lm.visible_instance_count = 0
	links.multimesh = lm
	add_child(links)
	apply_skin(0)

# 지렁이 스킨(Skins.WORMS 번호)을 적용한다. 머리와 마디 메시를 바꾸고 공용 셰이더 재질을 씌운다.
func apply_skin(index: int) -> void:
	skin_index = index
	var skin: Dictionary = Skins.WORMS[index]
	var seg := Models.load_model(skin["segment"])
	var c: Color = seg["colors"][0]
	body.multimesh.mesh = seg["mesh"]
	body.material_override = material(c, 0.0, false, c.lerp(Color.WHITE, 0.5))
	links.multimesh.mesh = seg["mesh"]
	links.material_override = material(c)  # 연결부에는 띠가 없다
	var hd := Models.load_model(skin["head"])
	head.mesh = hd["mesh"]
	for i in hd["colors"].size():
		head.set_surface_override_material(i, material(hd["colors"][i], 0.0, true))

func setup(g: Game) -> void:
	game = g
	_glance = 0.0
	_dead_time = 0.0
	_update(0.0)

func _process(delta: float) -> void:
	_time += delta
	_update(delta)

func _update(delta: float) -> void:
	if game == null:
		return
	var n := game.worm.length()
	var mm := body.multimesh
	mm.visible_instance_count = n - 1
	for j in range(1, n):
		mm.set_instance_transform(j - 1, body_transform(game, j, _time))
	links.multimesh.visible_instance_count = n - 1
	for j in n - 1:
		links.multimesh.set_instance_transform(j, link_transform(game, j, _time))
	head.transform = _head_transform(delta)

# 머리 변환. 다음 방향으로 미리 고개를 돌리는 예고 동작, 먹은 덩어리가 머리를 지날 때의 꿀꺽, 죽을 때의 찌그러짐을 얹는다.
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
	if game.state == Game.State.DEAD:
		_dead_time += delta
	else:
		_dead_time = 0.0
	var swallow := 1.0 + (_bump(game, 0.0) - 1.0) * 0.5
	var sq := death_squash(_dead_time)
	var wide := swallow * (1.0 + (1.0 - sq) * 0.4)
	var fwd := -t.basis.z
	t.basis = t.basis * Basis.from_scale(Vector3(wide, wide, swallow * sq))
	t.origin += fwd * (1.0 - sq) * Tuning.HEAD_SIZE * 0.5  # 앞면은 제자리에 둔다
	return t
