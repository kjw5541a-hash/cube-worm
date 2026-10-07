extends SceneTree

func _initialize() -> void:
	_test_bounds()
	_test_rocks_keep_away_from_start()
	_test_bug_spawns_only_on_empty_cells()
	_test_spawn_fails_when_full()
	print("test_field: OK")
	quit()

func _field(seed: int) -> Field:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return Field.new(8, rng)

func _test_bounds() -> void:
	var f := _field(1)
	assert(f.in_bounds(Vector3i(0, 0, 0)) and f.in_bounds(Vector3i(7, 7, 7)))
	for c in [Vector3i(-1, 0, 0), Vector3i(0, 8, 0), Vector3i(0, 0, -1), Vector3i(8, 7, 7)]:
		assert(not f.in_bounds(c), "상자 밖: %s" % c)

func _test_rocks_keep_away_from_start() -> void:
	var start: Array[Vector3i] = [Vector3i(4, 4, 4), Vector3i(5, 4, 4), Vector3i(6, 4, 4)]
	for seed in 50:
		var f := _field(seed)
		f.place_rocks(8, start, 2)
		assert(f.rocks.size() == 8, "바위는 정확히 8개")
		for r in f.rocks:
			for s in start:
				var d := maxi(maxi(absi(r.x - s.x), absi(r.y - s.y)), absi(r.z - s.z))
				assert(d > 2, "시작 지렁이 근처에 바위: %s" % r)

func _test_bug_spawns_only_on_empty_cells() -> void:
	var f := _field(7)
	f.place_rocks(8, [] as Array[Vector3i], 0)
	var blocked := {Vector3i(1, 1, 1): true}
	for i in 400:
		assert(f.spawn_bug(blocked))
	var seen := {}
	for b in f.bugs:
		assert(not f.rocks.has(b) and not blocked.has(b), "벌레가 막힌 칸에 생겼다: %s" % b)
		assert(not seen.has(b), "같은 칸에 벌레 두 마리")
		seen[b] = true

func _test_spawn_fails_when_full() -> void:
	var f := _field(3)
	var all := {}
	for c in f.empty_cells({}):
		all[c] = true
	assert(not f.spawn_bug(all), "빈 칸이 없으면 벌레를 못 둔다")
	assert(f.bugs.is_empty())
