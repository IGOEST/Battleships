extends Node

const Msg = preload("res://messagePacket.gd")

var server_grids = {}	# {player_id: {Vector2: ship_id}}
var player_boards = {}
var player_names = {}	# {player_id: "name"}

func process_message(client, message: Dictionary, pid: int) -> Array:
	var responses := []
	var msg_type: int = message.get("type")
	
	match msg_type:
		Msg.MsgType.FIRE:
			var x = message.get("x", -1)
			var y = message.get("y", -1)
 
			var opponent_id = 2 if pid == 1 else 1
			var outcome = "miss"
			
			if server_grids.has(opponent_id) and server_grids[opponent_id].has(Vector2(x,y)):
				outcome = "hit"
				print("SERVER: Hit at ", Vector2(x,y))
			else:
				print("SERVER: Miss at ", Vector2(x,y))
				
			# to the player who fired
			responses.append({"client": client, "packet": Msg.make_fire_result(x, y, outcome, -1)})
			# to the player who was shot
			responses.append({"target_id": opponent_id, "packet": Msg.make_your_board_hit(x, y, outcome, -1)})
			print("SERVER: Sending action result")
 
		Msg.MsgType.PLACE_REQUEST:
			var coords = message.get("coords", [])
			var ship_id = message.get("ship_id", -1)
			
			if is_placement_valid(pid, coords):
				# Save it to the server's version of the grid
				save_to_server_grid(pid, coords, ship_id)
				responses.append({"client": client, "packet": {
					"type": Msg.MsgType.PLACE_CONFIRM,
					"coords": coords,
					"ship_id": ship_id
				}})
			else:
				responses.append({"client": client, "packet": {
					"type": Msg.MsgType.PLACE_REJECT
				}})
		
		Msg.MsgType.BOARD:
			player_boards[pid] = "READY"
			player_names[pid] = message.get("player_name", "unknown")
			print("SERVER:Player %d is ready" % pid)
			
			if player_boards.size() == 2:
				responses.append({"target": "all", "packet": {
					"type": Msg.MsgType.GAME_START,
					"first_turn": 1,
					"p1_name": player_names[1],
					"p2_name": player_names[2] }
				})
				
	return responses
	
func is_placement_valid(pid, coords_array):
	if not server_grids.has(pid): server_grids[pid] = {}
	
	for c_raw in coords_array:
		var c = Vector2(c_raw[0], c_raw[1])
		if c.x < 0 or c.x > 9 or c.y < 0 or c.y > 9: return false
		
		# Buffer check against server's records
		for x_off in [-1, 0, 1]:
			for y_off in [-1, 0, 1]:
				if server_grids[pid].has(c + Vector2(x_off, y_off)):
					return false
	return true

func save_to_server_grid(pid, coords_array, ship_id):
	for c_raw in coords_array:
		var vec = Vector2(int(c_raw[0]), int(c_raw[1]))
		server_grids[pid][vec] = ship_id
		
func clear_player_data(pid):
	if server_grids.has(pid):
		server_grids.erase(pid)
	if player_boards.has(pid):
		player_boards.erase(pid)
