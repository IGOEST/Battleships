extends Control
const Msg = preload("res://messagePacket.gd")

@onready var network = $NetworkClient
@onready var start_screen = $StartScreen
@onready var username_input = $StartScreen/StartNodes/username_input
@onready var start_button = $StartScreen/StartNodes/start_button

@onready var waiting_screen_player = $WaitingScreenPlayer
@onready var waiting_screen_server = $WaitingScreenServer

@onready var setup_phase = $SetupPhase
@onready var grid_container = $SetupPhase/MainLayout/BoardContainer/Board/MainLayout/BoardRow/GridContainer
@onready var ship_label = $SetupPhase/MainLayout/SidebarPanel/SidebarStack/ship_label
@onready var rotate_button = $SetupPhase/MainLayout/SidebarPanel/SidebarStack/rotate_button
@onready var ready_button = $SetupPhase/MainLayout/SidebarPanel/SidebarStack/ready_button

@onready var battle_screen = $BattleScreen
@onready var player_name_label = $BattleScreen/MarginContainer/Layout/TopBar/PlayerName
@onready var opponent_name_label = $BattleScreen/MarginContainer/Layout/TopBar/OpponentName
@onready var battle_grid_player = $BattleScreen/MarginContainer/Layout/MainArea/Left/PlayerBoard/Board/MainLayout/BoardRow/GridContainer

# data connected with placing ships
var grid_data = {} # dictonary with key-(x, y) and value-ship_id or nulll
var ships_to_place = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1] # ship sizes
var current_ship_index = 0
var is_horizontal: bool = true
var my_player_name: String = ""		# for storing player's name

func _ready():
	# at the beginning we are checking if server is connected, so showing waiting screen
	waiting_screen_server.show()
	start_screen.hide()
	waiting_screen_player.hide()
	setup_phase.hide()
	battle_screen.hide()
	
	_initialize_grid_coordinates()
	update_placement_label()
	update_ship_preview()
	
func connection_established():
	waiting_screen_server.hide()
	start_screen.show()
	start_button.disabled = true
	
func _initialize_grid_coordinates():
	var buttons = grid_container.get_children()
	for i in range(buttons.size()):
		var x = i%10
		var y = i/10
		var btn = buttons[i]
		btn.set_coordinate(Vector2(x,y))
		btn.pressed.connect(_on_square_pressed.bind(btn))


# UI LOGIC
# if there is text, start button enabled
func _on_username_input_text_changed(new_text: String):
	start_button.disabled = (new_text.length() == 0)

# start button pressed = showing waiting screen
func _on_start_button_pressed():
	my_player_name = username_input.text
	start_screen.hide()
	setup_phase.show()
	
	
func _on_rotate_button_pressed():
	is_horizontal = !is_horizontal
	
func update_placement_label():
	if current_ship_index < ships_to_place.size():
		ship_label.text = "Placing ship with " + str(ships_to_place[current_ship_index]) + " fields"
		ready_button.disabled = true
	else:
		ship_label.text = "All ships placed, press start"
		ready_button.disabled = false

func update_ship_preview():
	if current_ship_index >= ships_to_place.size():
		$SetupPhase/MainLayout/SidebarPanel/SidebarStack/ShipPreviewGrid.hide()
		return
		
	var current_size = ships_to_place[current_ship_index]
	var preview_rects = $SetupPhase/MainLayout/SidebarPanel/SidebarStack/ShipPreviewGrid.get_children()
	
	# looping through 4 grids
	for i in range(preview_rects.size()):
		if i < current_size:
			preview_rects[i].show()
		else:
			preview_rects[i].hide()

# PLACEMENT UI LOGIC
func _on_square_pressed(btn):
	if current_ship_index >= ships_to_place.size():
		return # = all ships places
	var size = ships_to_place[current_ship_index]
	var coords = []
	# calculating full ship coordinates, including rotation
	for i in range(size):
		var pos = btn.coordinate + (Vector2(i, 0) if is_horizontal else Vector2(0, i))
		coords.append([pos.x, pos.y])
	
	network.out_mutex.lock()	
	network.out_queue.append({
		"type": Msg.MsgType.PLACE_REQUEST,
		"coords": coords,
		"ship_id": current_ship_index
	})
	network.out_mutex.unlock()

# if server approves, marking field as a ship
func handle_place_confirm(packet):
	var coords = packet["coords"]
	var ship_id = packet["ship_id"]
	
	for c in coords:
		var target_btn = grid_container.get_child(int(c[1] * 10 + c[0]))
		target_btn.mark_as_ship(ship_id)
		grid_data[Vector2(c[0], c[1])] = ship_id
		
	current_ship_index += 1
	update_placement_label()
	update_ship_preview()

# sending msg to the server that all ships are places
func _on_ready_button_pressed():
	if current_ship_index < ships_to_place.size():
		print("CLIENT: You must place all ships first")
		return
	
	network.out_mutex.lock()
	network.out_queue.append({
		"type": Msg.MsgType.BOARD
	})
	network.out_mutex.unlock()
	
	setup_phase.hide()
	waiting_screen_player.show()
	print("CLIENT: Told the server that we are ready, waiting for opponent")
	
# BATTLE UI LOGIC
func start_battle_phase(packet: Dictionary):
	waiting_screen_player.hide()
	battle_screen.show()
	
	player_name_label.text = "Player: " + my_player_name
	opponent_name_label.text = "Opponent: Ready" # placeholder

	# copying ships to the battle screen
	_sync_ships_to_battle_grid()

func _sync_ships_to_battle_grid():
	var battle_buttons = battle_grid_player.get_children()

	for coord in grid_data:
		var index = int(coord.y * 10 + coord.x)
		var ship_id = grid_data[coord]
		
		battle_buttons[index].mark_as_ship(ship_id)
