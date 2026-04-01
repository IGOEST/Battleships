extends Node

func process_message(client, message: String) -> Array:
	var responses := []

	var parts = message.strip_edges().split(" ", false)
	if parts.is_empty():
		return responses
	
	var command = parts[0]
	
	match command:
		"FIRE":
			if parts.size() >= 3:
				var x = parts[1]
				var y = parts[2]
				
				print("GAME: FIRE at ", x, ", ", y)
				
				# Just for now always HIT (to test the communication)
				var result = "HIT %s %s" % [x, y]
				responses.append({"client": client, "message": result})
				print("GAME: Sending action result: ", result)
			else:
				responses.append({"client": client, "message": "ERROR Invalid FIRE format"})
	
		_:
			responses.append({"client": client, "message": "ERROR Unknown command"})
	
	return responses
