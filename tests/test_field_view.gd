extends SceneTree

func _initialize() -> void:
	_test_layer_plane_follows_head()
	_test_bug_markers_per_kind()
	_test_box_follows_height_and_extra_bugs()
	_test_cell_marker_follows_head_cell()
	_test_rocks_use_the_model()
	_test_rock_basis_is_axis_aligned_and_stable()
	_test_ghost_is_pulled_into_the_head()
	print("test_field_view: OK")
	quit()

func _game() -> Game:
	var g := Game.new(2)
	g.field.bugs.assign([Vector3i(1, 4, 1), Vector3i(6, 1, 6), Vector3i(2, 7, 5)])
	g.field.kinds.assign([0, 1, 2])
	return g

func _view(g: Game) -> FieldView:
	var fv := FieldView.new()
	root.add_child(fv)
	fv.setup(g)
	return fv

func _test_layer_plane_follows_head() -> void:
	var g := _game()
	var fv := _view(g)
	g.press(Worm.Steer.UP)  # 출발 전 첫 입력은 바로 꺾임: -X 를 보는 지렁이가 위로 간다
	for i in 10:
		g.advance(1.0 / 60.0)
		fv._update()
		var head_y := WormPath.segment(g.worm, 0, g.alpha).origin.y
		assert(absf(fv.plane.position.y - head_y) < 1e-4, "머리 층 판은 머리 높이를 따라간다")
	fv.queue_free()

# 벌레는 종류마다 자기 메시와 색의 고리·기둥을 가진다.
func _test_bug_markers_per_kind() -> void:
	var g := _game()
	var fv := _view(g)
	assert(fv.bugs[0].mesh != fv.bugs[3].mesh and fv.bugs[3].mesh != fv.bugs[6].mesh, "종류마다 벌레 모양이 다르다")
	for k in 3:
		var marker := fv.rings[k * 3].material_override as StandardMaterial3D
		assert(marker.albedo_color == Skins.BUGS[k]["color"] and fv.stems[k * 3].material_override == marker, "고리·기둥은 종류 색: %d" % k)
	# 출발 전 머리는 칸 (4,4,4) 의 입구 면, 높이 4.5. 종류 0 은 (1,4,1) 로 같은 층이라 기둥이 없다.
	assert(fv.rings[0].visible and not fv.stems[0].visible, "같은 층 벌레는 고리만")
	assert(fv.stems[3].visible and fv.stems[6].visible, "다른 층 벌레는 기둥이 있다")
	assert(absf(fv.stems[3].scale.y - 3.0) < 1e-4, "기둥 길이 = 높이 차(4.5 - 1.5): %f" % fv.stems[3].scale.y)
	assert(fv.rings[3].position.distance_to(Vector3(6.5, 4.5, 6.5)) < 1e-4, "고리는 판 위, 벌레와 같은 (x, z): %s" % fv.rings[3].position)
	assert(absf(fv.bugs[3].position.x - 6.5) < 1e-4 and absf(fv.bugs[3].position.y - 1.5) < 0.07, "벌레는 자기 칸에 있다: %s" % fv.bugs[3].position)
	g.field.remove_bug(Vector3i(2, 7, 5))
	fv._update()
	assert(not fv.bugs[6].visible and not fv.rings[6].visible and not fv.stems[6].visible, "없는 종류의 표시는 숨긴다")
	assert(fv.bugs[0].visible and fv.bugs[3].visible, "있는 종류는 그대로 보인다")
	fv.queue_free()

# 맵 높이에 맞춰 상자가 줄고, 같은 종류 벌레가 여러 마리면 모두 그린다.
func _test_box_follows_height_and_extra_bugs() -> void:
	var g := Game.new(4, false, 3)
	var fv := _view(g)
	assert(is_equal_approx(fv._box_mesh.size.y, 3.0) and is_equal_approx(fv.box.position.y, 1.5), "상자 높이 = 레벨")
	assert(fv._soil.get_shader_parameter("box_size") == 3.0, "흙 셰이더도 높이를 안다")
	var g2 := Game.new(4, false, 8)
	fv.setup(g2)
	assert(is_equal_approx(fv._box_mesh.size.y, 8.0), "다음 판은 다시 8층")
	g2.field.bugs.assign([Vector3i(1, 1, 1), Vector3i(2, 2, 2), Vector3i(3, 3, 3)])
	g2.field.kinds.assign([1, 1, 1])
	fv._update()
	assert(fv.bugs[3].visible and fv.bugs[4].visible and fv.bugs[5].visible and not fv.bugs[0].visible, "같은 종류 3마리를 모두 그린다")
	fv.queue_free()

# 머리가 있는 칸에 블록이 놓이고, 한 걸음 가면 다음 칸으로 옮겨 간다.
func _test_cell_marker_follows_head_cell() -> void:
	var g := Game.new(4, false, 3)
	var fv := _view(g)
	assert(fv.cell_marker.position.is_equal_approx(WormPath.center(g.worm.head())), "블록이 머리 칸 중심에 있다")
	g.worm.head_exit = Vector3i(-1, 0, 0)
	g.worm.step(false)
	fv._update()
	assert(fv.cell_marker.position.is_equal_approx(WormPath.center(g.worm.head())), "한 걸음 뒤 블록도 따라간다")
	fv.queue_free()

func _test_rocks_use_the_model() -> void:
	var g := _game()
	var fv := _view(g)
	assert(fv.rocks.multimesh.instance_count == g.field.rocks.size(), "바위 수만큼 그린다")
	var mesh: Mesh = fv.rocks.multimesh.mesh
	assert(mesh.get_surface_count() == 1 and mesh.get_aabb().size.x > 0.85, "바위 에셋 메시를 쓴다")
	assert(fv.rocks.material_override is ShaderMaterial, "공용 셰이더 재질")
	fv.queue_free()

func _test_rock_basis_is_axis_aligned_and_stable() -> void:
	var seen := {}
	for x in 8:
		for y in 8:
			for z in 8:
				var b := FieldView.rock_basis(Vector3i(x, y, z))
				assert(b.is_equal_approx(b.orthonormalized()), "회전 행렬이어야 한다")
				for col in [b.x, b.y, b.z]:
					assert(absf(col.x) < 1e-5 or absf(absf(col.x) - 1.0) < 1e-5, "90° 단위 회전: %s" % b)
				assert(FieldView.rock_basis(Vector3i(x, y, z)) == b, "같은 칸은 늘 같은 회전")
				seen[b] = true
	assert(seen.size() > 8, "칸마다 다양한 회전이 나온다: %d" % seen.size())

# 먹힌 벌레는 먹은 걸음의 앞쪽 EAT_PULL 동안만 보이고, 먹은 칸에서 머리 쪽으로 움직이며 작아진다.
func _test_ghost_is_pulled_into_the_head() -> void:
	var g := _game()
	g.state = Game.State.RUNNING
	g.worm.head_exit = Vector3i(-1, 0, 0)
	var fv := _view(g)
	for gh in fv.ghosts:
		assert(not gh.visible, "먹은 적이 없으면 숨겨져 있다")
	g.just_grew = true
	g.eaten_cell = Vector3i(4, 4, 4)
	g.eaten_kind = 1
	g.alpha = 0.0
	fv._update()
	assert(fv.ghosts[1].visible and not fv.ghosts[0].visible and not fv.ghosts[2].visible, "먹힌 종류의 벌레만 보인다")
	assert(fv.ghosts[1].position.distance_to(WormPath.center(Vector3i(4, 4, 4))) < 1e-4 and is_equal_approx(fv.ghosts[1].scale.x, 1.0), "처음에는 먹힌 칸에 제 크기로")
	g.alpha = Tuning.EAT_PULL * 0.5
	fv._update()
	var mid := fv.ghosts[1].scale.x
	assert(mid > 0.0 and mid < 1.0, "빨려 들며 작아진다: %f" % mid)
	g.alpha = Tuning.EAT_PULL
	fv._update()
	assert(not fv.ghosts[1].visible, "EAT_PULL 이 지나면 사라진다")
	g.alpha = 0.1
	g.just_grew = false
	fv._update()
	assert(not fv.ghosts[1].visible, "자라는 걸음이 아니면 숨긴다")
	fv.queue_free()
