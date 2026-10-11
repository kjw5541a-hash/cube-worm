class_name FieldView
extends Node3D

# 흙 상자, 바위, 벌레(종류 3가지), 머리 층의 아래·위 판, 벌레 고리·기둥, 머리로 빨려 드는 벌레.

const ROCK_MODEL := "res://assets/models/rock.glb"
const MAX_PER_KIND := 3  # 한 종류 벌레가 한 판에 가장 많이 나오는 수(레벨 7~8)

var game: Game
var box := MeshInstance3D.new()
var rocks := MultiMeshInstance3D.new()
var plane := MeshInstance3D.new()      # 머리가 있는 층의 바닥 판
var plane_top := MeshInstance3D.new()  # 같은 층의 천장 판
var bugs: Array[MeshInstance3D] = []    # 종류 k 의 j 번째 벌레 = k * MAX_PER_KIND + j
var rings: Array[MeshInstance3D] = []
var stems: Array[MeshInstance3D] = []
var ghosts: Array[MeshInstance3D] = []  # 먹히는 중인 벌레(종류마다 하나)
var _time := 0.0
var _box_mesh: BoxMesh
var _soil: ShaderMaterial

# 칸마다 정해진 무작위 90° 회전: 같은 바위도 칸마다 다르게 보이고, 같은 판이면 늘 같다.
static func rock_basis(c: Vector3i) -> Basis:
	var h := absi((c.x * 73856093) ^ (c.y * 19349663) ^ (c.z * 83492791))
	return Basis.from_euler(Vector3(h % 4, (h / 4) % 4, (h / 16) % 4) * (PI * 0.5))

func _init() -> void:
	var bm := BoxMesh.new()
	_box_mesh = bm
	# 면을 안쪽으로 뒤집으면 뒷면 컬링이 어느 시점에서든 가까운 벽 2개와 윗면을 알아서 숨긴다.
	bm.flip_faces = true
	box.mesh = bm
	_soil = ShaderMaterial.new()
	_soil.shader = preload("res://shaders/soil_box.gdshader")
	box.material_override = _soil
	add_child(box)

	var rock := Models.load_model(ROCK_MODEL)
	var rm := MultiMesh.new()
	rm.transform_format = MultiMesh.TRANSFORM_3D
	rm.mesh = rock["mesh"]
	rocks.multimesh = rm
	rocks.material_override = WormView.material(rock["colors"][0])
	add_child(rocks)

	var pm := PlaneMesh.new()
	pm.size = Vector2(Tuning.BOX, Tuning.BOX)
	plane.mesh = pm
	var pmat := ShaderMaterial.new()
	pmat.shader = preload("res://shaders/layer_plane.gdshader")
	plane.material_override = pmat
	add_child(plane)
	plane_top.mesh = pm
	plane_top.material_override = pmat
	add_child(plane_top)

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.3
	ring_mesh.outer_radius = 0.38
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.03
	stem_mesh.bottom_radius = 0.03
	stem_mesh.height = 1.0
	for k in Tuning.BUG_COUNT:
		var model := Models.load_model(Skins.BUGS[k]["model"])
		var marker := StandardMaterial3D.new()
		marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.albedo_color = Skins.BUGS[k]["color"]  # 고리·기둥 색은 종류 색
		for j in MAX_PER_KIND:
			bugs.append(_bug_node(model, true))
			rings.append(_mesh(ring_mesh, marker))
			stems.append(_mesh(stem_mesh, marker))
		ghosts.append(_bug_node(model, false))
		ghosts[k].visible = false

# 벌레 메시에 공용 셰이더 재질을 씌운다(은은하게 빛난다). xray 면 가려졌을 때 비친다.
func _bug_node(model: Dictionary, xray: bool) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = model["mesh"]
	for i in model["colors"].size():
		m.set_surface_override_material(i, WormView.material(model["colors"][i], 0.5, xray))
	add_child(m)
	return m

func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	add_child(m)
	return m

func setup(g: Game) -> void:
	game = g
	# 상자는 가로·세로 BOX, 높이는 이 판의 층 수다. 바닥(y=0)은 늘 같은 자리에 있다.
	var h := float(g.height)
	_box_mesh.size = Vector3(Tuning.BOX, h, Tuning.BOX)
	box.position = Vector3(Tuning.BOX * 0.5, h * 0.5, Tuning.BOX * 0.5)
	_soil.set_shader_parameter("box_size", h)
	var rm := rocks.multimesh
	rm.instance_count = g.field.rocks.size()
	var i := 0
	for c in g.field.rocks:
		rm.set_instance_transform(i, Transform3D(rock_basis(c), WormPath.center(c)))
		i += 1
	_update()

func _process(delta: float) -> void:
	_time += delta
	_update()

func _update() -> void:
	if game == null:
		return
	var head_y := WormPath.segment(game.worm, 0, game.alpha).origin.y
	var half := Tuning.BOX * 0.5
	# 판은 머리를 관통하지 않고, 머리 칸이 있는 층의 아래·위 경계에 놓인다. 한 층이 통째로 칸으로 보인다.
	var layer := game.worm.head().y
	plane.position = Vector3(half, layer, half)
	plane_top.position = Vector3(half, layer + 1, half)
	for k in Tuning.BUG_COUNT:
		var cells: Array[Vector3i] = []
		for i in game.field.bugs.size():
			if game.field.kinds[i] == k:
				cells.append(game.field.bugs[i])
		for n in MAX_PER_KIND:
			var b := k * MAX_PER_KIND + n
			var has := n < cells.size()
			bugs[b].visible = has
			rings[b].visible = has
			stems[b].visible = false
			if not has:
				continue
			var c := cells[n]
			var p := WormPath.center(c)
			# 꼼지락: 칸마다 위상을 달리해 같이 움직이지 않게 한다. 위아래로 살짝 뜨고, 좌우로 몸을 튼다.
			bugs[b].position = p + Vector3(0, 0.06 * sin(_time * 3.0 + c.x + c.z * 1.7), 0)
			bugs[b].rotation.y = 0.35 * sin(_time * 2.2 + c.x * 1.3 + c.y)
			_flicker(bugs[b], c)
			rings[b].position = Vector3(p.x, head_y, p.z)
			# 기둥은 꼼지락을 뺀 칸 중심으로 잰다. 같은 층에서 기둥이 깜빡이지 않게.
			var gap := p.y - head_y
			if absf(gap) > 0.05:
				stems[b].visible = true
				stems[b].position = Vector3(p.x, head_y + gap * 0.5, p.z)
				stems[b].scale = Vector3(1, absf(gap), 1)
	_update_ghost()

# 벌레의 은은한 발광이 느리게 깜빡인다.
func _flicker(bug: MeshInstance3D, c: Vector3i) -> void:
	var e := 0.5 + 0.2 * sin(_time * 1.6 + c.x * 0.9 + c.z * 1.3)
	for i in bug.mesh.get_surface_count():
		(bug.get_surface_override_material(i) as ShaderMaterial).set_shader_parameter("emission", e)

# 먹힌 벌레: 먹은 걸음의 앞쪽 EAT_PULL 동안 머리 쪽으로 빨려 들며 작아진다. 게임 상태만으로 정해지므로 따로 시간을 세지 않는다.
func _update_ghost() -> void:
	for g in ghosts:
		g.visible = false
	if not game.just_grew or game.alpha >= Tuning.EAT_PULL:
		return
	var t := game.alpha / Tuning.EAT_PULL
	var e := t * t * (3.0 - 2.0 * t)
	var ghost := ghosts[game.eaten_kind]
	ghost.visible = true
	ghost.position = WormPath.center(game.eaten_cell).lerp(WormPath.segment(game.worm, 0, game.alpha).origin, e)
	ghost.scale = Vector3.ONE * (1.0 - e)
