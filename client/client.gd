extends Node

var server_ip := "127.0.0.1"
var server_port := 4242
var client := StreamPeerTCP.new()
var connected := false
var message_buffer := ""

func _ready():
	connect_to_server()
	
func connect_to_server():
	print("CLIENT: Attempting to connect to server at ", server_ip, ":", server_port)
	if client.connect_to_host(server_ip, server_port) != OK:
		print("CLIENT: Failed to connect to server")
		return

func _process(delta):
	client.poll()
	
	if not connected and client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		connected = true
		print("CLIENT: Connected to server!")
		
		#get_tree().create_timer(1.0).timeout.connect(func(): send_call_function("hello_from_client"))
		#get_tree().create_timer(2.0).timeout.connect(func(): request_server_info())
		get_tree().create_timer(1.0).timeout.connect(func(): send_fire(3, 5))
		return
	
	if not connected:
		return
		
	if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		print("CLIENT: Lost connection to server")
		connected = false
		return
	
	if client.get_available_bytes() > 0:
		var data = client.get_utf8_string(client.get_available_bytes())
		message_buffer += data
		
		while "\n" in message_buffer:
			var newLine_pos = message_buffer.find("\n")
			var message = message_buffer.substr(0, newLine_pos)
			message_buffer = message_buffer.substr(newLine_pos + 1)
			
			if message.length() > 0:
				handle_server_message(message)
				
func handle_server_message(message: String):
	print("CLIENT: Received from server: ", message)
	
	var parts = message.strip_edges().split(" ", false, 1)
	if parts.size() == 0:
		return
		
	var command = parts[0]
	var data = parts[1] if parts.size() > 1 else ""
	
	match command:
		"FUNCTION_RESULT":
			print("CLIENT: Function result: ", data)
			on_function_result(data)
		"INFO":
			var info = JSON.parse_string(data)
			print("CLIENT: Server info: ", info)
			on_server_info(info)
		"HIT":
			print("CLIENT: Hit confirmed at: ", data)
		"ERROR":
			print("CLIENT: Server error: ", data)
			
func send_call_function(data: String):
	if not connected:
		print("CLIENT: Not connected to server")
		return
	
	var message = "CALL_FUNCTION " + data + "\n"
	print("CLIENT: Sending to server (", message.length(), " bytes): '", message, "'")
	var result = client.put_data(message.to_utf8_buffer())
	print("CLIENT: Sent result: ", result)
	
func request_server_info():
	if not connected:
		print("CLIENT: Not connected to server")
		return
	
	var message = "REQUEST_INFO\n"
	print("CLIENT: Sending to server (", message.length(), " bytes): '", message, "'")
	var result = client.put_data(message.to_utf8_buffer())
	print("CLIENT: Sent result: ", result)
	
func on_function_result(result: String):
	print("CLIENT: Processing function result: ", result)
	
func on_server_info(info: Dictionary):
	print("CLIENT: Processing servr info:")
	print(" CLIENT: Server time: ", info.get("server_time", 0))
	print(" CLIENT: Connected clients: ", info.get("connected_clients", 0))
	print(" CLIENT: Status: ", info.get("status", "unknown"))
	
func send_fire(x:int, y:int):
	if not connected:
		return
		
	var message = "FIRE %d %d\n" % [x, y]
	print("CLIENT: Sending: ", message)
	var result = client.put_data(message.to_utf8_buffer())
	print("CLIENT: Sent result: ", result)
	
func _exit_tree() -> void:
	if connected:
		client.disconnect_from_host()
