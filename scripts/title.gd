class_name Title
extends CanvasLayer

# 시작 화면: 그림 한 장이 화면을 채운다. 어디든 터치하면 사라지고 started 신호를 낸다.
# 그림 안에 "TAP TO START" 글자가 들어 있다. 웹은 첫 터치 뒤에야 소리가 풀리므로 이 터치에서 BGM 을 시작한다.

signal started

const IMAGE := "res://assets/title.jpg"

var image := Picture.new()

class Picture extends TextureRect:
	signal tapped

	func _init() -> void:
		texture = load(IMAGE)
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤의 버튼이 터치를 받지 않게 막는다

	func _gui_input(event: InputEvent) -> void:
		var t := event as InputEventScreenTouch
		if t != null and t.pressed:
			tapped.emit()
			accept_event()

func _init() -> void:
	layer = 10  # HUD(1) 위
	add_child(image)
	image.tapped.connect(_on_tapped)

func _on_tapped() -> void:
	if not visible:
		return
	visible = false
	started.emit()

# 다시 보여 준다(나중에 일시정지·게임오버에서 타이틀로 돌아올 때 쓴다).
func show_again() -> void:
	visible = true
