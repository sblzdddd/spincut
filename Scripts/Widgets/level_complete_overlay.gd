## 通关结算覆盖层：显示关卡名与准确率，并提供重试 / 下一关 / 返回菜单导航。
## 作为独立预制场景使用，由主场景在通关时调用 show_result() 弹出。
extends Control
class_name LevelCompleteOverlay

signal retry_requested
signal next_requested
signal menu_requested

@export var title_label: Label
@export var level_label: Label
@export var accuracy_label: Label
@export var retry_button: Button
@export var next_button: Button
@export var menu_button: Button


func _ready() -> void:
	visible = false
	if retry_button != null:
		retry_button.pressed.connect(func() -> void: retry_requested.emit())
	if next_button != null:
		next_button.pressed.connect(func() -> void: next_requested.emit())
	if menu_button != null:
		menu_button.pressed.connect(func() -> void: menu_requested.emit())


## 弹出结算面板。has_next 为假时禁用“下一关”。
func show_result(level_name: String, accuracy: float, has_next: bool) -> void:
	if level_label != null:
		level_label.text = level_name
	if accuracy_label != null:
		accuracy_label.text = "Accuracy %.1f%%" % accuracy
	if next_button != null:
		next_button.disabled = not has_next
	visible = true


func hide_result() -> void:
	visible = false
