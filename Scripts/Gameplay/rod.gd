## 连杆物理节点：刚体 + 碰撞 + 线段可视化
extends RigidBody2D
class_name Rod

const THICKNESS := 14.0
const MIN_LENGTH := 24.0
const LINE_WIDTH := 8.0

const MOTORED_COLOR := Color(0.9, 0.3, 0.25)  # 电机驱动连杆
const DEFAULT_COLOR := Color(0.2, 0.8, 0.95)  # 普通连杆
const SELECTED_COLOR := Color(1, 1, 1)          # 选中高亮

var rod_id: int


## 根据模型数据生成一根连杆刚体
static func spawn(parent: Node2D, rod_data: Dictionary, selected: bool) -> Rod:
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
	var base_color := MOTORED_COLOR if rod_data["motored"] else DEFAULT_COLOR
	line.default_color = SELECTED_COLOR if selected else base_color
	body.add_child(line)

	return body
