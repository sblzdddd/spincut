## 背景齿轮：仅在播放模式累加动画时间，暂停/停止时冻结齿轮旋转
extends Node2D

var _anim_time := 0.0


func _ready() -> void:
	_apply()


func _process(delta: float) -> void:
	if not EditorStates.is_playing:
		return
	_anim_time += delta
	_apply()


func _apply() -> void:
	for child in get_children():
		if child is CanvasItem and child.material is ShaderMaterial:
			(child.material as ShaderMaterial).set_shader_parameter("anim_time", _anim_time)
