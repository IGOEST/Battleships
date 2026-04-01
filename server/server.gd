extends Node

var server_port := 4242
var max_clients := 2
var server := TCPServer.new()
var clients = []
var client_buffers = {}
var mutex := Mutex.new()
var threads = []

var game_logic := preload("res://game_logic.gd").new()

var game_thread : Thread
var semaphore := Semaphore.new()

var incoming_queue = []
var outgoing_queue = []

func _ready() -> void:
	if server.listen(server_port) != OK:
		push_error("Server failed to start on port %d" % server_port)
		return
	print("Server started on port %d" % server_port)

func _process(delta: float) -> void:
	if server.is_connection_available():
		var client := server.take_connection()
		clients.append(client)
		client_buffers[client] = ""
		print("SERVER: Client connected! Total clients: ", clients.size())
		
		var t = Thread.new()
		threads.append(t)
		t.start(Callable(self, "_client_thread").bind(client))
		
		game_thread = Thread.new()
		game_thread.start(Callable(self, "_game_logic_thread"))
		
	mutex.lock()
	while not outgoing_queue.is_empty():
		var packet = outgoing_queue.pop_front()
		send_to_client(packet["client"], packet["message"])
	mutex.unlock()
		
	#for i in range(clients.size()):
		#var client: StreamPeerTCP = clients[i]
		#client.poll()
			#
		#if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			#print("Client disconnected!")
			#client_buffers.erase(client)
			#clients.remove_at(i)
			#continue
			
		#if client.get_available_bytes() > 0:
			#var bytes_available = client.get_available_bytes()
			#var data = client.get_utf8_string(bytes_available)
			#print("Raw data received(", bytes_available, " bytes): '", data, "'")
			#client_buffers[client] += data
		#
		#while "\n" in client_buffers[client]:
			#var newLine_pos = client_buffers[client].find("\n")
			#var message = client_buffers[client].substr(0, newLine_pos)
			#client_buffers[client] = client_buffers[client].substr(newLine_pos + 1)
			#
			#print("Message: ", message, " (length: ", message.length(), ")")
			#if message.length() > 0:
				#print("Processing message ", message)
				#handle_client_message(client, message)
				
func _client_thread(client):
	while client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var bytes_available = client.get_available_bytes()
		if bytes_available > 0:
			var data = client.get_utf8_string(bytes_available)
			print("SERVER: Raw data received (", bytes_available, " bytes): ", data)
			mutex.lock()
			client_buffers[client] += data
			mutex.unlock()
			while "\n" in client_buffers[client]:
				var newLine_pos = client_buffers[client].find("\n")
				var message = client_buffers[client].substr(0, newLine_pos)
				client_buffers[client] = client_buffers[client].substr(newLine_pos + 1)
				print("SERVER: Extracted message: ", message, " (length: ", message.length(), ")")
				if message.length() > 0:
					print("SERVER: Processing message: ", message)
					handle_client_message(client, message)
		OS.delay_msec(10)
	print("SERVER: Client thread ending")
	client_buffers.erase(client)
	clients.erase(client)

func handle_client_message(client: StreamPeerTCP, message: String):
	#var parts = message.strip_edges().split(" ", false, 1)
	#if parts.size() == 0:
		#return
	#
	#var command = parts[0]
	#var data = parts[1] if parts.size() > 1 else ""
	#
	#match command:
		#"CALL_FUNCTION":
			#call_server_function(client, data)
		#"REQUEST_INFO":
			#send_info_to_client(client)
		#_:
			#send_to_client(client, "ERROR: Unknown command")
	print("SERVER: CLIENT THREAD - Received from client: ", message)
	
	mutex.lock()
	incoming_queue.append({
		"client": client,
		"message": message
	})
	mutex.unlock()
	semaphore.post()

func _game_logic_thread():
	print("SERVER: Game logic thread started")
	while true:
		semaphore.wait()
		
		mutex.lock()
		if incoming_queue.is_empty():
			mutex.unlock()
			continue
			
		var packet = incoming_queue.pop_front()
		mutex.unlock()
		
		var client = packet["client"]
		var message = packet["message"]
		
		var responses = game_logic.process_message(client, message)
		
		mutex.lock()
		for r in responses:
			outgoing_queue.append(r)
			print("SERVER: Received action result: ", r["message"])
		mutex.unlock()
					
func call_server_function(client: StreamPeerTCP, data: String):
	print("SERVER: Server function called with data: ", data)
	
	var result = "Server processed: " + data.to_upper()
	
	send_to_client(client, "FUNCTION_RESULT " + result)
	
func send_info_to_client(client: StreamPeerTCP):
	var info = {
		"server_time": Time.get_ticks_msec(),
		"connected_clients": clients.size(),
		"status": "running"
	}
	
	var json_string = JSON.stringify(info)
	send_to_client(client, "INFO " + json_string)
	
func send_to_client(client: StreamPeerTCP, message: String):
	var full_message = message + "\n"
	print("SERVER: Sending to client: ", full_message)
	var result = client.put_data(full_message.to_utf8_buffer())
	print("SERVER: Sent result: ", result)

func _exit_tree() -> void:
	for client in clients:
		client.disconnect_from_host()
	for t in threads:
		t.wait_to_finish()
	server.stop()
