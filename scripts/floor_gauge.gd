class_name FloorGauge
extends Control

# 층 눈금: 층마다 한 칸씩 아래(1층)부터 쌓고, 지렁이가 있는 층을 강조한다.
# 칸 안의 점은 그 층의 벌레(종류 색)와 바위(회색)다. 황금 벌레는 맨 앞의 큰 금색 점이다. 1층짜리 판에서는 숨긴다.

const CELL := Vector2(168, 26)
const GAP := 3.0
const DOT := 7.0
const ROCK_DOT := Color(0.72, 0.74, 0.8)

var height := 1
var focus := 0
var bug_layers: Array[int] = []   # 벌레마다 층
var bug_kinds: Array[int] = []
var rock_layers: Array[int] = []
var gold_layer := -1              # 황금 벌레가 있는 층(없으면 -1)

# 맨 아래 칸의 왼쪽 아래 모서리가 position 이 되도록 위로 쌓는다.
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_from(g: Game) -> void:
	height = g.height
	focus = g.worm.head().y
	bug_layers.clear()
	bug_kinds.clear()
	rock_layers.clear()
	for i in g.field.bugs.size():
		bug_layers.append(g.field.bugs[i].y)
		bug_kinds.append(g.field.kinds[i])
	for r in g.field.rocks:
		rock_layers.append(r.y)
	gold_layer = g.gold_cell.y if g.gold_left > 0.0 else -1
	visible = height > 1
	queue_redraw()

# 층 y(0 이 맨 아래) 칸의 사각형.
func cell_rect(y: int) -> Rect2:
	return Rect2(Vector2(0, -(y + 1) * (CELL.y + GAP) + GAP), CELL)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for y in height:
		var rc := cell_rect(y)
		var on := y == focus
		draw_rect(rc, Color(1.0, 0.9, 0.45, 0.35) if on else Color(1, 1, 1, 0.07))
		if on:
			draw_rect(rc, Color(1.0, 0.9, 0.45, 0.95), false, 2.0)
		draw_string(font, rc.position + Vector2(8, CELL.y - 7), str(y + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.95 if on else 0.55))
		var x := rc.position.x + 40.0
		if gold_layer == y:  # 황금 벌레: 큰 금색 점이 맨 앞
			draw_circle(Vector2(x, rc.position.y + CELL.y * 0.5), DOT * 1.4, Skins.GOLD["color"])
			x += DOT * 1.4 + DOT + 4.0
		for i in bug_layers.size():
			if bug_layers[i] == y:
				draw_circle(Vector2(x, rc.position.y + CELL.y * 0.5), DOT, Skins.BUGS[bug_kinds[i]]["color"])
				x += DOT * 2.0 + 4.0
		for r in rock_layers:
			if r == y:
				draw_rect(Rect2(Vector2(x - DOT, rc.position.y + CELL.y * 0.5 - DOT), Vector2.ONE * DOT * 2.0), ROCK_DOT)
				x += DOT * 2.0 + 4.0
