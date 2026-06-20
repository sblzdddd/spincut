## 预览覆盖层：置于场景上层，避免被背景/连杆遮挡
extends Node2D
class_name EditorPreviewOverlay

var _model: LinkageModel
var _mouse_world := Vector2.ZERO


func setup(model: LinkageModel) -> void:
	_model = model


func set_mouse_world(world_pos: Vector2) -> void:
	_mouse_world = world_pos
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if _model == null:
		return
	# 仅编辑模式绘制操作提示，播放/暂停时隐藏
	if not EditorStates.is_editing:
		return
	EditorPreview.draw(self, EditorStates.current_tool, _mouse_world, _model)
