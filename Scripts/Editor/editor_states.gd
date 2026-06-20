## 编辑器全局状态（Autoload）：工具、选中项与进行中的交互
extends Node

const Tool = preload("res://Scripts/Editor/editor_enums.gd").Tool
const PlayState = preload("res://Scripts/Editor/editor_enums.gd").PlayState

signal tool_changed(new_tool: Tool)
signal selection_changed
signal interaction_changed
signal play_state_changed(new_state: PlayState)

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
		_draw_start_snap = {}
		_is_box_selecting = false
		_is_dragging_selection = false
		_dragging_handle = {}
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

## 起点的完整吸附结果（含 kind / link / 锚点信息），用于第二次点击时建杆
var _draw_start_snap: Dictionary = {}
var draw_start_snap: Dictionary:
	get:
		return _draw_start_snap
	set(value):
		_draw_start_snap = value

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

## 正在拖动的连杆端点手柄 { rod_id, end }，空字典表示未拖动
var _dragging_handle: Dictionary = {}
var dragging_handle: Dictionary:
	get:
		return _dragging_handle
	set(value):
		if _dragging_handle == value:
			return
		var was_locked := is_interaction_locked
		_dragging_handle = value
		if was_locked != is_interaction_locked:
			interaction_changed.emit()


## 画线、框选、拖选或拖动手柄进行中时锁定工具切换
var is_interaction_locked: bool:
	get:
		return _is_drawing or _is_box_selecting or _is_dragging_selection or not _dragging_handle.is_empty()


## 当前运行模式（编辑 / 播放 / 暂停）
var _play_state: PlayState = PlayState.EDITING
var play_state: PlayState:
	get:
		return _play_state
	set(value):
		if _play_state == value:
			return
		_play_state = value
		play_state_changed.emit(_play_state)

## 仅编辑模式下允许编辑器交互
var is_editing: bool:
	get:
		return _play_state == PlayState.EDITING

## 物理是否应处于运行状态（仅播放模式）
var is_playing: bool:
	get:
		return _play_state == PlayState.PLAYING
