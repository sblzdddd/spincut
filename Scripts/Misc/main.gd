## 主场景入口：协调数据模型、交互逻辑、物理重建与预览层
extends Node2D

const Tool = preload("res://Scripts/Editor/editor_enums.gd").Tool
const PlayState = preload("res://Scripts/Editor/editor_enums.gd").PlayState
const PathAccuracyUtil = preload("res://Scripts/Gameplay/path_accuracy.gd")

@onready var ground: StaticBody2D = $Ground
@onready var editor_objects: Node2D = $EditorObjects
@onready var preview_overlay: EditorPreviewOverlay = $PreviewOverlay
@onready var marker_trail: MarkerTrail = $MarkerTrail
@onready var cut_target: CutTarget = $CutTarget
@onready var target_path_overlay: TargetPathOverlay = $TargetPathOverlay
@onready var cut_path_recorder: Node = $CutPathRecorder
@onready var level_sprite: Sprite2D = $LevelSprite
@onready var accuracy_label: Label = $CanvasLayer/AccuracyLabel
@onready var level_name_label: Label = $CanvasLayer/LevelNameLabel
@onready var level_complete: LevelCompleteOverlay = $CanvasLayer/LevelComplete
@export var gears_root: Node2D
@export var accuracy_tolerance_px: float = 28.0
@export var pass_accuracy_percent: float = 70.0
## 准确率检测间隔（秒）。准确率计算会扫描整条记录路径，逐帧执行会随路径增长越来越卡，
## 因此限频到每隔一段时间才算一次。
@export var accuracy_update_interval: float = 0.2

var model := LinkageModel.new()
var scene_builder := LinkageSceneBuilder.new()
var interaction := EditorInteraction.new()

var mouse_world := Vector2.ZERO
var _prev_play_state: PlayState = PlayState.EDITING
var _level_completed := false
var _latest_accuracy := 0.0
var _last_cut_point_count := {}
var _accuracy_timer := 0.0
var _level_title := ""


func _ready() -> void:
	# 通过 GameState 切换关卡场景会复用常驻的 EditorStates，进入关卡时先归位运行状态与选区。
	EditorStates.play_state = PlayState.EDITING
	EditorStates.selected_rods = []
	EditorStates.selected_joints = []
	EditorStates.is_drawing = false

	interaction.setup(model, _rebuild_editor_objects)
	preview_overlay.setup(model)
	EditorStates.tool_changed.connect(_on_tool_changed)
	EditorStates.selection_changed.connect(_rebuild_editor_objects)
	EditorStates.play_state_changed.connect(_on_play_state_changed)
	level_complete.retry_requested.connect(_on_retry_requested)
	level_complete.next_requested.connect(_on_next_requested)
	level_complete.menu_requested.connect(_on_menu_requested)
	_apply_current_level()
	model.build_initial_model()
	_rebuild_editor_objects()
	mouse_world = get_global_mouse_position()
	preview_overlay.set_mouse_world(mouse_world)
	_reset_level_status()


## 根据 GameState 当前关卡应用目标曲线、通关阈值、关卡名与展示精灵图。
func _apply_current_level() -> void:
	var level: LevelData = GameState.get_current_level()
	if level == null:
		_level_title = level_name_label.text
		return
	_level_title = level.level_name
	level_name_label.text = level.level_name
	pass_accuracy_percent = level.pass_accuracy_percent
	if not level.svg_solution.is_empty():
		target_path_overlay.svg_fit_size = level.target_size
		target_path_overlay.svg_file = level.svg_solution
	_apply_level_sprite(level)


func _apply_level_sprite(level: LevelData) -> void:
	var texture: Texture2D = level.sprite
	if texture == null:
		if level_sprite != null:
			level_sprite.visible = false
		cut_target.set_target_texture(null)
		return

	var tex_size := texture.get_size()
	var fit := 1.0
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		fit = minf(level.target_size.x / tex_size.x, level.target_size.y / tex_size.y)

	# 把关卡精灵图作为被切割目标的贴图，并保留淡显的参考精灵图作为底图。
	cut_target.set_target_texture(texture, tex_size * fit)

	if level_sprite != null:
		level_sprite.texture = texture
		level_sprite.visible = true
		level_sprite.scale = Vector2(fit, fit)


func _on_retry_requested() -> void:
	level_complete.hide_result()
	EditorStates.play_state = PlayState.EDITING


func _on_next_requested() -> void:
	GameState.next_level()


func _on_menu_requested() -> void:
	GameState.go_to_menu()


## 播放时让特殊点跟随刚体并记录标记点轨迹；暂停时仅让轨迹继续淡出
func _physics_process(delta: float) -> void:
	match EditorStates.play_state:
		PlayState.PLAYING:
			var marker_centers := {}
			for child in editor_objects.get_children():
				if child is LinkagePoint:
					child.update_follow()
					if child.kind == LinkagePoint.Kind.MARKER:
						var marker_id: int = int(child.get_meta("marker_id", -1))
						if marker_id != -1:
							marker_centers[marker_id] = child.global_position + LinkagePoint.SIZE * 0.5
			for marker_id in marker_centers.keys():
				marker_trail.add_marker_point(int(marker_id), marker_centers[marker_id])
				cut_path_recorder.add_marker_point(int(marker_id), marker_centers[marker_id])
			marker_trail.update_fade(delta)
			# 暂时禁用切割：_update_cutting()
			_accuracy_timer += delta
			if _accuracy_timer >= accuracy_update_interval:
				_accuracy_timer = 0.0
				_update_accuracy()
		PlayState.PAUSED:
			marker_trail.update_fade(delta)


func _on_tool_changed(_new_tool: Tool) -> void:
	mouse_world = get_global_mouse_position()
	preview_overlay.set_mouse_world(mouse_world)


## 模式切换：
##   进入播放（自编辑）-> 清空选区并以物理激活方式重建场景
##   暂停 -> 冻结连杆但保留当前姿态
##   暂停后继续播放 -> 解除冻结
##   停止（回编辑）-> 用数据模型重建，连杆回到原始位置
func _on_play_state_changed(new_state: PlayState) -> void:
	match new_state:
		PlayState.PLAYING:
			if _prev_play_state == PlayState.PAUSED:
				_set_rods_frozen(false)
			else:
				_start_play()
		PlayState.PAUSED:
			_set_rods_frozen(true)
		PlayState.EDITING:
			marker_trail.clear()
			cut_path_recorder.clear()
			_last_cut_point_count.clear()
			cut_target.reset_target()
			_reset_level_status()
			_rebuild_editor_objects()
	_prev_play_state = new_state


func _start_play() -> void:
	EditorStates.is_drawing = false
	EditorStates.selected_rods = []
	EditorStates.selected_joints = []
	marker_trail.clear()
	cut_path_recorder.clear()
	_last_cut_point_count.clear()
	cut_target.reset_target()
	_reset_level_status()
	_rebuild_editor_objects()


## 状态保留式暂停/恢复：冻结前缓存各连杆速度，解冻后恢复，避免暂停清空动量
func _set_rods_frozen(frozen: bool) -> void:
	for child in editor_objects.get_children():
		if child is Rod:
			if frozen:
				child.saved_linear_velocity = child.linear_velocity
				child.saved_angular_velocity = child.angular_velocity
				child.freeze = true
			else:
				child.freeze = false
				child.linear_velocity = child.saved_linear_velocity
				child.angular_velocity = child.saved_angular_velocity


func _unhandled_input(event: InputEvent) -> void:
	if not EditorStates.is_editing:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if interaction.handle_escape():
			preview_overlay.refresh()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_DELETE:
		if interaction.handle_delete():
			preview_overlay.refresh()
		return

	if event is InputEventMouseMotion:
		mouse_world = get_global_mouse_position()
		interaction.handle_mouse_motion(mouse_world)
		preview_overlay.set_mouse_world(mouse_world)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_world = get_global_mouse_position()
		if event.pressed:
			interaction.handle_left_press(mouse_world)
			preview_overlay.set_mouse_world(mouse_world)
		else:
			interaction.handle_left_release(mouse_world)
			preview_overlay.set_mouse_world(mouse_world)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		mouse_world = get_global_mouse_position()
		if event.pressed:
			if interaction.handle_right_press(mouse_world):
				preview_overlay.refresh()
		else:
			if interaction.handle_right_release():
				preview_overlay.refresh()
		return


## 根据模型数据重建所有物理刚体、关节与节点可视化
func _rebuild_editor_objects() -> void:
	scene_builder.rebuild(editor_objects, ground, model, EditorStates.is_playing)
	preview_overlay.refresh()


func _update_cutting() -> void:
	for marker_id in cut_path_recorder.get_marker_ids():
		var path: PackedVector2Array = cut_path_recorder.get_recorded_path(marker_id)
		if path.size() < 2:
			continue
		var previous_count: int = int(_last_cut_point_count.get(marker_id, 0))
		if path.size() == previous_count:
			continue
		cut_target.cut_by_path(path)
		_last_cut_point_count[marker_id] = path.size()


func _update_accuracy() -> void:
	var target_path: PackedVector2Array = target_path_overlay.get_target_path()
	if target_path.size() < 2:
		_latest_accuracy = 0.0
		accuracy_label.text = "Accuracy: 0.0%"
		return

	var actual_paths: Array = []
	for marker_id in cut_path_recorder.get_marker_ids():
		var path: PackedVector2Array = cut_path_recorder.get_recorded_path(marker_id)
		if path.size() >= 2:
			actual_paths.append(path)
	if actual_paths.is_empty():
		_latest_accuracy = 0.0
		accuracy_label.text = "Accuracy: 0.0%"
		return

	_latest_accuracy = PathAccuracyUtil.compute_multi_marker_coverage(actual_paths, target_path, accuracy_tolerance_px)
	accuracy_label.text = "Accuracy: %.1f%%" % _latest_accuracy

	if _level_completed:
		return
	if _latest_accuracy >= pass_accuracy_percent:
		_complete_level()


func _complete_level() -> void:
	_level_completed = true
	print("完成关卡，准确率 %.1f%%" % _latest_accuracy)
	EditorStates.play_state = PlayState.PAUSED
	level_complete.show_result(_level_title, _latest_accuracy, GameState.has_next_level())


func _reset_level_status() -> void:
	_level_completed = false
	_latest_accuracy = 0.0
	_accuracy_timer = 0.0
	accuracy_label.text = "Accuracy: 0.0%"
	level_complete.hide_result()
