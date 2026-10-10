extends SceneTree

# 에셋 10개의 계약: 삼각형 상한, 크기, 칸 중심 원점, 앞(-Z) 방향, 눈 돌출, 면 수, 색.
# Blender 스크립트(assets/blender)가 만든 GLB 를 헤드리스 Godot 으로 읽어 확인한다.

const DIR := "res://assets/models/"
const EPS := 0.005
# 스킨: [마디 색, 머리 색]
const SKINS := {"jelly": ["#F4A7AE", "#EE8793"], "ringed": ["#F29A88", "#EE7A6B"], "block": ["#F8BBC8", "#F4A6BA"]}
const GRUBS := ["cream", "antenna", "glow"]

func _initialize() -> void:
	for skin in SKINS:
		_check_segment(skin)
		_check_head(skin)
	for kind in GRUBS:
		_check_grub(kind)
	_check_rock()
	print("test_models: OK")
	quit()

func _tris(mesh: Mesh) -> int:
	var n := 0
	for i in mesh.get_surface_count():
		n += (mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n

func _verts(mesh: Mesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in mesh.get_surface_count():
		out.append_array(mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX])
	return out

func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02

func _has_color(colors: Array, hex: String) -> bool:
	for c in colors:
		if _near(c, Color(hex)):
			return true
	return false

func _check_segment(skin: String) -> void:
	var m := Models.load_model(DIR + "worm_segment_%s.glb" % skin)
	var mesh: Mesh = m["mesh"]
	assert(mesh.get_surface_count() == 1, "마디는 재질이 하나여야 한다(MultiMesh 는 면마다 재질을 못 준다): %s" % skin)
	assert(_tris(mesh) <= 300, "마디 삼각형 상한 300: %s %d" % [skin, _tris(mesh)])
	var box := mesh.get_aabb()
	for k in 3:
		assert(absf(box.size[k] - Tuning.SEGMENT_SIZE) < EPS, "마디 크기는 SEGMENT_SIZE: %s %s" % [skin, box.size])
	assert((box.position + box.size * 0.5).length() < EPS, "원점은 칸 중심: %s" % skin)
	assert(_has_color(m["colors"], SKINS[skin][0]), "마디 색: %s" % skin)

func _check_head(skin: String) -> void:
	var m := Models.load_model(DIR + "worm_head_%s.glb" % skin)
	var mesh: Mesh = m["mesh"]
	assert(mesh.get_surface_count() >= 3, "머리는 몸·눈·입 재질이 있다: %s" % skin)
	assert(_tris(mesh) <= 1500, "머리 삼각형 상한 1500: %s %d" % [skin, _tris(mesh)])
	var box := mesh.get_aabb()
	var half := Tuning.HEAD_SIZE * 0.5
	assert(absf(box.size.x - Tuning.HEAD_SIZE) < EPS and absf(box.size.y - Tuning.HEAD_SIZE) < EPS, "머리 폭·높이는 HEAD_SIZE: %s %s" % [skin, box.size])
	assert(absf(box.end.z - half) < EPS, "뒤쪽 면은 +HEAD_SIZE/2: %s %f" % [skin, box.end.z])
	assert(box.position.z < -half - 0.005, "눈과 입이 앞(-Z)에 있다: %s %f" % [skin, box.position.z])
	assert(box.position.z > -half - 0.06 - EPS, "눈이 앞면 밖으로 0.06 넘게 튀어나왔다(DEATH_STOP 이 앞면 기준): %s %f" % [skin, box.position.z])
	for v in _verts(mesh):
		assert(v.z <= half + EPS, "뒤쪽 면 밖으로 튀어나온 것이 있다: %s %s" % [skin, v])
	assert(_has_color(m["colors"], SKINS[skin][1]), "머리 몸 색: %s" % skin)

func _check_grub(kind: String) -> void:
	var m := Models.load_model(DIR + "grub_%s.glb" % kind)
	var mesh: Mesh = m["mesh"]
	assert(mesh.get_surface_count() >= 2, "벌레는 몸·머리·눈 재질이 있다: %s" % kind)
	assert(_tris(mesh) <= 2000, "벌레 삼각형 상한 2000: %s %d" % [kind, _tris(mesh)])
	var box := mesh.get_aabb()
	for k in 3:
		assert(box.size[k] <= 0.9, "벌레는 칸 안에 들어간다: %s %s" % [kind, box.size])
	assert((box.position + box.size * 0.5).length() < 0.02, "원점은 칸 중심: %s" % kind)

func _check_rock() -> void:
	var m := Models.load_model(DIR + "rock.glb")
	var mesh: Mesh = m["mesh"]
	assert(mesh.get_surface_count() == 1, "바위는 재질 하나(MultiMesh)")
	assert(_tris(mesh) <= 500, "바위 삼각형 상한 500: %d" % _tris(mesh))
	var box := mesh.get_aabb()
	for k in 3:
		assert(box.size[k] > 0.85 and box.size[k] <= 0.96 + EPS, "바위는 칸을 거의 채운다: %s" % box.size)
	assert((box.position + box.size * 0.5).length() < 0.03, "원점은 칸 중심")
	assert(_has_color(m["colors"], "#8C8F96"), "바위 색")
