## 播放控制 UI：播放/暂停切换 + 停止，并与 EditorStates 运行模式同步
extends HBoxContainer
class_name PlaybackControls
const PlayState = preload("res://Scripts/Editor/editor_enums.gd").PlayState

@export var play_button: Button
@export var stop_button: Button


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	EditorStates.play_state_changed.connect(_on_play_state_changed)
	_sync_buttons()


## 播放/暂停切换：编辑或暂停时开始播放，播放时暂停
func _on_play_pressed() -> void:
	match EditorStates.play_state:
		PlayState.PLAYING:
			EditorStates.play_state = PlayState.PAUSED
		_:
			EditorStates.play_state = PlayState.PLAYING


## 停止：回到编辑模式并回退至原始位置
func _on_stop_pressed() -> void:
	EditorStates.play_state = PlayState.EDITING


func _on_play_state_changed(_new_state) -> void:
	_sync_buttons()


func _sync_buttons() -> void:
	match EditorStates.play_state:
		PlayState.PLAYING:
			play_button.text = "Pause"
			play_button.button_pressed = true
			stop_button.disabled = false
		PlayState.PAUSED:
			play_button.text = "Play"
			play_button.button_pressed = false
			stop_button.disabled = false
		PlayState.EDITING:
			play_button.text = "Play"
			play_button.button_pressed = false
			stop_button.disabled = true
