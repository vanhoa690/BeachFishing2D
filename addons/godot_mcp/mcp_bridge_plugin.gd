@tool
extends EditorPlugin

var server: TCPServer = TCPServer.new()
var clients: Array[StreamPeerTCP] = []
const PORT = 7055

func _enter_tree():
	var err = server.listen(PORT, "127.0.0.1")
	if err == OK:
		print("[Godot MCP] Đang lắng nghe tại cổng: ", PORT)
	else:
		push_error("[Godot MCP] Không thể mở cổng: " + str(err))

func _exit_tree():
	server.stop()
	for client in clients:
		client.disconnect_from_host()
	clients.clear()

func _process(_delta):
	if server.is_connection_available():
		var client = server.take_connection()
		clients.append(client)
		print("[Godot MCP] Client kết nối thành công")

	for i in range(clients.size() - 1, -1, -1):
		var client = clients[i]
		if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			clients.remove_at(i)
			continue
		
		if client.get_available_bytes() > 0:
			var msg = client.get_utf8_string(client.get_available_bytes())
			_handle_command(client, msg)

func _handle_command(client: StreamPeerTCP, payload_str: String):
	var json = JSON.new()
	if json.parse(payload_str) == OK:
		var data = json.data
		var action = data.get("action", "")
		var response = {"status": "ok", "action": action}
		
		match action:
			"ping":
				response["message"] = "pong"
			"get_version":
				response["version"] = Engine.get_version_info()["string"]
			"rescan_filesystem":
				EditorInterface.get_resource_filesystem().scan()
				response["message"] = "Filesystem rescanned"
			"get_open_scenes":
				response["scenes"] = EditorInterface.get_open_scenes()
			_:
				response["status"] = "error"
				response["message"] = "Lệnh không hỗ trợ: " + action
		
		var reply_bytes = (JSON.stringify(response) + "\n").to_utf8_buffer()
		client.put_data(reply_bytes)
