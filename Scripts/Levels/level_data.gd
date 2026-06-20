## 单个关卡数据：关卡名、展示用精灵图、以及作为正确答案的 SVG 曲线。
class_name LevelData
extends Resource

@export var level_name: String = "Level"
## 关卡展示图形（描摹目标的视觉参考）。
@export var sprite: Texture2D
## 正确答案曲线来源 SVG（取其第一个 <path>）。可填 res:// 或 uid:// 路径。
@export_file("*.svg") var svg_solution: String = ""
## 把 SVG 曲线缩放到该尺寸。
@export var target_size: Vector2 = Vector2(240.0, 240.0)
## 通关所需准确率（百分比）。
@export var pass_accuracy_percent: float = 70.0
