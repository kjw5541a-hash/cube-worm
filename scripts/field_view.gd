class_name FieldView
extends Node3D

# 흙 상자, 바위, 벌레, 머리 층 판, 벌레 고리·기둥.

var game: Game
var box := MeshInstance3D.new()
var rocks := MultiMeshInstance3D.new()
var plane := MeshInstance3D.new()
var bugs: Array[MeshInstance3D] = []
var rings: Array[MeshInstance3D] = []
var stems: Array[MeshInstance3D] = []
var _time := 0.0

func _init() -> void:
	var half := Tuning.BOX * 0.5
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * Tuning.BOX
	# 면을 안쪽으로 뒤집으면 뒷면 컬링이 어느 시점에서든 가까운 벽 2개와 윗면을 알아서 숨긴다.
	bm.flip_faces = true
	box.mesh = bm
	box.position = Vector3.ONE * half
	var soil := ShaderMaterial.new()
	soil.shader = preload("res://shaders/soil_box.gdshader")
	box.material_override = soil
	add_child(box)

	var rm := MultiMesh.new()
	rm.transform_format = MultiMesh.TRANSFORM_3D
	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3.ONE * 0.9
	rm.mesh = rock_mesh
	rocks.multimesh = rm
	rocks.material_override = WormView.material(Color(0.55, 0.57, 0.6))
	add_child(rocks)

	var pm := PlaneMesh.new()
	pm.size = Vector2(Tuning.BOX, Tuning.BOX)
	plane.mesh = pm
	var pmat := ShaderMaterial.new()
	pmat.shader = preload("res://shaders/layer_plane.gdshader")
	plane.material_override = pmat
	add_child(plane)

	var marker := StandardMaterial3D.new()
	marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.albedo_color = Color(1.0, 0.85, 0.35)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.3
	ring_mesh.outer_radius = 0.38
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.03
	stem_mesh.bottom_radius = 0.03
	stem_mesh.height = 1.0
	var bug_mesh := SphereMesh.new()
	bug_mesh.radius = 0.28
	bug_mesh.height = 0.56
	var bug_mat := WormView.material(Color(1.0, 0.86, 0.45), 0.6, true)
	for i in Tuning.BUG_COUNT:
		bugs.append(_mesh(bug_mesh, bug_mat))
		rings.append(_mesh(ring_mesh, marker))
		stems.append(_mesh(stem_mesh, marker))

func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	add_child(m)
	return m

func setup(g: Game) -> void:
	game = g
	var rm := rocks.multimesh
	rm.instance_count = g.field.rocks.size()
	var i := 0
	for c in g.field.rocks:
		rm.set_instance_transform(i, Transform3D(Basis(), WormPath.center(c)))
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
	plane.position = Vector3(half, head_y, half)
	for i in Tuning.BUG_COUNT:
		var has := i < game.field.bugs.size()
		bugs[i].visible = has
		rings[i].visible = has
		stems[i].visible = false
		if not has:
			continue
		var c := game.field.bugs[i]
		var p := WormPath.center(c)
		# 꼼지락: 칸마다 위상을 달리해 셋이 같이 움직이지 않게 한다.
		bugs[i].position = p + Vector3(0, 0.06 * sin(_time * 3.0 + c.x + c.z * 1.7), 0)
		rings[i].position = Vector3(p.x, head_y, p.z)
		# 기둥은 꼼지락을 뺀 칸 중심으로 잰다. 같은 층에서 기둥이 깜빡이지 않게.
		var gap := p.y - head_y
		if absf(gap) > 0.05:
			stems[i].visible = true
			stems[i].position = Vector3(p.x, head_y + gap * 0.5, p.z)
			stems[i].scale = Vector3(1, absf(gap), 1)
