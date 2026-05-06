extends Node

const Msg = preload("res://messagePacket.gd")

var server_grids = {}	# {player_id: {Vector2: ship_id}}
var player_boards = {}

func process_message(client, message: Dictionary, pid: int) -> Array:
	var responses := []
	var msg_type: int = message.get("type")
	
	match msg_type:
		Msg.MsgType.FIRE:
			var x = message.get("x", -1)
			var y = message.get("y", -1)
 
			print("GAME: FIRE at ", x, ", ", y)
 
			# Just for now always HIT (to test the communication)
			responses.append({"client": client, "packet": Msg.make_fire_result(x, y, "hit")})
			print("GAME: Sending action result: FIRE_RESULT hit at [%d,%d]" % [x, y])
 
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
			print("SERVER:Player %d is ready" % pid)
			
			if player_boards.size() == 2:
				responses.append({"client": client, "packet": Msg.make_game_start(1)})
				
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
		server_grids[pid][Vector2(c_raw[0], c_raw[1])] = ship_id
		
func clear_player_data(pid):
	if server_grids.has(pid):
		server_grids.erase(pid)
	if player_boards.has(pid):
		player_boards.erase(pid)
