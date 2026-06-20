extends Node
class_name CutPathRecorder

@export var min_segment_distance: float = 2.0
## 单条路径保留的最大点数。标记点会随连杆不断循环，路径若无限增长会让
## 准确率扫描越来越慢、物理帧时间持续上升。超出后丢弃最旧的点，保留最近轨迹。
@export var max_points: int = 6000

var _paths: Dictionary = {} # marker_id -> PackedVector2Array


func clear() -> void:
	_paths.clear()


func add_marker_point(marker_id: int, world_pos: Vector2) -> void:
	var path: PackedVector2Array = _paths.get(marker_id, PackedVector2Array())
	if not path.is_empty():
		if path[path.size() - 1].distance_to(world_pos) < min_segment_distance:
			return
	path.append(world_pos)
	# 分批裁剪（每超出一段缓冲再裁一次），把裁剪摊销为接近 O(1)，避免逐帧整段复制。
	if path.size() > max_points + 512:
		path = path.slice(path.size() - max_points)
	_paths[marker_id] = path


func get_recorded_path(marker_id: int) -> PackedVector2Array:
	return _paths.get(marker_id, PackedVector2Array())


func get_marker_ids() -> Array[int]:
	var ids: Array[int] = []
	for key in _paths.keys():
		ids.append(int(key))
	return ids


func get_longest_path_marker_id() -> int:
	var selected_id := -1
	var max_size := -1
	for key in _paths.keys():
		var marker_id := int(key)
		var path: PackedVector2Array = _paths[marker_id]
		if path.size() > max_size:
			max_size = path.size()
			selected_id = marker_id
	return selected_id
