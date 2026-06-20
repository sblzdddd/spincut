extends RefCounted
class_name PathAccuracy


## 默认外圈权重系数：目标点离形状质心越远（越靠外圈），在评分中占比越高。
## 0 表示所有目标点等权重；数值越大，外圈轮廓越主导最终准确率。
const DEFAULT_OUTER_WEIGHT_BIAS := 2.0


## 兼容旧调用：单条 actual 路径，内部转发到多标记点版本。
static func compute_symmetric_coverage(
	actual_path: PackedVector2Array,
	target_path: PackedVector2Array,
	tolerance_px: float
) -> float:
	return compute_multi_marker_coverage([actual_path], target_path, tolerance_px)


## 多标记点综合评分：把所有标记点轨迹的并集与目标曲线对比，并对目标外圈点加权。
## 各标记轨迹保持独立（不互相连线），目标点取到任意一条轨迹的最近距离作为覆盖误差。
static func compute_multi_marker_coverage(
	actual_paths: Array,
	target_path: PackedVector2Array,
	tolerance_px: float,
	outer_weight_bias: float = DEFAULT_OUTER_WEIGHT_BIAS
) -> float:
	if target_path.size() < 2 or tolerance_px <= 0.001:
		return 0.0

	var spacing := maxf(4.0, tolerance_px * 0.35)
	var sampled_target := _resample_path(target_path, spacing)
	if sampled_target.size() < 2:
		return 0.0

	# 重采样每条标记轨迹并保持彼此独立，避免跨轨迹产生虚假连线段。
	var sampled_actuals: Array = []
	for raw in actual_paths:
		var path: PackedVector2Array = raw
		if path.size() < 2:
			continue
		var sampled := _resample_path(path, spacing)
		if sampled.size() >= 2:
			sampled_actuals.append(sampled)
	if sampled_actuals.is_empty():
		return 0.0

	# 目标 -> 实际（覆盖率）：每个目标点到任意标记轨迹的最近距离，外圈点加权。
	var err_target := _weighted_target_error(sampled_target, sampled_actuals, outer_weight_bias)
	# 实际 -> 目标（精度）：每个标记点到目标曲线的最近距离，惩罚跑偏的多余笔画。
	var err_actual := _actual_to_target_error(sampled_actuals, sampled_target)

	var bidirectional_error := (err_target + err_actual) * 0.5
	return clampf(100.0 * (1.0 - bidirectional_error / tolerance_px), 0.0, 100.0)


## 目标 -> 实际覆盖误差：按目标点的外圈程度加权求平均最近距离。
static func _weighted_target_error(
	target_samples: PackedVector2Array,
	actual_paths: Array,
	outer_weight_bias: float
) -> float:
	var centroid := _centroid(target_samples)
	var max_radius := 0.0
	for p in target_samples:
		max_radius = maxf(max_radius, p.distance_to(centroid))
	if max_radius <= 0.001:
		max_radius = 1.0

	var weighted_error := 0.0
	var weight_sum := 0.0
	for p in target_samples:
		var radius_norm := p.distance_to(centroid) / max_radius
		var weight := 1.0 + maxf(0.0, outer_weight_bias) * radius_norm
		weighted_error += weight * _min_distance_to_paths(p, actual_paths)
		weight_sum += weight
	if weight_sum <= 0.0:
		return 0.0
	return weighted_error / weight_sum


## 实际 -> 目标精度误差：所有标记点到目标折线的平均最近距离。
static func _actual_to_target_error(actual_paths: Array, target_samples: PackedVector2Array) -> float:
	var total := 0.0
	var count := 0
	for path in actual_paths:
		for point in path:
			total += _point_to_polyline_distance(point, target_samples)
			count += 1
	if count == 0:
		return 0.0
	return total / float(count)


## 取某点到多条折线的最小距离（多标记点并集覆盖）。
static func _min_distance_to_paths(point: Vector2, paths: Array) -> float:
	var min_dist := INF
	for path in paths:
		var d := _point_to_polyline_distance(point, path)
		if d < min_dist:
			min_dist = d
	return min_dist


static func _centroid(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / float(points.size())


static func _point_to_polyline_distance(point: Vector2, polyline: PackedVector2Array) -> float:
	if polyline.is_empty():
		return INF
	if polyline.size() == 1:
		return point.distance_to(polyline[0])

	var min_dist := INF
	for i in range(polyline.size() - 1):
		var a := polyline[i]
		var b := polyline[i + 1]
		var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
		var dist := point.distance_to(closest)
		if dist < min_dist:
			min_dist = dist
	return min_dist


static func _resample_path(path: PackedVector2Array, spacing: float) -> PackedVector2Array:
	if path.is_empty():
		return PackedVector2Array()
	if path.size() == 1:
		return PackedVector2Array([path[0]])

	var result := PackedVector2Array([path[0]])
	var last_added := path[0]
	var carry := 0.0

	for i in range(path.size() - 1):
		var segment_start := path[i]
		var segment_end := path[i + 1]
		var segment_length := segment_start.distance_to(segment_end)
		if segment_length <= 0.001:
			continue

		var dir := (segment_end - segment_start) / segment_length
		var traveled := spacing - carry
		while traveled <= segment_length:
			var sample := segment_start + dir * traveled
			if sample.distance_to(last_added) >= spacing * 0.5:
				result.append(sample)
				last_added = sample
			traveled += spacing
		carry = segment_length - (traveled - spacing)

	if result[result.size() - 1] != path[path.size() - 1]:
		result.append(path[path.size() - 1])
	return result
