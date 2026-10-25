extends SceneTree

# 다른 층 벌레 배지: 위·아래 방향과 층 수, 같은 층 벌레·바위 제외, 황금 벌레, 고리 자리, 터치 통과.
func _initialize() -> void:
	var g := Game.new(3, false, 4)
	var y := g.worm.head().y
	g.field.bugs.assign([Vector3i(1, y + 1, 1), Vector3i(2, y - 2, 2), Vector3i(3, y, 3)])
	g.field.kinds.assign([0, 1, 2])
	g.field.rocks = {Vector3i(5, y + 1, 5): true}
	var e := LayerBadges.entries(g)
	assert(e.size() == 2, "다른 층 벌레만 배지를 단다(같은 층 벌레·바위는 없다): %d" % e.size())
	assert(e[0]["cell"] == Vector3i(1, y + 1, 1) and e[0]["dy"] == 1 and e[0]["color"] == Skins.BUGS[0]["color"], "한 층 위, 종류 색")
	assert(e[1]["dy"] == -2 and e[1]["color"] == Skins.BUGS[1]["color"], "두 층 아래")

	g.gold_cell = Vector3i(4, y + 2, 4)
	assert(LayerBadges.entries(g).size() == 2, "황금 벌레가 없으면 배지도 없다")
	g.gold_left = Tuning.GOLD_TIME
	var last: Dictionary = LayerBadges.entries(g).back()
	assert(last["dy"] == 2 and last["color"] == Skins.GOLD["color"], "황금 벌레는 금색 배지")
	g.gold_cell.y = y
	assert(LayerBadges.entries(g).size() == 2, "같은 층 황금 벌레는 배지가 없다")

	# 배지는 그 벌레의 고리 자리(머리 층 높이, 벌레와 같은 x·z)를 화면에 옮긴 곳에 놓인다.
	var badges := LayerBadges.new()
	root.add_child(badges)
	assert(badges.mouse_filter == Control.MOUSE_FILTER_IGNORE, "배지는 터치를 막지 않는다")
	var head_y := WormPath.segment(g.worm, 0, g.alpha).origin.y
	badges.update_from(g, func(p: Vector3) -> Vector2: return Vector2(p.x * 100.0 + p.y, p.z * 100.0))
	assert(badges.items.size() == 2, "배지 둘")
	var want := WormPath.center(Vector3i(1, y + 1, 1))
	assert(badges.items[0]["pos"].is_equal_approx(Vector2(want.x * 100.0 + head_y, want.z * 100.0)), "고리 자리: %s" % badges.items[0]["pos"])
	badges.update_from(Game.new(3, false, 1), func(p: Vector3) -> Vector2: return Vector2.ZERO)
	assert(badges.items.is_empty(), "1층짜리 판에는 배지가 없다")
	badges.queue_free()
	print("test_layer_badges: OK")
	quit()
