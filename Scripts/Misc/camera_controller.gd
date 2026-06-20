## 场景相机：滚轮缩放（朝光标方向），按住鼠标中键拖拽平移。
## UI 位于 CanvasLayer，不受相机变换影响；世界中的连杆、目标与背景随相机移动/缩放。
extends Camera2D
class_name CameraController

## 每格滚轮的缩放倍率。
@export var zoom_step: float = 1.1
## 缩放范围限制（zoom 越大画面越放大）。
@export var min_zoom: float = 0.25
@export var max_zoom: float = 4.0

var _panning := false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_at(zoom_step, event.position)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_at(1.0 / zoom_step, event.position)
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _panning:
		# 屏幕位移换算到世界位移（除以缩放系数），反向移动相机实现“抓取”平移。
		position -= event.relative / zoom
		get_viewport().set_input_as_handled()


## 以光标处的世界点为锚缩放，使该点在缩放前后保持在相同的屏幕位置。
func _zoom_at(factor: float, screen_anchor: Vector2) -> void:
	var new_zoom := Vector2(
		clampf(zoom.x * factor, min_zoom, max_zoom),
		clampf(zoom.y * factor, min_zoom, max_zoom)
	)
	if new_zoom == zoom:
		return
	# 默认 anchor_mode 为居中拖拽：世界点 = 相机位置 + (屏幕点 - 视口中心) / 缩放。
	var viewport_center := Vector2(get_viewport_rect().size) * 0.5
	var world_before := position + (screen_anchor - viewport_center) / zoom
	zoom = new_zoom
	var world_after := position + (screen_anchor - viewport_center) / zoom
	position += world_before - world_after
