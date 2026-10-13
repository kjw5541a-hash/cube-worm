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
