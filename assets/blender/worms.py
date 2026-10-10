"""지렁이 스킨 3종(젤리·마디·블록)의 마디와 머리."""
from common import Builder, ball, rbox, xf

SEG, HEAD = 0.86, 0.96  # Tuning.SEGMENT_SIZE, Tuning.HEAD_SIZE 와 같아야 한다(tests/test_models.gd 가 지킨다)
# 스킨: (마디 색, 머리 색)
SKINS = {"jelly": ("#F4A7AE", "#EE8793"), "ringed": ("#F29A88", "#EE7A6B"), "block": ("#F8BBC8", "#F4A6BA")}
WHITE, BLACK, MOUTH, CHEEK = "#FFFFFF", "#1B1B22", "#7A2E3A", "#E5636B"


def segment(skin):
    b = Builder(f"worm_segment_{skin}")
    s = b.slot("seg", SKINS[skin][0])
    if skin == "jelly":  # 베개처럼 동글동글한 마디
        b.add(rbox((SEG,) * 3, 0.36 * SEG, 2), s)
    elif skin == "ringed":  # 앞·뒤 두 토막이 맞닿아 얕은 허리 홈이 생긴다
        for y in (0.205, -0.205):
            b.add(rbox((SEG, 0.45, SEG), 0.10, 1), s, xf((0, y, 0)))
    else:  # 모서리만 둥근 블록
        b.add(rbox((SEG,) * 3, 0.14, 1), s)
    return b.finish()


def head(skin):
    """앞(+Y)면에 눈·입. 눈이 앞면 밖으로 튀어나오는 길이는 0.06 이하(DEATH_STOP 이 앞면 0.48 기준)."""
    b = Builder(f"worm_head_{skin}")
    body = b.slot("body", SKINS[skin][1])
    if skin == "jelly":
        b.add(rbox((HEAD,) * 3, 0.36 * HEAD, 2), body)
        for sx in (-1, 1):
            b.add(ball((0.14, 0.05, 0.16), 12, 8), b.slot("eye_white", WHITE), xf((0.22 * sx, 0.46, 0.10)))
            b.add(ball((0.075, 0.035, 0.09), 8, 6), b.slot("eye_black", BLACK), xf((0.215 * sx, 0.50, 0.095)))
        b.add(ball((0.12, 0.035, 0.03), 8, 4), b.slot("mouth", MOUTH), xf((0, 0.47, -0.17)))
    elif skin == "ringed":
        b.add(rbox((HEAD,) * 3, 0.12, 1), body)
        for sx in (-1, 1):
            b.add(ball((0.055, 0.04, 0.065), 8, 6), b.slot("eye_black", BLACK), xf((0.27 * sx, 0.47, 0.12)))
            b.add(ball((0.08, 0.03, 0.05), 8, 4), b.slot("cheek", CHEEK), xf((0.34 * sx, 0.47, -0.06)))
        b.add(ball((0.17, 0.03, 0.022), 8, 4), b.slot("mouth", MOUTH), xf((0, 0.47, -0.12)))
    else:
        b.add(rbox((HEAD,) * 3, 0.14, 1), body)
        for sx in (-1, 1):
            b.add(rbox((0.15, 0.05, 0.17), 0.03, 1), b.slot("eye_black", BLACK), xf((0.22 * sx, 0.485, 0.10)))
            b.add(rbox((0.05, 0.03, 0.05), 0.012, 1), b.slot("eye_white", WHITE), xf((0.20 * sx, 0.51, 0.15)))
        b.add(rbox((0.20, 0.04, 0.045), 0.015, 1), b.slot("mouth", MOUTH), xf((0, 0.485, -0.15)))
    return b.finish()
