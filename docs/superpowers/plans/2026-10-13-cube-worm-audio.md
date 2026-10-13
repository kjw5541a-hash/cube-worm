# 큐브 지렁이 소리(BGM·효과음) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 합성한 효과음 11개와 BGM 한 곡을 게임에 붙이고, HUD 소리 버튼 하나로 전체를 켜고 끈다.

**Architecture:** 소리는 `Sfx`(Node) 한 곳에서만 낸다. `main.gd` 가 이미 받는 신호(`ate`, 조향·회전 입력, 스킨 변경)와 상태 전환에 `sfx.play(...)` 를 한 줄씩 연결한다. 소리 파일은 `tools/audio/synth.py` 가 합성해 `assets/audio/*.ogg` 로 쓴다. 켜짐·꺼짐은 `SaveData` 에 저장한다.

**Tech Stack:** Godot 4.7.2 GDScript(헤드리스 테스트 `./run_tests.sh`), Python 3 표준 라이브러리, ffmpeg(WAV → OGG, `/opt/homebrew/bin/ffmpeg`).

**Spec:** `docs/superpowers/specs/2026-10-13-cube-worm-audio-design.md`

## Global Constraints

- 답변·주석은 한국어. 커밋 메시지 끝에 `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- 작업 브랜치는 `audio`(이미 스펙 커밋이 있다). 푸시하면 Pages 가 라이브를 덮어쓴다 — 푸시 전에 `./run_tests.sh` 가 `전체 통과` 여야 한다.
- 소리 파일은 코드로 합성한 것만 쓴다. 외부 파일을 내려받지 않는다.
- 효과음·BGM 음량 조절 UI 와 개별 끄기 버튼은 만들지 않는다. 템포 변화도 없다.
- 새 `class_name` 이 생기면 `./run_tests.sh` 가 임포트 캐시를 갱신한다(스크립트가 매번 `--import` 를 먼저 돈다).
- 테스트는 `tests/test_*.gd`, 성공 표식은 `print("<파일명 확장자 없이>: OK")` 한 줄이다. 헤드리스에서는 실제 소리가 나지 않으므로 플레이어의 "재생 상태"가 아니라 `Sfx` 의 기록 변수(`plays`, `last_id`, `music_active`)를 본다.

## Review Focus

1. 소리를 끈 채로 `play`·`play_eat`·`start_music` 을 불러도 오류 없이 아무 소리도 안 난다 → Task 2 테스트.
2. 같은 소리를 한 프레임에 풀 크기보다 많이 불러도 오류가 없다 → Task 2 테스트.
3. 2초 넘게 쉬었다 먹으면 연속 먹기 음이 처음으로 돌아간다 → Task 2 테스트.
4. 저장 파일이 손상됐거나 값이 엉뚱한 타입이어도 소리 상태가 기본(켜짐)으로 읽힌다 → Task 3 테스트.
5. 소리를 끈 채 저장하고 다시 열면 꺼진 채로 시작하고, 첫 입력에도 BGM 이 시작되지 않는다 → Task 5 테스트.

---

### Task 1: 소리 합성 스크립트와 소리 파일

**Files:**
- Create: `tools/audio/synth.py`
- Create: `assets/audio/{eat_0,eat_1,eat_2,turn,up,down,rotate,die,clear,start,skin,bgm}.ogg`

**Interfaces:**
- Produces: `res://assets/audio/<이름>.ogg` 12개. 이름 목록은 Task 2 의 `Sfx.NAMES`(효과음 11개)와 `Sfx.MUSIC`(`"bgm"`)과 같다.

- [ ] **Step 1: 합성 스크립트 작성**

`tools/audio/synth.py` (표준 라이브러리 + ffmpeg 만 쓴다. 효과음·BGM 의 모양은 사용자가 시안으로 듣고 승인한 것과 같다):

```python
"""소리를 합성해 assets/audio/*.ogg 로 쓴다. 사용: python3 tools/audio/synth.py"""
import math, os, random, struct, subprocess, sys, tempfile, wave

SR = 22050
random.seed(7)  # 노이즈가 매번 같게

def tone(freq, dur, vol=0.5, shape="sine", f_end=None, attack=0.005, decay=3.0):
    n = int(SR * dur)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        f = freq if f_end is None else freq + (f_end - freq) * t
        phase += 2 * math.pi * f / SR
        if shape == "tri":
            s = 2 / math.pi * math.asin(math.sin(phase))
        elif shape == "square":
            s = 0.6 if math.sin(phase) >= 0 else -0.6
        else:
            s = math.sin(phase)
        out.append(s * min(1.0, i / (SR * attack)) * math.exp(-decay * t) * vol)
    return out

def noise(dur, vol=0.3, lp=0.2):
    n = int(SR * dur)
    out, y = [], 0.0
    for i in range(n):
        y += lp * (random.uniform(-1, 1) - y)
        out.append(y * vol * (1 - i / n) ** 2)
    return out

def mix(*tracks):
    out = [0.0] * max(len(t) for t in tracks)
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out

def seq(parts):
    out = []
    for p in parts:
        out += p
    return out

def eat(freq):
    # 뽁: 빠르게 올라가는 사인 + 아주 짧은 쩝(노이즈)
    return mix(tone(freq * 0.7, 0.14, 0.6, f_end=freq * 1.25, decay=5), noise(0.04, 0.12))

def bgm():
    # C 장조 펜타토닉 8마디, BPM 96, 4/4. 멜로디(삼각파) + 베이스(사인)
    beat = 60 / 96
    notes = {"C": 261.63, "D": 293.66, "E": 329.63, "G": 392.0, "A": 440.0, "c": 523.25}
    melody = [("E", 1), ("G", 1), ("A", 1), ("G", 1), ("E", 1), ("D", 1), ("C", 2),
              ("D", 1), ("E", 1), ("G", 1), ("E", 1), ("D", 2), ("C", 2),
              ("G", 1), ("A", 1), ("c", 1), ("A", 1), ("G", 1), ("E", 1), ("D", 2),
              ("E", 1), ("D", 1), ("C", 1), ("D", 1), ("C", 4)]
    roots = [130.81, 130.81, 110.0, 110.0, 174.61, 130.81, 146.83, 130.81]
    mel = seq([tone(notes[n], b * beat, 0.28, "tri", decay=2.2) for n, b in melody])
    bass = seq([tone(r, 2 * beat, 0.3, decay=1.6) for r in roots for _ in range(2)])
    size = max(len(mel), len(bass))
    mel += [0.0] * (size - len(mel))
    bass += [0.0] * (size - len(bass))
    return [m + b for m, b in zip(mel, bass)]

SOUNDS = {
    "eat_0": eat(392),
    "eat_1": eat(523),
    "eat_2": eat(698),
    "turn": tone(330, 0.05, 0.25, decay=8),
    "up": tone(300, 0.2, 0.4, f_end=620, decay=3.5),
    "down": tone(620, 0.2, 0.4, f_end=300, decay=3.5),
    "rotate": noise(0.22, 0.5, lp=0.08),
    "die": seq([mix(tone(110, 0.25, 0.7, f_end=70, decay=4), noise(0.1, 0.25)),
                tone(220, 0.35, 0.35, "tri", f_end=90, decay=3)]),
    "clear": seq([tone(523, 0.12, 0.45, "tri", decay=2), tone(659, 0.12, 0.45, "tri", decay=2),
                  tone(784, 0.3, 0.5, "tri", decay=2)]),
    "start": tone(440, 0.12, 0.4, f_end=880, decay=4),
    "skin": mix(tone(900, 0.04, 0.3, "square", decay=10), noise(0.02, 0.1)),
    "bgm": bgm(),
}

def write_wav(path, samples):
    scale = min(1.0, 0.9 / max(1e-9, max(abs(v) for v in samples)))  # 소리마다 최대 0.9 로 맞춘다
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * scale)) * 32767)) for v in samples))

def main():
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "audio")
    os.makedirs(out_dir, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, samples in SOUNDS.items():
            wav = os.path.join(tmp, name + ".wav")
            write_wav(wav, samples)
            # ffmpeg 내장 vorbis 인코더는 실험 단계라 -strict -2 가 필요하다.
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "vorbis", "-strict", "-2",
                            "-ac", "2", os.path.join(out_dir, name + ".ogg")], check=True)
    print("ok:", ", ".join(SOUNDS))

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: 실행해서 파일이 12개 만들어지는지 본다**

Run: `cd ~/games/cube-worm && python3 tools/audio/synth.py && ls assets/audio | wc -l && du -sh assets/audio`
Expected: `ok: eat_0, ...` 한 줄, 파일 수 `12`, 합계 용량 약 200KB 이하(BGM 이 대부분).

- [ ] **Step 3: OGG 가 올바른지 확인**

Run: `cd ~/games/cube-worm && for f in assets/audio/*.ogg; do ffprobe -v error -show_entries stream=codec_name,channels,duration -of csv=p=0 $f; done`
Expected: 12줄, 모두 `vorbis,2,...` 로 시작. `bgm.ogg` 의 길이는 약 20초(19.9~20.1).

- [ ] **Step 4: Commit**

```bash
cd ~/games/cube-worm
git add tools/audio/synth.py assets/audio
git commit -m "소리 합성 스크립트와 소리 파일 12개

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `Sfx` 클래스

**Files:**
- Create: `scripts/audio.gd`
- Create: `tests/test_audio.gd`

**Interfaces:**
- Consumes: Task 1 의 `res://assets/audio/<이름>.ogg`, `Worm.Steer`(`LEFT RIGHT UP DOWN`).
- Produces (Task 5 가 쓴다):
  - `Sfx.NAMES: Array[String]`, `Sfx.MUSIC := "bgm"`, `Sfx.MUSIC_DB`
  - `static func combo_pitch(step: int) -> float`
  - `static func steer_id(steer: int) -> String` — `LEFT/RIGHT → "turn"`, `UP → "up"`, `DOWN → "down"`
  - `func play(id: String, pitch := 1.0) -> void`
  - `func play_eat(kind: int, now := Time.get_ticks_msec() / 1000.0) -> void`
  - `func start_music() -> void`, `func set_muted(on: bool) -> void`, `func duck(on: bool) -> void`
  - 기록 변수: `muted: bool`, `plays: int`, `last_id: String`, `last_pitch: float`, `music_active: bool`, `music_starts: int`, 플레이어 `music`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_audio.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	_test_files_exist_and_load()
	_test_combo_pitch()
	_test_steer_id()
	_test_play_and_mute()
	_test_pool_overflow()
	_test_eat_combo()
	_test_music()
	print("test_audio: OK")
	quit()

func _sfx() -> Sfx:
	var s := Sfx.new()
	root.add_child(s)
	return s

func _test_files_exist_and_load() -> void:
	var names: Array[String] = []
	names.append_array(Sfx.NAMES)
	names.append(Sfx.MUSIC)
	assert(names.size() == 12, "효과음 11개 + BGM")
	for n in names:
		assert(load("res://assets/audio/%s.ogg" % n) is AudioStreamOggVorbis, "소리 파일이 불러와진다: %s" % n)

func _test_combo_pitch() -> void:
	assert(Sfx.combo_pitch(0) == 1.0, "0 단계는 원래 음")
	assert(is_equal_approx(Sfx.combo_pitch(1), pow(2.0, 2.0 / 12.0)), "한 단계는 온음(반음 두 개) 위")
	assert(Sfx.combo_pitch(2) > Sfx.combo_pitch(1), "단계가 오를수록 높다")
	assert(Sfx.combo_pitch(99) == Sfx.combo_pitch(Sfx.COMBO_MAX), "최대 단계에서 멈춘다")
	assert(Sfx.combo_pitch(-3) == 1.0, "음수 단계는 원래 음")

func _test_steer_id() -> void:
	assert(Sfx.steer_id(Worm.Steer.LEFT) == "turn" and Sfx.steer_id(Worm.Steer.RIGHT) == "turn")
	assert(Sfx.steer_id(Worm.Steer.UP) == "up" and Sfx.steer_id(Worm.Steer.DOWN) == "down")

func _test_play_and_mute() -> void:
	var s := _sfx()
	s.play("turn")
	assert(s.plays == 1 and s.last_id == "turn" and s.last_pitch == 1.0, "켜짐 상태에서는 재생 기록이 남는다")
	s.set_muted(true)
	s.play("turn")
	s.play_eat(0)
	s.start_music()
	assert(s.plays == 1 and not s.music_active, "꺼짐 상태에서는 아무 소리도 내지 않는다(오류도 없다)")
	s.queue_free()

func _test_pool_overflow() -> void:
	var s := _sfx()
	for i in Sfx.POOL * 3:
		s.play("eat_0")
	assert(s.plays == Sfx.POOL * 3, "풀보다 많이 연달아 불러도 오류 없이 돌려 쓴다")
	s.queue_free()

func _test_eat_combo() -> void:
	var s := _sfx()
	s.play_eat(1, 100.0)
	assert(s.last_id == "eat_1" and s.last_pitch == 1.0, "첫 먹기는 원래 음")
	s.play_eat(1, 101.0)
	assert(is_equal_approx(s.last_pitch, Sfx.combo_pitch(1)), "2초 안에 이어 먹으면 한 단계 위")
	s.play_eat(2, 102.5)
	assert(is_equal_approx(s.last_pitch, Sfx.combo_pitch(2)) and s.last_id == "eat_2", "계속 이으면 한 단계 더(종류는 그대로 따른다)")
	for i in 10:
		s.play_eat(0, 103.0 + i)
	assert(is_equal_approx(s.last_pitch, Sfx.combo_pitch(Sfx.COMBO_MAX)), "최대 단계를 넘지 않는다")
	s.play_eat(0, 200.0)
	assert(s.last_pitch == 1.0, "2초 넘게 쉬면 처음으로 돌아간다")
	s.queue_free()

func _test_music() -> void:
	var s := _sfx()
	s.start_music()
	assert(s.music_active and s.music.stream.loop, "BGM 이 시작되고 반복한다")
	var count := s.music_starts
	s.start_music()
	assert(s.music_starts == count, "이미 재생 중이면 다시 시작하지 않는다")
	s.set_muted(true)
	assert(not s.music_active, "끄면 BGM 이 멈춘다")
	s.set_muted(false)
	assert(s.music_active, "켜면 BGM 이 이어서 시작한다")
	s.duck(true)
	var ducked := s.music.volume_db
	s.duck(false)
	assert(ducked < s.music.volume_db, "죽은 뒤에는 BGM 이 작아진다")
	s.queue_free()
```

- [ ] **Step 2: 실패 확인**

Run: `cd ~/games/cube-worm && ./run_tests.sh 2>&1 | grep -A6 "test_audio"`
Expected: `FAIL: test_audio.gd` (`Sfx` 를 찾을 수 없다).

- [ ] **Step 3: 구현**

`scripts/audio.gd`:

```gdscript
class_name Sfx
extends Node

# 소리를 내는 유일한 곳: 효과음 풀(동시에 겹쳐 울림)과 BGM 하나.
# 꺼짐 상태에서는 아무것도 재생하지 않는다. 웹은 첫 입력 전까지 소리가 막히므로
# BGM 은 호출하는 쪽이 첫 입력에서 start_music() 을 부른다.

const DIR := "res://assets/audio/"
const NAMES: Array[String] = ["eat_0", "eat_1", "eat_2", "turn", "up", "down", "rotate", "die", "clear", "start", "skin"]
const MUSIC := "bgm"
const POOL := 6                # 한꺼번에 겹쳐 울릴 수 있는 효과음 수
const COMBO_WINDOW := 2.0      # 이 시간(초) 안에 이어 먹으면 연속
const COMBO_MAX := 4           # 연속 먹기 음 상승의 최대 단계(온음 단위)
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
var _combo := 0
var _last_eat := -1000.0
var _music_wanted := false

# 연속 먹기 step 단계의 음높이 배율: 단계마다 반음 두 개(온음)씩 올라간다.
static func combo_pitch(step: int) -> float:
	return pow(2.0, 2.0 * clampi(step, 0, COMBO_MAX) / 12.0)

# 조향 입력에 어울리는 소리 이름.
static func steer_id(steer: int) -> String:
	match steer:
		Worm.Steer.UP:
			return "up"
		Worm.Steer.DOWN:
			return "down"
	return "turn"

func _ready() -> void:
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
	p.play()
	plays += 1
	last_id = id
	last_pitch = pitch

# 벌레 종류 kind 를 먹는 소리. 2초 안에 이어 먹으면 한 단계씩 높아진다. now 는 테스트가 시간을 바꿔 끼우려고 둔 값이다.
func play_eat(kind: int, now := Time.get_ticks_msec() / 1000.0) -> void:
	if now - _last_eat <= COMBO_WINDOW:
		_combo = mini(_combo + 1, COMBO_MAX)
	else:
		_combo = 0
	_last_eat = now
	play("eat_%d" % kind, combo_pitch(_combo))

func start_music() -> void:
	_music_wanted = true
	if muted or music_active:
		return
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
```

- [ ] **Step 4: 통과 확인**

Run: `cd ~/games/cube-worm && ./run_tests.sh 2>&1 | grep -A4 "test_audio"`
Expected: `test_audio: OK`. (`./run_tests.sh` 가 새 OGG 를 임포트한다. 첫 실행은 조금 오래 걸린다.)
오류가 나면 `SCRIPT ERROR` 줄을 보고 그 호출만 고친다.

- [ ] **Step 5: 전체 테스트 후 Commit**

Run: `cd ~/games/cube-worm && ./run_tests.sh 2>&1 | tail -1`
Expected: `전체 통과`

```bash
git add scripts/audio.gd scripts/audio.gd.uid tests/test_audio.gd tests/test_audio.gd.uid
git commit -m "Sfx: 효과음 풀, 연속 먹기 음 상승, BGM 반복

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

(`.uid` 파일은 Godot 가 만든 것만 추가한다. 없으면 그 인자는 뺀다.)

---

### Task 3: 소리 켜짐 값 저장

**Files:**
- Modify: `scripts/save_data.gd`
- Test: `tests/test_save_data.gd`

**Interfaces:**
- Produces: `static func load_muted() -> bool`(기본 `false`), `static func save_muted(on: bool) -> void`, 상수 `MUTE_KEY := "sound_muted"`.

- [ ] **Step 1: 실패하는 테스트 추가**

`tests/test_save_data.gd` 의 `_initialize()` 에서 `_test_wrong_type_value()` 다음 줄에 `_test_muted()` 를 넣고, 파일 끝에 추가한다:

```gdscript
func _test_muted() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.PATH))
	assert(SaveData.load_muted() == false, "저장한 적이 없으면 소리는 켜짐")
	SaveData.save_muted(true)
	assert(SaveData.load_muted() == true, "끈 상태를 다시 읽을 수 있다")
	SaveData.save_skin("block")
	assert(SaveData.load_muted() == true and SaveData.load_skin() == "block", "스킨을 저장해도 소리 값이 지워지지 않는다")
	SaveData.save_muted(false)
	assert(SaveData.load_muted() == false and SaveData.load_skin() == "block", "소리를 저장해도 스킨이 지워지지 않는다")
	var cfg := ConfigFile.new()
	cfg.set_value(SaveData.SECTION, SaveData.MUTE_KEY, "yes")
	cfg.save(SaveData.PATH)
	assert(SaveData.load_muted() == false, "값이 엉뚱한 타입이면 켜짐")
	var f := FileAccess.open(SaveData.PATH, FileAccess.WRITE)
	f.store_string("{{{ 깨진 파일")
	f.close()
	assert(SaveData.load_muted() == false, "손상된 파일이면 켜짐")
```

- [ ] **Step 2: 실패 확인**

Run: `cd ~/games/cube-worm && ./run_tests.sh 2>&1 | grep -B2 -A6 "test_save_data"`
Expected: `SCRIPT ERROR` (`load_muted` 가 없다)와 `FAIL: test_save_data.gd`.

- [ ] **Step 3: 구현**

`scripts/save_data.gd` 에서 `const SKIN_KEY := "worm_skin"` 아래에 `const MUTE_KEY := "sound_muted"` 를 넣고, 파일 끝에 추가한다:

```gdscript

# 소리를 껐는지. 없거나 깨졌거나 불리언이 아니면 켜짐(false).
static func load_muted() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return false
	var v: Variant = cfg.get_value(SECTION, MUTE_KEY, false)
	return v if typeof(v) == TYPE_BOOL else false

static func save_muted(on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # 읽어서 덮어쓰므로 스킨 같은 다른 값은 지워지지 않는다
	cfg.set_value(SECTION, MUTE_KEY, on)
	cfg.save(PATH)
```

- [ ] **Step 4: 통과 확인**

Run: `cd ~/games/cube-worm && ./run_tests.sh 2>&1 | grep -A3 "test_save_data"`
Expected: `test_save_data: OK`

- [ ] **Step 5: Commit**

```bash
cd ~/games/cube-worm
git add scripts/save_data.gd tests/test_save_data.gd
git commit -m "소리 켜짐 값을 저장한다

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: HUD 소리 버튼

**Files:**
- Modify: `scripts/hud.gd`
- Test: `tests/test_hud.gd`

**Interfaces:**
- Produces: `signal sound_toggled(muted: bool)`, `func set_muted(on: bool) -> void`(신호는 내지 않는다), `Hud.SoundButton`(Control, 변수 `muted`), `hud.sound_button`.

- [ ] **Step 1: 실패하는 테스트 추가**

`tests/test_hud.gd` 의 `_initialize()` 에서 `print("test_hud: OK")` 앞에 `_test_sound_button()` 호출을 넣고, 파일 끝에 추가한다:

```gdscript
func _test_sound_button() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	var got: Array[bool] = []
	hud.sound_toggled.connect(func(m: bool) -> void: got.append(m))
	assert(hud.sound_button != null and not hud.sound_button.muted, "처음에는 소리 켜짐")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	hud.sound_button._gui_input(tap)
	assert(hud.sound_button.muted and got == [true], "누르면 꺼지고 신호가 한 번 온다")
	hud.sound_button._gui_input(tap)
	assert(not hud.sound_button.muted and got == [true, false], "다시 누르면 켜진다")
	hud.set_muted(true)
	assert(hud.sound_button.muted and got == [true, false], "set_muted 는 신호를 내지 않는다(저장된 값을 반영할 때 쓴다)")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	hud.sound_button._gui_input(release)
	assert(hud.sound_button.muted, "손가락을 뗄 때는 바뀌지 않는다")
	var turn_xs: Array = hud.get_children().filter(func(n: Node) -> bool: return n is Hud.TurnButton).map(func(b: Control) -> float: return b.position.x)
	assert(turn_xs.size() == 2 and hud.sound_button.position.x < turn_xs.min(), "소리 버튼은 회전 버튼들 왼쪽에 있다")
	hud.queue_free()
```

(`_initialize` 가 `await` 를 쓰는 구조이면 마지막 `queue_free` 뒤, `print` 앞에 호출을 둔다. 함수 안에는 `await` 가 없다.)

- [ ] **Step 2: 실패 확인**

Run: `cd ~/games/cube-worm && ./run_tests.sh 2>&1 | grep -B2 -A6 "test_hud"`
Expected: `SCRIPT ERROR`(`sound_button` 이 없다)와 `FAIL: test_hud.gd`.

- [ ] **Step 3: 구현**

`scripts/hud.gd` 수정:

① 맨 위 `signal turn_pressed(dir: int)` 아래에 추가:

```gdscript
signal sound_toggled(muted: bool)
```

② 변수 목록(`var clear_label := Label.new()` 아래)에 추가:

```gdscript
var sound_button := SoundButton.new()
```

③ `_ready()` 의 `for d in [-1, 1]:` 루프 뒤에 추가:

```gdscript
	sound_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sound_button.position = Vector2(-344, 16)  # 회전 버튼 둘(-232, -120) 왼쪽
	sound_button.toggled.connect(sound_toggled.emit)
	add_child(sound_button)
```

④ `show_clear` 아래에 추가:

```gdscript

# 저장된 값을 버튼에 반영한다(신호는 내지 않는다).
func set_muted(on: bool) -> void:
	sound_button.muted = on
	sound_button.queue_redraw()
```

⑤ 파일 맨 끝(`TurnButton` 클래스 뒤)에 추가:

```gdscript

# 소리 켜짐·꺼짐 버튼. 스피커 기호가 한글 폰트에 없을 수 있어 직접 그린다.
class SoundButton extends Control:
	signal toggled(muted: bool)
	var muted := false

	func _init() -> void:
		size = Vector2(104, 104)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		var t := event as InputEventScreenTouch
		if t != null and t.pressed:
			muted = not muted
			queue_redraw()
			toggled.emit(muted)
			accept_event()

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 46.0, Color(1, 1, 1, 0.12))
		var col := Color(1, 1, 1, 0.45 if muted else 1.0)
		# 스피커: 네모 + 나팔
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-22, -9), c + Vector2(-10, -9), c + Vector2(4, -22),
			c + Vector2(4, 22), c + Vector2(-10, 9), c + Vector2(-22, 9),
		]), col)
		if muted:  # ✕
			draw_line(c + Vector2(12, -12), c + Vector2(30, 12), col, 5.0, true)
			draw_line(c + Vector2(30, -12), c + Vector2(12, 12), col, 5.0, true)
		else:  # 소리 파동 두 겹
			for r in [14.0, 24.0]:
				draw_arc(c + Vector2(4, 0), r, deg_to_rad(-45.0), deg_to_rad(45.0), 12, col, 4.0, true)
```

- [ ] **Step 4: 통과 확인**

Run: `cd ~/games/cube-worm && ./run_tests.sh 2>&1 | grep -A3 "test_hud"`
Expected: `test_hud: OK`

- [ ] **Step 5: Commit**

```bash
cd ~/games/cube-worm
git add scripts/hud.gd tests/test_hud.gd
git commit -m "HUD 소리 켜짐·꺼짐 버튼

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: 게임에 소리 연결

**Files:**
- Modify: `scripts/main.gd`
- Test: `tests/test_main_smoke.gd`

**Interfaces:**
- Consumes: `Sfx`(Task 2 전부), `SaveData.load_muted/save_muted`(Task 3), `hud.sound_toggled`/`hud.set_muted`/`hud.sound_button`(Task 4).
- Produces: `main.sfx`(Sfx).

- [ ] **Step 1: 실패하는 테스트 추가**

`tests/test_main_smoke.gd` 는 한 함수에 `await` 로 이어진 긴 시나리오다. 기존 흐름을 바꾸지 않고 다음 곳에만 단언을 끼운다.

① `var game: Game = main.game` 아래에 추가:

```gdscript
	assert(main.sfx != null and not main.sfx.muted and not main.sfx.music_active, "처음에는 소리가 켜져 있고, 첫 입력 전에는 BGM 이 조용하다")
```

② 출발 입력 줄(`main.controller.steer_pressed.emit(Worm.Steer.LEFT)  # 출발 전 첫 입력은 바로 꺾임 ...`) 바로 뒤에 추가 — 기존 단언들은 그대로 둔다:

```gdscript
	assert(main.sfx.last_id == "start" and main.sfx.music_active, "출발 입력에서 시작 소리가 나고 BGM 이 시작된다")
```

③ 벌레 먹는 부분(`main._on_ate(1, ...)` 와 `pops.size() == 1` 단언) 바로 뒤에 추가:

```gdscript
	assert(main.sfx.last_id == "eat_1", "먹으면 그 종류의 먹는 소리가 난다")
```

④ 회전 버튼 단언(`assert(main.rig.yaw_step == 1, "회전 버튼으로 맵이 돈다")`) 바로 뒤에 추가:

```gdscript
	assert(main.sfx.last_id == "rotate", "회전하면 회전 소리가 난다")
	var plays_before: int = main.sfx.plays
	main.hud.sound_button._gui_input(tap)  # 위에서 만든 터치 이벤트(pressed = true)를 다시 쓴다
	assert(main.sfx.muted and not main.sfx.music_active and SaveData.load_muted(), "소리 버튼을 누르면 꺼지고 저장된다")
	main.controller.steer_pressed.emit(Worm.Steer.RIGHT)
	assert(main.sfx.plays == plays_before, "꺼진 동안에는 조향 소리도 나지 않는다")
	main.hud.sound_button._gui_input(tap)
	assert(not main.sfx.muted and main.sfx.music_active and not SaveData.load_muted(), "다시 누르면 켜지고 BGM 도 돌아온다")
```

⑤ 죽음 단언(`assert(main.rig.is_shaking(), "죽으면 화면이 흔들린다")`) 바로 뒤에 추가:

```gdscript
	assert(main.sfx.last_id == "die" and main.sfx.music.volume_db < Sfx.MUSIC_DB, "죽으면 쿵 소리가 나고 BGM 이 작아진다")
```

⑥ 새 판 단언(`assert(main.game != game and main.game.state == Game.State.WAITING, "새 판이 시작된다")`) 바로 뒤에 추가:

```gdscript
	assert(is_equal_approx(main.sfx.music.volume_db, Sfx.MUSIC_DB), "새 판에서는 BGM 이 원래 크기로 돌아온다")
```

⑦ 저장된 스킨 확인 블록(`var again := _screen()` 앞)에 꺼진 채 저장하고 다시 열기를 끼운다:

```gdscript
	SaveData.save_muted(true)
	var quiet := _screen()
	await process_frame
	assert(quiet.sfx.muted and quiet.hud.sound_button.muted, "꺼진 채 저장하면 다음에도 꺼진 채로 시작한다")
	quiet.controller.steer_pressed.emit(Worm.Steer.LEFT)
	assert(not quiet.sfx.music_active and quiet.sfx.plays == 0, "꺼진 채로 시작하면 첫 입력에도 소리가 나지 않는다")
	SaveData.save_muted(false)
```

- [ ] **Step 2: 실패 확인**

Run: `cd ~/games/cube-worm && ./run_tests.sh 2>&1 | grep -B2 -A6 "test_main_smoke"`
Expected: `SCRIPT ERROR`(`main.sfx` 가 없다) 또는 20초 `TIMEOUT`, 그리고 `FAIL: test_main_smoke.gd`.

- [ ] **Step 3: 구현 — `scripts/main.gd`**

① 변수 목록(`var picker := SkinPicker.new()` 아래)에 추가:

```gdscript
var sfx := Sfx.new()
```

② `_ready()` 의 `add_child(hud)` 앞에 추가:

```gdscript
	add_child(sfx)
	sfx.muted = SaveData.load_muted()
```

③ 같은 함수에서 `picker.skin_changed.connect(_on_skin_changed)` 아래에 추가:

```gdscript
	hud.sound_toggled.connect(_on_sound_toggled)
	hud.set_muted(sfx.muted)
```

④ `new_game()` 의 `_was_dead = false` 아래에 추가:

```gdscript
	sfx.duck(false)
```

그리고 `game.ate.connect(_on_ate)` 아래에 추가:

```gdscript
	game.cleared.connect(func() -> void: sfx.play("clear"))
```

⑤ `_process()` 의 죽음 분기에서 `rig.shake()` 바로 아래(`_was_dead` 가 처음 켜질 때 한 번만 실행되는 줄 안)에 추가:

```gdscript
			sfx.play("die")
			sfx.duck(true)
```

⑥ `_on_ate` 의 첫 줄 위에 추가:

```gdscript
	sfx.play_eat(kind)
```

⑦ `_on_steer` 의 `game.press(steer)` 한 줄을 다음으로 바꾼다:

```gdscript
	var was_waiting := game.state == Game.State.WAITING
	if game.press(steer):  # 받아들여진 입력만 소리가 난다
		sfx.start_music()
		sfx.play("start" if was_waiting else Sfx.steer_id(steer))
```

⑧ `_on_turn` 을 다음으로 바꾼다(`rig.turn` 은 입력을 늘 받아들이므로 죽지 않았으면 소리를 낸다):

```gdscript
func _on_turn(dir: int) -> void:
	if game.state != Game.State.DEAD:
		rig.turn(dir)
		sfx.start_music()
		sfx.play("rotate")
```

⑨ `_on_skin_changed` 의 첫 줄 앞에 추가:

```gdscript
	sfx.start_music()
	sfx.play("skin")
```

⑩ 파일 맨 아래에 추가:

```gdscript

func _on_sound_toggled(muted: bool) -> void:
	sfx.set_muted(muted)
	SaveData.save_muted(muted)
	if not muted:
		sfx.start_music()  # 사용자의 입력이므로 웹에서도 재생이 풀린다
```

**확인할 것:** 시작 때 `picker.set_index(...)` 는 `skin_changed` 신호를 내지 않는다(저장된 스킨을 띄울 때 쓰는 함수). 그래서 화면을 열 때 `skin` 소리나 BGM 이 나오지 않는다. 확인만 하고 고칠 것은 없다.

- [ ] **Step 4: 통과 확인**

Run: `cd ~/games/cube-worm && ./run_tests.sh 2>&1 | grep -A3 "test_main_smoke"`
Expected: `test_main_smoke: OK`
단언이 실패하면 어느 줄인지 `SCRIPT ERROR` 로 나온다. 실패한 단언의 소리 연결 지점만 고친다.

- [ ] **Step 5: 전체 테스트와 Commit**

Run: `cd ~/games/cube-worm && ./run_tests.sh > /tmp/audio_all.txt 2>&1; grep -E "SCRIPT ERROR|FAIL|TIMEOUT" /tmp/audio_all.txt; tail -1 /tmp/audio_all.txt`
Expected: 앞의 `grep` 은 아무것도 안 찍고, 마지막 줄이 `전체 통과`. (`test_main_smoke` 가 가끔 한 번 실패한다고 알려져 있다. 한 번 더 돌려서 통과하는지 보되, 두 번 연속 실패하면 원인을 조사한다.)

```bash
cd ~/games/cube-worm
git add scripts/main.gd tests/test_main_smoke.gd
git commit -m "게임에 효과음·BGM 연결

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: 배포와 웹 확인

**Files:** 없음(푸시와 확인만).

- [ ] **Step 1: 푸시**

```bash
cd ~/games/cube-worm
git push -u origin audio
```

Run: `sleep 90; gh run list --branch audio --limit 1`
Expected: `completed success`. 실패하면 `gh run view --log-failed` 로 읽고 고친다. OGG 임포트 때문에 내보내기가 실패하는 경우가 가장 의심스럽다.

- [ ] **Step 2: 크롬 에뮬레이션으로 소리 버튼과 오류 확인**

`https://kjw5541a-hash.github.io/cube-worm/?level=1&v=<번호>` 를 열고(`v=` 는 캐시를 피하는 아무 숫자),
1. 오른쪽 위에 소리 버튼(스피커)이 회전 버튼 왼쪽에 보이는지 스크린샷으로 본다.
2. 콘솔에 오디오 관련 오류가 없는지 `list_console_messages` 로 본다.
3. 소리 버튼을 눌러 ✕ 로 바뀌는지, 한 번 더 눌러 되돌아오는지 본다.

실제로 들리는 소리와 크기 균형은 자동 확인이 안 된다 — 사용자가 폰에서 듣는다.

- [ ] **Step 3: 사용자에게 보고**

빌드 번호와 주소, 폰에서 들어 볼 것(스펙 7절: 소리 크기 균형, 20초 루프가 질리는지, 방향 전환 "톡"이 거슬리는지, 첫 터치 전에 조용한 것이 어색한지)을 한국어로 알린다.
