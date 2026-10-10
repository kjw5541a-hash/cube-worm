"""큐브 지렁이 에셋 빌더 공용 도우미. 헤드리스 Blender 에서 build_all.py 가 불러 쓴다.

좌표: 1 단위 = 1 칸, Blender 위 +Z, 앞 +Y. glTF 로 내보내면 앞이 -Z 가 되어 Godot 의 앞(-Z)과 같다.
모든 에셋의 원점은 칸 중심이다. 재질은 단색(metallic 0), 텍스처 없음.
"""
import math

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector


def srgb(hex_color):
    """'#RRGGBB'(sRGB) → 선형 색 3원소 튜플."""
    h = hex_color.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def xf(loc=(0, 0, 0), rot=(0, 0, 0)):
    """위치(m)와 XYZ 회전(도)으로 만든 4×4 변환."""
    return Matrix.Translation(loc) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()


def rbox(size, r, s=2):
    """둥근 직육면체. 모서리를 반지름 r 호로 깎고, 호를 한 면당 s 칸으로 나눈다.
    정점 법선은 호의 정확한 법선이라 삼각형이 적어도 음영이 매끈하다. 반환: (bmesh, 정점 법선 목록)."""
    h = [v / 2 for v in size]
    inner = [x - r for x in h]
    arc = [j / s for j in range(s + 1)]
    slots = [(-1, u) for u in reversed(arc)] + [(1, u) for u in arc]
    bm = bmesh.new()
    cache, normals = {}, []

    def vert(idx):
        if idx not in cache:
            q = [slots[idx[k]][0] * inner[k] for k in range(3)]
            d = [slots[idx[k]][0] * slots[idx[k]][1] for k in range(3)]
            n = [x / math.sqrt(sum(y * y for y in d)) for x in d]
            cache[idx] = bm.verts.new([q[k] + r * n[k] for k in range(3)])
            normals.append(n)
        return cache[idx]

    for k in range(3):
        a, b = [x for x in range(3) if x != k]
        for e in (0, len(slots) - 1):
            for ia in range(len(slots) - 1):
                for ib in range(len(slots) - 1):
                    quad = []
                    for x, y in ((ia, ib), (ia + 1, ib), (ia + 1, ib + 1), (ia, ib + 1)):
                        idx = [0, 0, 0]
                        idx[k], idx[a], idx[b] = e, x, y
                        quad.append(vert(tuple(idx)))
                    bm.faces.new(quad)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm, normals


def ball(radii, seg=10, ring=6):
    """타원체(UV 구). 반환: (bmesh, None) — 법선은 합칠 때 메시에서 계산한다."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=ring, radius=1.0, matrix=Matrix.Diagonal((*radii, 1.0)))
    return bm, None


class Builder:
    """여러 부품을 한 메시로 합친다. 재질은 면마다 칸 번호(slot)로 구분한다."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.normals = []
        self.materials = []

    def slot(self, name, hex_color):
        for i, m in enumerate(self.materials):
            if m.name == name:
                return i
        m = bpy.data.materials.new(name)
        p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        p.inputs["Base Color"].default_value = (*srgb(hex_color), 1.0)
        p.inputs["Metallic"].default_value = 0.0
        p.inputs["Roughness"].default_value = 0.7
        self.materials.append(m)
        return len(self.materials) - 1

    def add(self, part, slot, matrix=None):
        bm, normals = part
        matrix = matrix if matrix is not None else Matrix.Identity(4)
        rot = matrix.to_3x3().normalized()
        bm.verts.index_update()
        if normals is None:
            bm.normal_update()
            normals = [tuple(v.normal) for v in bm.verts]
        new = {}
        for v, n in zip(bm.verts, normals):
            new[v.index] = self.bm.verts.new(matrix @ v.co)
            self.normals.append(tuple((rot @ Vector(n)).normalized()))
        for f in bm.faces:
            self.bm.faces.new([new[v.index] for v in f.verts]).material_index = slot
        bm.free()

    def recenter(self):
        """모양의 바운딩 박스 중심을 원점(칸 중심)으로 옮긴다."""
        lo = Vector([min(v.co[k] for v in self.bm.verts) for k in range(3)])
        hi = Vector([max(v.co[k] for v in self.bm.verts) for k in range(3)])
        for v in self.bm.verts:
            v.co -= (lo + hi) / 2

    def finish(self, flat=False):
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.materials:
            me.materials.append(m)
        if flat:
            me.shade_flat()
        else:
            me.shade_smooth()
            me.normals_split_custom_set_from_vertices(self.normals)
        obj = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def export_glb(path):
    """장면(오브젝트 하나)을 GLB 로 내보낸다. Y 위 변환으로 Blender +Y(앞)가 glTF -Z 가 된다."""
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=False,
                              export_yup=True, export_normals=True, export_materials="EXPORT",
                              export_cameras=False, export_lights=False)
