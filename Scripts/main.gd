## 主场景入口：协调数据模型、交互逻辑、物理重建与预览层
extends Node2D

const Tool = preload("res://Scripts/Editor/editor_enums.gd").Tool

@onready var ground: StaticBody2D = $Ground
@onready var editor_objects: Node2D = $EditorObjects
@onready var preview_overlay: EditorPreviewOverlay = $PreviewOverlay

var model := LinkageModel.new()
var scene_builder := LinkageSceneBuilder.new()
var interaction := EditorInteraction.new()

var mouse_world := Vector2.ZERO


func _ready() -> void:
	interaction.setup(model, _rebuild_editor_objects)
	preview_overlay.setup(model)
	EditorStates.tool_changed.connect(_on_tool_changed)
	EditorStates.selection_changed.connect(_rebuild_editor_objects)
	model.build_initial_model()
	_rebuild_editor_objects()
	mouse_world = get_global_mouse_position()
	preview_overlay.set_mouse_world(mouse_world)


func _on_tool_changed(_new_tool: Tool) -> void:
	mouse_world = get_global_mouse_position()
	preview_overlay.set_mouse_world(mouse_world)


func _unhandled_input(event: InputEvent) -> void:
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
	scene_builder.rebuild(editor_objects, ground, model)
	preview_overlay.refresh()
