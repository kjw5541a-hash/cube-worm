extends SceneTree

const X := Vector3i(1, 0, 0)
const Y := Vector3i(0, 1, 0)
const Z := Vector3i(0, 0, 1)
const L := Worm.Steer.LEFT
const R := Worm.Steer.RIGHT
const U := Worm.Steer.UP
const D := Worm.Steer.DOWN

func _initialize() -> void:
	_test_straight()
	_test_step_moves_head_and_drops_tail()
	_test_step_grow_keeps_tail()
	_test_blocks_skips_only_tail()
	_test_refs_remember_last_horizontal()
	_test_serpentine_is_connected()
	_test_up_of()
	_test_turned_horizontal_table()
	_test_turned_vertical_rules()
	_test_turned_is_always_perpendicular()
	print("test_worm: OK")
	quit()

func _cells(a: Array) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	out.assign(a)
	return out

func _test_straight() -> void:
	var w := Worm.straight(Vector3i(4, 4, 4), Vector3i(-1, 0, 0), 3)
	assert(w.cells == _cells([Vector3i(4, 4, 4), Vector3i(5, 4, 4), Vector3i(6, 4, 4)]), "몸은 머리 반대쪽으로 뻗는다: %s" % [w.cells])
	for e in w.entries:
		assert(e == Vector3i(-1, 0, 0), "일직선이면 모든 칸의 입구가 같다")
	assert(w.head_exit == Vector3i.ZERO, "출발 전에는 출구가 없다")
	assert(w.exit_of(1) == Vector3i(-1, 0, 0), "몸 칸의 출구는 머리 쪽 이웃 칸의 입구다")

func _test_step_moves_head_and_drops_tail() -> void:
	var w := Worm.straight(Vector3i(4, 4, 4), Vector3i(-1, 0, 0), 3)
	w.head_exit = Vector3i(0, 0, 1)
	w.step(false)
	assert(w.cells == _cells([Vector3i(4, 4, 5), Vector3i(4, 4, 4), Vector3i(5, 4, 4)]), "머리가 출구로 한 칸, 꼬리는 한 칸 줄어든다: %s" % [w.cells])
	assert(w.entries[0] == Vector3i(0, 0, 1), "새 머리 칸의 입구는 방금 출구")
	assert(w.length() == 3)

func _test_step_grow_keeps_tail() -> void:
	var w := Worm.straight(Vector3i(4, 4, 4), Vector3i(-1, 0, 0), 3)
	w.head_exit = Vector3i(-1, 0, 0)
	w.step(true)
	assert(w.length() == 4, "자라면 한 마디 길어진다")
	assert(w.cells[3] == Vector3i(6, 4, 4), "자라는 걸음에는 꼬리가 제자리에 남는다")
	assert(w.entries.size() == 4 and w.refs.size() == 4, "칸마다 입구와 기준 방향이 있어야 한다")

func _test_blocks_skips_only_tail() -> void:
	var w := Worm.straight(Vector3i(2, 4, 4), Vector3i(-1, 0, 0), 4)
	assert(w.blocks(Vector3i(3, 4, 4)), "몸 칸은 막는다")
	assert(not w.blocks(Vector3i(5, 4, 4)), "현재 꼬리 칸은 이번 걸음에 비워지므로 막지 않는다")
	assert(not w.blocks(Vector3i(0, 0, 0)))

func _test_refs_remember_last_horizontal() -> void:
	var w := Worm.straight(Vector3i(4, 4, 4), Vector3i(-1, 0, 0), 3)
	w.head_exit = Vector3i(0, 1, 0)
	w.step(false)
	assert(w.refs[0] == Vector3i(-1, 0, 0), "위로 꺾여도 직전 수평 방향을 기억한다")
	w.head_exit = Vector3i(0, 1, 0)
	w.step(false)
	assert(w.refs[0] == Vector3i(-1, 0, 0), "수직이 이어져도 같은 기준을 물려받는다")
	w.head_exit = Vector3i(0, 0, 1)
	w.step(false)
	assert(w.refs[0] == Vector3i(0, 0, 1), "다시 수평이면 그 방향이 기준")

func _test_serpentine_is_connected() -> void:
	var p := Worm.serpentine_path(8)
	assert(p.size() == 512, "상자 전체를 지난다")
	var seen := {}
	for i in p.size():
		seen[p[i]] = true
		if i > 0:
			var d := p[i] - p[i - 1]
			assert(absi(d.x) + absi(d.y) + absi(d.z) == 1, "이웃한 두 칸이 맞닿아야 한다: %s → %s" % [p[i - 1], p[i]])
	assert(seen.size() == 512, "같은 칸을 두 번 지나면 안 된다")

func _test_up_of() -> void:
	for d in [X, -X, Z, -Z]:
		assert(Worm.up_of(d, d) == Y, "수평으로 갈 때 윗면은 +Y: %s" % d)
	for r in [X, -X, Z, -Z]:
		assert(Worm.up_of(Y, r) == -r, "위로 가면 윗면은 -r: %s" % r)
		assert(Worm.up_of(-Y, r) == r, "아래로 가면 윗면은 r: %s" % r)

# 수평으로 갈 때의 표. 표를 직접 적어 두는 이유: 관계만 보면 왼쪽·오른쪽을 통째로 맞바꿔도 통과한다.
# 진행 방향을 위에서 내려다볼 때, 오른쪽은 시계 방향으로 90° 돈 쪽이다.
func _test_turned_horizontal_table() -> void:
	var table := [
		[-X, Z, -Z],  # [진행 방향, 왼쪽, 오른쪽]
		[X, -Z, Z],
		[Z, X, -X],
		[-Z, -X, X],
	]
	for row in table:
		var d: Vector3i = row[0]
		assert(Worm.turned(L, d, d) == row[1], "%s 로 갈 때 왼쪽: %s" % [d, Worm.turned(L, d, d)])
		assert(Worm.turned(R, d, d) == row[2], "%s 로 갈 때 오른쪽: %s" % [d, Worm.turned(R, d, d)])
		assert(Worm.turned(U, d, d) == Y, "수평으로 갈 때 위는 월드 위: %s" % d)
		assert(Worm.turned(D, d, d) == -Y, "수평으로 갈 때 아래는 월드 아래: %s" % d)

func _test_turned_vertical_rules() -> void:
	for r in [X, -X, Z, -Z]:
		# 위로 가는 중(윗면은 -r): 아래로 꺾으면 가던 수평 방향으로 눕고, 위로 꺾으면 반대편으로 넘어간다.
		assert(Worm.turned(D, Y, r) == r, "위로 가다 아래로 꺾으면 가던 수평 방향으로 눕는다: %s" % r)
		assert(Worm.turned(U, Y, r) == -r, "위로 가다 위로 꺾으면 반대편으로 넘어간다: %s" % r)
		# 아래로 가는 중(윗면은 r): 반대.
		assert(Worm.turned(U, -Y, r) == r, "아래로 가다 위로 꺾으면 가던 수평 방향으로 눕는다: %s" % r)
		assert(Worm.turned(D, -Y, r) == -r, "아래로 가다 아래로 꺾으면 반대편으로 넘어간다: %s" % r)
		# 오른쪽·왼쪽은 피치를 줘도 그대로다 — 수평으로 갈 때의 오른쪽·왼쪽과 같다.
		for v in [Y, -Y]:
			assert(Worm.turned(R, v, r) == Worm.turned(R, r, r), "수직에서도 오른쪽은 같다: %s %s" % [v, r])
			assert(Worm.turned(L, v, r) == Worm.turned(L, r, r), "수직에서도 왼쪽은 같다: %s %s" % [v, r])

func _test_turned_is_always_perpendicular() -> void:
	for d in [X, -X, Y, -Y, Z, -Z]:
		for r in [X, -X, Z, -Z]:
			if d.y == 0 and r != d:
				continue  # 수평으로 갈 때 기준 방향은 진행 방향 자신이다
			var seen := {}
			for s in [L, R, U, D]:
				var out: Vector3i = Worm.turned(s, d, r)
				assert(out.x * d.x + out.y * d.y + out.z * d.z == 0, "꺾은 방향은 진행 방향에 수직이어야 한다(뒤로 못 간다): %s %s → %s" % [d, r, out])
				assert(absi(out.x) + absi(out.y) + absi(out.z) == 1, "한 축으로 한 칸: %s" % out)
				seen[out] = true
			assert(seen.size() == 4, "네 버튼은 서로 다른 방향이어야 한다: %s %s" % [d, r])
