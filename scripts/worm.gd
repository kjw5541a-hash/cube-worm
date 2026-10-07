class_name Worm
extends RefCounted

# 지렁이가 차지한 칸. 0번이 머리다.
# entries[j] 는 칸 j 에 들어올 때의 진행 방향이다. 칸 j 의 출구는 칸 j-1 의 입구와 같고,
# 머리 칸의 출구만 head_exit 로 따로 둔다(출발 전에는 ZERO).
var cells: Array[Vector3i] = []
var entries: Array[Vector3i] = []
# 칸마다 "기준 수평 방향". 수직으로 지나는 칸의 자세(윗면 방향)를 정하는 데 쓴다.
# 입구가 수평이면 입구 방향 그대로, 수직이면 꼬리 쪽 이웃 칸의 값을 물려받는다.
var refs: Array[Vector3i] = []
var head_exit := Vector3i.ZERO

# 머리부터 꼬리까지 이웃한 칸 목록으로 만든다. 꼬리 칸의 입구는 그 앞 칸의 입구와 같다고 본다.
static func from_cells(path: Array[Vector3i]) -> Worm:
	assert(path.size() >= 2, "지렁이는 두 칸 이상이어야 한다")
	var w := Worm.new()
	var n := path.size()
	for i in n:
		w.cells.append(path[i])
		w.entries.append(path[i] - path[i + 1] if i + 1 < n else w.entries[i - 1])
	w.refs.resize(n)
	var r := Vector3i(1, 0, 0)  # 꼬리부터 수직으로만 이어지면 쓰는 기본값
	for i in range(n - 1, -1, -1):
		if w.entries[i].y == 0:
			r = w.entries[i]
		w.refs[i] = r
	return w

# 머리가 dir 쪽을 보고 몸이 반대쪽으로 일직선인 지렁이.
static func straight(head: Vector3i, dir: Vector3i, length: int) -> Worm:
	var path: Array[Vector3i] = []
	for i in length:
		path.append(head - dir * i)
	return from_cells(path)

# 상자 전체를 층마다 지그재그로 지나는 길. 이웃한 두 칸은 늘 맞닿아 있다(성능 확인용).
static func serpentine_path(size: int) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	var row := 0
	for y in size:
		for r in size:
			var z := r if y % 2 == 0 else size - 1 - r
			for c in size:
				var x := c if row % 2 == 0 else size - 1 - c
				path.append(Vector3i(x, y, z))
			row += 1
	return path

func length() -> int:
	return cells.size()

func head() -> Vector3i:
	return cells[0]

func exit_of(j: int) -> Vector3i:
	return head_exit if j == 0 else entries[j - 1]

# 머리가 c 로 들어가면 몸에 부딪히는가. 현재 꼬리 칸은 이번 걸음에 비워지므로 빼고 본다.
func blocks(c: Vector3i) -> bool:
	for i in cells.size() - 1:
		if cells[i] == c:
			return true
	return false

func cell_set() -> Dictionary:
	var out := {}
	for c in cells:
		out[c] = true
	return out

# 머리를 출구 방향으로 한 칸 옮긴다. grow 면 꼬리를 남겨 한 마디 길어진다.
func step(grow: bool) -> void:
	var d := head_exit
	cells.push_front(cells[0] + d)
	entries.push_front(d)
	refs.push_front(d if d.y == 0 else refs[0])
	if not grow:
		cells.pop_back()
		entries.pop_back()
		refs.pop_back()
