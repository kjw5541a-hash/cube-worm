class_name Skins
extends RefCounted

# 지렁이 스킨(시작 전에 고른다)과 벌레 종류(모두 나온다) 목록. 에셋은 assets/blender 스크립트가 만든 GLB 다.
# 지렁이 스킨은 모양과 색만 다르고 크기 계약은 모두 같다(tests/test_models.gd).

const DIR := "res://assets/models/"

const WORMS: Array[Dictionary] = [
	{"id": "jelly", "name": "젤리", "segment": DIR + "worm_segment_jelly.glb", "head": DIR + "worm_head_jelly.glb"},
	{"id": "ringed", "name": "마디", "segment": DIR + "worm_segment_ringed.glb", "head": DIR + "worm_head_ringed.glb"},
	{"id": "block", "name": "블록", "segment": DIR + "worm_segment_block.glb", "head": DIR + "worm_head_block.glb"},
]

# 벌레 종류. 번호가 곧 Tuning.BUG_SCORES 의 번호다. color 는 고리·기둥·점수 표시의 색.
const BUGS: Array[Dictionary] = [
	{"id": "cream", "name": "크림", "model": DIR + "grub_cream.glb", "color": Color("#FFE9B0")},
	{"id": "antenna", "name": "더듬이", "model": DIR + "grub_antenna.glb", "color": Color("#FFC93C")},
	{"id": "glow", "name": "반딧불", "model": DIR + "grub_glow.glb", "color": Color("#FF9B3D")},
]

# 저장된 id 에 해당하는 지렁이 스킨 번호. 없는 id 면 0(기본).
static func worm_index(id: String) -> int:
	for i in WORMS.size():
		if WORMS[i]["id"] == id:
			return i
	return 0
