## 编辑器交互逻辑：处理鼠标/键盘输入，驱动模型变更
class_name EditorInteraction
extends RefCounted

const Tool = preload("res://Scripts/Editor/editor_enums.gd").Tool

var _model: LinkageModel
var _on_rebuild: Callable


func setup(model: LinkageModel, on_rebuild: Callable) -> void:
	_model = model
	_on_rebuild = on_rebuild


func handle_escape() -> bool:
	if EditorStates.current_tool == Tool.DRAW_LINE and EditorStates.is_drawing:
		EditorStates.is_drawing = false
		return true
	return false


func handle_delete() -> bool:
	if _delete_selected():
		_on_rebuild.call()
		return true
	return false


func handle_right_click_cancel() -> bool:
	if EditorStates.current_tool == Tool.DRAW_LINE and EditorStates.is_drawing:
		EditorStates.is_drawing = false
		return true
	return false


func handle_left_press(mouse_pos: Vector2) -> bool:
	var needs_redraw := true

	match EditorStates.current_tool:
		Tool.SELECT:
			needs_redraw = _handle_select_press(mouse_pos)
		Tool.DRAW_LINE:
			needs_redraw = _handle_draw_line_press(mouse_pos)
		Tool.FIXED_POINT:
			if LinkageEditing.place_fixed_point(_model, mouse_pos):
				_on_rebuild.call()
		Tool.MARKER_POINT:
			if LinkageEditing.place_marker_point(_model, mouse_pos):
				_on_rebuild.call()

	return needs_redraw


func handle_left_release(_mouse_pos: Vector2) -> bool:
	if EditorStates.current_tool != Tool.SELECT:
		return true

	if EditorStates.is_box_selecting:
		var rect := Rect2(EditorStates.box_start, EditorStates.box_end - EditorStates.box_start).abs()
		_select_in_rect(rect)
		EditorStates.is_box_selecting = false

	EditorStates.is_dragging_selection = false
	return true


func handle_mouse_motion(mouse_pos: Vector2) -> bool:
	match EditorStates.current_tool:
		Tool.SELECT:
			if EditorStates.is_box_selecting:
				EditorStates.box_end = mouse_pos
				return true
			if EditorStates.is_dragging_selection:
				var delta := mouse_pos - EditorStates.drag_last
				if _move_selection(delta):
					_on_rebuild.call()
				EditorStates.drag_last = mouse_pos
				return true
		Tool.DRAW_LINE, Tool.FIXED_POINT, Tool.MARKER_POINT:
			return true

	return false


## 选择工具：优先选中关节，其次连杆，否则开始框选
func _handle_select_press(mouse_pos: Vector2) -> bool:
	var joint_hit := LinkageQueries.pick_joint(_model, mouse_pos)
	var rod_hit := LinkageQueries.pick_rod(_model, mouse_pos)

	if not joint_hit.is_empty():
		if not _has_selected_joint(joint_hit):
			EditorStates.selected_joints = [joint_hit]
			EditorStates.selected_rods = []
			EditorStates.selection_changed.emit()
		EditorStates.drag_last = mouse_pos
		EditorStates.is_dragging_selection = true
	elif rod_hit != -1:
		if not EditorStates.selected_rods.has(rod_hit):
			EditorStates.selected_rods = [rod_hit]
			EditorStates.selected_joints = []
			EditorStates.selection_changed.emit()
		EditorStates.drag_last = mouse_pos
		EditorStates.is_dragging_selection = true
	else:
		if not EditorStates.selected_rods.is_empty() or not EditorStates.selected_joints.is_empty():
			EditorStates.selected_rods = []
			EditorStates.selected_joints = []
			EditorStates.selection_changed.emit()
		EditorStates.box_start = mouse_pos
		EditorStates.box_end = mouse_pos
		EditorStates.is_box_selecting = true

	return true


## 画线工具：第一次点击定起点，第二次点击定终点（均需合法吸附）
func _handle_draw_line_press(mouse_pos: Vector2) -> bool:
	if not EditorStates.is_drawing:
		var start_snap := LinkageQueries.find_line_snap(_model, mouse_pos, true)
		if start_snap.is_empty():
			return true
		EditorStates.draw_start = start_snap["position"]
		EditorStates.is_drawing = true
	else:
		var end_snap := LinkageQueries.find_line_snap(_model, mouse_pos, false)
		if end_snap.is_empty():
			return true
		var end_pos: Vector2 = end_snap["position"]
		if EditorStates.draw_start.distance_to(end_pos) < LinkageModel.MIN_ROD_LENGTH:
			return true
		if LinkageEditing.create_rod_from_line(_model, EditorStates.draw_start, end_pos):
			_on_rebuild.call()
		EditorStates.is_drawing = false

	return true


func _has_selected_joint(joint_ref: Dictionary) -> bool:
	for selected in EditorStates.selected_joints:
		if selected["type"] == joint_ref["type"] and selected["id"] == joint_ref["id"]:
			return true
	return false


func _select_in_rect(rect: Rect2) -> void:
	EditorStates.selected_rods = []
	EditorStates.selected_joints = []

	for rod in _model.rods:
		if _segment_intersects_rect(rod["start"], rod["end"], rect):
			EditorStates.selected_rods.append(rod["id"])

	if not _model.motor_point.is_empty() and rect.has_point(_model.motor_point["position"]):
		EditorStates.selected_joints.append({"type": "motor", "id": 1})

	for fixed in _model.fixed_points:
		if rect.has_point(fixed["position"]):
			EditorStates.selected_joints.append({"type": "fixed", "id": fixed["id"]})

	if not _model.marker_point.is_empty() and rect.has_point(_model.marker_point["position"]):
		EditorStates.selected_joints.append({"type": "marker", "id": 1})

	EditorStates.selection_changed.emit()


func _move_selection(delta: Vector2) -> bool:
	if delta.is_zero_approx():
		return false

	for rod_id in EditorStates.selected_rods:
		var rod := _model.get_rod_by_id(rod_id)
		if rod.is_empty():
			continue
		rod["start"] += delta
		rod["end"] += delta

	for joint_ref in EditorStates.selected_joints:
		if joint_ref["type"] == "motor":
			_model.motor_point["position"] += delta
			LinkageEditing.set_attached_endpoints(_model, _model.motor_point)
		elif joint_ref["type"] == "fixed":
			var fixed := _model.get_fixed_by_id(joint_ref["id"])
			if fixed.is_empty():
				continue
			fixed["position"] += delta
			LinkageEditing.set_attached_endpoints(_model, fixed)
		elif joint_ref["type"] == "marker" and not _model.marker_point.is_empty():
			_model.marker_point["position"] += delta
			LinkageEditing.set_attached_endpoints(_model, _model.marker_point)

	LinkageEditing.sync_points_to_attached_endpoints(_model)
	return true


func _delete_selected() -> bool:
	if EditorStates.selected_rods.is_empty() and EditorStates.selected_joints.is_empty():
		return false

	for rod_id in EditorStates.selected_rods:
		LinkageEditing.delete_rod(_model, rod_id)

	for joint_ref in EditorStates.selected_joints:
		match joint_ref["type"]:
			"fixed":
				LinkageEditing.delete_fixed_point(_model, joint_ref["id"])
			"marker":
				LinkageEditing.clear_marker(_model)
			"motor":
				pass

	EditorStates.selected_rods = []
	EditorStates.selected_joints = []
	LinkageEditing.cleanup_orphan_points(_model)
	EditorStates.selection_changed.emit()
	return true


func _segment_intersects_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true

	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y)
	]

	for i in range(4):
		var c0: Vector2 = corners[i]
		var c1: Vector2 = corners[(i + 1) % 4]
		if Geometry2D.segment_intersects_segment(a, b, c0, c1) != null:
			return true
	return false
