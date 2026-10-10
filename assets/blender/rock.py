"""바위: 칸을 거의 채우는 모난 돌덩이(둥근 상자에 잔물결을 주고 면마다 평평하게 칠한다)."""
import random

from mathutils import Vector, noise

from common import Builder, rbox


def rock():
    b = Builder("rock")
    bm, _ = rbox((0.76, 0.76, 0.76), 0.22, 2)
    rnd = random.Random(7)
    for v in bm.verts:
        f = 1.0 + 0.14 * noise.noise(v.co * 2.3 + Vector((3.1, 1.7, 5.3))) + 0.07 * noise.noise(v.co * 5.1 + Vector((8.2, 2.4, 1.1)))
        v.co = Vector((v.co.x * f, v.co.y * f * 0.95, v.co.z * f * 0.92)) + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * 0.015
    far = max(max(abs(c) for c in v.co) for v in bm.verts)
    for v in bm.verts:
        v.co *= 0.48 / far  # 가장 먼 점이 칸 안쪽 0.02 에 오게 맞춘다
    b.add((bm, None), b.slot("rock", "#8C8F96"))
    return b.finish(flat=True)
