class_name WormPath
extends RefCounted

# 칸 기록 + 진행률 → 마디의 위치와 자세. 순수 수학이다.
# 칸 안 경로: 직진이면 입구 면 중심 → 출구 면 중심 직선, 꺾이면 두 면 중심을 잇는 반지름 0.5 의 4분원.

static func center(c: Vector3i) -> Vector3:
	return Vector3(c) + Vector3(0.5, 0.5, 0.5)

static func turns(d_in: Vector3i, d_out: Vector3i) -> bool:
	return d_out != Vector3i.ZERO and d_out != d_in

static func point(c: Vector3i, d_in: Vector3i, d_out: Vector3i, a: float) -> Vector3:
	var fin := Vector3(d_in)
	var start := center(c) - fin * 0.5
	if not turns(d_in, d_out):
		return start + fin * a
	var fout := Vector3(d_out)
	var t := a * PI * 0.5
	# 원의 중심은 입구 면과 출구 면이 만나는 모서리의 중점이다.
	return start + fout * 0.5 - fout * (0.5 * cos(t)) + fin * (0.5 * sin(t))

static func tangent(d_in: Vector3i, d_out: Vector3i, a: float) -> Vector3:
	if not turns(d_in, d_out):
		return Vector3(d_in)
	var t := a * PI * 0.5
	return Vector3(d_in) * cos(t) + Vector3(d_out) * sin(t)

# 진행 방향 d, 기준 수평 방향 r 일 때의 자세. 모델 정면은 -Z.
# 수평이면 윗면이 +Y, 수직이면 직전 수평 자세에서 피치만 한 자세다.
static func pose(d: Vector3i, r: Vector3i) -> Basis:
	var up := Vector3.UP
	if d.y > 0:
		up = -Vector3(r)
	elif d.y < 0:
		up = Vector3(r)
	return Basis.looking_at(Vector3(d), up)

static func exit_ref(d_out: Vector3i, r: Vector3i) -> Vector3i:
	return d_out if d_out.y == 0 else r

# 꺾이는 칸에서는 꺾이는 축으로 돌리며(앞이 접선을 정확히 따른다) 출구 자세와의
# 남은 차이(앞 방향 둘레의 비틀림)를 a 만큼 나눠 푼다. 위로 갔다가 되돌아가는
# U턴처럼 순수 피치만으로는 거꾸로 서게 되는 경우에도 연속으로 바로 선다.
static func basis(d_in: Vector3i, d_out: Vector3i, r: Vector3i, a: float) -> Basis:
	var b_in := pose(d_in, r)
	if not turns(d_in, d_out):
		return b_in
	var axis := Vector3(d_in).cross(Vector3(d_out))
	var b_end := Basis(axis, PI * 0.5) * b_in
	var want := pose(d_out, exit_ref(d_out, r))
	var roll := b_end.y.signed_angle_to(want.y, Vector3(d_out))
	var b := Basis(axis, PI * 0.5 * a) * b_in
	return Basis(tangent(d_in, d_out, a), roll * a) * b

# 마디 j(머리 = 0) 의 변환. 크기는 1 이다.
static func segment(worm: Worm, j: int, a: float) -> Transform3D:
	var d_in := worm.entries[j]
	var d_out := worm.exit_of(j)
	return Transform3D(basis(d_in, d_out, worm.refs[j], a), point(worm.cells[j], d_in, d_out, a))
