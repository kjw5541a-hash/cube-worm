extends SceneTree

func _initialize() -> void:
	_test_layer_plane_follows_head()
	_test_bug_markers()
	print("test_field_view: OK")
	quit()

func _game() -> Game:
	var g := Game.new(2)
	g.field.bugs.assign([Vector3i(1, 4, 1), Vector3i(6, 1, 6), Vector3i(2, 7, 5)])
	return g

func _view(g: Game) -> FieldView:
	var fv := FieldView.new()
	root.add_child(fv)
	fv.setup(g)
	return fv

func _test_layer_plane_follows_head() -> void:
	var g := _game()
	var fv := _view(g)
	assert(fv.rocks.multimesh.instance_count == g.field.rocks.size(), "바위 수만큼 그린다")
	g.press(Worm.Steer.UP)  # 출발 전 첫 입력은 바로 꺾임: -X 를 보는 지렁이가 위로 간다
	for i in 10:
		g.advance(1.0 / 60.0)
		fv._update()
		var head_y := WormPath.segment(g.worm, 0, g.alpha).origin.y
		assert(absf(fv.plane.position.y - head_y) < 1e-4, "머리 층 판은 머리 높이를 따라간다")
	fv.queue_free()

func _test_bug_markers() -> void:
	var g := _game()
	var fv := _view(g)
	# 출발 전 머리는 칸 (4,4,4) 의 입구 면, 높이 4.5. 벌레 (1,4,1) 은 같은 층이라 기둥이 없다.
	assert(fv.rings[0].visible and not fv.stems[0].visible, "같은 층 벌레는 고리만")
	assert(fv.stems[1].visible and fv.stems[2].visible, "다른 층 벌레는 기둥이 있다")
	assert(absf(fv.stems[1].scale.y - 3.0) < 1e-4, "기둥 길이 = 높이 차(4.5 - 1.5): %f" % fv.stems[1].scale.y)
	var ring := fv.rings[1].position
	assert(ring.distance_to(Vector3(6.5, 4.5, 6.5)) < 1e-4, "고리는 판 위, 벌레와 같은 (x, z): %s" % ring)
	g.field.bugs.remove_at(2)
	fv._update()
	assert(not fv.bugs[2].visible and not fv.rings[2].visible and not fv.stems[2].visible, "없는 벌레의 표시는 숨긴다")
	fv.queue_free()
