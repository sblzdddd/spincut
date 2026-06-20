## 主场景入口：协调数据模型、交互逻辑、物理重建与预览层
extends Node2D

const Tool = preload("res://Scripts/Editor/editor_enums.gd").Tool
const PlayState = preload("res://Scripts/Editor/editor_enums.gd").PlayState

@onready var ground: StaticBody2D = $Ground
@onready var editor_objects: Node2D = $EditorObjects
@onready var preview_overlay: EditorPreviewOverlay = $PreviewOverlay

var model := LinkageModel.new()
var scene_builder := LinkageSceneBuilder.new()
var interaction := EditorInteraction.new()

var mouse_world := Vector2.ZERO
var _prev_play_state: PlayState = PlayState.EDITING


func _ready() -> void:
	interaction.setup(model, _rebuild_editor_objects)
	preview_overlay.setup(model)
	EditorStates.tool_changed.connect(_on_tool_changed)
	EditorStates.selection_changed.connect(_rebuild_editor_objects)
	EditorStates.play_state_changed.connect(_on_play_state_changed)
	model.build_initial_model()
	_rebuild_editor_objects()
	mouse_world = get_global_mouse_position()
	preview_overlay.set_mouse_world(mouse_world)


## 播放（非暂停）时让特殊点可视化跟随其绑定的连杆刚体运动
func _physics_process(_delta: float) -> void:
	if not EditorStates.is_playing:
		return
	for child in editor_objects.get_children():
		if child is LinkagePoint:
			child.update_follow()


func _on_tool_changed(_new_tool: Tool) -> void:
	mouse_world = get_global_mouse_position()
	preview_overlay.set_mouse_world(mouse_world)


## 模式切换：
##   进入播放（自编辑）-> 清空选区并以物理激活方式重建场景
##   暂停 -> 冻结连杆但保留当前姿态
##   暂停后继续播放 -> 解除冻结
##   停止（回编辑）-> 用数据模型重建，连杆回到原始位置
func _on_play_state_changed(new_state: PlayState) -> void:
	match new_state:
		PlayState.PLAYING:
			if _prev_play_state == PlayState.PAUSED:
				_set_rods_frozen(false)
			else:
				_start_play()
		PlayState.PAUSED:
			_set_rods_frozen(true)
		PlayState.EDITING:
			_rebuild_editor_objects()
	_prev_play_state = new_state


func _start_play() -> void:
	EditorStates.is_drawing = false
	EditorStates.selected_rods = []
	EditorStates.selected_joints = []
	_rebuild_editor_objects()


## 状态保留式暂停/恢复：冻结前缓存各连杆速度，解冻后恢复，避免暂停清空动量
func _set_rods_frozen(frozen: bool) -> void:
	for child in editor_objects.get_children():
		if child is Rod:
			if frozen:
				child.saved_linear_velocity = child.linear_velocity
				child.saved_angular_velocity = child.angular_velocity
				child.freeze = true
			else:
				child.freeze = false
				child.linear_velocity = child.saved_linear_velocity
				child.angular_velocity = child.saved_angular_velocity


func _unhandled_input(event: InputEvent) -> void:
	if not EditorStates.is_editing:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if interaction.handle_escape():
			preview_overlay.refresh()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_DELETE:
		if interaction.handle_delete():
			preview_overlay.refresh()
		return

	if event is InputEventMouseMotion:
		mouse_world = get_global_mouse_position()
		interaction.handle_mouse_motion(mouse_world)
		preview_overlay.set_mouse_world(mouse_world)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_world = get_global_mouse_position()
		if event.pressed:
			interaction.handle_left_press(mouse_world)
			preview_overlay.set_mouse_world(mouse_world)
		else:
			interaction.handle_left_release(mouse_world)
			preview_overlay.set_mouse_world(mouse_world)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if interaction.handle_right_click_cancel():
			preview_overlay.refresh()


## 根据模型数据重建所有物理刚体、关节与节点可视化
func _rebuild_editor_objects() -> void:
	scene_builder.rebuild(editor_objects, ground, model, EditorStates.is_playing)
	preview_overlay.refresh()
