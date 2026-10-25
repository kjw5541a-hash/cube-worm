"""에셋 11개를 만들어 assets/models/*.glb 로 내보낸다. 스크립트가 원본이고 GLB 는 결과물이다.

실행(저장소 루트에서):
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 --python assets/blender/build_all.py
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bugs  # noqa: E402
import common  # noqa: E402
import rock  # noqa: E402
import worms  # noqa: E402

OUT = os.path.abspath(os.path.join(HERE, "..", "models"))
SEGMENT_MAX, HEAD_MAX, GRUB_MAX, ROCK_MAX = 300, 1500, 2000, 500  # 삼각형 상한(스펙 7절)


def build(name, make, limit):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    obj = make()
    t = common.tris(obj)
    assert t <= limit, f"{name}: 삼각형 {t} 개가 상한 {limit} 을 넘는다"
    common.export_glb(os.path.join(OUT, name + ".glb"))
    print(f"{name}: 삼각형 {t}, 재질 {len(obj.data.materials)}")


os.makedirs(OUT, exist_ok=True)
for skin in worms.SKINS:
    build(f"worm_segment_{skin}", lambda s=skin: worms.segment(s), SEGMENT_MAX)
    build(f"worm_head_{skin}", lambda s=skin: worms.head(s), HEAD_MAX)
for kind in bugs.KINDS:
    build(f"grub_{kind}", lambda k=kind: bugs.grub(k), GRUB_MAX)
build("rock", rock.rock, ROCK_MAX)
print("BUILD_OK")
