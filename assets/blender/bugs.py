"""벌레(굼벵이) 4종(일반 3종 + 황금): 작은 둥근 정육면체를 C 자로 이은 모양. 바운딩 박스 중심을 원점(칸 중심)에 둔다."""
import math

from common import Builder, ball, rbox, xf

EYE, TIP = "#1B1B22", "#FF9B3D"
# 종류: (크기 목록(꼬리→머리), 호 각도(도), 호 반지름, 몸 색, 머리 색, 꼬리 색 또는 None, 더듬이 여부)
KINDS = {
    "cream": ([0.21, 0.26, 0.30, 0.32], [-120, -40, 40, 120], 0.20, "#FFF0C8", "#F2C27B", None, False),
    "antenna": ([0.28, 0.32, 0.35], [-70, 0, 70], 0.26, "#FFD45A", "#FFBF47", None, True),
    "glow": ([0.17, 0.22, 0.26, 0.29], [-95, -32, 32, 95], 0.26, "#FFF3D1", "#FFF3D1", "#FF9B3D", False),
    # 황금 벌레: 크림과 같은 모양, 몸과 머리만 금색. 게임에서 Tuning.GOLD_SCALE 배로 키워 쓴다.
    "gold": ([0.21, 0.26, 0.30, 0.32], [-120, -40, 40, 120], 0.20, "#FFC21A", "#FFE680", None, False),
}


def grub(kind):
    sizes, angs, radius, body_c, head_c, tail_c, antennae = KINDS[kind]
    b = Builder(f"grub_{kind}")
    last = len(sizes) - 1
    for i, (sz, a) in enumerate(zip(sizes, angs)):
        phi = math.radians(a)
        if i == last:
            slot = b.slot("head", head_c)
        elif i == 0 and tail_c:
            slot = b.slot("tail", tail_c)
        else:
            slot = b.slot("body", body_c)
        m = xf((radius * math.sin(phi), -radius * math.cos(phi), 0), (0, 0, a - 90))
        b.add(rbox((sz,) * 3, 0.30 * sz, 2), slot, m)
        if i == last:  # 머리: 로컬 +Y 가 앞
            for sx in (-1, 1):
                b.add(ball((0.032, 0.03, 0.032), 8, 5), b.slot("eye", EYE), m @ xf((0.085 * sx, 0.5 * sz - 0.01, 0.04)))
            if antennae:
                for sx in (-1, 1):
                    am = m @ xf((0.09 * sx, 0.05, 0.5 * sz + 0.05), (-25, 20 * sx, 0))
                    b.add(rbox((0.03, 0.03, 0.17), 0.01, 1), slot, am)
                    b.add(ball((0.04, 0.04, 0.04), 8, 5), b.slot("tip", TIP), am @ xf((0, 0, 0.09)))
    b.recenter()
    return b.finish()
