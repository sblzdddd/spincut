## 开始界面：展示标题并根据 GameState 关卡列表生成关卡选择按钮。
extends Control

@export var play_button: Button
@export var level_list_container: VBoxContainer


func _ready() -> void:
	if play_button != null:
		play_button.pressed.connect(_on_play_pressed)
	_populate_levels()


func _on_play_pressed() -> void:
	GameState.start_level(0)


func _populate_levels() -> void:
	if level_list_container == null:
		return
	for child in level_list_container.get_children():
		child.queue_free()

	var count := GameState.level_count()
	for index in range(count):
		var level := GameState.level_list.get_level(index)
		var label := level.level_name if level != null else "Level %d" % (index + 1)
		var button := Button.new()
		button.text = "%d. %s" % [index + 1, label]
		button.custom_minimum_size = Vector2(260, 40)
		button.pressed.connect(GameState.start_level.bind(index))
		level_list_container.add_child(button)
