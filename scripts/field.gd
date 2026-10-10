class_name Field
extends RefCounted

# 상자 경계, 바위, 벌레. 난수는 시드를 고정할 수 있게 밖에서 받는다.
var size: int      # 가로·세로 칸 수
var height: int    # 높이 칸 수(레벨 N 이면 N)
var rocks := {}                     # Vector3i -> true
var bugs: Array[Vector3i] = []
var kinds: Array[int] = []          # bugs 와 같은 순서의 벌레 종류(0 ~ BUG_COUNT-1). 둘은 늘 같이 간다
var rng: RandomNumberGenerator

func _init(box_size: int, random: RandomNumberGenerator, box_height := -1) -> void:
	size = box_size
	height = box_size if box_height < 0 else box_height
	rng = random

func in_bounds(c: Vector3i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.z >= 0 and c.x < size and c.y < height and c.z < size

func has_rock(c: Vector3i) -> bool:
	return rocks.has(c)

func has_bug(c: Vector3i) -> bool:
	return bugs.has(c)

# 바위·벌레·blocked(지렁이 등, Vector3i -> true) 어느 것도 없는 칸.
func empty_cells(blocked: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for x in size:
		for y in height:
			for z in size:
				var c := Vector3i(x, y, z)
				if not rocks.has(c) and not bugs.has(c) and not blocked.has(c):
					out.append(c)
	return out

# keep_away 칸들에서 체비쇼프 거리 radius 안에는 두지 않는다.
func place_rocks(count: int, keep_away: Array[Vector3i], radius: int) -> void:
	var allowed: Array[Vector3i] = []
	for c in empty_cells({}):
		if not _near(c, keep_away, radius):
			allowed.append(c)
	for i in mini(count, allowed.size()):
		var k := rng.randi_range(i, allowed.size() - 1)
		var t := allowed[i]
		allowed[i] = allowed[k]
		allowed[k] = t
		rocks[allowed[i]] = true

static func _near(c: Vector3i, cells: Array[Vector3i], radius: int) -> bool:
	for o in cells:
		if maxi(maxi(absi(c.x - o.x), absi(c.y - o.y)), absi(c.z - o.z)) <= radius:
			return true
	return false

# 빈 칸 하나에 kind 종류 벌레를 둔다. 빈 칸이 없으면 false.
func spawn_bug(blocked: Dictionary, kind: int) -> bool:
	var free := empty_cells(blocked)
	if free.is_empty():
		return false
	bugs.append(free[rng.randi_range(0, free.size() - 1)])
	kinds.append(kind)
	return true

# 칸 c 에 있는 벌레의 종류. 없으면 -1.
func kind_at(c: Vector3i) -> int:
	var i := bugs.find(c)
	return kinds[i] if i >= 0 else -1

func remove_bug(c: Vector3i) -> void:
	var i := bugs.find(c)
	if i >= 0:
		bugs.remove_at(i)
		kinds.remove_at(i)
