class_name Game
extends RefCounted

# 규칙 전부: 입력 큐, 진행률, 걸음, 먹기, 죽음. 노드를 쓰지 않아 헤드리스로 검사한다.

enum State { WAITING, RUNNING, DEAD, CLEARED }

# 벌레를 먹은 순간(걸음 이벤트 안). 종류, 얻은 점수, 먹은 칸.
signal ate(kind: int, points: int, cell: Vector3i)
# 판의 벌레를 전부 먹었다.
signal cleared

var level := Tuning.LEVEL_MAX
var height := Tuning.BOX
var worm: Worm
var field: Field
var state := State.WAITING
var alpha := 0.0              # 머리가 지금 칸을 지난 비율. 0 = 입구 면, 1 = 출구 면
var speed := Tuning.SPEED_START
var score := 0
var elapsed := 0.0            # 실행 중(맵 회전 중 제외)에 흐른 시간(초). 타임어택 기록이 쓴다
var queue: Array[int] = []    # 아직 적용 안 된 조향 입력(Worm.Steer). 칸 경계마다 하나씩 꺼내 쓴다
var paused := false           # 맵 회전 중이면 밖에서 켠다
var just_grew := false        # 이번 걸음에 꼬리가 자랐는가(새 꼬리가 부풀어 오르는 연출용)
var steps := 0                # 지금까지 넘은 칸 수(걸음 이벤트 횟수)
var eat_steps: Array[int] = []  # 벌레를 먹은 걸음 번호. 먹은 덩어리가 몸을 따라 흐르는 연출이 쓴다(꼬리를 지나면 버린다)
var eaten_cell := Vector3i.ZERO # 가장 최근에 먹은 벌레의 칸
var eaten_kind := -1            # 가장 최근에 먹은 벌레의 종류

# 레벨 N 의 맵 높이 = N 칸(최대 LEVEL_MAX).
static func height_of(lv: int) -> int:
	return clampi(lv, 1, Tuning.LEVEL_MAX)

# 종류마다 나오는 벌레 수: 레벨 1~3 은 1, 4~6 은 2, 7~8 은 3. 한 판에 이만큼만 나오고 다시 생기지 않는다.
static func bugs_per_kind(lv: int) -> int:
	return clampi((height_of(lv) - 1) / 3 + 1, 1, 3)

# 바위 수: 레벨 1 은 4개, 레벨마다 하나씩, 최대 ROCK_COUNT.
static func rocks_of(lv: int) -> int:
	return mini(3 + height_of(lv), Tuning.ROCK_COUNT)

func _init(seed: int = 0, perf := false, lv: int = Tuning.LEVEL_MAX) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	level = height_of(Tuning.LEVEL_MAX if perf else lv)
	height = level
	field = Field.new(Tuning.BOX, rng, height)
	var per_kind := 1 if perf else bugs_per_kind(level)
	if perf:
		var path := Worm.serpentine_path(Tuning.BOX)
		# 상자를 줄여도 벌레 놓을 칸은 남긴다.
		var n := mini(Tuning.PERF_LENGTH, path.size() - Tuning.BUG_COUNT)
		var body: Array[Vector3i] = []
		for i in range(n - 1, -1, -1):
			body.append(path[i])
		worm = Worm.from_cells(body)
	else:
		var start := Vector3i(Tuning.START_HEAD.x, height / 2, Tuning.START_HEAD.z)  # 높이의 가운데 층
		worm = Worm.straight(start, Tuning.START_DIR, Tuning.START_LENGTH)
		field.place_rocks(rocks_of(level), worm.cells, Tuning.ROCK_CLEAR_RADIUS)
	for k in Tuning.BUG_COUNT:  # 종류마다 per_kind 마리
		for j in per_kind:
			field.spawn_bug(worm.cell_set(), k)

# 조향 입력(Worm.Steer). 지렁이는 늘 앞으로 가고, 이 입력이 머리 방향을 지렁이 기준으로 꺾는다.
# 받아들였으면 true. 출발 전 첫 입력은 바로 첫 꺾임이 되고, 그 뒤에는 큐에 쌓였다가 칸 경계에서 적용된다.
func press(steer: int) -> bool:
	if height == 1 and (steer == Worm.Steer.UP or steer == Worm.Steer.DOWN):
		return false  # 1층 맵에는 위아래가 없다
	if state == State.WAITING:
		worm.head_exit = Worm.turned(steer, worm.entries[0], worm.refs[0])
		state = State.RUNNING
		return true
	if state != State.RUNNING or queue.size() >= Tuning.QUEUE_MAX:
		return false
	queue.append(steer)
	return true

# 큐 맨 앞 입력이 다음 칸에서 만들 나가는 방향(고개 예고 연출용). 큐가 비었으면 ZERO.
func queued_exit() -> Vector3i:
	if queue.is_empty():
		return Vector3i.ZERO
	var d := worm.head_exit
	var r := d if d.y == 0 else worm.refs[0]
	return Worm.turned(queue[0], d, r)

func advance(delta: float) -> void:
	if state == State.CLEARED:  # 마지막 벌레를 삼키던 걸음만 마저 끝내고 선다
		alpha = minf(alpha + minf(speed * delta, Tuning.MAX_STEP_PER_FRAME), 0.99)
		return
	if state != State.RUNNING or paused:
		return
	elapsed += delta
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

# 진행값: 지금까지 넘은 칸 수 + 지금 칸 안의 진행률. 단조 증가한다.
func progress() -> float:
	return float(steps) + alpha

# 머리가 출구 면을 넘는 순간. 막힌 칸은 advance 가 먼저 걸러낸다.
func _step() -> void:
	var next := worm.head() + worm.head_exit
	alpha -= 1.0
	steps += 1
	while not eat_steps.is_empty() and steps - eat_steps[0] > worm.length() + 2:
		eat_steps.pop_front()
	just_grew = field.has_bug(next)
	var kind := -1
	var points := 0
	if just_grew:
		kind = field.kind_at(next)
		points = Tuning.BUG_SCORES[kind]
		field.remove_bug(next)
		score += points
		speed = minf(speed + Tuning.SPEED_STEP, Tuning.SPEED_MAX)
		eat_steps.append(steps)
		eaten_cell = next
		eaten_kind = kind
	worm.step(just_grew)
	if just_grew:
		ate.emit(kind, points, next)
		if field.bugs.is_empty():
			state = State.CLEARED
			cleared.emit()
	# 새 칸의 출구: 큐의 입력을 이 칸으로 들어온 방향(entries[0])과 윗면 기준(refs[0])에서 꺾은 방향, 없으면 직진.
	worm.head_exit = Worm.turned(queue.pop_front(), worm.entries[0], worm.refs[0]) if not queue.is_empty() else worm.entries[0]
