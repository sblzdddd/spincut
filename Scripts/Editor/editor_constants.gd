## 编辑器预览与 UI 用色常量
class_name EditorConstants
extends RefCounted

const PREVIEW_RADIUS := 7.0
const PREVIEW_ALPHA := 0.5
const INVALID_ALPHA := 0.3

const BOX_SELECT_FILL := Color(0.8, 0.9, 1.0, 0.15)
const BOX_SELECT_STROKE := Color(0.9, 0.95, 1.0, 0.8)

const LINE_PREVIEW_COLOR := Color(0.7, 0.95, 1.0)
const LINE_START_COLOR := Color(0.55, 0.85, 1.0)
const FIXED_POINT_COLOR := Color(0.7, 0.7, 0.7)
const MARKER_POINT_COLOR := Color(0.85, 0.2, 0.85)
const INVALID_PLACE_COLOR := Color(1.0, 0.35, 0.35)

const ALONG_SNAP_COLOR := Color(0.4, 1.0, 0.6)    # 杆身内部吸附点
const MOTOR_ANCHOR_COLOR := Color(1.0, 0.9, 0.2)  # 空置电机锚点吸附点
const FLOATING_MOTOR_COLOR := Color(1.0, 0.62, 0.22) # 浮动/ground 电机（更偏橙）

const HANDLE_RADIUS := 6.0
const HANDLE_COLOR := Color(1.0, 0.85, 0.3)
const HANDLE_ALPHA := 0.9

## 普通连杆调色板：按连杆 id 取色，使每根新画的连杆颜色不同，便于区分
const ROD_PALETTE := [
	Color(0.2, 0.8, 0.95),   # 青
	Color(0.45, 0.9, 0.45),  # 绿
	Color(0.95, 0.8, 0.3),   # 黄
	Color(0.7, 0.5, 0.95),   # 紫
	Color(0.95, 0.55, 0.3),  # 橙
	Color(0.45, 0.65, 0.95), # 蓝
	Color(0.95, 0.45, 0.65), # 粉
	Color(0.4, 0.9, 0.8),    # 蓝绿
]
