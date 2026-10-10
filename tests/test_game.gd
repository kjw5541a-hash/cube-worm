extends SceneTree

const X := Vector3i(1, 0, 0)
const Y := Vector3i(0, 1, 0)
const Z := Vector3i(0, 0, 1)
const L := Worm.Steer.LEFT
const R := Worm.Steer.RIGHT
const U := Worm.Steer.UP
const D := Worm.Steer.DOWN
const FRAME := 1.0 / 60.0

func _initialize() -> void:
	_test_start_rules()
	_test_queue_rules()
	_test_alpha_and_frame_clamp()
	_test_straight_when_queue_empty()
	_test_queue_turns_next_cell()
	_test_double_turn_is_a_u_turn()
	_test_up_then_down_down_comes_back_down()
	_test_queued_exit_previews_next_turn()
	_test_wall_death()
	_test_rock_death()
	_test_body_death()
	_test_tail_follow_allowed()
	_test_stop_before_obstacle_every_frame()
	_test_eating()
	_test_scores_by_kind()
	_test_ate_signal()
	_test_progress_and_eat_marks()
	_test_speed_cap()
	_test_paused_freezes()
	_test_new_game_layout()
	_test_bugs_stay_valid_in_random_play()
	_test_perf_worm()
	print("test_game: OK")
	quit()

# 바위·벌레를 치운 판. 시작 지렁이는 머리 (4,4,4), -X 를 본다.
func _clean(head := Vector3i(4, 4, 4), length := 3) -> Game:
	var g := Game.new(1)
	g.field.rocks.clear()
	g.field.bugs.clear()
	g.field.kinds.clear()
	g.worm = Worm.straight(head, -X, length)
	return g

# 출발한 상태로 만든다: 머리가 dir 쪽으로 곧장 간다. 조향은 지렁이 기준이라 첫 입력이 곧 꺾임이므로,
# 곧장 출발하는 판이 필요한 테스트는 이렇게 직접 놓는다.
func _go(g: Game, dir: Vector3i) -> void:
	g.state = Game.State.RUNNING
	g.worm.head_exit = dir

# 판의 벌레를 [칸, 종류] 쌍 목록으로 바꿔 놓는다(bugs 와 kinds 는 늘 같이 간다).
func _bugs(g: Game, list: Array) -> void:
	g.field.bugs.clear()
	g.field.kinds.clear()
	for row in list:
		g.field.bugs.append(row[0])
		g.field.kinds.append(row[1])

# 머리가 한 칸 나아갈 때까지 돌린다.
func _one_step(g: Game) -> void:
	var start := g.worm.head()
	for i in 200:
		g.advance(FRAME)
		if g.worm.head() != start or g.state != Game.State.RUNNING:
			return
	assert(false, "200 프레임 안에 한 걸음도 못 갔다")

func _test_start_rules() -> void:
	var g := _clean()
	assert(g.state == Game.State.WAITING)
	g.advance(1.0)
	assert(g.alpha == 0.0, "출발 전에는 진행하지 않는다")
	# 첫 버튼이 곧 첫 꺾임이다. 시작 지렁이는 -X 를 본다.
	for row in [[L, Z], [R, -Z], [U, Y], [D, -Y]]:
		var s := _clean()
		assert(s.press(row[0]), "출발 전 첫 입력은 받는다")
		assert(s.state == Game.State.RUNNING and s.worm.head_exit == row[1], "-X 를 보는 지렁이의 %s → %s" % [row[0], s.worm.head_exit])
		assert(s.queue.is_empty(), "첫 입력은 큐를 거치지 않고 바로 머리 칸의 출구가 된다")

func _test_queue_rules() -> void:
	var g := _clean()
	_go(g, -X)
	assert(g.press(L))
	assert(g.press(L), "같은 버튼을 이어서 눌러도 받는다 — 두 번 꺾는다")
	assert(not g.press(R), "큐는 최대 2개")
	assert(g.queue == ([L, L] as Array[int]), "큐: %s" % [g.queue])

func _test_alpha_and_frame_clamp() -> void:
	var g := _clean()
	_go(g, -X)
	g.advance(0.1)
	assert(is_equal_approx(g.alpha, Tuning.SPEED_START * 0.1), "시작 속도 × 0.1초만큼 간다: %f" % g.alpha)
	var g2 := _clean()
	_go(g2, -X)
	g2.advance(5.0)
	assert(is_equal_approx(g2.alpha, 1.0 / 3.0), "한 프레임에 1/3 칸을 넘지 않는다: %f" % g2.alpha)
	assert(g2.worm.head() == Vector3i(4, 4, 4), "프레임이 밀려도 칸을 건너뛰지 않는다")

func _test_straight_when_queue_empty() -> void:
	var g := _clean()
	_go(g, -X)
	_one_step(g)
	assert(g.worm.head() == Vector3i(3, 4, 4))
	assert(g.worm.head_exit == -X, "큐가 비면 직진")
	assert(g.worm.length() == 3)
	assert(g.alpha >= 0.0 and g.alpha < 1.0)

func _test_queue_turns_next_cell() -> void:
	var g := _clean()
	_go(g, -X)
	g.press(U)
	_one_step(g)
	assert(g.worm.head() == Vector3i(3, 4, 4), "이미 정해진 출구로 먼저 간다")
	assert(g.worm.head_exit == Y, "새 칸의 출구는 큐에서 꺼낸 입력을 지렁이 기준으로 꺾은 방향")
	assert(g.queue.is_empty())
	_one_step(g)
	assert(g.worm.head() == Vector3i(3, 5, 4), "다음 걸음에 꺾인다")

# ◀ 를 두 번 누르면 두 칸에 걸쳐 U턴한다. 두 번째 꺾임은 첫 꺾임 뒤의 방향이 기준이다.
func _test_double_turn_is_a_u_turn() -> void:
	var g := _clean()
	_go(g, -X)
	g.press(L)
	g.press(L)
	_one_step(g)
	assert(g.worm.head() == Vector3i(3, 4, 4) and g.worm.head_exit == Z, "첫 ◀: -X 에서 +Z 로")
	_one_step(g)
	assert(g.worm.head() == Vector3i(3, 4, 5) and g.worm.head_exit == X, "둘째 ◀: +Z 에서 +X 로")
	_one_step(g)
	assert(g.worm.head() == Vector3i(4, 4, 5), "U턴을 마치고 되돌아간다")

# 위로 올라가다 다시 내려오려면 ▼ 를 두 번 누른다: 첫 ▼ 는 가던 수평 방향으로 눕고, 둘째 ▼ 가 아래로 꺾는다.
func _test_up_then_down_down_comes_back_down() -> void:
	var g := _clean()
	_go(g, -X)
	g.press(U)
	_one_step(g)
	assert(g.worm.head() == Vector3i(3, 4, 4) and g.worm.head_exit == Y, "▲ 로 위를 향한다")
	g.press(D)
	g.press(D)
	_one_step(g)
	assert(g.worm.head() == Vector3i(3, 5, 4) and g.worm.head_exit == -X, "올라가다 ▼ 한 번: 가던 수평 방향(-X)으로 눕는다")
	_one_step(g)
	assert(g.worm.head() == Vector3i(2, 5, 4) and g.worm.head_exit == -Y, "▼ 두 번째: 아래로 꺾는다")
	_one_step(g)
	assert(g.worm.head() == Vector3i(2, 4, 4), "올라간 길 옆 칸으로 내려온다")

func _test_queued_exit_previews_next_turn() -> void:
	var g := _clean()
	_go(g, -X)
	assert(g.queued_exit() == Vector3i.ZERO, "큐가 비면 예고할 방향이 없다")
	g.press(U)
	assert(g.queued_exit() == Y, "-X 로 가는 중 ▲ 는 다음 칸에서 위")
	g.press(L)
	assert(g.queued_exit() == Y, "예고는 큐 맨 앞 입력만 본다")
	var up := _clean()
	_go(up, -X)
	up.press(U)
	_one_step(up)
	up.press(D)
	assert(up.queued_exit() == -X, "위로 가는 중 ▼ 는 가던 수평 방향(-X)")

func _test_wall_death() -> void:
	var g := _clean(Vector3i(0, 4, 4))
	_go(g, -X)
	_one_step(g)
	assert(g.state == Game.State.DEAD, "상자 밖으로 나가면 죽는다")
	assert(g.alpha == Tuning.DEATH_STOP, "머리 앞면이 벽 면에 닿는 자리에서 멈춘다: %f" % g.alpha)
	assert(g.worm.head() == Vector3i(0, 4, 4))
	g.advance(1.0)
	assert(g.alpha == Tuning.DEATH_STOP, "죽은 뒤에는 진행하지 않는다")
	assert(not g.press(U), "죽은 뒤에는 입력을 받지 않는다")

func _test_rock_death() -> void:
	var g := _clean()
	g.field.rocks[Vector3i(3, 4, 4)] = true
	_go(g, -X)
	_one_step(g)
	assert(g.state == Game.State.DEAD, "바위에 부딪히면 죽는다")

func _test_body_death() -> void:
	var g := _clean(Vector3i(2, 4, 4), 5)
	g.press(L)  # 출발: -X 에서 왼쪽 = +Z
	g.press(L)  # +Z 에서 왼쪽 = +X
	g.press(L)  # +X 에서 왼쪽 = -Z
	_one_step(g)
	_one_step(g)
	assert(g.state == Game.State.RUNNING)
	_one_step(g)
	assert(g.state == Game.State.DEAD, "자기 몸에 부딪히면 죽는다")

func _test_tail_follow_allowed() -> void:
	var g := _clean(Vector3i(2, 4, 4), 4)
	g.press(L)
	g.press(L)
	g.press(L)
	for i in 3:
		_one_step(g)
	assert(g.state == Game.State.RUNNING, "막 비워지는 꼬리 칸으로는 들어가도 된다")
	assert(g.worm.head() == Vector3i(3, 4, 4))

# 막힌 칸 앞에서는 어떤 프레임 간격으로 와도 DEATH_STOP 을 넘지 않는다.
func _test_stop_before_obstacle_every_frame() -> void:
	for dt in [1.0 / 144.0, 1.0 / 60.0, 1.0 / 20.0, 0.5]:
		var g := _clean()
		g.field.rocks[Vector3i(3, 4, 4)] = true
		_go(g, -X)
		for i in 400:
			g.advance(dt)
			assert(g.alpha <= Tuning.DEATH_STOP, "막힌 칸 앞에서 머리가 장애물에 박혔다: %f (dt %f)" % [g.alpha, dt])
		assert(g.state == Game.State.DEAD and g.worm.head() == Vector3i(4, 4, 4), "바위 앞 칸에서 멈춰 죽는다")

func _test_eating() -> void:
	var g := _clean()
	_bugs(g, [[Vector3i(3, 4, 4), 0], [Vector3i(0, 0, 0), 1], [Vector3i(7, 7, 7), 2]])
	_go(g, -X)
	_one_step(g)
	assert(g.score == Tuning.BUG_SCORES[0], "크림(종류 0) 한 마리의 점수")
	assert(g.worm.length() == 4, "한 마디 자란다")
	assert(g.worm.cells[3] == Vector3i(6, 4, 4), "꼬리가 제자리에 남는다")
	assert(g.just_grew)
	assert(is_equal_approx(g.speed, Tuning.SPEED_START + Tuning.SPEED_STEP), "먹으면 속도가 오른다: %f" % g.speed)
	assert(g.field.bugs.size() == 3, "먹으면 새 벌레가 생겨 3마리를 유지한다")
	assert(not g.field.bugs.has(Vector3i(3, 4, 4)), "먹은 벌레는 사라진다")
	var ks := g.field.kinds.duplicate()
	ks.sort()
	assert(ks == ([0, 1, 2] as Array[int]), "먹은 종류가 다시 생겨 종류마다 한 마리씩: %s" % [ks])
	for b in g.field.bugs:
		assert(not g.worm.cell_set().has(b), "새 벌레가 지렁이 위에 생겼다")
	_one_step(g)
	assert(not g.just_grew, "다음 걸음에는 자라지 않는다")
	assert(g.worm.length() == 4)

func _test_speed_cap() -> void:
	var g := _clean()
	g.speed = Tuning.SPEED_MAX - Tuning.SPEED_STEP * 0.5
	_bugs(g, [[Vector3i(3, 4, 4), 0], [Vector3i(2, 4, 4), 0]])
	_go(g, -X)
	_one_step(g)
	assert(g.speed == Tuning.SPEED_MAX, "최대 속도에서 멈춘다: %f" % g.speed)
	_one_step(g)
	assert(g.speed == Tuning.SPEED_MAX, "최대에서 더 오르지 않는다: %f" % g.speed)

func _test_paused_freezes() -> void:
	var g := _clean()
	_go(g, -X)
	g.paused = true
	g.advance(0.2)
	assert(g.alpha == 0.0, "회전 중에는 진행하지 않는다")
	g.paused = false
	g.advance(0.1)
	assert(g.alpha > 0.0)

func _test_new_game_layout() -> void:
	for seed in 30:
		var g := Game.new(seed)
		assert(g.worm.length() == Tuning.START_LENGTH and g.worm.head() == Tuning.START_HEAD)
		assert(g.field.rocks.size() == Tuning.ROCK_COUNT, "바위 수")
		assert(g.field.bugs.size() == Tuning.BUG_COUNT, "벌레 수")
		assert(g.field.kinds == ([0, 1, 2] as Array[int]), "종류마다 한 마리씩: %s" % [g.field.kinds])
		var worm := g.worm.cell_set()
		for b in g.field.bugs:
			assert(not worm.has(b) and not g.field.rocks.has(b), "벌레는 빈 칸에만")

# 아무렇게나 눌러 수천 걸음을 진행하며 매 걸음 불변식을 본다.
func _test_bugs_stay_valid_in_random_play() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var steers := [L, R, U, D]
	var g := Game.new(0)
	var games := 0
	var steps := 0
	while steps < 3000:
		if g.state == Game.State.DEAD:
			games += 1
			g = Game.new(games)
		if rng.randf() < 0.08 or g.state == Game.State.WAITING:
			g.press(steers[rng.randi_range(0, 3)])
		var before := g.worm.head()
		g.advance(FRAME)
		if g.worm.head() != before:
			steps += 1
			assert(g.field.bugs.size() == Tuning.BUG_COUNT, "벌레 수가 늘 같다")
			var ks := g.field.kinds.duplicate()
			ks.sort()
			assert(ks == ([0, 1, 2] as Array[int]), "벌레는 늘 종류마다 한 마리씩이다: %s" % [ks])
			assert(g.eat_steps.size() <= g.worm.length() + 3, "꼬리를 지난 먹은 기록은 버린다: %d" % g.eat_steps.size())
			var worm := g.worm.cell_set()
			assert(worm.size() == g.worm.length(), "지렁이가 자기 칸과 겹친다")
			for b in g.field.bugs:
				assert(not worm.has(b) and not g.field.rocks.has(b), "벌레가 빈 칸이 아닌 곳에 있다")
			for c in g.worm.cells:
				assert(g.field.in_bounds(c) and not g.field.rocks.has(c), "지렁이가 상자 밖이나 바위 위에 있다")

func _test_perf_worm() -> void:
	var g := Game.new(5, true)
	var cells := Tuning.BOX * Tuning.BOX * Tuning.BOX
	assert(g.worm.length() == mini(Tuning.PERF_LENGTH, cells - Tuning.BUG_COUNT), "성능 확인용 지렁이 길이")
	assert(g.field.rocks.is_empty(), "성능 확인용 판에는 바위가 없다")
	assert(g.field.bugs.size() == Tuning.BUG_COUNT and g.field.kinds == ([0, 1, 2] as Array[int]))
	for j in range(1, g.worm.length()):
		var d := g.worm.cells[j - 1] - g.worm.cells[j]
		assert(absi(d.x) + absi(d.y) + absi(d.z) == 1, "마디가 끊겼다")
		assert(g.worm.entries[j - 1] == d, "입구 방향이 실제 이동과 다르다")

# 벌레 종류마다 점수가 다르고, 성장과 속도 상승은 같다.
func _test_scores_by_kind() -> void:
	var seen := {}
	for kind in Tuning.BUG_COUNT:
		seen[Tuning.BUG_SCORES[kind]] = true
		var g := _clean()
		_bugs(g, [[Vector3i(3, 4, 4), kind]])
		_go(g, -X)
		_one_step(g)
		assert(g.score == Tuning.BUG_SCORES[kind], "종류 %d 의 점수: %d" % [kind, g.score])
		assert(g.worm.length() == 4, "점수와 무관하게 한 마디 자란다: 종류 %d" % kind)
		assert(is_equal_approx(g.speed, Tuning.SPEED_START + Tuning.SPEED_STEP), "속도 상승도 같다: 종류 %d" % kind)
		assert(g.field.kinds == ([kind] as Array[int]), "먹은 종류가 다시 생긴다: 종류 %d, %s" % [kind, g.field.kinds])
	assert(Tuning.BUG_SCORES.size() == Tuning.BUG_COUNT and seen.size() == Tuning.BUG_COUNT, "점수는 종류마다 다르다")

# 먹는 순간 ate 신호가 한 번, 종류·점수·칸과 함께 온다.
func _test_ate_signal() -> void:
	var g := _clean()
	_bugs(g, [[Vector3i(3, 4, 4), 2]])
	var got := []
	g.ate.connect(func(kind: int, points: int, cell: Vector3i) -> void: got.append([kind, points, cell]))
	_go(g, -X)
	_one_step(g)
	assert(got == [[2, Tuning.BUG_SCORES[2], Vector3i(3, 4, 4)]], "먹으면 ate 신호가 한 번: %s" % [got])
	assert(g.eaten_cell == Vector3i(3, 4, 4) and g.eaten_kind == 2, "최근에 먹은 벌레 기록")
	_one_step(g)
	assert(got.size() == 1, "먹지 않은 걸음에는 신호가 없다")

# 진행값(넘은 칸 수 + 칸 안 진행률)과 먹은 걸음 기록. 연출이 쓴다.
func _test_progress_and_eat_marks() -> void:
	var g := _clean()
	_bugs(g, [[Vector3i(3, 4, 4), 0]])
	_go(g, -X)
	assert(g.progress() == 0.0, "출발 직후 진행값 0")
	g.advance(0.1)
	assert(is_equal_approx(g.progress(), g.alpha), "첫 칸 안에서는 진행값 = alpha")
	_one_step(g)
	assert(g.steps == 1 and g.eat_steps == ([1] as Array[int]), "먹은 걸음 번호를 기록한다: %s" % [g.eat_steps])
	assert(g.progress() >= 1.0 and g.progress() < 2.0, "한 칸 넘긴 뒤 진행값: %f" % g.progress())
