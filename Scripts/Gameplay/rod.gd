## 连杆物理节点：刚体 + 碰撞 + 线段可视化
extends RigidBody2D
class_name Rod

const THICKNESS := 14.0
const MIN_LENGTH := 24.0
const LINE_WIDTH := 8.0

const MOTORED_COLOR := Color(0.9, 0.3, 0.25)  # 电机驱动连杆
const SELECTED_COLOR := Color(1, 1, 1)          # 选中高亮

## 普通连杆调色板：按连杆 id 取色，使每根新画的连杆颜色不同，便于区分
const ROD_PALETTE := [
	Color(0.2, 0.8, 0.95),   # 青
	Color(0.45, 0.9, 0.45),  # 绿
	Color(0.95, 0.8, 0.3),   # 黄
	Color(0.7, 0.5, 0.95),   # 紫
	Color(0.95, 0.55, 0.3),  # 橙
	Color(0.45, 0.65, 0.95), # 蓝
	Color(0.95, 0.45, 0.65), # 粉
	Color(0.4, 0.9, 0.8),    # 蓝绿
]

var rod_id: int

## 暂停时缓存的运动状态，用于恢复时保留动量/惯性
var saved_linear_velocity := Vector2.ZERO
var saved_angular_velocity := 0.0


## 根据模型数据生成一根连杆刚体；frozen=true 时锁定为静态（编辑模式不参与物理）
static func spawn(parent: Node2D, rod_data: Dictionary, selected: bool, frozen := true) -> Rod:
	var start_pos: Vector2 = rod_data["start"]
	var end_pos: Vector2 = rod_data["end"]
	var center := (start_pos + end_pos) * 0.5
	var length: float = maxf(start_pos.distance_to(end_pos), MIN_LENGTH)

	var body := Rod.new()
	body.rod_id = rod_data["id"]
	body.name = "Rod_%s" % rod_data["id"]
	body.position = center
	body.rotation = (end_pos - start_pos).angle()
	body.mass = 0.015
	body.linear_damp = 0.05
	body.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	body.freeze = frozen
	# 理想连杆机构：连杆之间互不碰撞（仅靠销钉约束），避免交叉的连杆互相挤压导致机构卡死
	body.collision_layer = 0
	body.collision_mask = 0
	parent.add_child(body)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length, THICKNESS)
	collision.shape = shape
	body.add_child(collision)

	var line := Line2D.new()
	line.width = LINE_WIDTH
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.points = PackedVector2Array([Vector2(-length * 0.5, 0), Vector2(length * 0.5, 0)])
	var base_color := MOTORED_COLOR if rod_data["motored"] else _color_for_id(rod_data["id"])
	line.default_color = SELECTED_COLOR if selected else base_color
	body.add_child(line)

	return body


## 按连杆 id 在调色板中循环取色，保证同一根连杆每次重建颜色一致
static func _color_for_id(id: int) -> Color:
	return ROD_PALETTE[(id - 1) % ROD_PALETTE.size()]
