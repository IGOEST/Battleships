extends Node

const Msg = preload("res://messagePacket.gd")

var server_ip := "127.0.0.1"
var server_port := 4242
var client := StreamPeerTCP.new()
var connected := false
var message_buffer := ""

var network_thread := Thread.new()

# for communication from network thread to UI/input thread
var in_queue := []
var in_mutex := Mutex.new()

# for communication from UI/input thread to network thread
var out_queue := []
var out_mutex := Mutex.new()

# for running network thread (set to false to exit)
var running := false
var running_mutex := Mutex.new()

# assigned when the server sends ASSIGN_ID
var my_player_id := -1

func _ready():
	get_parent().get_node("StartScreen").hide()
	get_parent().get_node("WaitingScreenServer").show()
	connect_to_server()
	
func connect_to_server():
	print("CLIENT: Attempting to connect to server at ", server_ip, ":", server_port)
	if client.connect_to_host(server_ip, server_port) != OK:
		print("CLIENT: Failed to connect to server")
		return

	running_mutex.lock()
	running = true
	running_mutex.unlock()
	
	if network_thread.is_started():
		network_thread.wait_to_finish()

	network_thread = Thread.new()
	network_thread.start(Callable(self, "_network_thread"))
 
# main thread acting as intended UI/input thread
func _process(delta):
	# get messages from network thread
	in_mutex.lock()
	var packets := in_queue.duplicate()
	in_queue.clear()
	in_mutex.unlock()
	
	for packet in packets:
		handle_server_message(packet)

	if not connected and client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		connected = true
		print("CLIENT: Connected to server!")
		get_parent().connection_established()
		return
	
	if not connected:
		return
		
	if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		print("CLIENT: Lost connection to server")
		connected = false
		get_parent().handle_server_disconnect()
		return


func _network_thread() -> void:
	print("CLIENT: Network thread started")
 
	while is_running():
		client.poll()
		var status := client.get_status()
 
		if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
			push_warning("CLIENT: Network thread — connection lost or error")
			break
 
		if status == StreamPeerTCP.STATUS_CONNECTING:
			OS.delay_msec(10)
			continue
 
		# Flush out queue
		out_mutex.lock()
		var to_send := out_queue.duplicate()
		out_queue.clear()
		out_mutex.unlock()
 
		for packet in to_send:
			var wire := Msg.writeMsg(packet)
			print("CLIENT: Sending: ", wire.strip_edges())
			var err := client.put_data(wire.to_utf8_buffer())
			print("CLIENT: Sent result: ", err)
 
		# Receive incoming bytes and read packets.
		if client.get_available_bytes() > 0:
			var data = client.get_utf8_string(client.get_available_bytes())
			message_buffer += data
 
			while "\n" in message_buffer:
				var newLine_pos = message_buffer.find("\n")
				var raw_line = message_buffer.substr(0, newLine_pos)
				message_buffer = message_buffer.substr(newLine_pos + 1)
 
				if raw_line.length() > 0:
					var packet = Msg.readMsg(raw_line)
					if packet != null:
						# Push onto in_queue for the UI thread.
						in_mutex.lock()
						in_queue.append(packet)
						in_mutex.unlock()
					else:
						push_warning("CLIENT: Could not parse line: %s" % raw_line)
 
		OS.delay_msec(10)
 
	print("CLIENT: Network thread exit")

func handle_server_message(packet: Dictionary):
	print("CLIENT: Received from server: ", packet)
	
	var msg_type: int = packet.get("type")
	
	match msg_type:
		Msg.MsgType.ASSIGN_ID:
			my_player_id = packet["player_id"]
			print("CLIENT: Assigned player id = %d" % my_player_id)
 
		Msg.MsgType.WAIT_FOR_PLAYER:
			print("CLIENT: Waiting for opponent...")
 		
		Msg.MsgType.PLACE_CONFIRM:
			get_parent().handle_place_confirm(packet)
			
		Msg.MsgType.PLACE_REJECT:
			print("CLIENT: Server rejected placement (overlap or out of bounds)")
			
		Msg.MsgType.GAME_START:
			print("CLIENT: Game started. First turn: player %d" % packet["first_turn"])
			get_parent().call_deferred("start_battle_phase", packet) 

		Msg.MsgType.FIRE_RESULT:
			print("CLIENT: Fire result at [%d,%d] -> %s" % [packet["x"], packet["y"], packet["outcome"]])
			get_parent().handle_fire_result(packet)
 
		Msg.MsgType.YOUR_BOARD_HIT:
			print("CLIENT: Opponent hit your board at [%d,%d] -> %s" % [packet["x"], packet["y"], packet["outcome"]])
			get_parent().handle_incoming_hit(packet)
 
		Msg.MsgType.SHIP_SUNK:
			print("CLIENT: Ship %d of player %d sunk!" % [packet["ship_id"], packet["owner_id"]])
			get_parent().handle_ship_sunk(packet)

		Msg.MsgType.TURN_CHANGE:
			get_parent().handle_turn_change(packet)

		Msg.MsgType.PLAYER_DISCONNECT:
			print("CLIENT: Opponent disconnected")
			get_parent().handle_opponent_disconnected()

		Msg.MsgType.GAME_OVER:
			print("CLIENT: Game over! Winner: player %d" % packet["winner_id"])
			get_parent().handle_game_over(packet)

		Msg.MsgType.CLEAR_BOARD:
			get_parent().handle_clear_board()

		Msg.MsgType.SERVER_FULL:
			print("CLIENT: Server is full")
			get_parent().handle_server_full()
 
		_:
			print("CLIENT: Unhandled packet type: ", msg_type)

func send_fire(x: int, y: int):
	if not connected:
		return
	out_mutex.lock()
	out_queue.append(Msg.make_fire(x, y))
	out_mutex.unlock()
	print("CLIENT: Queued FIRE at [%d,%d]" % [x, y])

func send_board(ships: Array):
	if not connected:
		return
	out_mutex.lock()
	out_queue.append(Msg.make_board(ships))
	out_mutex.unlock()
	print("CLIENT: Queued BOARD_SUBMIT (%d ships)" % ships.size())

func is_running() -> bool:
	running_mutex.lock()
	var r := running
	running_mutex.unlock()
	return r

func _exit_tree() -> void:
	running_mutex.lock()
	running = false
	running_mutex.unlock()
 
	if network_thread.is_started():
		network_thread.wait_to_finish()
 
	if connected:
		client.disconnect_from_host()
