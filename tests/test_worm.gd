extends SceneTree

func _initialize() -> void:
	_test_straight()
	_test_step_moves_head_and_drops_tail()
	_test_step_grow_keeps_tail()
	_test_blocks_skips_only_tail()
	_test_refs_remember_last_horizontal()
	_test_serpentine_is_connected()
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
