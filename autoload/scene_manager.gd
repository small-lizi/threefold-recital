extends Node

# 场景配置
var scene_config = {}
var current_scene = null
var settings_path = "user://settings.cfg"
var taskbar_height = 40  # 默认任务栏高度
var is_ai_disabled = false  # 添加全局变量来记录AI禁用状态
var last_operation_time = 0.0  # 记录上次操作时间
const COOLDOWN_TIME = 2.0  # 操作冷却时间（秒）

func _ready():
	# 获取任务栏高度
	get_taskbar_height()
	
	# 检查是否需要打开帮助网页
	check_first_run_today()
	
	# 加载场景配置
	load_config()
	
	# 设置窗口属性
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
		# 添加窗口移动限制
		limit_window_position()
	
	# 获取初始场景
	for child in get_tree().root.get_children():
		if child.name != "SceneManager" and child is Node2D:
			current_scene = child
			print("找到初始场景：", child.name)
			# 如果AI已被禁用，对初始场景也禁用AI
			if is_ai_disabled:
				disable_character_ai(child)
			break
	
	# 打印当前场景树中的所有节点
	print_scene_tree()

# 获取任务栏高度
func get_taskbar_height():
	var screen_size = DisplayServer.screen_get_size()
	var usable_size = DisplayServer.screen_get_usable_rect().size
	taskbar_height = screen_size.y - usable_size.y
	print("任务栏高度：", taskbar_height)

# 限制窗口位置
func limit_window_position():
	var screen_size = DisplayServer.screen_get_size()
	var window_size = DisplayServer.window_get_size()
	var window_position = DisplayServer.window_get_position()
	
	# 计算可用区域的底部边界（屏幕高度减去任务栏高度）
	var max_y = screen_size.y - taskbar_height - window_size.y
	
	# 如果窗口位置超出底部边界，调整位置
	if window_position.y > max_y:
		window_position.y = max_y
		DisplayServer.window_set_position(window_position)

# 在窗口移动时检查位置
func _process(_delta):
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		limit_window_position()

# 打印场景树中的所有节点
func print_scene_tree():
	print("\n--- 当前场景树节点 ---")
	var root = get_tree().root
	print_node_recursive(root)
	print("-------------------\n")

# 递归打印节点及其子节点
func print_node_recursive(node: Node, indent: String = ""):
	print(indent + "- " + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		print_node_recursive(child, indent + "  ")

func load_config():
	# 读取配置文件
	var config_file = FileAccess.open("res://config/scene_config.json", FileAccess.READ)
	if config_file:
		var json_string = config_file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			scene_config = json.get_data()
		else:
			print("解析配置文件失败: ", json.get_error_message())
			return
	else:
		print("无法打开配置文件")
		return

func _input(event):
	# 检测Tab+数字键组合
	if event is InputEventKey and event.pressed:
		if Input.is_key_pressed(KEY_TAB):
			# 检测是否按下ESC键来关闭程序
			if event.keycode == KEY_ESCAPE:
				get_tree().quit()
				return
				
			# 检测是否按下A键来禁用AI行为
			if event.keycode == KEY_A:
				disable_all_ai_behaviors()
				return
			
			# 检测是否按下C键来创建新实例
			if event.keycode == KEY_C:
				create_new_instance()
				return
				
			# 将按键转换为字符串
			var key_number = ""
			match event.keycode:
				KEY_1: key_number = "1"
				KEY_2: key_number = "2"
				KEY_3: key_number = "3"
				KEY_4: key_number = "4"
				KEY_5: key_number = "5"
				KEY_6: key_number = "6"
				KEY_7: key_number = "7"
				KEY_8: key_number = "8"
				KEY_9: key_number = "9"
			
			# 如果按下了数字键，尝试切换场景
			if key_number != "":
				switch_scene(key_number)

# 检查是否可以执行操作
func can_perform_operation() -> bool:
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_operation_time >= COOLDOWN_TIME:
		last_operation_time = current_time
		return true
	print("请等待 %.1f 秒后再操作" % (COOLDOWN_TIME - (current_time - last_operation_time)))
	return false

func switch_scene(key_number: String):
	if not can_perform_operation():
		return
	
	print("\n=== 切换场景前的节点状态 ===")
	print_scene_tree()
	
	# 检查配置中是否存在该场景
	if not scene_config.has("scenes") or not scene_config["scenes"].has(key_number):
		print("未找到场景配置: ", key_number)
		return
	
	var scene_data = scene_config["scenes"][key_number]
	var scene_path = scene_data["path"]
	
	# 加载新场景
	var new_scene = load(scene_path)
	if new_scene:
		# 如果当前有场景，先从场景树中移除并释放
		if current_scene != null:
			print("\n正在移除场景: ", current_scene.name)
			if is_instance_valid(current_scene) and current_scene.is_inside_tree():
				var parent = current_scene.get_parent()
				print("从父节点移除: ", parent.name)
				parent.remove_child(current_scene)
				current_scene.queue_free()  # 立即释放旧场景
			current_scene = null
		
		# 等待一帧确保旧场景被完全移除
		await get_tree().process_frame
		
		# 实例化新场景
		current_scene = new_scene.instantiate()
		get_tree().root.add_child(current_scene)
		
		# 如果AI已被禁用，对新场景也禁用AI
		if is_ai_disabled:
			disable_character_ai(current_scene)
		
		print("\n=== 切换场景后的节点状态 ===")
		print_scene_tree()
		
		print("切换到场景: ", scene_data["description"])
		
		# 重新隐藏任务栏图标
		await get_tree().create_timer(0.1).timeout  # 等待一小段时间确保窗口已完全创建
		var hidewindow_node = get_node("/root/Hidewindow")
		if hidewindow_node:
			hidewindow_node.HideTaskbarIcon()
	else:
		print("加载场景失败: ", scene_path)

func check_first_run_today():
	var config = ConfigFile.new()
	var err = config.load(settings_path)
	
	# 获取当前日期
	var today = Time.get_date_string_from_system()
	
	if err == OK:  # 文件存在
		var last_open_date = config.get_value("general", "last_open_date", "")
		if last_open_date != today:
			# 今天第一次打开
			OS.shell_open("https://three.mlzi.top/help.html")
			config.set_value("general", "last_open_date", today)
			config.save(settings_path)
	else:  # 文件不存在
		OS.shell_open("https://three.mlzi.top/help.html")
		config.set_value("general", "last_open_date", today)
		config.save(settings_path)

# 禁用所有角色的AI行为
func disable_all_ai_behaviors():
	print("\n=== 正在禁用所有角色的AI行为 ===")
	is_ai_disabled = true  # 设置全局禁用状态
	var root = get_tree().root
	var characters = find_all_characters(root)
	
	for character in characters:
		disable_character_ai(character)
	
	print("所有角色的AI行为已禁用")

# 禁用单个角色的AI行为
func disable_character_ai(character: Node):
	# 查找Timer节点
	for child in character.get_children():
		if child is Timer:
			print("找到Timer节点：", child.name)
			child.stop()  # 先停止计时器
			child.wait_time = 999999.0  # 设置一个很长的等待时间
			child.start()  # 重新启动计时器
			print("已禁用角色AI行为：", character.name)
			return
	
	print("警告：在角色", character.name, "中未找到Timer节点")

# 查找所有角色节点（继承自Node2D的节点）
func find_all_characters(node: Node) -> Array:
	var characters = []
	
	if node is Node2D and node.get_children().any(func(child): return child is Timer):
		characters.append(node)
	
	for child in node.get_children():
		characters.append_array(find_all_characters(child))
	
	return characters

# 创建新的应用程序实例
func create_new_instance():
	if not can_perform_operation():
		return
		
	print("\n=== 正在创建新的应用程序实例 ===")
	
	# 获取当前执行文件的路径
	var executable_path = OS.get_executable_path()
	var executable_dir = OS.get_executable_path().get_base_dir()
	
	# 在Windows系统中，如果是导出的exe文件，直接运行
	if OS.has_feature("windows") and executable_path.ends_with(".exe"):
		OS.create_process(executable_path, [], false)
		print("已启动新实例：", executable_path)
	# 如果是在编辑器中运行，则使用命令行启动Godot引擎
	else:
		var godot_executable = OS.get_environment("GODOT_BINARY")
		if godot_executable == "":
			godot_executable = "godot"  # 假设godot在系统PATH中
		
		var args = ["--path", executable_dir]
		OS.create_process(godot_executable, args, false)
		print("已在编辑器模式下启动新实例")
	
	print("新实例启动完成")
