## 从 SVG 文件读取第一个 <path> 元素，并把其 d 路径数据解析/展开为折线点集。
## 支持 M/L/H/V/C/S/Q/T/A/Z 全部命令（含相对小写形式），曲线会按采样数离散为线段。
## 坐标保持 SVG 原始坐标系（Y 向下，与 Godot 2D 一致），不做归一化。
extends RefCounted
class_name SvgPathLoader


## 读取 svg_file 中第一个 <path> 的 d 数据并展开为点集；失败时返回空数组。
static func load_first_path_points(svg_file: String, curve_samples: int = 16) -> PackedVector2Array:
	var d := read_first_path_data(svg_file)
	if d.is_empty():
		return PackedVector2Array()
	return parse_path_data(d, curve_samples)


## 取出 SVG 中第一个 <path> 的 d 属性字符串。
static func read_first_path_data(svg_file: String) -> String:
	var resolved := _resolve_path(svg_file)
	if not FileAccess.file_exists(resolved):
		push_error("SvgPathLoader: 找不到 SVG 文件 %s" % svg_file)
		return ""
	var parser := XMLParser.new()
	if parser.open(resolved) != OK:
		push_error("SvgPathLoader: 无法打开 SVG 文件 %s" % svg_file)
		return ""
	while parser.read() == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT and parser.get_node_name() == "path":
			for i in range(parser.get_attribute_count()):
				if parser.get_attribute_name(i) == "d":
					return parser.get_attribute_value(i)
	push_warning("SvgPathLoader: SVG 中没有带 d 属性的 <path>：%s" % svg_file)
	return ""


## 把 uid:// 路径解析为真实的 res:// 源文件路径；普通路径原样返回。
static func _resolve_path(svg_file: String) -> String:
	if svg_file.begins_with("uid://"):
		var id := ResourceUID.text_to_id(svg_file)
		if ResourceUID.has_id(id):
			return ResourceUID.get_id_path(id)
	return svg_file


## 把 SVG path 的 d 字符串解析为折线点集。
static func parse_path_data(d: String, curve_samples: int = 16) -> PackedVector2Array:
	var samples := maxi(2, curve_samples)
	var tokens := _tokenize(d)
	var points := PackedVector2Array()

	var current := Vector2.ZERO
	var subpath_start := Vector2.ZERO
	var last_control := Vector2.ZERO
	var prev_cmd := ""
	var cmd := ""

	var idx := 0
	var count := tokens.size()
	while idx < count:
		var token = tokens[idx]
		if token is String:
			cmd = token
			idx += 1
		elif cmd == "":
			idx += 1
			continue

		match cmd:
			"M", "m":
				current = _read_point(tokens, idx, cmd == "m", current)
				idx += 2
				subpath_start = current
				points.append(current)
				cmd = "L" if cmd == "M" else "l"
			"L", "l":
				current = _read_point(tokens, idx, cmd == "l", current)
				idx += 2
				points.append(current)
			"H", "h":
				var x: float = tokens[idx]
				idx += 1
				current = Vector2(current.x + x if cmd == "h" else x, current.y)
				points.append(current)
			"V", "v":
				var y: float = tokens[idx]
				idx += 1
				current = Vector2(current.x, current.y + y if cmd == "v" else y)
				points.append(current)
			"C", "c":
				var relative := cmd == "c"
				var c1 := _read_point(tokens, idx, relative, current)
				var c2 := _read_point(tokens, idx + 2, relative, current)
				var end := _read_point(tokens, idx + 4, relative, current)
				idx += 6
				_append_cubic(points, current, c1, c2, end, samples)
				last_control = c2
				current = end
			"S", "s":
				var c1 := current
				if prev_cmd in ["C", "c", "S", "s"]:
					c1 = current * 2.0 - last_control
				var relative := cmd == "s"
				var c2 := _read_point(tokens, idx, relative, current)
				var end := _read_point(tokens, idx + 2, relative, current)
				idx += 4
				_append_cubic(points, current, c1, c2, end, samples)
				last_control = c2
				current = end
			"Q", "q":
				var relative := cmd == "q"
				var c1 := _read_point(tokens, idx, relative, current)
				var end := _read_point(tokens, idx + 2, relative, current)
				idx += 4
				_append_quadratic(points, current, c1, end, samples)
				last_control = c1
				current = end
			"T", "t":
				var c1 := current
				if prev_cmd in ["Q", "q", "T", "t"]:
					c1 = current * 2.0 - last_control
				var end := _read_point(tokens, idx, cmd == "t", current)
				idx += 2
				_append_quadratic(points, current, c1, end, samples)
				last_control = c1
				current = end
			"A", "a":
				var rx: float = tokens[idx]
				var ry: float = tokens[idx + 1]
				var rot: float = tokens[idx + 2]
				var large_arc: bool = tokens[idx + 3] != 0.0
				var sweep: bool = tokens[idx + 4] != 0.0
				var end := _read_point(tokens, idx + 5, cmd == "a", current)
				idx += 7
				_append_arc(points, current, rx, ry, rot, large_arc, sweep, end, samples)
				current = end
			"Z", "z":
				if not points.is_empty():
					points.append(subpath_start)
				current = subpath_start
			_:
				idx += 1

		prev_cmd = cmd

	return points


static func _read_point(tokens: Array, idx: int, relative: bool, origin: Vector2) -> Vector2:
	var p := Vector2(tokens[idx], tokens[idx + 1])
	return origin + p if relative else p


static func _append_cubic(points: PackedVector2Array, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, samples: int) -> void:
	for s in range(1, samples + 1):
		var t := float(s) / float(samples)
		var u := 1.0 - t
		points.append(
			u * u * u * p0
			+ 3.0 * u * u * t * p1
			+ 3.0 * u * t * t * p2
			+ t * t * t * p3
		)


static func _append_quadratic(points: PackedVector2Array, p0: Vector2, p1: Vector2, p2: Vector2, samples: int) -> void:
	for s in range(1, samples + 1):
		var t := float(s) / float(samples)
		var u := 1.0 - t
		points.append(u * u * p0 + 2.0 * u * t * p1 + t * t * p2)


## 椭圆弧 (A/a)：按 SVG 规范做端点到圆心参数化转换，再离散为折线。
static func _append_arc(
	points: PackedVector2Array,
	p0: Vector2,
	rx: float,
	ry: float,
	x_axis_rotation_deg: float,
	large_arc: bool,
	sweep: bool,
	p1: Vector2,
	samples: int
) -> void:
	if p0.is_equal_approx(p1):
		return
	if is_zero_approx(rx) or is_zero_approx(ry):
		points.append(p1)
		return

	rx = absf(rx)
	ry = absf(ry)
	var phi := deg_to_rad(x_axis_rotation_deg)
	var cos_phi := cos(phi)
	var sin_phi := sin(phi)

	var dx := (p0.x - p1.x) * 0.5
	var dy := (p0.y - p1.y) * 0.5
	var x1p := cos_phi * dx + sin_phi * dy
	var y1p := -sin_phi * dx + cos_phi * dy

	var lambda := (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
	if lambda > 1.0:
		var scale := sqrt(lambda)
		rx *= scale
		ry *= scale

	var arc_sign := -1.0 if large_arc == sweep else 1.0
	var num := maxf(rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p, 0.0)
	var denom := rx * rx * y1p * y1p + ry * ry * x1p * x1p
	var coef := 0.0
	if denom > 0.0:
		coef = arc_sign * sqrt(num / denom)
	var cxp := coef * (rx * y1p / ry)
	var cyp := coef * (-ry * x1p / rx)

	var cx := cos_phi * cxp - sin_phi * cyp + (p0.x + p1.x) * 0.5
	var cy := sin_phi * cxp + cos_phi * cyp + (p0.y + p1.y) * 0.5

	var start_vec := Vector2((x1p - cxp) / rx, (y1p - cyp) / ry)
	var end_vec := Vector2((-x1p - cxp) / rx, (-y1p - cyp) / ry)
	var theta1 := _vector_angle(Vector2(1.0, 0.0), start_vec)
	var dtheta := _vector_angle(start_vec, end_vec)
	if not sweep and dtheta > 0.0:
		dtheta -= TAU
	elif sweep and dtheta < 0.0:
		dtheta += TAU

	var steps := maxi(2, int(ceil(absf(dtheta) / (PI / float(samples)))))
	for s in range(1, steps + 1):
		var angle := theta1 + dtheta * (float(s) / float(steps))
		var x := cos_phi * rx * cos(angle) - sin_phi * ry * sin(angle) + cx
		var y := sin_phi * rx * cos(angle) + cos_phi * ry * sin(angle) + cy
		points.append(Vector2(x, y))


static func _vector_angle(u: Vector2, v: Vector2) -> float:
	var len_prod := u.length() * v.length()
	if len_prod == 0.0:
		return 0.0
	var ang := acos(clampf(u.dot(v) / len_prod, -1.0, 1.0))
	if u.x * v.y - u.y * v.x < 0.0:
		ang = -ang
	return ang


## 把 d 字符串切分为命令字母 (String) 与数值 (float) 的混合 token 序列。
static func _tokenize(d: String) -> Array:
	var tokens := []
	var i := 0
	var n := d.length()
	while i < n:
		var code := d.unicode_at(i)
		if _is_alpha(code):
			tokens.append(char(code))
			i += 1
		elif _is_digit(code) or code == 46 or code == 45 or code == 43: # . - +
			var start := i
			if code == 45 or code == 43:
				i += 1
			var seen_dot := false
			while i < n:
				var ch := d.unicode_at(i)
				if _is_digit(ch):
					i += 1
				elif ch == 46 and not seen_dot: # .
					seen_dot = true
					i += 1
				elif ch == 101 or ch == 69: # e / E 指数
					i += 1
					if i < n:
						var next_code := d.unicode_at(i)
						if next_code == 45 or next_code == 43:
							i += 1
				else:
					break
			tokens.append(float(d.substr(start, i - start)))
		else:
			i += 1 # 空白、逗号等分隔符
	return tokens


static func _is_alpha(code: int) -> bool:
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


static func _is_digit(code: int) -> bool:
	return code >= 48 and code <= 57
