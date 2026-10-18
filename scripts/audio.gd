class_name Sfx
extends Node

# 소리를 내는 유일한 곳: 효과음 풀(동시에 겹쳐 울림)과 BGM 하나.
# 꺼짐 상태에서는 아무것도 재생하지 않는다. 웹은 첫 입력 전까지 소리가 막히므로
# BGM 은 호출하는 쪽이 첫 입력에서 start_music() 을 부른다.

const DIR := "res://assets/audio/"
const NAMES: Array[String] = ["eat_0", "eat_1", "eat_2", "eat_3", "turn", "up", "down", "rotate", "die", "clear", "start", "skin", "gold"]
const MUSIC := "bgm"
const POOL := 6                # 한꺼번에 겹쳐 울릴 수 있는 효과음 수
const SFX_DB := -4.0
const MUSIC_DB := -10.0
const DUCK_DB := -6.0          # 죽은 뒤 BGM 을 줄이는 양

var muted := false
var music := AudioStreamPlayer.new()
# 헤드리스 테스트가 실제 재생 상태 대신 보는 기록들
var plays := 0
var last_id := ""
var last_pitch := 1.0
var music_active := false
var music_starts := 0

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music_wanted := false

# 연속 먹기 수 combo 의 음높이 배율: 연속 1번째는 원래 음, 이을 때마다 반음 두 개(온음)씩 올라 Tuning.COMBO_MAX 에서 멈춘다.
static func combo_pitch(combo: int) -> float:
	return pow(2.0, 2.0 * (clampi(combo, 1, Tuning.COMBO_MAX) - 1) / 12.0)

# 조향 입력에 어울리는 소리 이름.
static func steer_id(steer: int) -> String:
	match steer:
		Worm.Steer.UP:
			return "up"
		Worm.Steer.DOWN:
			return "down"
	return "turn"

# _init 에서 만든다: 헤드리스 테스트가 _initialize 안에서 add_child 하면 _ready 가 아직 안 돌았다(FieldView 와 같다).
func _init() -> void:
	for n in NAMES:
		_streams[n] = load(DIR + n + ".ogg")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_DB
		add_child(p)
		_pool.append(p)
	var m := load(DIR + MUSIC + ".ogg") as AudioStreamOggVorbis
	m.loop = true
	music.stream = m
	music.volume_db = MUSIC_DB
	add_child(music)

func play(id: String, pitch := 1.0) -> void:
	if muted:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[id]
	p.pitch_scale = pitch
	if p.is_inside_tree():  # 트리 밖에서 부르면 엔진이 오류를 찍는다(헤드리스 테스트 초기화 중)
		p.play()
	plays += 1
	last_id = id
	last_pitch = pitch

# 벌레 종류 kind 를 먹는 소리. combo 는 게임이 센 연속 먹기 수라서, 화면의 점수 배율과 음이 같이 올라간다.
func play_eat(kind: int, combo: int) -> void:
	play("eat_%d" % kind, combo_pitch(combo))

func start_music() -> void:
	_music_wanted = true
	if muted or music_active:
		return
	if music.is_inside_tree():
		music.play()
	music_active = true
	music_starts += 1

func set_muted(on: bool) -> void:
	muted = on
	if on:
		music.stop()
		music_active = false
	elif _music_wanted:
		start_music()

# 죽은 뒤에는 BGM 을 작게 한다(끊기지 않고 줄었다가 새 판에서 돌아온다).
func duck(on: bool) -> void:
	music.volume_db = MUSIC_DB + (DUCK_DB if on else 0.0)
