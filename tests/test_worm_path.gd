extends SceneTree

const X := Vector3i(1, 0, 0)
const Y := Vector3i(0, 1, 0)
const Z := Vector3i(0, 0, 1)
const DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const EPS := 1e-4

func _initialize() -> void:
	_test_straight_points()
	_test_turn_points()
	_test_pose_rules()
	_test_basis_ends_and_tangent()
	_test_u_turn_comes_out_upright()
	_test_steer_matches_drawn_pose()
	_test_random_play_inside_cells_and_continuous()
	print("test_worm_path: OK")
	quit()

func _near(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < EPS

func _same_basis(a: Basis, b: Basis) -> bool:
	return _near(a.x, b.x) and _near(a.y, b.y) and _near(a.z, b.z)

func _test_straight_points() -> void:
	var c := Vector3i(0, 0, 0)
	assert(_near(WormPath.point(c, X, X, 0.0), Vector3(0, 0.5, 0.5)), "입구 면 중심")
	assert(_near(WormPath.point(c, X, X, 1.0), Vector3(1, 0.5, 0.5)), "출구 면 중심")
	assert(_near(WormPath.point(c, X, Vector3i.ZERO, 0.0), Vector3(0, 0.5, 0.5)), "출구가 없으면 직진으로 본다")

func _test_turn_points() -> void:
	var c := Vector3i(1, 0, 0)
	assert(_near(WormPath.point(c, X, Y, 0.0), Vector3(1, 0.5, 0.5)), "꺾여도 입구 면 중심에서 시작")
	assert(_near(WormPath.point(c, X, Y, 1.0), Vector3(1.5, 1.0, 0.5)), "출구 면(+Y) 중심에서 끝")
	for i in 11:
		var p := WormPath.point(c, X, Y, i / 10.0)
		assert(absf(p.distance_to(Vector3(1, 1, 0.5)) - 0.5) < EPS, "모서리 중점을 중심으로 반지름 0.5")
	assert(_near(WormPath.tangent(X, Y, 0.0), Vector3(X)) and _near(WormPath.tangent(X, Y, 1.0), Vector3(Y)))

func _test_pose_rules() -> void:
	var b := WormPath.pose(-X, -X)
	assert(_near(-b.z, Vector3(-X)), "정면(-Z)이 진행 방향")
	assert(_near(b.y, Vector3.UP), "수평이면 윗면이 +Y")
	var up := WormPath.pose(Y, X)
	assert(_near(-up.z, Vector3(Y)) and _near(up.y, Vector3(-X)), "+X 로 가다 올라가면 윗면이 -X")
	var down := WormPath.pose(-Y, X)
	assert(_near(-down.z, Vector3(-Y)) and _near(down.y, Vector3(X)), "+X 로 가다 내려가면 윗면이 +X")

# 모든 꺾임 조합에서 양 끝 자세가 맞고, 앞(-Z)이 경로 접선을 정확히 따른다.
func _test_basis_ends_and_tangent() -> void:
	for d_in in DIRS:
		for d_out in DIRS:
			if d_out == d_in or d_out == -d_in:
				continue
			var refs: Array = [d_in] if d_in.y == 0 else [X, -X, Z, -Z]
			for r in refs:
				assert(_same_basis(WormPath.basis(d_in, d_out, r, 0.0), WormPath.pose(d_in, r)), "입구 자세 %s→%s" % [d_in, d_out])
				assert(_same_basis(WormPath.basis(d_in, d_out, r, 1.0), WormPath.pose(d_out, WormPath.exit_ref(d_out, r))), "출구 자세 %s→%s r=%s" % [d_in, d_out, r])
				for i in 11:
					var a := i / 10.0
					var b := WormPath.basis(d_in, d_out, r, a)
					assert(_near(-b.z, WormPath.tangent(d_in, d_out, a)), "앞이 접선과 다르다 %s→%s a=%f" % [d_in, d_out, a])
					assert(b.is_equal_approx(b.orthonormalized()), "자세가 직교가 아니다")

func _test_u_turn_comes_out_upright() -> void:
	# +X 로 가다 올라간 뒤(-X 가 윗면) 되돌아 -X 로 꺾는 칸.
	var b := WormPath.basis(Y, -X, X, 1.0)
	assert(_near(b.y, Vector3.UP), "되돌아 나온 머리는 바로 서야 한다: %s" % b.y)

# 조향의 오른쪽·위는 화면에 그려지는 머리 자세의 오른쪽·윗면과 같아야 한다 — 조작이 보이는 것과 어긋나지 않게.
func _test_steer_matches_drawn_pose() -> void:
	for d in DIRS:
		for r in [X, -X, Z, -Z]:
			if d.y == 0 and r != d:
				continue  # 수평으로 갈 때 기준 방향은 진행 방향 자신이다
			var b := WormPath.pose(d, r)
			var frame := "d=%s r=%s" % [d, r]
			assert(_near(Vector3(Worm.turned(Worm.Steer.RIGHT, d, r)), b.x), "오른쪽이 그려진 머리의 오른쪽과 다르다 " + frame)
			assert(_near(Vector3(Worm.turned(Worm.Steer.LEFT, d, r)), -b.x), "왼쪽이 그려진 머리의 왼쪽과 다르다 " + frame)
			assert(_near(Vector3(Worm.turned(Worm.Steer.UP, d, r)), b.y), "위가 그려진 머리의 윗면과 다르다 " + frame)
			assert(_near(Vector3(Worm.turned(Worm.Steer.DOWN, d, r)), -b.y), "아래가 그려진 머리의 배 쪽과 다르다 " + frame)

# 아무렇게나 눌러 진행하며 (1) 모든 마디가 자기 칸 안에 있고 (2) 걸음이 바뀌는 순간 위치·자세가 이어지는지 본다.
func _test_random_play_inside_cells_and_continuous() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var g := Game.new(0)
	var games := 0
	var steps := 0
	var turns := 0
	while steps < 3000:
		if g.state == Game.State.DEAD:
			games += 1
			g = Game.new(games)
		if rng.randf() < 0.1 or g.state == Game.State.WAITING:
			g.press(rng.randi_range(0, 3))  # Worm.Steer 네 가지 중 아무거나
		var w := g.worm
		var before: Array[Transform3D] = []
		for j in w.length():
			before.append(WormPath.segment(w, j, 1.0))
		var head := w.head()
		g.advance(1.0 / 60.0)
		for j in w.length():
			var p := WormPath.segment(w, j, g.alpha).origin - Vector3(w.cells[j])
			assert(p.x > -EPS and p.y > -EPS and p.z > -EPS and p.x < 1 + EPS and p.y < 1 + EPS and p.z < 1 + EPS, "마디 %d 가 자기 칸 밖에 있다: %s" % [j, p])
		if w.head() != head:
			steps += 1
			if WormPath.turns(w.entries[1], w.entries[0]):
				turns += 1
			for j in before.size():
				var after := WormPath.segment(w, j, 0.0)
				assert(_near(before[j].origin, after.origin), "걸음이 바뀔 때 마디 %d 위치가 튄다" % j)
				assert(_same_basis(before[j].basis, after.basis), "걸음이 바뀔 때 마디 %d 자세가 튄다" % j)
	assert(turns > 300, "꺾임을 충분히 검사하지 못했다: %d" % turns)
