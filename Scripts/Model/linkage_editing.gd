## 连杆机构的编辑操作：创建/放置/删除/同步，所有方法均为静态并直接修改模型
class_name LinkageEditing
extends RefCounted


## 依据起点/终点的吸附结果创建连杆：
## - kind=="along" 的一端记录 start_link/end_link，钉到目标连杆杆身内部点；
## - kind=="motor_anchor" 的一端绑定电机锚点并标记该连杆为电机驱动。
static func create_rod_from_snaps(model: LinkageModel, start_snap: Dictionary, end_snap: Dictionary) -> bool:
	var start_pos: Vector2 = start_snap["position"]
	var end_pos: Vector2 = end_snap["position"]
	if start_pos.distance_to(end_pos) < LinkageModel.MIN_ROD_LENGTH:
		return false

	var motored: bool = start_snap.get("kind", "") == "motor_anchor" or end_snap.get("kind", "") == "motor_anchor"
	var rod := {
		"id": model.next_rod_id,
		"start": start_pos,
		"end": end_pos,
		"motored": motored
	}
	if start_snap.get("kind", "") == "along":
		rod["start_link"] = {"rod_id": start_snap["rod_id"], "t": start_snap["t"]}
	if end_snap.get("kind", "") == "along":
		rod["end_link"] = {"rod_id": end_snap["rod_id"], "t": end_snap["t"]}

	var rod_id: int = model.next_rod_id
	model.next_rod_id += 1
	model.rods.append(rod)

	if start_snap.get("kind", "") == "motor_anchor":
		_attach_motor(model, rod_id, 0, start_pos)
	if end_snap.get("kind", "") == "motor_anchor":
		_attach_motor(model, rod_id, 1, end_pos)
	return true


static func _attach_motor(model: LinkageModel, rod_id: int, end_idx: int, pos: Vector2) -> void:
	if model.motor_point.is_empty():
		model.motor_point = {"id": 1, "position": pos, "attached": []}
	model.motor_point["position"] = pos
	model.motor_point["attached"] = [{"rod_id": rod_id, "end": end_idx}]


## 在连杆端点放置固定点；同位置已有其他点会被覆盖
static func place_fixed_point(model: LinkageModel, mouse_pos: Vector2) -> bool:
	var snap := LinkageQueries.find_nearest_rod_endpoint(model, mouse_pos)
	if snap.is_empty():
		return false

	var endpoint: Dictionary = snap["endpoint"]
	if LinkageQueries.endpoint_used_by_motor(model, endpoint):
		return false

	_clear_points_at_position(model, snap["position"])

	var fixed := {
		"id": model.next_fixed_id,
		"position": snap["position"],
		"attached": [endpoint]
	}
	model.next_fixed_id += 1
	model.fixed_points.append(fixed)
	model.set_rod_endpoint(endpoint, snap["position"])
	return true


## 在连杆端点放置标记点；全局仅保留一个，且会覆盖同位置其他点
static func place_marker_point(model: LinkageModel, mouse_pos: Vector2) -> bool:
	var snap := LinkageQueries.find_nearest_rod_endpoint(model, mouse_pos)
	if snap.is_empty():
		return false

	var endpoint: Dictionary = snap["endpoint"]
	if LinkageQueries.endpoint_used_by_motor(model, endpoint):
		return false

	_clear_points_at_position(model, snap["position"])

	model.marker_point = {
		"id": 1,
		"position": snap["position"],
		"attached": [endpoint]
	}
	model.set_rod_endpoint(endpoint, model.marker_point["position"])
	return true


## 先把杆身链接端点的位置从目标连杆重算（多趟以处理链式依赖），再同步各特殊点
static func sync_points_to_attached_endpoints(model: LinkageModel) -> void:
	sync_links(model)

	if not model.motor_point.is_empty():
		var motor_attached: Array = model.motor_point.get("attached", [])
		if not motor_attached.is_empty():
			model.motor_point["position"] = model.get_endpoint_position(motor_attached[0])

	for fixed in model.fixed_points:
		var attached: Array = fixed.get("attached", [])
		if not attached.is_empty():
			fixed["position"] = model.get_endpoint_position(attached[0])

	if not model.marker_point.is_empty():
		var marker_attached: Array = model.marker_point.get("attached", [])
		if not marker_attached.is_empty():
			model.marker_point["position"] = model.get_endpoint_position(marker_attached[0])


## 移动特殊点时，同步更新其绑定的所有连杆端点坐标
static func set_attached_endpoints(model: LinkageModel, point_data: Dictionary) -> void:
	for endpoint in point_data.get("attached", []):
		model.set_rod_endpoint(endpoint, point_data["position"])


## 把所有带 start_link/end_link 的连杆端点重算到目标连杆杆身内部点。
## 多趟迭代以处理链式依赖（A 钉在 B 上、B 钉在 C 上）。
static func sync_links(model: LinkageModel) -> void:
	for _pass in range(model.rods.size()):
		for rod in model.rods:
			if rod.has("start_link"):
				rod["start"] = LinkageQueries.link_world_position(model, rod["start_link"])
			if rod.has("end_link"):
				rod["end"] = LinkageQueries.link_world_position(model, rod["end_link"])


static func delete_rod(model: LinkageModel, rod_id: int) -> void:
	var new_rods: Array = []
	for rod in model.rods:
		if rod["id"] != rod_id:
			new_rods.append(rod)
	model.rods = new_rods

	# 删除指向该连杆的杆身链接，避免悬空引用
	for rod in model.rods:
		if rod.has("start_link") and rod["start_link"]["rod_id"] == rod_id:
			rod.erase("start_link")
		if rod.has("end_link") and rod["end_link"]["rod_id"] == rod_id:
			rod.erase("end_link")

	_remove_endpoint_from_point(model.motor_point, rod_id)
	for fixed in model.fixed_points:
		_remove_endpoint_from_point(fixed, rod_id)
	if not model.marker_point.is_empty():
		_remove_endpoint_from_point(model.marker_point, rod_id)


static func delete_fixed_point(model: LinkageModel, fixed_id: int) -> void:
	var kept: Array = []
	for fixed in model.fixed_points:
		if fixed["id"] != fixed_id:
			kept.append(fixed)
	model.fixed_points = kept


static func clear_marker(model: LinkageModel) -> void:
	model.marker_point.clear()


## 清理失去绑定的孤立固定点/标记点。
## 电机点不再自动回退到某根连杆：失去连杆后保留为空置锚点（停在原位），可再次从其画线。
static func cleanup_orphan_points(model: LinkageModel) -> void:
	var kept_fixed: Array = []
	for fixed in model.fixed_points:
		if not fixed.get("attached", []).is_empty():
			kept_fixed.append(fixed)
	model.fixed_points = kept_fixed

	if not model.marker_point.is_empty() and model.marker_point.get("attached", []).is_empty():
		model.marker_point.clear()


static func _remove_endpoint_from_point(point_data: Dictionary, rod_id: int) -> void:
	if point_data.is_empty():
		return
	var kept: Array = []
	for endpoint in point_data.get("attached", []):
		if endpoint["rod_id"] != rod_id:
			kept.append(endpoint)
	point_data["attached"] = kept


## 清除指定位置附近的固定点/标记点，供新点覆盖旧点
static func _clear_points_at_position(model: LinkageModel, pos: Vector2) -> void:
	var kept_fixed: Array = []
	for fixed in model.fixed_points:
		if fixed["position"].distance_to(pos) > LinkageModel.SNAP_DISTANCE:
			kept_fixed.append(fixed)
	model.fixed_points = kept_fixed

	if not model.marker_point.is_empty() and model.marker_point["position"].distance_to(pos) <= LinkageModel.SNAP_DISTANCE:
		model.marker_point.clear()
