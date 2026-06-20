extends Node2D
class_name CutTarget

@export var cut_thickness: float = 4.0
@export var min_segment_length: float = 3.0
@export var initial_size: Vector2 = Vector2(260.0, 140.0)
@export var base_color: Color = Color(1.0, 1.0, 1.0, 1.0)

var _fragments: Array[Polygon2D] = []
var _checker_texture: Texture2D
## 关卡配置的展示贴图。设置后用它填充被切割的目标，未设置时回退到棋盘格占位纹理。
var _target_texture: Texture2D


func _ready() -> void:
	_checker_texture = _build_checker_texture()
	reset_target()


## 由主场景在应用关卡时调用：用关卡精灵图作为目标贴图，并按需调整目标尺寸（已按比例适配）。
func set_target_texture(texture: Texture2D, display_size: Vector2 = Vector2.ZERO) -> void:
	_target_texture = texture
	if display_size.x > 0.0 and display_size.y > 0.0:
		initial_size = display_size
	reset_target()


func reset_target() -> void:
	for fragment in _fragments:
		if is_instance_valid(fragment):
			fragment.queue_free()
	_fragments.clear()

	var half := initial_size * 0.5
	var rect := PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])
	_add_fragment(rect)


func cut_by_path(global_path_points: PackedVector2Array) -> void:
	if global_path_points.size() < 2:
		return

	var local_path := PackedVector2Array()
	for point in global_path_points:
		local_path.append(to_local(point))
	if local_path.size() < 2:
		return

	var start := local_path[local_path.size() - 2]
	var ending := local_path[local_path.size() - 1]
	if start.distance_to(ending) < min_segment_length:
		return

	var segment := PackedVector2Array([start, ending])
	var cutter_polygons := Geometry2D.offset_polyline(segment, cut_thickness)
	if cutter_polygons.is_empty():
		return

	var cutter: PackedVector2Array = cutter_polygons[0]
	if cutter.size() < 3:
		return

	var new_fragments: Array[PackedVector2Array] = []
	for fragment in _fragments:
		if not is_instance_valid(fragment):
			continue
		var remaining := Geometry2D.clip_polygons(fragment.polygon, cutter)
		if remaining.is_empty():
			continue
		for piece in remaining:
			if piece.size() >= 3:
				new_fragments.append(piece)

	if new_fragments.is_empty():
		return

	for fragment in _fragments:
		if is_instance_valid(fragment):
			fragment.queue_free()
	_fragments.clear()

	for piece in new_fragments:
		_add_fragment(piece)


func _add_fragment(poly_points: PackedVector2Array) -> void:
	var polygon := Polygon2D.new()
	polygon.polygon = poly_points
	polygon.color = base_color
	polygon.antialiased = true
	if _target_texture != null:
		# 用关卡贴图填充：按整块目标矩形映射 UV，使每个被切碎片仍显示对应的图像局部。
		polygon.texture = _target_texture
		polygon.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		polygon.uv = _compute_sprite_uv(poly_points)
	else:
		polygon.texture = _checker_texture
		polygon.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(polygon)
	_fragments.append(polygon)


## 把以原点为中心的目标矩形（initial_size）映射到贴图像素坐标，碎片各顶点据此取 UV。
func _compute_sprite_uv(poly_points: PackedVector2Array) -> PackedVector2Array:
	var tex_size := _target_texture.get_size()
	var half := initial_size * 0.5
	var uv := PackedVector2Array()
	for p in poly_points:
		var u := (p.x + half.x) / initial_size.x
		var v := (p.y + half.y) / initial_size.y
		uv.append(Vector2(u * tex_size.x, v * tex_size.y))
	return uv


func _build_checker_texture() -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var tile_x := int(floor(float(x) / 8.0))
			var tile_y := int(floor(float(y) / 8.0))
			var light := ((tile_x + tile_y) % 2) == 0
			var c := Color(0.95, 0.95, 0.95, 1.0) if light else Color(0.82, 0.82, 0.82, 1.0)
			image.set_pixel(x, y, c)
	return ImageTexture.create_from_image(image)
