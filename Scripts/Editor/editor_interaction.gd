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


func handle_right_press(mouse_pos: Vector2) -> bool:
	if handle_right_click_cancel():
		return true
	if EditorStates.is_interaction_locked:
		return false
	EditorStates.begin_right_delete_hold()
	if _delete_at_point(mouse_pos):
		_on_rebuild.call()
	return true


func handle_right_release() -> bool:
	if EditorStates.is_right_delete_hold:
		EditorStates.end_right_delete_hold()
		return true
	return false


func handle_left_press(mouse_pos: Vector2) -> bool:
	var needs_redraw := true

	match EditorStates.current_tool:
		Tool.SELECT:
			needs_redraw = _handle_select_press(mouse_pos)
		Tool.DELETE:
			needs_redraw = _handle_delete_press(mouse_pos)
		Tool.DRAW_LINE:
			needs_redraw = _handle_draw_line_press(mouse_pos)
		Tool.FIXED_POINT:
			if LinkageEditing.place_fixed_point(_model, mouse_pos):
				_on_rebuild.call()
		Tool.MARKER_POINT:
			if LinkageEditing.place_marker_point(_model, mouse_pos):
				_on_rebuild.call()
		Tool.MOTOR_POINT:
			if LinkageEditing.place_motor_point(_model, mouse_pos):
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
	EditorStates.dragging_handle = {}
	return true


func handle_mouse_motion(mouse_pos: Vector2) -> bool:
	match EditorStates.current_tool:
		Tool.SELECT:
			if not EditorStates.dragging_handle.is_empty():
				if _drag_handle(mouse_pos):
					_on_rebuild.call()
				return true
			if EditorStates.is_box_selecting:
				EditorStates.box_end = mouse_pos
				return true
			if EditorStates.is_dragging_selection:
				var delta := mouse_pos - EditorStates.drag_last
				if _move_selection(delta):
					_on_rebuild.call()
				EditorStates.drag_last = mouse_pos
				return true
		Tool.DELETE:
			if EditorStates.is_right_delete_hold or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				if _delete_at_point(mouse_pos):
					_on_rebuild.call()
			return true
		Tool.DRAW_LINE, Tool.FIXED_POINT, Tool.MARKER_POINT, Tool.MOTOR_POINT:
			return true

	return false


## 选择工具：优先抓取已选连杆的端点手柄，其次关节，其次选中连杆（仅选中，不整体拖动），否则框选
func _handle_select_press(mouse_pos: Vector2) -> bool:
	var handle := _pick_handle(mouse_pos)
	if not handle.is_empty():
		EditorStates.dragging_handle = handle
		EditorStates.drag_last = mouse_pos
		return true

	var joint_hit := LinkageQueries.pick_joint(_model, mouse_pos)
	if not joint_hit.is_empty():
		if not _has_selected_joint(joint_hit):
			EditorStates.selected_joints = [joint_hit]
			EditorStates.selected_rods = []
			EditorStates.selection_changed.emit()
		EditorStates.drag_last = mouse_pos
		EditorStates.is_dragging_selection = true
		return true

	var rod_hit := LinkageQueries.pick_rod(_model, mouse_pos)
	if rod_hit != -1:
		# 连杆只可被选中以显示手柄，不再通过拖动杆体整体移动
		if not EditorStates.selected_rods.has(rod_hit):
			EditorStates.selected_rods = [rod_hit]
			EditorStates.selected_joints = []
			EditorStates.selection_changed.emit()
		return true

	if not EditorStates.selected_rods.is_empty() or not EditorStates.selected_joints.is_empty():
		EditorStates.selected_rods = []
		EditorStates.selected_joints = []
		EditorStates.selection_changed.emit()
	EditorStates.box_start = mouse_pos
	EditorStates.box_end = mouse_pos
	EditorStates.is_box_selecting = true
	return true


## 删除工具：点击或拖过关节/连杆时立即删除
func _handle_delete_press(mouse_pos: Vector2) -> bool:
	if _delete_at_point(mouse_pos):
		_on_rebuild.call()
	return true


func _delete_at_point(mouse_pos: Vector2) -> bool:
	var joint_hit := LinkageQueries.pick_joint(_model, mouse_pos)
	if not joint_hit.is_empty():
		EditorStates.selected_joints = [joint_hit]
		EditorStates.selected_rods = []
		return _delete_selected()

	var rod_hit := LinkageQueries.pick_rod(_model, mouse_pos)
	if rod_hit != -1:
		EditorStates.selected_rods = [rod_hit]
		EditorStates.selected_joints = []
		return _delete_selected()

	return false


## 命中已选连杆的端点手柄时返回 { rod_id, end }
func _pick_handle(mouse_pos: Vector2) -> Dictionary:
	for rod_id in EditorStates.selected_rods:
		var rod := _model.get_rod_by_id(rod_id)
		if rod.is_empty():
			continue
		if rod["start"].distance_to(mouse_pos) <= LinkageModel.JOINT_PICK_RADIUS:
			return {"rod_id": rod_id, "end": 0}
		if rod["end"].distance_to(mouse_pos) <= LinkageModel.JOINT_PICK_RADIUS:
			return {"rod_id": rod_id, "end": 1}
	return {}


## 画线工具：第一次点击定起点，第二次点击定终点（均需合法吸附）
func _handle_draw_line_press(mouse_pos: Vector2) -> bool:
	if not EditorStates.is_drawing:
		var start_snap := LinkageQueries.find_draw_snap(_model, mouse_pos, true)
		if start_snap.is_empty():
			return true
		EditorStates.draw_start = start_snap["position"]
		EditorStates.draw_start_snap = start_snap
		EditorStates.is_drawing = true
	else:
		var end_snap := LinkageQueries.find_draw_snap(_model, mouse_pos, false)
		if end_snap.is_empty():
			return true
		var end_pos: Vector2 = end_snap["position"]
		if EditorStates.draw_start.distance_to(end_pos) < LinkageModel.MIN_ROD_LENGTH:
			return true
		if LinkageEditing.create_rod_from_snaps(_model, EditorStates.draw_start_snap, end_snap):
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

	for motor in _model.motor_points:
		if rect.has_point(motor["position"]):
			EditorStates.selected_joints.append({"type": "motor", "id": motor["id"]})

	for fixed in _model.fixed_points:
		if rect.has_point(fixed["position"]):
			EditorStates.selected_joints.append({"type": "fixed", "id": fixed["id"]})

	for marker in _model.marker_points:
		if rect.has_point(marker["position"]):
			EditorStates.selected_joints.append({"type": "marker", "id": marker["id"]})

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
			var motor := _model.get_motor_by_id(joint_ref["id"])
			if motor.is_empty():
				continue
			motor["position"] += delta
			LinkageEditing.set_attached_endpoints(_model, motor)
		elif joint_ref["type"] == "fixed":
			var fixed := _model.get_fixed_by_id(joint_ref["id"])
			if fixed.is_empty():
				continue
			fixed["position"] += delta
			LinkageEditing.set_attached_endpoints(_model, fixed)
		elif joint_ref["type"] == "marker":
			var marker: Dictionary = _model.get_marker_by_id(joint_ref["id"])
			if marker.is_empty():
				continue
			marker["position"] += delta
			LinkageEditing.set_attached_endpoints(_model, marker)

	LinkageEditing.sync_points_to_attached_endpoints(_model)
	return true


## 拖动端点手柄：仅吸附到其他连杆的端点（ENDS），否则悬空跟随鼠标。
## 若手柄所在位置是多杆共享关节，则整簇端点一起移动以保持连接。
func _drag_handle(mouse_pos: Vector2) -> bool:
	var handle := EditorStates.dragging_handle
	var rod := _model.get_rod_by_id(handle["rod_id"])
	if rod.is_empty():
		return false

	var old_pos: Vector2 = rod["start"] if handle["end"] == 0 else rod["end"]
	var target_pos := mouse_pos
	var snap := _find_end_snap_excluding(mouse_pos, handle["rod_id"])
	if not snap.is_empty():
		target_pos = snap["position"]

	if target_pos.is_equal_approx(old_pos):
		return false

	_move_cluster(old_pos, target_pos)
	EditorStates.drag_last = mouse_pos
	return true


## 查找可吸附的端点（排除被拖动的连杆自身），且该端点仍可再接一根连杆
func _find_end_snap_excluding(pos: Vector2, exclude_rod_id: int) -> Dictionary:
	var best_dist := LinkageModel.SNAP_DISTANCE
	var best: Dictionary = {}
	for rod in _model.rods:
		if rod["id"] == exclude_rod_id:
			continue
		for end_idx in [0, 1]:
			var p: Vector2 = rod["start"] if end_idx == 0 else rod["end"]
			var d := p.distance_to(pos)
			if d <= best_dist and LinkageQueries.count_members_at_position(_model, p) <= 1:
				best_dist = d
				best = {"position": p}
	return best


## 将与 old_pos 重合的所有连杆端点（及附着其上的特殊点）整体移动到 new_pos
func _move_cluster(old_pos: Vector2, new_pos: Vector2) -> void:
	for rod in _model.rods:
		if rod["start"].distance_to(old_pos) <= LinkageModel.SNAP_DISTANCE:
			rod["start"] = new_pos
			rod.erase("start_link")
		if rod["end"].distance_to(old_pos) <= LinkageModel.SNAP_DISTANCE:
			rod["end"] = new_pos
			rod.erase("end_link")

	for fixed in _model.fixed_points:
		if fixed["position"].distance_to(old_pos) <= LinkageModel.SNAP_DISTANCE:
			fixed["position"] = new_pos

	for marker in _model.marker_points:
		if marker["position"].distance_to(old_pos) <= LinkageModel.SNAP_DISTANCE:
			marker["position"] = new_pos

	for motor in _model.motor_points:
		if motor["position"].distance_to(old_pos) <= LinkageModel.SNAP_DISTANCE:
			motor["position"] = new_pos

	LinkageEditing.sync_points_to_attached_endpoints(_model)


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
				LinkageEditing.delete_marker_point(_model, joint_ref["id"])
			"motor":
				LinkageEditing.delete_motor_point(_model, joint_ref["id"])

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
