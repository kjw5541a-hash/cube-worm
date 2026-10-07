class_name Game
extends RefCounted

# 규칙 전부: 입력 큐, 진행률, 걸음, 먹기, 죽음. 노드를 쓰지 않아 헤드리스로 검사한다.

enum State { WAITING, RUNNING, DEAD }

var worm: Worm
var field: Field
var state := State.WAITING
var alpha := 0.0              # 머리가 지금 칸을 지난 비율. 0 = 입구 면, 1 = 출구 면
var speed := Tuning.SPEED_START
var score := 0
var queue: Array[Vector3i] = []
var paused := false           # 맵 회전 중이면 밖에서 켠다
var just_grew := false        # 이번 걸음에 꼬리가 자랐는가(새 꼬리가 부풀어 오르는 연출용)

func _init(seed: int = 0, perf := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	field = Field.new(Tuning.BOX, rng)
	if perf:
		var path := Worm.serpentine_path(Tuning.BOX)
		# 상자를 줄여도 벌레 놓을 칸은 남긴다.
		var n := mini(Tuning.PERF_LENGTH, path.size() - Tuning.BUG_COUNT)
		var body: Array[Vector3i] = []
		for i in range(n - 1, -1, -1):
			body.append(path[i])
		worm = Worm.from_cells(body)
	else:
		worm = Worm.straight(Tuning.START_HEAD, Tuning.START_DIR, Tuning.START_LENGTH)
		field.place_rocks(Tuning.ROCK_COUNT, worm.cells, Tuning.ROCK_CLEAR_RADIUS)
	for i in Tuning.BUG_COUNT:
		field.spawn_bug(worm.cell_set())

# 월드 방향 입력. 받아들였으면 true.
func press(dir: Vector3i) -> bool:
	if state == State.WAITING:
		if dir == -worm.entries[0]:
			return false  # 목 쪽으로는 출발할 수 없다
		worm.head_exit = dir
		state = State.RUNNING
		return true
	if state != State.RUNNING:
		return false
	var last: Vector3i = queue.back() if not queue.is_empty() else worm.head_exit
	if dir == last or dir == -last or queue.size() >= Tuning.QUEUE_MAX:
		return false
	queue.append(dir)
	return true

func advance(delta: float) -> void:
	if state != State.RUNNING or paused:
		return
	alpha += minf(speed * delta, Tuning.MAX_STEP_PER_FRAME)
	# 다음 칸이 막혔으면 머리 앞면이 그 면에 닿는 순간 멈춘다. 몸 칸은 걸음 이벤트에서만 바뀌므로
	# 여기서 보나 걸음 이벤트에서 보나 결과가 같다(출구는 칸에 들어설 때 이미 정해졌다).
	if alpha >= Tuning.DEATH_STOP and blocked(worm.head() + worm.head_exit):
		alpha = Tuning.DEATH_STOP
		state = State.DEAD
		return
	if alpha >= 1.0:
		_step()

# 머리가 c 로 들어가면 죽는가. 현재 꼬리 칸은 그 걸음에 비워지므로 통과다.
func blocked(c: Vector3i) -> bool:
	return not field.in_bounds(c) or field.has_rock(c) or worm.blocks(c)

# 머리가 출구 면을 넘는 순간. 막힌 칸은 advance 가 먼저 걸러낸다.
func _step() -> void:
	var next := worm.head() + worm.head_exit
	alpha -= 1.0
	just_grew = field.has_bug(next)
	if just_grew:
		field.remove_bug(next)
		score += 1
		speed = minf(speed + Tuning.SPEED_STEP, Tuning.SPEED_MAX)
	worm.step(just_grew)
	if just_grew:
		field.spawn_bug(worm.cell_set())
	worm.head_exit = queue.pop_front() if not queue.is_empty() else worm.entries[0]
