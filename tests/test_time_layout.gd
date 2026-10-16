extends SceneTree

# 타임어택 고정 판: 같은 시드는 늘 같은 배치이고, 타임어택으로 할 만한 배치다.
const DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

# 고정 시드가 만드는 배치를 글자 그대로 적어 둔다. 판 생성 코드(Field, Game)가 바뀌어 배치가 달라지면 여기서 실패한다.
# 의도한 변경이면 Tuning.TIME_LAYOUT_VERSION 을 올리고(옛 시간 기록은 숨겨진다) 이 목록을 새 배치로 고친다.
# 바위는 x,y,z 를 글자순으로, 벌레는 생기는 순서대로 x,y,z:종류 다.
const ROCKS: Array[String] = ["0,4,5", "1,1,2", "1,5,1", "1,7,7", "2,2,1", "4,5,0", "5,6,7", "7,4,1"]
const BUGS: Array[String] = ["1,5,0:0", "1,3,1:0", "3,4,5:0", "2,7,1:1", "5,1,6:1", "6,5,6:1", "7,2,5:2", "2,0,5:2", "5,7,4:2"]

func _initialize() -> void:
	_test_same_seed_same_layout()
	_test_layout_snapshot()
	_test_every_bug_is_reachable()
	_test_bugs_spread_over_floors()
	print("test_time_layout: OK")
	quit()

func _game() -> Game:
	return Game.new(Tuning.TIME_SEED, false, Tuning.TIME_LEVEL)

func _rock_texts(g: Game) -> Array[String]:
	var out: Array[String] = []
	for r in g.field.rocks:
		out.append("%d,%d,%d" % [r.x, r.y, r.z])
	out.sort()
	return out

func _bug_texts(g: Game) -> Array[String]:
	var out: Array[String] = []
	for i in g.field.bugs.size():
		var b: Vector3i = g.field.bugs[i]
		out.append("%d,%d,%d:%d" % [b.x, b.y, b.z, g.field.kinds[i]])
	return out

func _test_same_seed_same_layout() -> void:
	var a := _game()
	var b := _game()
	assert(_rock_texts(a) == _rock_texts(b) and _bug_texts(a) == _bug_texts(b), "같은 시드로 두 번 만들면 배치가 같다")

func _test_layout_snapshot() -> void:
	var g := _game()
	assert(_rock_texts(g) == ROCKS, "바위 배치가 스냅샷과 다르다: %s" % [_rock_texts(g)])
	assert(_bug_texts(g) == BUGS, "벌레 배치가 스냅샷과 다르다: %s" % [_bug_texts(g)])

# 시작 칸에서 바위를 거치지 않고(상자 안의 이웃 칸으로 이어져) 모든 벌레에 닿는다.
func _test_every_bug_is_reachable() -> void:
	var g := _game()
	var seen := {g.worm.head(): true}
	var queue: Array[Vector3i] = [g.worm.head()]
	while not queue.is_empty():
		var c: Vector3i = queue.pop_front()
		for d in DIRS:
			var n := c + d
			if g.field.in_bounds(n) and not g.field.has_rock(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	for b in g.field.bugs:
		assert(seen.has(b), "벌레 %s 에 바위를 거치지 않고는 닿을 수 없다" % [b])

func _test_bugs_spread_over_floors() -> void:
	var g := _game()
	assert(g.height == 8 and g.field.bugs.size() == 9 and g.field.rocks.size() == 8, "레벨 8 판: 8층, 벌레 9마리, 바위 8개")
	var floors := {}
	for b in g.field.bugs:
		floors[b.y] = true
	assert(floors.size() >= 5, "벌레가 서로 다른 층 5개 이상에 퍼져 있다(세로 이동이 필요하다): %d" % floors.size())
