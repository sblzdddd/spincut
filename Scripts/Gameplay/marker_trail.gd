## 标记点运动轨迹：支持多标记点并行记录，播放时逐条淡出；停止时清空
## 暂停时不再追加新点，但已有轨迹继续淡出，直至消失
extends Node2D
class_name MarkerTrail

@export var LIFETIME := 1.2          # 单个轨迹点存活时间（秒）
@export var WIDTH := 3.0
@export var MIN_SEGMENT := 2.0       # 相邻记录点的最小间距，避免轨迹过密
@export var COLOR := Color(0.85, 0.2, 0.85)  # 与标记点同色

var _trails := {} # marker_id -> { points: PackedVector2Array, ages: PackedFloat32Array }


## 清空轨迹（停止回到编辑模式时调用）
func clear() -> void:
	_trails.clear()
	queue_redraw()


## 兼容旧调用：默认写入 id=0 轨迹
func add_point(world_pos: Vector2) -> void:
	add_marker_point(0, world_pos)


## 追加一个轨迹点（仅播放且标记点存在时调用）
func add_marker_point(marker_id: int, world_pos: Vector2) -> void:
	var trail := _get_or_create_trail(marker_id)
	var points: PackedVector2Array = trail["points"]
	var ages: PackedFloat32Array = trail["ages"]
	var count := points.size()
	if count > 0 and points[count - 1].distance_to(world_pos) < MIN_SEGMENT:
		return
	points.append(world_pos)
	ages.append(0.0)
	trail["points"] = points
	trail["ages"] = ages
	_trails[marker_id] = trail
	queue_redraw()


## 老化所有点并移除超寿命者，使轨迹整体随时间淡出并从尾端缩短
func update_fade(delta: float) -> void:
	if _trails.is_empty():
		return
	var dead_marker_ids: Array[int] = []
	for marker_id in _trails.keys():
		var trail: Dictionary = _trails[marker_id]
		var points: PackedVector2Array = trail["points"]
		var ages: PackedFloat32Array = trail["ages"]
		var first_alive := 0
		for i in range(ages.size()):
			ages[i] += delta
			if ages[i] >= LIFETIME:
				first_alive = i + 1
		if first_alive > 0:
			points = points.slice(first_alive)
			ages = ages.slice(first_alive)
		if points.is_empty():
			dead_marker_ids.append(int(marker_id))
		else:
			trail["points"] = points
			trail["ages"] = ages
			_trails[marker_id] = trail
	for marker_id in dead_marker_ids:
		_trails.erase(marker_id)
	queue_redraw()


func _draw() -> void:
	for marker_id in _trails.keys():
		var trail: Dictionary = _trails[marker_id]
		var points: PackedVector2Array = trail["points"]
		if points.size() < 2:
			continue
		var ages: PackedFloat32Array = trail["ages"]
		var colors := PackedColorArray()
		for age in ages:
			var alpha := clampf(1.0 - age / LIFETIME, 0.0, 1.0)
			colors.append(Color(COLOR.r, COLOR.g, COLOR.b, alpha))
		draw_polyline_colors(points, colors, WIDTH, true)


func _get_or_create_trail(marker_id: int) -> Dictionary:
	if not _trails.has(marker_id):
		_trails[marker_id] = {
			"points": PackedVector2Array(),
			"ages": PackedFloat32Array()
		}
	return _trails[marker_id]
