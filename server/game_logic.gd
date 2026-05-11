extends Node

const Msg = preload("res://messagePacket.gd")

var server_grids = {}	# {player_id: {Vector2: ship_id}}
var player_boards = {}
var player_names = {}	# {player_id: "name"}

var ships_data = {}
var ship_cells = {}

var current_turn := 1
var game_started := false
var game_over := false

func process_message(client, message: Dictionary, pid: int) -> Array:
	var responses := []
	var msg_type: int = message.get("type")
	
	match msg_type:
		Msg.MsgType.FIRE:
			if not game_started:
				print("SERVER: Game has not started yet")
				return responses

			if game_over:
				print("SERVER: Game has ended")
				return responses

			if pid != current_turn:
				print("SERVER: Player %d tried to play out of turn" % pid)
				return responses
				
			var x = message.get("x", -1)
			var y = message.get("y", -1)
			var target = Vector2(x, y)
 
			var opponent_id = 2 if pid == 1 else 1
			var outcome = "miss"
			var sunk_ship_id = -1
			
			if server_grids.has(opponent_id) and server_grids[opponent_id].has(target):
				var ship_id = server_grids[opponent_id][target]
				# register hit
				ships_data[opponent_id][ship_id]["hits"][target] = true
				ship_cells = ships_data[opponent_id][ship_id]["cells"]
				var hit_count = ships_data[opponent_id][ship_id]["hits"].size()
				
				if hit_count >= ship_cells.size():
					outcome = "sunk"
					sunk_ship_id = ship_id
					print("SERVER: Ship sunk -> player %d ship %d" % [opponent_id, ship_id])
				else:
					outcome = "hit"
					print("SERVER: Hit at ", target)
			else:
				print("SERVER: Miss at ", target)
				
			# to the player who fired
			responses.append({"client": client, "packet": Msg.make_fire_result(x, y, outcome, -1)})
			# to the player who was shot
			responses.append({"target_id": opponent_id, "packet": Msg.make_your_board_hit(x, y, outcome, -1)})
			
			# sunk ship notification
			if outcome == "sunk":
				responses.append({
					"target": "all",
					"packet": Msg.make_ship_sunk(
						opponent_id,
						sunk_ship_id,
						vector_array_to_packet(ship_cells)
					)
				})
				
				# game over check
				if are_all_ships_destroyed(opponent_id):
					responses.append({"target": "all", "packet": Msg.make_game_over(pid)})
			
			if not game_over:
				current_turn = opponent_id

				responses.append({
					"target": "all",
					"packet": Msg.make_turn_change(current_turn)
				})
				print("SERVER: Sending action result")
 
		Msg.MsgType.PLACE_REQUEST:
			var coords = message.get("coords", [])
			var ship_id = message.get("ship_id", -1)
			
			if is_placement_valid(pid, coords):
				# Save it to the server's version of the grid
				save_to_server_grid(pid, coords, ship_id)
				responses.append({
					"client": client, 
					"packet": {
						"type": Msg.MsgType.PLACE_CONFIRM,
						"coords": coords,
						"ship_id": ship_id
					}
				})
			else:
				responses.append({
					"client": client, 
					"packet": {
						"type": Msg.MsgType.PLACE_REJECT
					}
				})
		
		Msg.MsgType.BOARD:
			player_boards[pid] = "READY"
			player_names[pid] = message.get("player_name", "unknown")
			print("SERVER: Player %d is ready" % pid)
			
			if player_boards.size() == 2:
				game_started = true
				game_over = false
				current_turn = 1
				responses.append({
					"target": "all", 
					"packet": {
						"type": Msg.MsgType.GAME_START,
						"first_turn": 1,
						"p1_name": player_names[1],
						"p2_name": player_names[2] 
					}
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
	if not server_grids.has(pid):
		server_grids[pid] = {}
	
	if not ships_data.has(pid):
		ships_data[pid] = {}
	
	ships_data[pid][ship_id] = {
		"cells": [],
		"hits": {}
	}
	
	for c_raw in coords_array:
		var vec = Vector2(int(c_raw[0]), int(c_raw[1]))
		server_grids[pid][vec] = ship_id
		ships_data[pid][ship_id]["cells"].append(vec)

func are_all_ships_destroyed(pid: int) -> bool:
	if not ships_data.has(pid):
		return false
	
	for ship_id in ships_data[pid]:
		var ship = ships_data[pid][ship_id]
		
		if ship["hits"].size() < ship["cells"].size():
			return false
	
	return true

func vector_array_to_packet(arr: Array) -> Array:
	var out := []
	
	for v in arr:
		out.append([v.x, v.y])
	
	return out

func clear_player_data(pid):
	if server_grids.has(pid):
		server_grids.erase(pid)
	if ships_data.has(pid):
		ships_data.erase(pid)
	if ship_cells.has(pid):
		ship_cells.erase(pid)
	if player_boards.has(pid):
		player_boards.erase(pid)
	if player_names.has(pid):
		player_names.erase(pid)

func reset_game():
	server_grids.clear()
	ships_data.clear()
	ship_cells.clear()
	player_boards.clear()
	player_names.clear()
	game_started = false
	game_over = false
	current_turn = 1
