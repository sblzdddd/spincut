## 全局游戏状态（Autoload）：持有关卡列表与当前关卡索引，并负责开始游戏、
## 关卡间导航以及返回开始界面的场景切换。
extends Node

const LEVEL_LIST_PATH := "res://Resources/Levels/level_list.tres"
const MAIN_SCENE := "res://main.tscn"
const START_SCENE := "res://Scenes/start_screen.tscn"

var level_list: LevelList
var current_level_index: int = 0


func _ready() -> void:
	_load_level_list()


func _load_level_list() -> void:
	if ResourceLoader.exists(LEVEL_LIST_PATH):
		var loaded := load(LEVEL_LIST_PATH)
		if loaded is LevelList:
			level_list = loaded
	if level_list == null:
		level_list = LevelList.new()


func level_count() -> int:
	return level_list.size() if level_list != null else 0


func get_current_level() -> LevelData:
	if level_list == null:
		return null
	return level_list.get_level(current_level_index)


func has_next_level() -> bool:
	return current_level_index + 1 < level_count()


## 选定关卡并进入主游戏场景。
func start_level(index: int) -> void:
	current_level_index = clampi(index, 0, maxi(0, level_count() - 1))
	get_tree().change_scene_to_file(MAIN_SCENE)


## 进入下一关（若存在），否则停留在当前关并重载。
func next_level() -> void:
	if has_next_level():
		current_level_index += 1
	get_tree().change_scene_to_file(MAIN_SCENE)


## 重新加载当前关卡场景。
func restart_level() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)


## 返回开始界面。
func go_to_menu() -> void:
	get_tree().change_scene_to_file(START_SCENE)
