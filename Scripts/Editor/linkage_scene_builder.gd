## 根据数据模型重建物理场景（连杆、关节、特殊点可视化）
class_name LinkageSceneBuilder
extends RefCounted


## playing=true（播放模式）时：连杆解除冻结、电机启用，特殊点绑定刚体以跟随运动
func rebuild(editor_objects: Node2D, ground: StaticBody2D, model: LinkageModel, playing := false) -> void:
	for child in editor_objects.get_children():
		child.queue_free()

	var body_by_rod_id := {}
	for rod in model.rods:
		var body := Rod.spawn(editor_objects, rod, EditorStates.selected_rods.has(rod["id"]), not playing)
		body_by_rod_id[rod["id"]] = body

	LinkagePinJoint.spawn_ground_joints(editor_objects, ground, body_by_rod_id, model, playing)
	LinkagePinJoint.spawn_rod_to_rod_joints(editor_objects, body_by_rod_id, model.rods)
	LinkagePinJoint.spawn_link_joints(editor_objects, body_by_rod_id, model.rods)
	_spawn_point_visuals(editor_objects, model, body_by_rod_id, playing)


func _spawn_point_visuals(
	editor_objects: Node2D,
	model: LinkageModel,
	body_by_rod_id: Dictionary,
	playing: bool
) -> void:
	if not model.motor_point.is_empty():
		var motor_point := LinkagePoint.spawn(
			editor_objects,
			LinkagePoint.Kind.MOTOR,
			model.motor_point["position"],
			"MotorPoint",
			_is_joint_selected({"type": "motor", "id": 1})
		)
		if playing:
			_bind_follow(motor_point, model.motor_point, body_by_rod_id)

	for fixed in model.fixed_points:
		var fixed_point := LinkagePoint.spawn(
			editor_objects,
			LinkagePoint.Kind.FIXED,
			fixed["position"],
			"Fixed_%s" % fixed["id"],
			_is_joint_selected({"type": "fixed", "id": fixed["id"]})
		)
		if playing:
			_bind_follow(fixed_point, fixed, body_by_rod_id)

	if not model.marker_point.is_empty():
		var marker_point := LinkagePoint.spawn(
			editor_objects,
			LinkagePoint.Kind.MARKER,
			model.marker_point["position"],
			"MarkerPoint",
			_is_joint_selected({"type": "marker", "id": 1})
		)
		if playing:
			_bind_follow(marker_point, model.marker_point, body_by_rod_id)


## 将特殊点绑定到其首个附着端点所属的连杆刚体，使其在播放时跟随运动
func _bind_follow(point: LinkagePoint, point_data: Dictionary, body_by_rod_id: Dictionary) -> void:
	var attached: Array = point_data.get("attached", [])
	if attached.is_empty():
		return
	var rod_id: int = attached[0]["rod_id"]
	if not body_by_rod_id.has(rod_id):
		return
	point.attach_follow(body_by_rod_id[rod_id], point_data["position"])


func _is_joint_selected(joint_ref: Dictionary) -> bool:
	for selected in EditorStates.selected_joints:
		if selected["type"] == joint_ref["type"] and selected["id"] == joint_ref["id"]:
			return true
	return false
