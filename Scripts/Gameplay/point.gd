## 特殊点可视化：电机 / 固定 / 标记
extends ColorRect
class_name LinkagePoint

enum Kind {
	MOTOR,  # 电机锚点
	FIXED,  # 固定点
	MARKER  # 标记点
}

const SIZE := Vector2(12, 12)

const MOTOR_COLOR := Color(1.0, 0.9, 0.2)
const FIXED_COLOR := Color(0.7, 0.7, 0.7)
const MARKER_COLOR := Color(0.85, 0.2, 0.85)
const SELECTED_COLOR := Color(1, 1, 1)

var kind: Kind


static func spawn(
	parent: Node2D,
	point_kind: Kind,
	world_pos: Vector2,
	name_text: String,
	selected: bool
) -> LinkagePoint:
	var point := LinkagePoint.new()
	point.kind = point_kind
	point.name = name_text
	point.size = SIZE
	point.position = world_pos - SIZE * 0.5
	# 纯可视化节点，不能拦截鼠标，否则点击会被它吞掉而到不了编辑器输入处理
	point.mouse_filter = Control.MOUSE_FILTER_IGNORE
	point.color = SELECTED_COLOR if selected else _color_for_kind(point_kind)
	parent.add_child(point)
	return point


static func _color_for_kind(point_kind: Kind) -> Color:
	match point_kind:
		Kind.MOTOR:
			return MOTOR_COLOR
		Kind.FIXED:
			return FIXED_COLOR
		Kind.MARKER:
			return MARKER_COLOR
	return FIXED_COLOR
