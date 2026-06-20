## 工具栏 UI：切换编辑器工具，并与 EditorStates 同步按钮状态
extends HBoxContainer
class_name EditorToolbars
const Tool = preload("res://Scripts/Editor/editor_enums.gd").Tool

@export var select_button: Button
@export var draw_button: Button
@export var fixed_button: Button
@export var marker_button: Button

func _ready() -> void:
	select_button.pressed.connect(func() -> void: _set_tool(Tool.SELECT))
	draw_button.pressed.connect(func() -> void: _set_tool(Tool.DRAW_LINE))
	fixed_button.pressed.connect(func() -> void: _set_tool(Tool.FIXED_POINT))
	marker_button.pressed.connect(func() -> void: _set_tool(Tool.MARKER_POINT))
	EditorStates.tool_changed.connect(_on_tool_changed)
	EditorStates.interaction_changed.connect(_on_interaction_changed)
	EditorStates.play_state_changed.connect(_on_play_state_changed)
	_sync_toolbar_buttons()


func _set_tool(tool: Tool) -> void:
	if EditorStates.is_interaction_locked:
		return
	EditorStates.current_tool = tool


func _on_tool_changed(_new_tool: Tool) -> void:
	_sync_toolbar_buttons()


func _on_interaction_changed() -> void:
	_sync_toolbar_buttons()


func _on_play_state_changed(_new_state) -> void:
	_sync_toolbar_buttons()


func _sync_toolbar_buttons() -> void:
	var current_tool := EditorStates.current_tool
	# 交互进行中或处于播放/暂停模式时禁用工具按钮
	var disabled: bool = EditorStates.is_interaction_locked or not EditorStates.is_editing

	select_button.button_pressed = current_tool == Tool.SELECT
	draw_button.button_pressed = current_tool == Tool.DRAW_LINE
	fixed_button.button_pressed = current_tool == Tool.FIXED_POINT
	marker_button.button_pressed = current_tool == Tool.MARKER_POINT

	select_button.disabled = disabled
	draw_button.disabled = disabled
	fixed_button.disabled = disabled
	marker_button.disabled = disabled
