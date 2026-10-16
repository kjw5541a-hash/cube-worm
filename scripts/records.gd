class_name Records
extends RefCounted

# 기록 판정과 표시 형식을 모은 순수 함수. 저장은 SaveData, 화면은 Title·Hud 가 맡는다.

# 기록 비교 결과: 못 깼다 / 첫 기록 / 신기록
enum Verdict { NONE, FIRST, NEW_BEST }

# 초 → 밀리초 정수(반올림). 음수는 0.
static func to_ms(seconds: float) -> int:
	return maxi(0, roundi(seconds * 1000.0))

# 밀리초 → 초 단위 글자. decimals 가 1 이하면 소수 첫째 자리, 아니면 둘째 자리.
static func format_time(ms: int, decimals: int) -> String:
	var s := ms / 1000.0
	return ("%.1f" if decimals <= 1 else "%.2f") % s

# 새 시간 ms 를 저장된 최고 best_ms(0 = 기록 없음)와 비교한다. 같은 시간은 신기록이 아니다.
static func judge_time(ms: int, best_ms: int) -> int:
	if ms <= 0:
		return Verdict.NONE
	if best_ms <= 0:
		return Verdict.FIRST
	return Verdict.NEW_BEST if ms < best_ms else Verdict.NONE

# 점수 score 가 저장된 최고 best 를 넘었는가. 기록이 없으면(best <= 0) 신기록 연출을 하지 않으므로 NONE 이다.
# 첫 기록을 저장하는 일은 부르는 쪽이 따로 한다.
static func judge_score(score: int, best: int) -> int:
	return Verdict.NEW_BEST if best > 0 and score > best else Verdict.NONE

# 타임어택 결과 문구. best_ms 는 이번 기록을 반영한 뒤의 최고 시간이다.
static func time_result_text(ms: int, verdict: int, best_ms: int) -> String:
	var lines: Array[String] = ["클리어!", "%s초" % format_time(ms, 2)]
	match verdict:
		Verdict.FIRST:
			lines.append("첫 기록!")
		Verdict.NEW_BEST:
			lines.append("신기록!")
		_:
			lines.append("최고 %s초" % format_time(best_ms, 2))
	lines.append("탭하면 다시 도전")
	return "\n".join(lines)
