extends SceneTree

# 층 눈금: 층마다 벌레·바위 개수를 세고, 지렁이 층을 가리키며, 1층짜리 판에서는 숨는다.
func _initialize() -> void:
	var gauge := FloorGauge.new()
	root.add_child(gauge)
	var g := Game.new(3, false, 4)
	g.field.bugs.assign([Vector3i(1, 0, 1), Vector3i(2, 3, 2), Vector3i(3, 3, 3)])
	g.field.kinds.assign([0, 1, 2])
	g.field.rocks = {Vector3i(5, 0, 5): true, Vector3i(6, 2, 6): true}
	gauge.update_from(g)
	assert(gauge.visible and gauge.height == 4, "4층 판에서는 눈금이 보인다")
	assert(gauge.focus == g.worm.head().y, "지렁이가 있는 층을 가리킨다")
	assert(gauge.bug_layers == ([0, 3, 3] as Array[int]) and gauge.rock_layers == ([0, 2] as Array[int]), "층별 벌레·바위")
	assert(gauge.gold_layer == -1, "황금 벌레가 없으면 -1")
	g.gold_cell = Vector3i(2, 2, 2)
	g.gold_left = Tuning.GOLD_TIME
	gauge.update_from(g)
	assert(gauge.gold_layer == 2, "황금 벌레가 있는 층")
	g.gold_left = 0.0
	gauge.update_from(g)
	assert(gauge.gold_layer == -1, "사라지면 다시 -1")
	for y in 3:
		assert(gauge.cell_rect(y).position.y > gauge.cell_rect(y + 1).position.y, "1층이 맨 아래, 위층일수록 위에 있다")
	gauge.update_from(Game.new(3, false, 1))
	assert(not gauge.visible, "1층짜리 판에서는 눈금을 숨긴다")
	print("test_floor_gauge: OK")
	quit()
