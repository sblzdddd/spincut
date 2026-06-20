## 连杆机构的只读查询与吸附逻辑：所有方法均为静态，不修改模型
class_name LinkageQueries
extends RefCounted


## 画线吸附：返回带 kind 标签的字典，供 DRAW 工具与预览使用。
## kind 取值：
##   "endpoint"      落在某连杆端点上 -> { position, endpoint:{rod_id,end} }
##   "along"         落在某连杆杆身内部 -> { position, rod_id, t }
##   "motor_anchor"  落在空置的电机锚点上 -> { position }
##   "free"          悬空到任意位置 -> { position }
## require_node=true（起点）时不允许 "free"，杜绝凭空起线造成孤立连杆。
static func find_draw_snap(model: LinkageModel, pos: Vector2, require_node: bool) -> Dictionary:
	var endpoint_snap := find_nearest_rod_endpoint(model, pos)
	if not endpoint_snap.is_empty() and endpoint_open_for_draw(model, endpoint_snap["endpoint"]):
		return {
			"kind": "endpoint",
			"position": endpoint_snap["position"],
			"endpoint": endpoint_snap["endpoint"]
		}

	var along := find_snap_on_rod(model, pos)
	if not along.is_empty() and along_open_for_draw(model, along["rod_id"], along["t"]):
		return {
			"kind": "along",
			"position": along["position"],
			"rod_id": along["rod_id"],
			"t": along["t"]
		}

	for motor in model.motor_points:
		if _motor_open_for_draw(motor) and motor["position"].distance_to(pos) <= LinkageModel.SNAP_DISTANCE:
			return {
				"kind": "motor_anchor",
				"position": motor["position"],
				"motor_id": motor["id"]
			}

	if require_node:
		return {}
	return {"kind": "free", "position": pos}


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


## 投影到各连杆线段，返回杆身内部最近的吸附点（端点附近交由端点吸附处理）
static func find_snap_on_rod(model: LinkageModel, pos: Vector2) -> Dictionary:
	var best_dist := LinkageModel.SNAP_DISTANCE
	var best: Dictionary = {}
	for rod in model.rods:
		var a: Vector2 = rod["start"]
		var b: Vector2 = rod["end"]
		var closest := Geometry2D.get_closest_point_to_segment(pos, a, b)
		var d := closest.distance_to(pos)
		if d > best_dist:
			continue
		if closest.distance_to(a) <= LinkageModel.SNAP_DISTANCE or closest.distance_to(b) <= LinkageModel.SNAP_DISTANCE:
			continue
		var seg_len := a.distance_to(b)
		var t := 0.0 if seg_len <= 0.0 else a.distance_to(closest) / seg_len
		best_dist = d
		best = {"position": closest, "rod_id": rod["id"], "t": t}
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
	for i in range(model.marker_points.size() - 1, -1, -1):
		var marker: Dictionary = model.marker_points[i]
		if marker["position"].distance_to(pos) <= LinkageModel.JOINT_PICK_RADIUS:
			return {"type": "marker", "id": marker["id"]}

	for fixed in model.fixed_points:
		if fixed["position"].distance_to(pos) <= LinkageModel.JOINT_PICK_RADIUS:
			return {"type": "fixed", "id": fixed["id"]}

	for i in range(model.motor_points.size() - 1, -1, -1):
		var motor: Dictionary = model.motor_points[i]
		if motor["position"].distance_to(pos) <= LinkageModel.JOINT_PICK_RADIUS:
			return {"type": "motor", "id": motor["id"]}

	return {}


## 端点是否还能再接一根连杆：
## - 电机锚点只驱动其专属连杆，永不接受新的连接；
## - 其余位置最多两根连杆共点（即一个关节），超过视为冲突。
static func endpoint_open_for_draw(model: LinkageModel, endpoint: Dictionary) -> bool:
	if endpoint_used_by_motor(model, endpoint):
		return false
	var endpoint_pos := model.get_endpoint_position(endpoint)
	return count_members_at_position(model, endpoint_pos) <= 1


## 杆身内部点是否可作为新关节：该点最多两根连杆共点（目标杆自身穿过算一根）
static func along_open_for_draw(model: LinkageModel, rod_id: int, t: float) -> bool:
	var rod := model.get_rod_by_id(rod_id)
	if rod.is_empty():
		return false
	var pos: Vector2 = rod["start"].lerp(rod["end"], t)
	return count_members_at_position(model, pos) <= 1


## 统计某位置已有多少根连杆刚性共点：端点共点计入，杆身内部穿过亦计入
static func count_members_at_position(model: LinkageModel, pos: Vector2) -> int:
	var count := 0
	for rod in model.rods:
		var at_start: bool = rod["start"].distance_to(pos) <= LinkageModel.SNAP_DISTANCE
		var at_end: bool = rod["end"].distance_to(pos) <= LinkageModel.SNAP_DISTANCE
		if at_start:
			count += 1
		if at_end:
			count += 1
		if not at_start and not at_end:
			var closest := Geometry2D.get_closest_point_to_segment(pos, rod["start"], rod["end"])
			if closest.distance_to(pos) <= LinkageModel.SNAP_DISTANCE:
				count += 1
	return count


static func endpoint_used_by_motor(model: LinkageModel, endpoint: Dictionary) -> bool:
	for motor in model.motor_points:
		for other in motor.get("attached", []):
			if other.has("end") and same_endpoint(other, endpoint):
				return true
	return false


## 电机工具吸附：
## - 优先吸附端点；
## - 其次吸附杆身内部点；
## - 最后允许悬空（grounded 电机）。
static func find_motor_snap(model: LinkageModel, pos: Vector2) -> Dictionary:
	var endpoint_snap := find_nearest_rod_endpoint(model, pos)
	if not endpoint_snap.is_empty():
		return {
			"position": endpoint_snap["position"],
			"attachment": endpoint_snap["endpoint"]
		}

	var along := find_snap_on_rod(model, pos)
	if not along.is_empty():
		return {
			"position": along["position"],
			"attachment": {"rod_id": along["rod_id"], "t": along["t"]}
		}

	return {"position": pos}


## 可作为画线起止点的电机锚点：
## - grounded 电机最多连接 1 根连杆（另一侧是地面）；
## - rod 电机最多连接 2 根连杆（替代地面形成杆-杆电机）。
static func _motor_open_for_draw(motor: Dictionary) -> bool:
	var attached: Array = motor.get("attached", [])
	if motor.get("grounded", false):
		return attached.size() < 1
	return attached.size() < 2


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


## 连杆链接锚点（杆身内部点）的世界坐标
static func link_world_position(model: LinkageModel, link: Dictionary) -> Vector2:
	var target := model.get_rod_by_id(link["rod_id"])
	if target.is_empty():
		return Vector2.ZERO
	return target["start"].lerp(target["end"], link["t"])
