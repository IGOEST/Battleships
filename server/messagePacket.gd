extends RefCounted

enum MsgType {
	# client -> server
	BOARD = 1,
	FIRE = 2,
	# server -> client
	ASSIGN_ID = 3,  # id for player assigned by server
	WAIT_FOR_PLAYER = 4, # server tells client to wait
	GAME_START = 5,
	FIRE_RESULT = 6,  # result of player's fire: hit, miss, or sunk
	YOUR_BOARD_HIT = 7,
	SHIP_SUNK = 8,
	GAME_OVER = 9,
}

#BOARD
# ships is array of: id of ship, cells it is on [0,0],[0,1]...
static func make_board(ships: Array) -> Dictionary:
	return {
		"type": MsgType.BOARD,
		"ships": ships,
	}
	
# FIRE
static func make_fire(x: int, y: int) -> Dictionary:
	return {
		"type": MsgType.FIRE,
		"x": x,
		"y": y,
	}
	
# ASSIGN_ID (1 or 2)
static func make_assign_id(player_id: int) -> Dictionary:
	return {
		"type": MsgType.ASSIGN_ID,
		"player_id": player_id,
	}
	
# WAIT_FOR_PLAYER
static func make_wait_for_player() -> Dictionary:
	return {
		"type": MsgType.WAIT_FOR_PLAYER,
	}
	
# GAME_START
#(1 or 2) which player starts game
static func make_game_start(first_turn: int) -> Dictionary:
	return {
		"type": MsgType.GAME_START,
		"first_turn": first_turn,
	}
	
# FIRE_RESULT
# outcome: hit, miss or sunk
# ship_id, -1 if missed
static func make_fire_result(x: int, y: int, outcome: String, ship_id: int = -1) -> Dictionary:
	return {
		"type": MsgType.FIRE_RESULT,
		"x": x,
		"y": y,
		"outcome": outcome,
		"ship_id": ship_id,
	}
 
# YOUR_BOARD_HIT
# outcome: hit, miss or sunk
# ship_id, -1 if missed
static func make_your_board_hit(x: int, y: int, outcome: String, ship_id: int = -1) -> Dictionary:
	return {
		"type": MsgType.YOUR_BOARD_HIT,
		"x": x,
		"y": y,
		"outcome": outcome,
		"ship_id": ship_id,
	}
	
# SHIP_SUNK is send to both players
# owner_id: whos ship sunk
# cells: cells that ship is on
static func make_ship_sunk(owner_id: int, ship_id: int, cells: Array) -> Dictionary:
	return {
		"type": MsgType.SHIP_SUNK,
		"owner_id": owner_id,
		"ship_id": ship_id,
		"cells": cells,
	}
	
# GAME_OVER
static func make_game_over(winner_id: int) -> Dictionary:
	return {
		"type": MsgType.GAME_OVER,
		"winner_id": winner_id,
	}

static func writeMsg(packet: Dictionary) -> String:
	return JSON.stringify(packet) + "\n"
	
static func readMsg(raw: String) -> Variant:
	var trimmed = raw.strip_edges()
	if trimmed.is_empty():
		return null
	var result = JSON.parse_string(trimmed)
	if result == null:
		push_warning("failed to read message: '%s'" % trimmed)
		return null
	return result
