## 关卡列表资源：按顺序保存所有关卡数据，供 GameState 读取与导航。
class_name LevelList
extends Resource

@export var levels: Array[LevelData] = []


func size() -> int:
	return levels.size()


func get_level(index: int) -> LevelData:
	if index < 0 or index >= levels.size():
		return null
	return levels[index]
