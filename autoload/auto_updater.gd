extends Node

# 更新配置
const UPDATE_CHECK_URL = "https://three.mlzi.top/update.json"  # 替换为您的实际版本检查URL
const UPDATE_PAGE_URL = "https://three.mlzi.top/update.html"   # 替换为您的更新页面URL
const CURRENT_VERSION = "1.2.2"  # 当前版本号
var version_http: HTTPRequest

func _ready():
	# 创建HTTP请求节点
	version_http = HTTPRequest.new()
	add_child(version_http)
	
	# 连接信号
	version_http.request_completed.connect(_on_version_check_completed)
	
	# 启动时检查更新
	check_for_updates()

# 检查更新
func check_for_updates():
	version_http.request(UPDATE_CHECK_URL)

# 版本检查完成的回调
func _on_version_check_completed(_result, response_code, _headers, body):
	if response_code != 200:
		return
	
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return
	
	var update_info = json.get_data()
	if not update_info.has("version"):
		return
		
	var new_version = update_info["version"].split(".")
	var current_version = CURRENT_VERSION.split(".")
	
	# 比较版本号
	for i in range(min(new_version.size(), current_version.size())):
		if new_version[i].to_int() > current_version[i].to_int():
			OS.shell_open(UPDATE_PAGE_URL)
			return
		elif new_version[i].to_int() < current_version[i].to_int():
			return

# 比较版本号
