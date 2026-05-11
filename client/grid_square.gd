extends Button

var coordinate: Vector2 = Vector2.ZERO
var ship_id: int = -1 # -1 means no ship is here

func set_coordinate(c: Vector2):
	coordinate = c

func mark_as_ship(id: int):
	ship_id = id
	# changing the color if the ship is places
	self_modulate = Color("ff88ff")

func mark_as_sunk():
	self_modulate = Color.DARK_RED

func mark_as_water():
	ship_id = -1
	modulate = Color("89cff0") # resetting if necessary
