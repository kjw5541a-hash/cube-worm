extends SceneTree

const X := Vector3i(1, 0, 0)
const Y := Vector3i(0, 1, 0)
const Z := Vector3i(0, 0, 1)
const FRAME := 1.0 / 60.0

func _initialize() -> void:
	_test_start_rules()
	_test_queue_rules()
	_test_alpha_and_frame_clamp()
	_test_straight_when_queue_empty()
	_test_queue_turns_next_cell()
	_test_wall_death()
	_test_rock_death()
	_test_body_death()
	_test_tail_follow_allowed()
	_test_stop_before_obstacle_every_frame()
	_test_eating()
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
	g.worm = Worm.straight(head, -X, length)
	return g

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
	assert(not g.press(X), "목 쪽으로는 출발할 수 없다")
	assert(g.state == Game.State.WAITING)
	g.advance(1.0)
	assert(g.alpha == 0.0, "출발 전에는 진행하지 않는다")
	assert(g.press(-X), "앞으로 출발")
	assert(g.state == Game.State.RUNNING and g.worm.head_exit == -X)
	var g2 := _clean()
	assert(g2.press(Y), "옆이나 위로도 바로 출발한다")
	assert(g2.worm.head_exit == Y, "첫 입력은 큐를 거치지 않고 바로 머리 칸의 출구가 된다")
	assert(g2.queue.is_empty())

func _test_queue_rules() -> void:
	var g := _clean()
	g.press(-X)
	assert(not g.press(-X), "같은 방향은 무시")
	assert(not g.press(X), "정반대는 무시")
	assert(g.press(Y))
	assert(not g.press(-Y), "큐 마지막의 정반대도 무시")
	assert(not g.press(Y), "큐 마지막과 같은 방향도 무시")
	assert(g.press(Z))
	assert(not g.press(-X), "큐는 최대 2개")
	assert(g.queue.size() == 2)

func _test_alpha_and_frame_clamp() -> void:
	var g := _clean()
	g.press(-X)
	g.advance(0.1)
	assert(is_equal_approx(g.alpha, Tuning.SPEED_START * 0.1), "시작 속도 × 0.1초만큼 간다: %f" % g.alpha)
	var g2 := _clean()
	g2.press(-X)
	g2.advance(5.0)
	assert(is_equal_approx(g2.alpha, 1.0 / 3.0), "한 프레임에 1/3 칸을 넘지 않는다: %f" % g2.alpha)
	assert(g2.worm.head() == Vector3i(4, 4, 4), "프레임이 밀려도 칸을 건너뛰지 않는다")

func _test_straight_when_queue_empty() -> void:
	var g := _clean()
	g.press(-X)
	_one_step(g)
	assert(g.worm.head() == Vector3i(3, 4, 4))
	assert(g.worm.head_exit == -X, "큐가 비면 직진")
	assert(g.worm.length() == 3)
	assert(g.alpha >= 0.0 and g.alpha < 1.0)

func _test_queue_turns_next_cell() -> void:
	var g := _clean()
	g.press(-X)
	g.press(Y)
	_one_step(g)
	assert(g.worm.head() == Vector3i(3, 4, 4), "이미 정해진 출구로 먼저 간다")
	assert(g.worm.head_exit == Y, "새 칸의 출구는 큐에서 꺼낸 방향")
	assert(g.queue.is_empty())
	_one_step(g)
	assert(g.worm.head() == Vector3i(3, 5, 4), "다음 걸음에 꺾인다")

func _test_wall_death() -> void:
	var g := _clean(Vector3i(0, 4, 4))
	g.press(-X)
	_one_step(g)
	assert(g.state == Game.State.DEAD, "상자 밖으로 나가면 죽는다")
	assert(g.alpha == Tuning.DEATH_STOP, "머리 앞면이 벽 면에 닿는 자리에서 멈춘다: %f" % g.alpha)
	assert(g.worm.head() == Vector3i(0, 4, 4))
	g.advance(1.0)
	assert(g.alpha == Tuning.DEATH_STOP, "죽은 뒤에는 진행하지 않는다")
	assert(not g.press(Y), "죽은 뒤에는 입력을 받지 않는다")

func _test_rock_death() -> void:
	var g := _clean()
	g.field.rocks[Vector3i(3, 4, 4)] = true
	g.press(-X)
	_one_step(g)
	assert(g.state == Game.State.DEAD, "바위에 부딪히면 죽는다")

func _test_body_death() -> void:
	var g := _clean(Vector3i(2, 4, 4), 5)
	g.press(Z)
	g.press(X)
	g.press(-Z)
	_one_step(g)
	_one_step(g)
	assert(g.state == Game.State.RUNNING)
	_one_step(g)
	assert(g.state == Game.State.DEAD, "자기 몸에 부딪히면 죽는다")

func _test_tail_follow_allowed() -> void:
	var g := _clean(Vector3i(2, 4, 4), 4)
	g.press(Z)
	g.press(X)
	g.press(-Z)
	for i in 3:
		_one_step(g)
	assert(g.state == Game.State.RUNNING, "막 비워지는 꼬리 칸으로는 들어가도 된다")
	assert(g.worm.head() == Vector3i(3, 4, 4))

# 막힌 칸 앞에서는 어떤 프레임 간격으로 와도 DEATH_STOP 을 넘지 않는다.
func _test_stop_before_obstacle_every_frame() -> void:
	for dt in [1.0 / 144.0, 1.0 / 60.0, 1.0 / 20.0, 0.5]:
		var g := _clean()
		g.field.rocks[Vector3i(3, 4, 4)] = true
		g.press(-X)
		for i in 400:
			g.advance(dt)
			assert(g.alpha <= Tuning.DEATH_STOP, "막힌 칸 앞에서 머리가 장애물에 박혔다: %f (dt %f)" % [g.alpha, dt])
		assert(g.state == Game.State.DEAD and g.worm.head() == Vector3i(4, 4, 4), "바위 앞 칸에서 멈춰 죽는다")

func _test_eating() -> void:
	var g := _clean()
	g.field.bugs.assign([Vector3i(3, 4, 4), Vector3i(0, 0, 0), Vector3i(7, 7, 7)])
	g.press(-X)
	_one_step(g)
	assert(g.score == 1, "벌레 한 마리 = 1점")
	assert(g.worm.length() == 4, "한 마디 자란다")
	assert(g.worm.cells[3] == Vector3i(6, 4, 4), "꼬리가 제자리에 남는다")
	assert(g.just_grew)
	assert(is_equal_approx(g.speed, Tuning.SPEED_START + Tuning.SPEED_STEP), "먹으면 속도가 오른다: %f" % g.speed)
	assert(g.field.bugs.size() == 3, "먹으면 새 벌레가 생겨 3마리를 유지한다")
	assert(not g.field.bugs.has(Vector3i(3, 4, 4)), "먹은 벌레는 사라진다")
	for b in g.field.bugs:
		assert(not g.worm.cell_set().has(b), "새 벌레가 지렁이 위에 생겼다")
	_one_step(g)
	assert(not g.just_grew, "다음 걸음에는 자라지 않는다")
	assert(g.worm.length() == 4)

func _test_speed_cap() -> void:
	var g := _clean()
	g.speed = Tuning.SPEED_MAX - Tuning.SPEED_STEP * 0.5
	g.field.bugs.assign([Vector3i(3, 4, 4), Vector3i(2, 4, 4)])
	g.press(-X)
	_one_step(g)
	assert(g.speed == Tuning.SPEED_MAX, "최대 속도에서 멈춘다: %f" % g.speed)
	_one_step(g)
	assert(g.speed == Tuning.SPEED_MAX, "최대에서 더 오르지 않는다: %f" % g.speed)

func _test_paused_freezes() -> void:
	var g := _clean()
	g.press(-X)
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
		var worm := g.worm.cell_set()
		for b in g.field.bugs:
			assert(not worm.has(b) and not g.field.rocks.has(b), "벌레는 빈 칸에만")

# 아무렇게나 눌러 수천 걸음을 진행하며 매 걸음 불변식을 본다.
func _test_bugs_stay_valid_in_random_play() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var dirs: Array[Vector3i] = [X, -X, Y, -Y, Z, -Z]
	var g := Game.new(0)
	var games := 0
	var steps := 0
	while steps < 3000:
		if g.state == Game.State.DEAD:
			games += 1
			g = Game.new(games)
		if rng.randf() < 0.08 or g.state == Game.State.WAITING:
			g.press(dirs[rng.randi_range(0, 5)])
		var before := g.worm.head()
		g.advance(FRAME)
		if g.worm.head() != before:
			steps += 1
			assert(g.field.bugs.size() == Tuning.BUG_COUNT, "벌레 수가 늘 같다")
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
	assert(g.field.bugs.size() == Tuning.BUG_COUNT)
	for j in range(1, g.worm.length()):
		var d := g.worm.cells[j - 1] - g.worm.cells[j]
		assert(absi(d.x) + absi(d.y) + absi(d.z) == 1, "마디가 끊겼다")
		assert(g.worm.entries[j - 1] == d, "입구 방향이 실제 이동과 다르다")
