## 工具栏 UI：切换编辑器工具，并与 EditorStates 同步按钮状态
extends HBoxContainer
class_name EditorToolbars
const Tool = preload("res://Scripts/Editor/editor_enums.gd").Tool

@export var select_button: Button
@export var draw_button: Button
@export var fixed_button: Button
@export var marker_button: Button
@export var motor_button: Button
@export var delete_button: Button

func _ready() -> void:
	_resolve_buttons()
	_connect_button(select_button, Tool.SELECT)
	_connect_button(draw_button, Tool.DRAW_LINE)
	_connect_button(fixed_button, Tool.FIXED_POINT)
	_connect_button(marker_button, Tool.MARKER_POINT)
	_connect_button(motor_button, Tool.MOTOR_POINT)
	_connect_button(delete_button, Tool.DELETE)
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


func _resolve_buttons() -> void:
	if select_button == null:
		select_button = get_node_or_null("SelectButton")
	if draw_button == null:
		draw_button = get_node_or_null("DrawButton")
	if fixed_button == null:
		fixed_button = get_node_or_null("FixedButton")
	if marker_button == null:
		marker_button = get_node_or_null("MarkerButton")
	if motor_button == null:
		motor_button = get_node_or_null("MotorButton")
	if delete_button == null:
		delete_button = get_node_or_null("DeleteButton")


func _connect_button(button: Button, tool: Tool) -> void:
	if button == null:
		push_warning("EditorToolbars: missing toolbar button for tool %s" % str(tool))
		return
	button.pressed.connect(func() -> void: _set_tool(tool))


func _sync_toolbar_buttons() -> void:
	if select_button == null or draw_button == null or fixed_button == null or marker_button == null or motor_button == null or delete_button == null:
		return
	var current_tool := EditorStates.current_tool
	# 交互进行中或处于播放/暂停模式时禁用工具按钮
	var disabled: bool = EditorStates.is_interaction_locked or not EditorStates.is_editing

	select_button.button_pressed = current_tool == Tool.SELECT
	draw_button.button_pressed = current_tool == Tool.DRAW_LINE
	fixed_button.button_pressed = current_tool == Tool.FIXED_POINT
	marker_button.button_pressed = current_tool == Tool.MARKER_POINT
	motor_button.button_pressed = current_tool == Tool.MOTOR_POINT
	delete_button.button_pressed = current_tool == Tool.DELETE

	select_button.disabled = disabled
	draw_button.disabled = disabled
	fixed_button.disabled = disabled
	marker_button.disabled = disabled
	motor_button.disabled = disabled
	delete_button.disabled = disabled
