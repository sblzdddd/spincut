## 编辑器预览绘制：在 CanvasItem 上绘制操作提示
class_name EditorPreview
extends RefCounted

const Tool = preload("res://Scripts/Editor/editor_enums.gd").Tool


static func draw(
	canvas: CanvasItem,
	tool: Tool,
	mouse_world: Vector2,
	model: LinkageModel
) -> void:
	match tool:
		Tool.DRAW_LINE:
			_draw_line_tool_preview(canvas, mouse_world, model)
		Tool.FIXED_POINT:
			_draw_point_tool_preview(canvas, Tool.FIXED_POINT, mouse_world, model)
		Tool.MARKER_POINT:
			_draw_point_tool_preview(canvas, Tool.MARKER_POINT, mouse_world, model)
		Tool.MOTOR_POINT:
			_draw_motor_tool_preview(canvas, mouse_world, model)
		Tool.SELECT:
			if EditorStates.is_box_selecting:
				_draw_box_select(canvas)
			_draw_rod_handles(canvas, model)


static func _draw_box_select(canvas: CanvasItem) -> void:
	var rect := Rect2(EditorStates.box_start, EditorStates.box_end - EditorStates.box_start).abs()
	canvas.draw_rect(rect, EditorConstants.BOX_SELECT_FILL, true)
	canvas.draw_rect(rect, EditorConstants.BOX_SELECT_STROKE, false, 1.5)


static func _draw_line_tool_preview(canvas: CanvasItem, mouse_world: Vector2, model: LinkageModel) -> void:
	if not EditorStates.is_drawing:
		# 尚未开始画线：仅显示起点吸附提示（起点必须落在已有节点/杆身/空电机锚点上）
		var start_snap := LinkageQueries.find_draw_snap(model, mouse_world, true)
		if start_snap.is_empty():
			_draw_preview_dot(canvas, mouse_world, EditorConstants.LINE_PREVIEW_COLOR, EditorConstants.INVALID_ALPHA)
			return
		_draw_preview_dot(canvas, start_snap["position"], _snap_color(start_snap), EditorConstants.PREVIEW_ALPHA)
		return

	# 已确定起点：显示起点到终点的预览线段（终点可吸附端点/杆身/锚点，也可悬空）
	var end_snap := LinkageQueries.find_draw_snap(model, mouse_world, false)
	var end_pos: Vector2 = end_snap["position"]
	var end_valid := end_pos.distance_to(EditorStates.draw_start) >= LinkageModel.MIN_ROD_LENGTH
	var end_alpha := EditorConstants.PREVIEW_ALPHA if end_valid else EditorConstants.INVALID_ALPHA
	var end_color := _snap_color(end_snap) if end_valid else EditorConstants.INVALID_PLACE_COLOR

	_draw_preview_dot(canvas, EditorStates.draw_start, EditorConstants.LINE_START_COLOR, EditorConstants.PREVIEW_ALPHA)
	_draw_preview_dot(canvas, end_pos, end_color, end_alpha)
	canvas.draw_line(
		EditorStates.draw_start,
		end_pos,
		Color(end_color, end_alpha),
		3.0
	)


## 不同吸附类型的提示颜色
static func _snap_color(snap: Dictionary) -> Color:
	match snap.get("kind", ""):
		"along":
			return EditorConstants.ALONG_SNAP_COLOR
		"motor_anchor":
			return EditorConstants.MOTOR_ANCHOR_COLOR
		_:
			return EditorConstants.LINE_PREVIEW_COLOR


## 为选中的连杆绘制两个端点手柄
static func _draw_rod_handles(canvas: CanvasItem, model: LinkageModel) -> void:
	for rod_id in EditorStates.selected_rods:
		var rod := model.get_rod_by_id(rod_id)
		if rod.is_empty():
			continue
		_draw_handle_dot(canvas, rod["start"])
		_draw_handle_dot(canvas, rod["end"])


static func _draw_handle_dot(canvas: CanvasItem, pos: Vector2) -> void:
	var fill := Color(
		EditorConstants.HANDLE_COLOR.r,
		EditorConstants.HANDLE_COLOR.g,
		EditorConstants.HANDLE_COLOR.b,
		EditorConstants.HANDLE_ALPHA
	)
	canvas.draw_circle(pos, EditorConstants.HANDLE_RADIUS, fill)
	canvas.draw_arc(pos, EditorConstants.HANDLE_RADIUS + 1.0, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 1.5)


static func _draw_point_tool_preview(
	canvas: CanvasItem,
	tool: Tool,
	mouse_world: Vector2,
	model: LinkageModel
) -> void:
	var snap := LinkageQueries.find_nearest_rod_endpoint(model, mouse_world)
	var base_color := (
		EditorConstants.FIXED_POINT_COLOR
		if tool == Tool.FIXED_POINT
		else EditorConstants.MARKER_POINT_COLOR
	)

	if snap.is_empty():
		_draw_preview_dot(canvas, mouse_world, base_color, EditorConstants.INVALID_ALPHA)
		return

	var endpoint: Dictionary = snap["endpoint"]
	var can_place := _can_place_on_endpoint(tool, endpoint, model)
	var color := base_color if can_place else EditorConstants.INVALID_PLACE_COLOR
	var alpha := EditorConstants.PREVIEW_ALPHA if can_place else EditorConstants.INVALID_ALPHA
	_draw_preview_dot(canvas, snap["position"], color, alpha)


static func _draw_motor_tool_preview(
	canvas: CanvasItem,
	mouse_world: Vector2,
	model: LinkageModel
) -> void:
	var snap := LinkageQueries.find_motor_snap(model, mouse_world)
	var has_attachment := snap.has("attachment")
	var color := EditorConstants.MOTOR_ANCHOR_COLOR if has_attachment else EditorConstants.FLOATING_MOTOR_COLOR
	_draw_preview_dot(canvas, snap["position"], color, EditorConstants.PREVIEW_ALPHA)


## 电机端点不可放置新的固定点/标记点
static func _can_place_on_endpoint(_tool: Tool, endpoint: Dictionary, model: LinkageModel) -> bool:
	return not LinkageQueries.endpoint_used_by_motor(model, endpoint)


static func _draw_preview_dot(canvas: CanvasItem, pos: Vector2, color: Color, alpha: float) -> void:
	var fill := Color(color.r, color.g, color.b, alpha)
	var stroke := Color(1.0, 1.0, 1.0, clampf(alpha + 0.2, 0.0, 1.0))
	canvas.draw_circle(pos, EditorConstants.PREVIEW_RADIUS, fill)
	canvas.draw_arc(pos, EditorConstants.PREVIEW_RADIUS + 1.0, 0.0, TAU, 24, stroke, 1.0)
