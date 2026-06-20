extends Button
class_name HotkeyButton

enum BadgePlacement {
	TOP,
	BOTTOM,
}

@export var hotkey_action: StringName
@export var badge_scene: PackedScene = preload("res://Prefabs/hotkey_badge.tscn")
@export var badge_placement: BadgePlacement = BadgePlacement.TOP
@export var badge_min_width: float = 10.0
@export var badge_height: float = 18.0
@export var badge_gap: float = 8.0
@export var pressed_badge_bg_color: Color = Color(0.4, 0.4, 0.4, 0.82)
@export var pressed_badge_border_color: Color = Color(1, 1, 1, 1)
@export var pressed_badge_font_color: Color = Color(1, 1, 1, 1)

var _badge: Control
var _badge_panel: PanelContainer
var _badge_label: Label
var _badge_style: StyleBoxFlat
var _normal_badge_bg_color: Color
var _normal_badge_border_color: Color
var _normal_badge_font_color: Color = Color(1, 1, 1, 1)
var _last_disabled := false
var _last_action: StringName = &""
var _hotkey_press_armed := false


func _ready() -> void:
	_ensure_badge()
	_update_badge_text()
	_update_badge_layout()
	_refresh_badge_visibility()
	_last_disabled = disabled
	_last_action = hotkey_action


func _process(_delta: float) -> void:
	if disabled and _hotkey_press_armed:
		_hotkey_press_armed = false
		_set_badge_pressed_visual(false)
	if _last_disabled != disabled:
		_last_disabled = disabled
		_refresh_badge_visibility()
	if _last_action != hotkey_action:
		_last_action = hotkey_action
		_update_badge_text()
		_update_badge_layout()
		_refresh_badge_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if disabled or hotkey_action == StringName():
		_hotkey_press_armed = false
		_set_badge_pressed_visual(false)
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed(hotkey_action):
		_hotkey_press_armed = true
		_set_badge_pressed_visual(true)
		emit_signal("button_down")
		get_viewport().set_input_as_handled()
	elif event.is_action_released(hotkey_action) and _hotkey_press_armed:
		_hotkey_press_armed = false
		_set_badge_pressed_visual(false)
		emit_signal("button_up")
		emit_signal("pressed")
		get_viewport().set_input_as_handled()


func _ensure_badge() -> void:
	var existing := get_node_or_null("HotkeyBadge")
	if existing is Control:
		_badge = existing
	else:
		if badge_scene == null:
			return
		var instance := badge_scene.instantiate()
		if not (instance is Control):
			instance.queue_free()
			return
		_badge = instance
		_badge.name = "HotkeyBadge"
		add_child(_badge)

	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_panel = _badge as PanelContainer
	_badge_label = _badge.get_node_or_null("HotkeyLabel") as Label
	_prepare_badge_style()
	_set_badge_pressed_visual(false)


func _prepare_badge_style() -> void:
	if _badge_panel == null:
		return
	var source_style := _badge_panel.get_theme_stylebox("panel")
	if source_style is StyleBoxFlat:
		_badge_style = (source_style as StyleBoxFlat).duplicate()
		_badge_panel.add_theme_stylebox_override("panel", _badge_style)
		_normal_badge_bg_color = _badge_style.bg_color
		_normal_badge_border_color = _badge_style.border_color
	if _badge_label != null:
		_normal_badge_font_color = _badge_label.get_theme_color("font_color", "Label")


func _update_badge_text() -> void:
	if _badge_label == null:
		return
	_badge_label.text = _action_to_badge_text(hotkey_action)


func _update_badge_layout() -> void:
	if _badge == null:
		return
	var width := badge_min_width
	if _badge_label != null:
		var estimated_text_width := float(_badge_label.text.length()) * 7.0 + 12.0
		width = max(width, estimated_text_width)
	_badge.custom_minimum_size = Vector2(width, badge_height)
	_badge.anchor_left = 0.5
	_badge.anchor_right = 0.5
	_badge.offset_left = -width * 0.5
	_badge.offset_right = width * 0.5

	match badge_placement:
		BadgePlacement.TOP:
			_badge.anchor_top = 0.0
			_badge.anchor_bottom = 0.0
			_badge.offset_top = -badge_height - badge_gap
			_badge.offset_bottom = -badge_gap
		BadgePlacement.BOTTOM:
			_badge.anchor_top = 1.0
			_badge.anchor_bottom = 1.0
			_badge.offset_top = badge_gap
			_badge.offset_bottom = badge_height + badge_gap


func _refresh_badge_visibility() -> void:
	if _badge == null:
		return
	var has_action := hotkey_action != StringName()
	var has_text := _badge_label != null and _badge_label.text != ""
	_badge.visible = not disabled and has_action and has_text
	if not _badge.visible:
		_set_badge_pressed_visual(false)


func _set_badge_pressed_visual(pressed_state: bool) -> void:
	if _badge_style != null:
		_badge_style.bg_color = pressed_badge_bg_color if pressed_state else _normal_badge_bg_color
		_badge_style.border_color = pressed_badge_border_color if pressed_state else _normal_badge_border_color
	if _badge_label != null:
		var font_color := pressed_badge_font_color if pressed_state else _normal_badge_font_color
		_badge_label.add_theme_color_override("font_color", font_color)


func _action_to_badge_text(action: StringName) -> String:
	if action == StringName():
		return ""
	var events := InputMap.action_get_events(action)
	for mapped_event in events:
		var shortcut_text := _event_to_short_text(mapped_event)
		if shortcut_text != "":
			return shortcut_text
	return String(action)


func _event_to_short_text(mapped_event: InputEvent) -> String:
	if mapped_event is InputEventKey:
		var key_event := mapped_event as InputEventKey
		var keycode := key_event.keycode
		if keycode == KEY_NONE:
			keycode = key_event.physical_keycode
		if keycode != KEY_NONE:
			return OS.get_keycode_string(keycode)
		return ""
	if mapped_event is InputEventMouseButton:
		var mouse_event := mapped_event as InputEventMouseButton
		return "M%s" % str(mouse_event.button_index)
	return ""
