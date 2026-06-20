## 根据数据模型重建物理场景（连杆、关节、特殊点可视化）
class_name LinkageSceneBuilder
extends RefCounted


func rebuild(editor_objects: Node2D, ground: StaticBody2D, model: LinkageModel) -> void:
	for child in editor_objects.get_children():
		child.queue_free()

	var body_by_rod_id := {}
	for rod in model.rods:
		var body := Rod.spawn(editor_objects, rod, EditorStates.selected_rods.has(rod["id"]))
		body_by_rod_id[rod["id"]] = body

	LinkagePinJoint.spawn_ground_joints(editor_objects, ground, body_by_rod_id, model)
	LinkagePinJoint.spawn_rod_to_rod_joints(editor_objects, body_by_rod_id, model.rods)
	_spawn_point_visuals(editor_objects, model)


func _spawn_point_visuals(editor_objects: Node2D, model: LinkageModel) -> void:
	if not model.motor_point.is_empty():
		LinkagePoint.spawn(
			editor_objects,
			LinkagePoint.Kind.MOTOR,
			model.motor_point["position"],
			"MotorPoint",
			_is_joint_selected({"type": "motor", "id": 1})
		)

	for fixed in model.fixed_points:
		LinkagePoint.spawn(
			editor_objects,
			LinkagePoint.Kind.FIXED,
			fixed["position"],
			"Fixed_%s" % fixed["id"],
			_is_joint_selected({"type": "fixed", "id": fixed["id"]})
		)

	if not model.marker_point.is_empty():
		LinkagePoint.spawn(
			editor_objects,
			LinkagePoint.Kind.MARKER,
			model.marker_point["position"],
			"MarkerPoint",
			_is_joint_selected({"type": "marker", "id": 1})
		)


func _is_joint_selected(joint_ref: Dictionary) -> bool:
	for selected in EditorStates.selected_joints:
		if selected["type"] == joint_ref["type"] and selected["id"] == joint_ref["id"]:
			return true
	return false
