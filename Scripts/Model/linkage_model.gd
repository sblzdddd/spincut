## 连杆机构数据模型（纯数据与基础访问）
## 复杂逻辑见 LinkageQueries（只读查询/吸附）与 LinkageEditing（增删改）
class_name LinkageModel
extends RefCounted

const SNAP_DISTANCE := 18.0       # 吸附/覆盖判定距离（像素）
const JOINT_PICK_RADIUS := 14.0   # 点击选中关节的半径
const MIN_ROD_LENGTH := 24.0      # 允许创建的最短连杆长度

var rods: Array = []              # 连杆列表，每项为 { id, start, end, motored }
var fixed_points: Array = []      # 固定点列表
var marker_point: Dictionary = {} # 标记点（全局唯一）
var motor_point: Dictionary = {}  # 电机锚点

var next_rod_id := 1
var next_fixed_id := 1


func reset() -> void:
	rods.clear()
	fixed_points.clear()
	marker_point.clear()
	motor_point.clear()
	next_rod_id = 1
	next_fixed_id = 1


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

	motor_point = {
		"id": 1,
		"position": motor_rod["start"],
		"attached": [{"rod_id": motor_rod["id"], "end": 0}]
	}


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


## endpoint 格式：{ rod_id, end }，end=0 为起点，end=1 为终点
func get_endpoint_position(endpoint: Dictionary) -> Vector2:
	var rod := get_rod_by_id(endpoint["rod_id"])
	if rod.is_empty():
		return Vector2.ZERO
	return rod["start"] if endpoint["end"] == 0 else rod["end"]


func set_rod_endpoint(endpoint: Dictionary, new_position: Vector2) -> void:
	var rod := get_rod_by_id(endpoint["rod_id"])
	if rod.is_empty():
		return
	if endpoint["end"] == 0:
		rod["start"] = new_position
	else:
		rod["end"] = new_position
