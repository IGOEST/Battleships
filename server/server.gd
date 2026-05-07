extends Node

var server_port := 4242
var max_clients := 2
var server := TCPServer.new()
var clients = []
var client_buffers = {}
var mutex := Mutex.new()
var threads = []

const Msg = preload("res://messagePacket.gd")
var game_logic := preload("res://game_logic.gd").new()

var game_thread : Thread
var semaphore := Semaphore.new()

var incoming_queue = []
var outgoing_queue = []

# to assign player id
var _player_ids = {}
var _next_player_id := 1

func _ready() -> void:
	if server.listen(server_port) != OK:
		push_error("Server failed to start on port %d" % server_port)
		return
	print("Server started on port %d" % server_port)
	game_thread = Thread.new()
	game_thread.start(Callable(self, "_game_logic_thread"))


func _process(delta: float) -> void:
	if server.is_connection_available():
		var client := server.take_connection()
		clients.append(client)
		client_buffers[client] = ""
		
		# assign player id
		var pid := _next_player_id
		_next_player_id += 1
		_player_ids[client] = pid
		print("SERVER: Client connected as player %d. Total clients: %d" % [pid, clients.size()])
		send_packet(client, Msg.make_assign_id(pid))
		
		if clients.size() < max_clients:
			send_packet(client, Msg.make_wait_for_player())

		
		var t = Thread.new()
		threads.append(t)
		t.start(Callable(self, "_client_thread").bind(client))
		
	mutex.lock()
	while not outgoing_queue.is_empty():
		var entry = outgoing_queue.pop_front()
		var target_client = entry["client"]
		var packet = entry["packet"]
		mutex.unlock()
		send_packet(target_client, packet)
		mutex.lock()
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
	var pid: int = _player_ids[client]
	print("SERVER: Client thread started for player %d" % pid)

	while client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		client.poll()
		var bytes_available = client.get_available_bytes()
		if bytes_available > 0:
			var data = client.get_utf8_string(bytes_available)
			print("SERVER: Raw data received (%d bytes) from player %d: %s" % [bytes_available, pid, data])
			mutex.lock()
			client_buffers[client] += data
			mutex.unlock()
			
			# extract lines from buffer
			var keep_reading := true
			while keep_reading:
				mutex.lock()
				var buf: String = client_buffers[client]
				mutex.unlock()
 
				var nl_pos := buf.find("\n")
				if nl_pos == -1:
					keep_reading = false
				else:
					var raw_line := buf.substr(0, nl_pos)
					mutex.lock()
					client_buffers[client] = buf.substr(nl_pos + 1)
					mutex.unlock()
 
					if raw_line.length() > 0:
						print("SERVER: Extracted message: ", raw_line, " (length: ", raw_line.length(), ")")
						print("SERVER: Processing message: ", raw_line)
						handle_client_message(client, raw_line)
 
		OS.delay_msec(10)
 
	print("SERVER: Client thread exit")
	mutex.lock()
	client_buffers.erase(client)
	clients.erase(client)
	_player_ids.erase(client)
	mutex.unlock()


func handle_client_message(client: StreamPeerTCP, message: String) -> void:
	print("SERVER: CLIENT THREAD - Received from client: ", message)
 
	var packet = Msg.readMsg(message)
	if packet == null:
		push_warning("SERVER: Failed to parse packet from player %d" % _player_ids.get(client, -1))
		return
 
	mutex.lock()
	incoming_queue.append({
		"client": client,
		"player_id": _player_ids.get(client, -1),
		"packet": packet,
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
		var pid = packet["player_id"]
		var message = packet["packet"]
		
		var responses = game_logic.process_message(client, message, pid)
		
		mutex.lock()
		for r in responses:
			if r.has("target") and r["target"] == "all":
				for c in clients:
					outgoing_queue.append({"client": c, "packet": r["packet"]})
			elif r.has("target_id"):
				for c in _player_ids:
					if _player_ids[c] == r["target_id"]:
						outgoing_queue.append({"client": c, "packet": r["packet"]})
			else:		# send only to specific client
				outgoing_queue.append(r)
			print("SERVER: Received action result: ", r["packet"])
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


func send_packet(client: StreamPeerTCP, packet: Dictionary) -> void:
	var message := Msg.writeMsg(packet)
	print("SERVER: Sending to client: ", message.strip_edges())
	var err := client.put_data(message.to_utf8_buffer())
	if err != OK:
		push_warning("SERVER: error %d" % err)
 

func _exit_tree() -> void:
	for client in clients:
		client.disconnect_from_host()
	for t in threads:
		t.wait_to_finish()
	server.stop()
