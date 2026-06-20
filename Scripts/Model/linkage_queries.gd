## 连杆机构的只读查询与吸附逻辑：所有方法均为静态，不修改模型
class_name LinkageQueries
extends RefCounted


## 画线工具的吸附点：
## - require_node=true（起点）：必须落在仍可连接的已有端点上，杜绝凭空起线造成孤立连杆；
## - require_node=false（终点）：优先吸附到可连接端点，否则允许悬空到任意位置以生长出新连杆。
static func find_line_snap(model: LinkageModel, pos: Vector2, require_node: bool) -> Dictionary:
	var endpoint_snap := find_nearest_rod_endpoint(model, pos)
	if not endpoint_snap.is_empty() and endpoint_open_for_draw(model, endpoint_snap["endpoint"]):
		return endpoint_snap
	if require_node:
		return {}
	return {"position": pos}


## 查找距鼠标最近的连杆端点
static func find_nearest_rod_endpoint(model: LinkageModel, pos: Vector2) -> Dictionary:
	var best_dist := LinkageModel.SNAP_DISTANCE
	var best: Dictionary = {}
	for rod in model.rods:
		for end_idx in [0, 1]:
			var endpoint_pos: Vector2 = rod["start"] if end_idx == 0 else rod["end"]
			var d := endpoint_pos.distance_to(pos)
			if d <= best_dist:
				best_dist = d
				best = {
					"position": endpoint_pos,
					"endpoint": {"rod_id": rod["id"], "end": end_idx}
				}
	return best


## 点击检测：返回命中的连杆 id，未命中返回 -1
static func pick_rod(model: LinkageModel, pos: Vector2) -> int:
	for i in range(model.rods.size() - 1, -1, -1):
		var rod: Dictionary = model.rods[i]
		var closest := Geometry2D.get_closest_point_to_segment(pos, rod["start"], rod["end"])
		if closest.distance_to(pos) <= 10.0:
			return rod["id"]
	return -1


## 点击检测：返回命中的关节 { type, id }
static func pick_joint(model: LinkageModel, pos: Vector2) -> Dictionary:
	if not model.marker_point.is_empty() and model.marker_point["position"].distance_to(pos) <= LinkageModel.JOINT_PICK_RADIUS:
		return {"type": "marker", "id": 1}

	for fixed in model.fixed_points:
		if fixed["position"].distance_to(pos) <= LinkageModel.JOINT_PICK_RADIUS:
			return {"type": "fixed", "id": fixed["id"]}

	if not model.motor_point.is_empty() and model.motor_point["position"].distance_to(pos) <= LinkageModel.JOINT_PICK_RADIUS:
		return {"type": "motor", "id": 1}

	return {}


## 端点是否还能再连一根连杆：
## - 电机锚点只驱动其专属连杆，永不接受新的连接；
## - 普通关节同位置最多连接两根连杆（即一个关节），超过视为冲突。
static func endpoint_open_for_draw(model: LinkageModel, endpoint: Dictionary) -> bool:
	if endpoint_used_by_motor(model, endpoint):
		return false
	var endpoint_pos := model.get_endpoint_position(endpoint)
	return count_endpoints_at_position(model, endpoint_pos) <= 1


static func count_endpoints_at_position(model: LinkageModel, pos: Vector2) -> int:
	var count := 0
	for rod in model.rods:
		if rod["start"].distance_to(pos) <= LinkageModel.SNAP_DISTANCE:
			count += 1
		if rod["end"].distance_to(pos) <= LinkageModel.SNAP_DISTANCE:
			count += 1
	return count


static func endpoint_used_by_motor(model: LinkageModel, endpoint: Dictionary) -> bool:
	if model.motor_point.is_empty():
		return false
	for other in model.motor_point.get("attached", []):
		if same_endpoint(other, endpoint):
			return true
	return false


static func endpoint_used_by_fixed(model: LinkageModel, endpoint: Dictionary) -> bool:
	return not find_fixed_by_endpoint(model, endpoint).is_empty()


static func find_fixed_by_endpoint(model: LinkageModel, endpoint: Dictionary) -> Dictionary:
	for fixed in model.fixed_points:
		for other in fixed.get("attached", []):
			if same_endpoint(other, endpoint):
				return fixed
	return {}


static func same_endpoint(a: Dictionary, b: Dictionary) -> bool:
	return a["rod_id"] == b["rod_id"] and a["end"] == b["end"]
