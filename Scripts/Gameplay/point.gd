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

## 播放模式下跟随的刚体及其在刚体局部坐标系中的偏移；为空则保持静态
var follow_body: RigidBody2D = null
var follow_offset := Vector2.ZERO


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


## 绑定一个刚体，记录当前世界位置在该刚体局部坐标系中的偏移，供播放时跟随
func attach_follow(body: RigidBody2D, world_pos: Vector2) -> void:
	follow_body = body
	follow_offset = body.to_local(world_pos)


## 播放时根据所跟随刚体的最新变换更新自身位置（不改动数据模型，便于停止后回退）
func update_follow() -> void:
	if follow_body == null:
		return
	var world := follow_body.global_position + follow_offset.rotated(follow_body.global_rotation)
	global_position = world - SIZE * 0.5


static func _color_for_kind(point_kind: Kind) -> Color:
	match point_kind:
		Kind.MOTOR:
			return MOTOR_COLOR
		Kind.FIXED:
			return FIXED_COLOR
		Kind.MARKER:
			return MARKER_COLOR
	return FIXED_COLOR
