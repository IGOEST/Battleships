extends Node

const Msg = preload("res://messagePacket.gd")

func process_message(client, message: Dictionary) -> Array:
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
 
		Msg.MsgType.BOARD:
			print("GAME: Received board from client")
			# TODO: store the board in game state
 
		_:
			print("GAME: Unknown packet type %d" % msg_type)
 
	return responses
