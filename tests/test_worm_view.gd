extends SceneTree

func _initialize() -> void:
	_test_tail_scale()
	_test_instances_follow_path()
	_test_new_tail_grows_from_zero()
	_test_head_glances_toward_queued_turn()
	print("test_worm_view: OK")
	quit()

func _test_tail_scale() -> void:
	assert(WormView.tail_scale(-1.0) == 0.0, "막 돋아나는 마디는 크기 0")
	assert(is_equal_approx(WormView.tail_scale(0.0), Tuning.TAIL_TAPER[0]), "꼬리 끝 마디")
	assert(is_equal_approx(WormView.tail_scale(2.5), lerpf(Tuning.TAIL_TAPER[2], 1.0, 0.5)), "사이 값은 보간")
	assert(WormView.tail_scale(3.0) == 1.0 and WormView.tail_scale(40.0) == 1.0, "꼬리에서 먼 마디는 제 크기")
	for i in 400:
		var k := -1.0 + i * 0.01
		assert(absf(WormView.tail_scale(k + 0.01) - WormView.tail_scale(k)) < 0.07, "꼬리 크기가 튄다: k=%f" % k)

func _game_moving_up() -> Game:
	var g := Game.new(3)
	g.field.rocks.clear()
	g.field.bugs.clear()
	g.press(Worm.Steer.UP)  # 출발 전 첫 입력은 바로 꺾임: -X 를 보는 지렁이가 위로 간다
	for i in 20:
		g.advance(1.0 / 60.0)
	return g

func _test_instances_follow_path() -> void:
	var g := _game_moving_up()
	var wv := WormView.new()
	root.add_child(wv)
	wv.setup(g)
	assert(wv.body.multimesh.visible_instance_count == g.worm.length() - 1, "몸 마디 수 = 길이 - 1")
	# 헤드리스의 MultiMesh 는 넣은 값을 돌려주지 않으므로(더미 렌더러) 넣기 전 계산을 본다.
	for j in range(1, g.worm.length()):
		var want := WormPath.segment(g.worm, j, g.alpha).origin
		assert(WormView.body_transform(g, j, 0.0).origin.distance_to(want) < 1e-4, "마디 %d 가 경로 위치에 없다" % j)
	assert(wv.head.transform.origin.distance_to(WormPath.segment(g.worm, 0, g.alpha).origin) < 1e-4, "머리가 경로 위치에 없다")
	wv.queue_free()

func _test_new_tail_grows_from_zero() -> void:
	var g := Game.new(3)
	g.field.rocks.clear()
	g.field.bugs.assign([Vector3i(3, 4, 4)])
	g.state = Game.State.RUNNING  # 곧장 -X 로 간다. 조향 첫 입력은 꺾임이라 직접 출발시킨다
	g.worm.head_exit = Vector3i(-1, 0, 0)
	while g.worm.length() == 3:
		g.advance(1.0 / 60.0)
	var last := WormView.body_transform(g, g.worm.length() - 1, 0.0).basis.get_scale().z
	assert(last <= Tuning.TAIL_TAPER[0] * g.alpha + 0.01, "새 꼬리는 크기 0 에서 부풀어야 한다: %f (alpha %f)" % [last, g.alpha])
	var before := WormView.body_transform(g, g.worm.length() - 2, 0.0).basis.get_scale().z
	assert(absf(before - Tuning.TAIL_TAPER[0]) < 0.12, "원래 꼬리는 자라는 걸음 처음에 원래 크기를 유지한다: %f" % before)

# 다음 칸에서 꺾을 입력이 큐에 있으면 머리가 그쪽으로 고개를 살짝 돌린다(예고 동작).
func _test_head_glances_toward_queued_turn() -> void:
	var g := Game.new(3)
	g.field.rocks.clear()
	g.field.bugs.clear()
	g.state = Game.State.RUNNING
	g.worm.head_exit = Vector3i(-1, 0, 0)  # 곧장 -X 로
	g.press(Worm.Steer.LEFT)  # 다음 칸에서 왼쪽 = +Z
	var want := Vector3(g.queued_exit())
	assert(want == Vector3(0, 0, 1), "-X 로 가는 중 왼쪽은 +Z: %s" % want)
	var wv := WormView.new()
	root.add_child(wv)
	wv.setup(g)
	var straight := -WormPath.segment(g.worm, 0, g.alpha).basis.z
	var looking := -wv._head_transform(1.0).basis.z  # 예고 동작이 끝까지 간 뒤
	assert(looking.dot(want) > straight.dot(want) + sin(deg_to_rad(Tuning.GLANCE_DEG)) * 0.9, "머리가 꺾을 쪽(+Z)으로 고개를 돌려야 한다: %s" % looking)
	wv.queue_free()
