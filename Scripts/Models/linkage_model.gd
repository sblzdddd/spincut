## 连杆机构数据模型（纯数据与基础访问）
## 复杂逻辑见 LinkageQueries（只读查询/吸附）与 LinkageEditing（增删改）
class_name LinkageModel
extends RefCounted

const SNAP_DISTANCE := 18.0       # 吸附/覆盖判定距离（像素）
const JOINT_PICK_RADIUS := 14.0   # 点击选中关节的半径
const MIN_ROD_LENGTH := 24.0      # 允许创建的最短连杆长度

var rods: Array = []              # 连杆列表，每项为 { id, start, end, motored }
var fixed_points: Array = []      # 固定点列表
var marker_points: Array = []     # 标记点列表（可多个）
var motor_points: Array = []      # 电机点列表（可多个）

var next_rod_id := 1
var next_fixed_id := 1
var next_marker_id := 1
var next_motor_id := 1


func reset() -> void:
	rods.clear()
	fixed_points.clear()
	marker_points.clear()
	motor_points.clear()
	next_rod_id = 1
	next_fixed_id = 1
	next_marker_id = 1
	next_motor_id = 1


## 初始化默认场景：一根电机驱动的水平连杆
func build_initial_model() -> void:
	reset()
	var motor_rod := {
		"id": next_rod_id,
		"start": Vector2(460, 360),
		"end": Vector2(570, 360),
		"motored": true
	}
	next_rod_id += 1
	rods.append(motor_rod)

	motor_points.append({
		"id": next_motor_id,
		"position": motor_rod["start"],
		"grounded": true,
		"attached": [{"rod_id": motor_rod["id"], "end": 0}]
	})
	next_motor_id += 1


func get_rod_by_id(rod_id: int) -> Dictionary:
	for rod in rods:
		if rod["id"] == rod_id:
			return rod
	return {}


func get_fixed_by_id(fixed_id: int) -> Dictionary:
	for fixed in fixed_points:
		if fixed["id"] == fixed_id:
			return fixed
	return {}


func get_marker_by_id(marker_id: int) -> Dictionary:
	for marker in marker_points:
		if marker["id"] == marker_id:
			return marker
	return {}


func get_motor_by_id(motor_id: int) -> Dictionary:
	for motor in motor_points:
		if motor["id"] == motor_id:
			return motor
	return {}


## endpoint 格式：{ rod_id, end }，end=0 为起点，end=1 为终点
func get_endpoint_position(endpoint: Dictionary) -> Vector2:
	var rod := get_rod_by_id(endpoint["rod_id"])
	if rod.is_empty():
		return Vector2.ZERO
	return rod["start"] if endpoint["end"] == 0 else rod["end"]


## attachment 支持两种格式：
## - 端点：{ rod_id, end }
## - 杆身：{ rod_id, t }，t 为 [0,1] 插值参数
func get_attachment_position(attachment: Dictionary) -> Vector2:
	var rod := get_rod_by_id(attachment.get("rod_id", -1))
	if rod.is_empty():
		return Vector2.ZERO
	if attachment.has("end"):
		return rod["start"] if attachment["end"] == 0 else rod["end"]
	if attachment.has("t"):
		return rod["start"].lerp(rod["end"], clampf(float(attachment["t"]), 0.0, 1.0))
	return Vector2.ZERO


func set_rod_endpoint(endpoint: Dictionary, new_position: Vector2) -> void:
	var rod := get_rod_by_id(endpoint["rod_id"])
	if rod.is_empty():
		return
	if endpoint["end"] == 0:
		rod["start"] = new_position
	else:
		rod["end"] = new_position
