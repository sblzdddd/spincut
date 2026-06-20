@tool
extends Path2D
class_name TargetPathOverlay

const SvgPathLoader = preload("res://Scripts/Gameplay/svg_path_loader.gd")

const DEFAULT_PATH := [
	Vector2(300, 520),
	Vector2(620, 520),
	Vector2(620, 700),
	Vector2(300, 700),
	Vector2(300, 520)
]

@export var line_color: Color = Color(0.2, 0.95, 0.3, 0.9)
@export var line_width: float = 3.0
@export var draw_closed: bool = false
@export var bake_interval: float = 8.0:
	set(value):
		bake_interval = maxf(1.0, value)
		if curve != null:
			curve.bake_interval = bake_interval
		queue_redraw()

## 正确答案路径来源：指定 SVG 文件后，取其第一个 <path> 作为目标路径，覆盖默认曲线。
@export_file("*.svg") var svg_file: String = "":
	set(value):
		svg_file = value
		if is_inside_tree():
			load_from_svg()
## 把 SVG 路径包围盒缩放到该尺寸（以节点本地原点为中心）。
@export var svg_fit_size: Vector2 = Vector2(240.0, 240.0)
## SVG 曲线（C/Q/A 等）离散为折线时每段曲线的采样数。
@export var svg_curve_samples: int = 14
## 是否保持 SVG 原始宽高比。
@export var svg_keep_aspect: bool = true


func _ready() -> void:
	_ensure_curve()
	if not svg_file.is_empty():
		load_from_svg()
	queue_redraw()


## 从 svg_file 读取第一个 path，归一化到 svg_fit_size 后作为目标路径。
func load_from_svg() -> bool:
	if svg_file.is_empty():
		return false
	var points := SvgPathLoader.load_first_path_points(svg_file, svg_curve_samples)
	if points.size() < 2:
		push_warning("TargetPathOverlay: SVG 路径点数不足 %s" % svg_file)
		return false
	set_target_path(_fit_points(points, svg_fit_size, svg_keep_aspect))
	return true


## 把点集按包围盒缩放到目标尺寸，并以本地原点为中心。SVG 与 Godot 同为 Y 向下，无需翻转。
func _fit_points(points: PackedVector2Array, target_size: Vector2, keep_aspect: bool) -> PackedVector2Array:
	var min_p := points[0]
	var max_p := points[0]
	for p in points:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var size := max_p - min_p
	if size.x <= 0.0001:
		size.x = 1.0
	if size.y <= 0.0001:
		size.y = 1.0

	var scale_x := target_size.x / size.x
	var scale_y := target_size.y / size.y
	if keep_aspect:
		var uniform := minf(scale_x, scale_y)
		scale_x = uniform
		scale_y = uniform

	var center := (min_p + max_p) * 0.5
	var result := PackedVector2Array()
	for p in points:
		var offset := p - center
		result.append(Vector2(offset.x * scale_x, offset.y * scale_y))
	return result


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_ensure_curve()
		if curve != null and not curve.changed.is_connected(_on_curve_changed):
			curve.changed.connect(_on_curve_changed)
	elif what == NOTIFICATION_EXIT_TREE:
		if curve != null and curve.changed.is_connected(_on_curve_changed):
			curve.changed.disconnect(_on_curve_changed)


func set_target_path(points: PackedVector2Array) -> void:
	_ensure_curve()
	curve.clear_points()
	for point in points:
		curve.add_point(point)
	queue_redraw()


func get_target_path() -> PackedVector2Array:
	_ensure_curve()
	var local_points := curve.get_baked_points()
	if local_points.size() < 2:
		local_points = _curve_points_to_array()

	var world_points := PackedVector2Array()
	for point in local_points:
		world_points.append(to_global(point))
	return world_points


func _draw() -> void:
	_ensure_curve()
	var points := curve.get_baked_points()
	if points.size() < 2:
		points = _curve_points_to_array()
	if points.size() < 2:
		return
	draw_polyline(points, line_color, line_width, true)
	if draw_closed and points[0] != points[points.size() - 1]:
		draw_line(points[points.size() - 1], points[0], line_color, line_width, true)

	if Engine.is_editor_hint():
		for i in range(curve.point_count):
			draw_circle(curve.get_point_position(i), 4.0, Color(1.0, 1.0, 1.0, 0.8))


func _on_curve_changed() -> void:
	queue_redraw()


func _curve_points_to_array() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(curve.point_count):
		points.append(curve.get_point_position(i))
	return points


func _ensure_curve() -> void:
	if curve == null:
		curve = Curve2D.new()
		curve.bake_interval = bake_interval
		for point in DEFAULT_PATH:
			curve.add_point(point)
	elif curve.bake_interval != bake_interval:
		curve.bake_interval = bake_interval
