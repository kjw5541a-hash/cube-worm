extends SceneTree

func _initialize() -> void:
	_test_tail_scale()
	_test_instances_follow_path()
	_test_new_tail_grows_from_zero()
	_test_head_glances_toward_queued_turn()
	_test_skin_applies_models()
	_test_links_fill_the_gaps()
	_test_worm_ignores_layer_focus()
	_test_segments_touch()
	_test_band_marks_one_segment()
	_test_bulge_scale()
	_test_bulge_follows_the_eat()
	_test_death_squash_keeps_the_front_face()
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
	g.field.kinds.clear()
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
	g.field.kinds.assign([0])
	g.state = Game.State.RUNNING  # 곧장 -X 로 간다. 조향 첫 입력은 꺾임이라 직접 출발시킨다
	g.worm.head_exit = Vector3i(-1, 0, 0)
	while g.worm.length() == 3:
		g.advance(1.0 / 60.0)
	var last := WormView.body_transform(g, g.worm.length() - 1, 0.0).basis.get_scale().z / WormView.SEGMENT_STRETCH
	assert(last <= Tuning.TAIL_TAPER[0] * g.alpha + 0.01, "새 꼬리는 크기 0 에서 부풀어야 한다: %f (alpha %f)" % [last, g.alpha])
	var before := WormView.body_transform(g, g.worm.length() - 2, 0.0).basis.get_scale().z / WormView.SEGMENT_STRETCH
	assert(absf(before - Tuning.TAIL_TAPER[0]) < 0.12, "원래 꼬리는 자라는 걸음 처음에 원래 크기를 유지한다: %f" % before)

# 다음 칸에서 꺾을 입력이 큐에 있으면 머리가 그쪽으로 고개를 살짝 돌린다(예고 동작).
func _test_head_glances_toward_queued_turn() -> void:
	var g := Game.new(3)
	g.field.rocks.clear()
	g.field.bugs.clear()
	g.field.kinds.clear()
	g.state = Game.State.RUNNING  # 곧장 -X 로 간다. 조향 첫 입력은 꺾임이라 직접 출발시킨다
	g.worm.head_exit = Vector3i(-1, 0, 0)
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

# 스킨마다 머리·마디 메시와 공용 셰이더 재질이 맞게 붙는다.
func _test_skin_applies_models() -> void:
	var wv := WormView.new()
	root.add_child(wv)
	var seen := {}
	for i in Skins.WORMS.size():
		wv.apply_skin(i)
		assert(wv.skin_index == i)
		var seg: Mesh = wv.body.multimesh.mesh
		assert(seg.get_surface_count() == 1 and absf(seg.get_aabb().size.x - Tuning.SEGMENT_SIZE) < 0.01, "마디 메시: 스킨 %d" % i)
		var m := wv.body.material_override as ShaderMaterial
		assert(m != null and m.get_shader_parameter("band_color") != m.get_shader_parameter("albedo"), "띠 색은 마디 색과 다르다: 스킨 %d" % i)
		assert(wv.head.mesh.get_surface_count() >= 3, "머리 메시: 스킨 %d" % i)
		for s in wv.head.mesh.get_surface_count():
			var hm := wv.head.get_surface_override_material(s) as ShaderMaterial
			assert(hm != null and hm.next_pass != null, "머리의 모든 면에 공용 셰이더와 비침 패스: 스킨 %d 면 %d" % [i, s])
		seen[wv.head.mesh] = true
	assert(seen.size() == Skins.WORMS.size(), "스킨마다 머리 모양이 다르다")
	wv.queue_free()

# 연결부는 이웃한 두 마디의 한가운데에 있고, 마디가 하나 줄 때마다 하나씩 준다.
func _test_links_fill_the_gaps() -> void:
	var g := _game_moving_up()
	var wv := WormView.new()
	root.add_child(wv)
	wv.setup(g)
	assert(wv.links.multimesh.visible_instance_count == g.worm.length() - 1, "연결부 수 = 길이 - 1")
	for j in g.worm.length() - 1:
		var a := WormPath.segment(g.worm, 0, g.alpha).origin if j == 0 else WormView.body_transform(g, j, 0.0).origin
		var b := WormView.body_transform(g, j + 1, 0.0).origin
		var mid := WormView.link_transform(g, j, 0.0).origin
		assert(mid.distance_to((a + b) * 0.5) < 1e-4, "연결부 %d 는 두 마디의 가운데다" % j)
		assert(a.distance_to(b) < Tuning.SEGMENT_SIZE + 0.2 + 1.0, "마디 사이가 한 칸 안쪽이다")
	assert(wv.links.multimesh.mesh == wv.body.multimesh.mesh, "연결부는 마디와 같은 메시다")
	wv.queue_free()

# 지렁이 자신은 층 구분(유령 패스)을 받지 않는다: 머리와 몸이 다른 층에 걸쳐도 또렷하다.
func _test_worm_ignores_layer_focus() -> void:
	var wv := WormView.new()
	root.add_child(wv)
	for m: ShaderMaterial in [wv.body.material_override, wv.links.material_override, wv.head.get_surface_override_material(0)]:
		assert(m.get_shader_parameter("ignore_focus") == true, "지렁이 재질은 층 구분을 건너뛴다")
		var p := m.next_pass as ShaderMaterial
		assert(p == null or p.shader != WormView.GHOST, "지렁이에는 유령 패스가 없다")
	wv.queue_free()

# 마디는 길이 방향으로 늘어나 이웃 마디와 맞닿는다(한 칸 간격보다 길다).
func _test_segments_touch() -> void:
	var g := _game_moving_up()
	var len_z := Tuning.SEGMENT_SIZE * WormView.SEGMENT_STRETCH
	assert(len_z >= 1.0, "마디 길이 %f 가 칸 간격 1.0 이상이어야 이웃과 맞닿는다" % len_z)
	var mid := WormView.body_transform(g, 2, 0.0)
	assert(is_equal_approx(mid.basis.get_scale().z, WormView.tail_scale(float(g.worm.length() - 3)) * WormView.SEGMENT_STRETCH), "마디 길이 배율이 적용된다")

func _test_band_marks_one_segment() -> void:
	var bands := []
	for i in 12:
		var c := WormView.instance_color(i)
		assert(c.a == 0.0 or c.a == 1.0, "알파는 띠(0)와 보통(1)뿐")
		if c.a == 0.0:
			bands.append(i + 1)  # 인스턴스 i 는 마디 i+1
	assert(bands == [WormView.BAND_INDEX], "밝은 띠는 머리에서 %d 번째 마디 하나뿐: %s" % [WormView.BAND_INDEX, bands])

func _test_bulge_scale() -> void:
	assert(is_equal_approx(WormView.bulge_scale(5.0, 5.0), 1.0 + Tuning.BULGE_PEAK), "덩어리 한가운데가 가장 부푼다")
	assert(WormView.bulge_scale(5.0 + Tuning.BULGE_WIDTH, 5.0) == 1.0 and WormView.bulge_scale(0.0, 9.0) == 1.0, "폭 밖은 그대로")
	assert(is_equal_approx(WormView.bulge_scale(4.5, 5.0), WormView.bulge_scale(5.5, 5.0)), "앞뒤 대칭")
	var prev := 1.0 + Tuning.BULGE_PEAK + 1.0
	for i in 14:  # 한가운데에서 멀어질수록 줄어든다
		var v := WormView.bulge_scale(5.0 + i * 0.1, 5.0)
		assert(v <= prev + 1e-6, "한가운데에서 멀어질수록 줄어야 한다")
		prev = v

# 먹은 덩어리가 머리에서 시작해 마디를 하나씩 지나 꼬리로 흐른다.
func _test_bulge_follows_the_eat() -> void:
	var g := Game.new(3)
	g.field.rocks.clear()
	g.field.bugs.clear()
	g.field.kinds.clear()
	g.steps = 10
	g.eat_steps.assign([10])
	g.alpha = 0.0
	var plain := func(j: int) -> float: return WormView.body_transform(g, j, 0.0).basis.get_scale().x
	var no_eat := func(j: int) -> float:
		var saved := g.eat_steps.duplicate()
		g.eat_steps.clear()
		var v: float = WormView.body_transform(g, j, 0.0).basis.get_scale().x
		g.eat_steps.assign(saved)
		return v
	assert(is_equal_approx(plain.call(1) / no_eat.call(1), 1.0 + Tuning.BULGE_PEAK * 0.5 * (1.0 + cos(PI * 1.0 / Tuning.BULGE_WIDTH))), "막 먹었을 때 덩어리는 머리 자리: 첫 마디가 조금 부푼다")
	g.steps = 12  # 두 걸음 뒤에는 덩어리가 마디 2 에 있다
	assert(is_equal_approx(plain.call(2) / no_eat.call(2), 1.0 + Tuning.BULGE_PEAK), "두 걸음 뒤 덩어리는 마디 2")
	assert(plain.call(1) / no_eat.call(1) < 1.0 + Tuning.BULGE_PEAK * 0.5, "지나간 마디는 다시 가라앉는다")

# 죽으면 머리가 앞뒤로 찌그러지고, 앞면(장애물에 닿은 면)은 제자리에 있다.
func _test_death_squash_keeps_the_front_face() -> void:
	assert(WormView.death_squash(0.0) == 1.0 and is_equal_approx(WormView.death_squash(Tuning.DEATH_SQUASH_TIME), Tuning.DEATH_SQUASH), "찌그러짐은 1 에서 DEATH_SQUASH 까지")
	assert(WormView.death_squash(10.0) == WormView.death_squash(Tuning.DEATH_SQUASH_TIME), "다 찌그러진 뒤에는 그대로")
	var g := Game.new(3)
	g.field.rocks.clear()
	g.field.bugs.clear()
	g.field.kinds.clear()
	g.state = Game.State.RUNNING
	g.worm.head_exit = Vector3i(-1, 0, 0)
	g.alpha = 0.3
	var wv := WormView.new()
	root.add_child(wv)
	wv.setup(g)
	var before := wv.head.transform
	var front_before := before.origin - before.basis.z * Tuning.HEAD_SIZE * 0.5
	g.state = Game.State.DEAD
	var after := wv._head_transform(1.0)  # 1 초 뒤: 다 찌그러졌다
	assert(is_equal_approx(after.basis.get_scale().z, Tuning.DEATH_SQUASH), "앞뒤 길이가 DEATH_SQUASH 로 줄어든다: %f" % after.basis.get_scale().z)
	assert(after.basis.get_scale().x > 1.0, "찌그러지며 옆으로 조금 퍼진다")
	var front_after := after.origin - after.basis.z * Tuning.HEAD_SIZE * 0.5
	assert(front_after.distance_to(front_before) < 1e-4, "앞면은 제자리: %s → %s" % [front_before, front_after])
	wv.queue_free()
