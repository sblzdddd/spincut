## 编辑器全局状态（Autoload）：工具、选中项与进行中的交互
extends Node

const Tool = preload("res://Scripts/Editor/editor_enums.gd").Tool

signal tool_changed(new_tool: Tool)
signal selection_changed
signal interaction_changed

var _current_tool: Tool = Tool.SELECT
var current_tool: Tool:
	get:
		return _current_tool
	set(value):
		if _current_tool == value or is_interaction_locked:
			return
		var was_locked := is_interaction_locked
		_current_tool = value
		_is_drawing = false
		_is_box_selecting = false
		_is_dragging_selection = false
		if was_locked != is_interaction_locked:
			interaction_changed.emit()
		tool_changed.emit(_current_tool)

var _selected_rods: Array[int] = []
var selected_rods: Array[int]:
	get:
		return _selected_rods
	set(value):
		_selected_rods = value

var _selected_joints: Array = []
var selected_joints: Array:
	get:
		return _selected_joints
	set(value):
		_selected_joints = value

var _is_drawing := false
var is_drawing: bool:
	get:
		return _is_drawing
	set(value):
		if _is_drawing == value:
			return
		var was_locked := is_interaction_locked
		_is_drawing = value
		if was_locked != is_interaction_locked:
			interaction_changed.emit()

var _draw_start := Vector2.ZERO
var draw_start: Vector2:
	get:
		return _draw_start
	set(value):
		_draw_start = value

var _is_box_selecting := false
var is_box_selecting: bool:
	get:
		return _is_box_selecting
	set(value):
		if _is_box_selecting == value:
			return
		var was_locked := is_interaction_locked
		_is_box_selecting = value
		if was_locked != is_interaction_locked:
			interaction_changed.emit()

var _box_start := Vector2.ZERO
var box_start: Vector2:
	get:
		return _box_start
	set(value):
		_box_start = value

var _box_end := Vector2.ZERO
var box_end: Vector2:
	get:
		return _box_end
	set(value):
		_box_end = value

var _is_dragging_selection := false
var is_dragging_selection: bool:
	get:
		return _is_dragging_selection
	set(value):
		if _is_dragging_selection == value:
			return
		var was_locked := is_interaction_locked
		_is_dragging_selection = value
		if was_locked != is_interaction_locked:
			interaction_changed.emit()

var _drag_last := Vector2.ZERO
var drag_last: Vector2:
	get:
		return _drag_last
	set(value):
		_drag_last = value


## 画线、框选或拖选进行中时锁定工具切换
var is_interaction_locked: bool:
	get:
		return _is_drawing or _is_box_selecting or _is_dragging_selection
