## 编辑器枚举定义
class_name EditorEnums
extends RefCounted

enum Tool {
	SELECT = 0,       # 选择/移动
	DRAW_LINE = 1,    # 画连杆
	FIXED_POINT = 2,  # 放置固定点
	MARKER_POINT = 3  # 放置标记点
}

## 运行模式：
##   EDITING 编辑模式 -> 编辑器启用，连杆/关节物理冻结
##   PLAYING 播放模式 -> 物理运行（电机驱动、关节联动），编辑器禁用
##   PAUSED  暂停      -> 物理冻结但不回退，保留当前姿态
enum PlayState {
	EDITING = 0,
	PLAYING = 1,
	PAUSED = 2
}
