## 销钉关节：连接连杆与地面，或连杆与连杆
class_name LinkagePinJoint
extends RefCounted

const MERGE_DISTANCE := 6.0  # 端点聚类合并距离
const SOFTNESS := 0.16
const MOTOR_SPEED := 3.0      # 播放时电机角速度（弧度/秒）


## 将电机点/固定点通过销钉连接到地面；motors_active=true（播放模式）时启用电机驱动
static func spawn_ground_joints(
	parent: Node2D,
	ground: StaticBody2D,
	body_by_rod_id: Dictionary,
	model: LinkageModel,
	motors_active := false
) -> void:
	if not model.motor_point.is_empty():
		var attached: Array = model.motor_point.get("attached", [])
		for endpoint in attached:
			var rod_id: int = endpoint["rod_id"]
			if not body_by_rod_id.has(rod_id):
				continue
			create(parent, model.motor_point["position"], ground, body_by_rod_id[rod_id], true, motors_active)

	for fixed in model.fixed_points:
		var attached: Array = fixed.get("attached", [])
		for endpoint in attached:
			var rod_id: int = endpoint["rod_id"]
			if not body_by_rod_id.has(rod_id):
				continue
			create(parent, fixed["position"], ground, body_by_rod_id[rod_id], false)


## 将彼此靠近的连杆端点通过销钉互连
static func spawn_rod_to_rod_joints(parent: Node2D, body_by_rod_id: Dictionary, rods: Array) -> void:
	var clusters: Array = []
	for rod in rods:
		for end_idx in [0, 1]:
			var endpoint := {
				"rod_id": rod["id"],
				"position": rod["start"] if end_idx == 0 else rod["end"]
			}
			var found_cluster := false
			for cluster in clusters:
				if cluster["position"].distance_to(endpoint["position"]) <= MERGE_DISTANCE:
					cluster["members"].append(endpoint)
					found_cluster = true
					break
			if not found_cluster:
				clusters.append({
					"position": endpoint["position"],
					"members": [endpoint]
				})

	for cluster in clusters:
		var members: Array = cluster["members"]
		if members.size() < 2:
			continue

		var anchor_rod_id: int = members[0]["rod_id"]
		if not body_by_rod_id.has(anchor_rod_id):
			continue
		var anchor_body: RigidBody2D = body_by_rod_id[anchor_rod_id]

		for i in range(1, members.size()):
			var other_rod_id: int = members[i]["rod_id"]
			if other_rod_id == anchor_rod_id:
				continue
			if not body_by_rod_id.has(other_rod_id):
				continue
			create(parent, cluster["position"], anchor_body, body_by_rod_id[other_rod_id], false)


## 将带 start_link/end_link 的连杆端点，钉到其目标连杆的杆身内部点
static func spawn_link_joints(parent: Node2D, body_by_rod_id: Dictionary, rods: Array) -> void:
	for rod in rods:
		for key in ["start_link", "end_link"]:
			if not rod.has(key):
				continue
			var target_id: int = rod[key]["rod_id"]
			if not body_by_rod_id.has(rod["id"]) or not body_by_rod_id.has(target_id):
				continue
			var pos: Vector2 = rod["start"] if key == "start_link" else rod["end"]
			create(parent, pos, body_by_rod_id[target_id], body_by_rod_id[rod["id"]], false)


static func create(
	parent: Node2D,
	at_position: Vector2,
	body_a: PhysicsBody2D,
	body_b: PhysicsBody2D,
	motor: bool,
	motor_active := false
) -> PinJoint2D:
	var joint := PinJoint2D.new()
	joint.position = at_position
	parent.add_child(joint)
	joint.node_a = joint.get_path_to(body_a)
	joint.node_b = joint.get_path_to(body_b)
	joint.softness = SOFTNESS
	var drive := motor and motor_active
	joint.motor_enabled = drive
	joint.motor_target_velocity = MOTOR_SPEED if drive else 0.0
	return joint
