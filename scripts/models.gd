class_name Models
extends RefCounted

# GLB 한 개에서 메시와 면(surface)별 색을 꺼낸다. 재질은 게임의 공용 셰이더로 바꿔 끼우므로 색만 필요하다.
# 반환: {"mesh": Mesh, "colors": Array[Color]} — colors[i] 는 면 i 의 albedo 색.
static func load_model(path: String) -> Dictionary:
	var scene := load(path) as PackedScene
	assert(scene != null, "GLB 를 못 읽었다: %s" % path)
	var root := scene.instantiate()
	var mi := _first_mesh(root)
	assert(mi != null, "메시가 없다: %s" % path)
	# 메시만 꺼내 쓰므로 노드에 변환이 있으면 방향이 틀어진다. 에셋은 변환 없이 내보낸다.
	var node: Node = mi
	while node != null:
		assert(node is not Node3D or (node as Node3D).transform.is_equal_approx(Transform3D.IDENTITY), "에셋 노드에 변환이 있다: %s" % path)
		node = node.get_parent()
	var mesh: Mesh = mi.mesh
	var colors: Array[Color] = []
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i) as BaseMaterial3D
		colors.append(m.albedo_color if m != null else Color.WHITE)
	root.free()
	return {"mesh": mesh, "colors": colors}

static func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var found := _first_mesh(c)
		if found != null:
			return found
	return null
