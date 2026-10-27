class_name LayerBadges
extends Control

# 다른 층 벌레 배지: 머리 층의 고리 자리에 화살표와 층 수(▲2 = 두 층 위, ▼1 = 한 층 아래)를 화면 위에 그린다.
# 3D 물체에 가려지지 않는다. 같은 층 벌레와 바위에는 달지 않는다. 바탕은 벌레 종류 색이다.
# 황금 벌레는 반대로 진한 바탕에 금색 테두리·화살표·숫자다(노란 더듬이 벌레 배지와 헷갈리지 않게).

const INK := Color(0.11, 0.07, 0.05)  # 화살표·숫자·테두리(배경과 같은 진한 흙색)
const FONT_SIZE := 18

var items: Array[Dictionary] = []  # 배지마다 {cell, dy, color, gold, pos}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = Tuning.BADGE_ALPHA

# 머리와 다른 층에 있는 벌레(보이는 황금 벌레 포함)마다 {cell, dy(위로 +), color, gold}.
static func entries(g: Game) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var y := g.worm.head().y
	for i in g.field.bugs.size():
		var c: Vector3i = g.field.bugs[i]
		if c.y != y:
			out.append({"cell": c, "dy": c.y - y, "color": Skins.BUGS[g.field.kinds[i]]["color"], "gold": false})
	if FieldView.gold_shown(g.gold_left) and g.gold_cell.y != y:
		out.append({"cell": g.gold_cell, "dy": g.gold_cell.y - y, "color": Skins.GOLD["color"], "gold": true})
	return out

# project: 월드 위치 → 화면 위치(Main 은 카메라의 unproject_position). 고리와 같이 머리 높이를 따라간다.
func update_from(g: Game, project: Callable) -> void:
	items = entries(g)
	var head_y := WormPath.segment(g.worm, 0, g.alpha).origin.y
	for e in items:
		var p := WormPath.center(e["cell"])
		e["pos"] = project.call(Vector3(p.x, head_y, p.z))
	queue_redraw()

# ponytail: 배지끼리 겹치면 그냥 겹친다. 붐비는 판에서 읽기 어려우면 겹침 밀어내기를 더한다.
func _draw() -> void:
	var font := ThemeDB.fallback_font
	var s := Tuning.BADGE_SIZE
	for e in items:
		var r := Rect2(e["pos"] - s * 0.5, s)
		var ink: Color = e["color"] if e["gold"] else INK
		var box := StyleBoxFlat.new()
		box.bg_color = INK if e["gold"] else e["color"]
		box.border_color = ink
		box.set_border_width_all(2)
		box.set_corner_radius_all(int(s.y * 0.5))
		draw_style_box(box, r)
		# 화살표: 배지 왼쪽, 위층이면 위로, 아래층이면 아래로.
		var a := Vector2(r.position.x + s.y * 0.5 + 1.0, r.position.y + s.y * 0.5)
		var up := 1.0 if e["dy"] > 0 else -1.0
		draw_colored_polygon(PackedVector2Array([
			a + Vector2(0, -6) * up, a + Vector2(-6, 5) * up, a + Vector2(6, 5) * up]), ink)
		var t := str(absi(e["dy"]))
		var base := r.position.y + (s.y + font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) * 0.5
		draw_string(font, Vector2(a.x + 9.0, base), t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, ink)
