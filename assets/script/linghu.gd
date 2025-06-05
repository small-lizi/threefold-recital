extends Node2D

@export var base_move_speed: float = 100.0  # 基础移动速度
@export var ai_interval: float = 15.0  # AI行为间隔时间(秒)
@export var animation_chances: Dictionary = {
	"run": 0.1,
	"sit": 0.2,
	"door": 0.2
}  # 动画触发概率字典，可在编辑器调整

# 定义动画移动配置
@export var movement_animations: Dictionary = {
	"run": 1.0
}

@onready var animated_sprite = $AnimatedSprite2D
@onready var window = get_window()
@onready var ai_timer = Timer.new()

# 声明所有需要的变量
var is_moving = false  # 改名以更好地表达状态
var current_direction = 1  # 1表示向右，-1表示向左
var move_tween: Tween
var is_dragging = false    # 右键拖动状态
var drag_offset = Vector2.ZERO  # 拖动偏移量
var current_animation = "idel"  # 当前动画名称

# 动画过渡规则
var transition_rules = {
}

# AI行为状态
enum AIState {IDLE, MOVING}
var current_ai_state = AIState.IDLE

# 添加动画和按键的映射字典
var animation_key_map = {
	"run": KEY_2,
	"walk": KEY_3,
	"disco": KEY_4,
	"disco2": KEY_5,
	"lie": KEY_6
}

# 道具节点列表
var prop_nodes = []

func _ready():
	animated_sprite.play("idel")
	window.always_on_top = true
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# 设置AI计时器
	add_child(ai_timer)
	ai_timer.wait_time = ai_interval
	ai_timer.timeout.connect(_on_ai_timeout)
	ai_timer.start()

# 播放动画并更新状态
func play_animation(anim_name: String):
	current_animation = anim_name
	animated_sprite.play(anim_name)

# 切换移动状态
func toggle_movement(anim_name: String):
	# 检查是否需要先播放过渡动画
	if animated_sprite.animation in transition_rules:
		var required_anim = transition_rules[animated_sprite.animation]
		if animated_sprite.animation != required_anim:
			play_animation(required_anim)
			await animated_sprite.animation_finished
	
	if is_moving and current_animation == anim_name:
		# 如果已经在移动且是同一个动画，则改变方向
		current_direction *= -1
		animated_sprite.flip_h = current_direction < 0
		# 重新设置可见道具的方向
		for prop in prop_nodes:
			if has_node(prop) and get_node(prop).visible:
				set_node_visibility(prop, true)
	else:
		# 开始新的移动动画
		is_moving = true
		play_animation(anim_name)
	
	# 开始移动窗口
	start_window_move()

func stop_movement():
	if is_moving:
		is_moving = false
		if move_tween:
			move_tween.kill()
		play_animation("idel")

func _input(event):
	# 右键拖动窗口
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			stop_movement()  # 拖动时停止移动
			is_dragging = true
			drag_offset = window.position - DisplayServer.mouse_get_position()
		else:
			is_dragging = false

	# 检查是否需要先播放过渡动画
	if event is InputEventKey and event.pressed and not is_dragging and animated_sprite.animation in transition_rules:
		var required_anim = transition_rules[animated_sprite.animation]
		if animated_sprite.animation != required_anim:
			play_animation(required_anim)
			await animated_sprite.animation_finished
	
	if is_dragging and event is InputEventMouseMotion:
		var new_pos = DisplayServer.mouse_get_position() + drag_offset
		var screen_size = DisplayServer.screen_get_size()
		var window_size = window.size
		# 限制窗口在屏幕范围内
		new_pos.x = clamp(new_pos.x, 0, screen_size.x - window_size.x)
		new_pos.y = clamp(new_pos.y, 0, screen_size.y - window_size.y)
		window.position = new_pos
	
	# 按键控制
	if event is InputEventKey and event.pressed and not is_dragging:
		match event.keycode:
			KEY_1:
				stop_movement()
				play_animation("idel")
			KEY_2:
				toggle_movement("run")
			KEY_3:
				stop_movement()
				play_animation("knife")
			KEY_4:
				stop_movement()
				play_animation("sit")
			KEY_5:
				stop_movement()
				play_animation("door")

func start_window_move():
	if move_tween:
		move_tween.kill()
	
	var screen_size = DisplayServer.screen_get_size()
	var window_size = window.size
	
	# 计算目标位置，确保不超出屏幕
	var target_x = window.position.x + (screen_size.x * current_direction)
	target_x = clamp(target_x, 0, screen_size.x - window_size.x)
	
	# 获取当前动画的速度倍率
	var speed_multiplier = movement_animations.get(current_animation, 1.0)
	
	# 计算移动时间（根据速度和距离）
	var distance = abs(target_x - window.position.x)
	var duration = distance / (base_move_speed * speed_multiplier)
	
	move_tween = create_tween()
	move_tween.tween_property(window, "position:x", target_x, duration)
	move_tween.tween_callback(func():
		# 到达边界后改变方向继续移动
		current_direction *= -1
		animated_sprite.flip_h = current_direction < 0
		# 重新设置可见道具的方向
		for prop in prop_nodes:
			if has_node(prop) and get_node(prop).visible:
				set_node_visibility(prop, true)
		start_window_move()
	)

func _on_animation_finished():
	if animated_sprite.animation in ["knife"]:
		play_animation("idel")
		
	# 动画结束后重置AI状态
	current_ai_state = AIState.IDLE

func _on_ai_timeout():
	# 如果正在拖动或已经有动画在播放，则跳过
	if is_dragging or animated_sprite.animation != "idel":
		return
	
	# 随机决定AI行为
	var rand_val = randf()
	var cumulative_chance = 0.0
	
	for anim in animation_chances:
		cumulative_chance += animation_chances[anim]
		if rand_val < cumulative_chance:
			# 如果动画在按键映射中存在，则模拟按下对应按键
			if anim in animation_key_map:
				# 创建一个按键事件
				var event = InputEventKey.new()
				event.keycode = animation_key_map[anim]  # 设置按键码
				event.pressed = true  # 设置为按下状态
				
				# 模拟按键输入
				Input.parse_input_event(event)
			break

func set_node_visibility(node_names: Array, is_visible: bool) -> void:
	# 使用队列进行广度优先搜索
	var queue = [self]
	var found_nodes = []
	
	# 查找所有指定的节点
	while not queue.is_empty():
		var current = queue.pop_front()
		if current.name in node_names:
			found_nodes.append(current)
			if found_nodes.size() == node_names.size():
				break  # 如果找到所有节点就提前退出
		queue.append_array(current.get_children())
	
	# 设置找到的节点的可见性
	for target_node in found_nodes:
		target_node.visible = is_visible
		# 如果节点可见且是Sprite2D，设置翻转
		if is_visible and target_node is Sprite2D:
			target_node.flip_h = current_direction < 0
	
	# 检查是否有未找到的节点并输出警告
	for node_name in node_names:
		if not found_nodes.any(func(node): return node.name == node_name):
			print("警告：找不到节点 ", node_name)
