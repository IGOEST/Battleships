extends Control
const Msg = preload("res://messagePacket.gd")

@onready var network = $NetworkClient
@onready var start_screen = $StartScreen
@onready var username_input = $StartScreen/StartNodes/username_input
@onready var start_button = $StartScreen/StartNodes/start_button

@onready var waiting_screen_player = $WaitingScreenPlayer
@onready var waiting_screen_server = $WaitingScreenServer

@onready var playerWin_screen = $PlayerWin
@onready var playerLose_screen = $PlayerLose

@onready var disconnected_screen = $ServerDisconnected

@onready var setup_phase = $SetupPhase
@onready var grid_container = $SetupPhase/MainLayout/BoardContainer/Board/MainLayout/BoardRow/GridContainer
@onready var ship_label = $SetupPhase/MainLayout/SidebarPanel/SidebarStack/ship_label
@onready var rotate_button = $SetupPhase/MainLayout/SidebarPanel/SidebarStack/rotate_button
@onready var ready_button = $SetupPhase/MainLayout/SidebarPanel/SidebarStack/ready_button

@onready var battle_screen = $BattleScreen
@onready var player_name_label = $BattleScreen/MarginContainer/Layout/TopBar/PlayerName
@onready var opponent_name_label = $BattleScreen/MarginContainer/Layout/TopBar/OpponentName
@onready var battle_grid_player = $BattleScreen/MarginContainer/Layout/MainArea/Left/PlayerBoard/Board/MainLayout/BoardRow/GridContainer
@onready var battle_grid_opponent = $BattleScreen/MarginContainer/Layout/MainArea/Right/OpponentsBoard/Board/MainLayout/BoardRow/GridContainer
@onready var turn_label = $BattleScreen/MarginContainer/Layout/TopBar/TurnIndicator

@onready var ships_list = $SetupPhase/MainLayout/SidebarPanel/SidebarStack/ListOfShips

# data connected with placing ships
var grid_data = {} # dictonary with key-(x, y) and value-ship_id or nulll
var ships_to_place = [4, 3, 2, 1] #[4, 3, 3, 2, 2, 2, 1, 1, 1, 1] # ship sizes
var current_ship_index = 0
var is_horizontal: bool = true
var my_player_name: String = ""		# for storing player's name
var opponent_name: String = ""
var my_turn: bool = false

enum ScreenState {
	WAITING_SERVER,
	START,
	SETUP,
	WAITING_PLAYER,
	BATTLE,
	DISCONNECTED
}

var current_screen: ScreenState

func _ready():
	# at the beginning we are checking if server is connected, so showing waiting screen
	show_screen(ScreenState.WAITING_SERVER)
	draw_ship_list()
	_initialize_grid_coordinates()
	update_placement_label()
	update_ship_preview()
	
func connection_established():
	show_screen(ScreenState.START)
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
	show_screen(ScreenState.SETUP)
	
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
	draw_ship_list()
	update_placement_label()
	update_ship_preview()

# sending msg to the server that all ships are places
func _on_ready_button_pressed():
	if current_ship_index < ships_to_place.size():
		print("CLIENT: You must place all ships first")
		return
	
	network.out_mutex.lock()
	network.out_queue.append({
		"type": Msg.MsgType.BOARD,
		"player_name": my_player_name
	})
	network.out_mutex.unlock()
	
	show_screen(ScreenState.WAITING_PLAYER)
	print("CLIENT: Told the server that we are ready, waiting for opponent")
	
func _on_auto_place_button_pressed():
	# list of prepared ship placement
	var test_layout = [
		[[0,0], [1,0], [2,0], [3,0]],
		[[0,2], [1,2], [2,2]],
		[[4,2], [5,2], [6,2]],
		[[0,4], [1,4]],
		[[3,4], [4,4]],
		[[6,4], [7,4]],
		[[0,6]],
		[[2,6]],
		[[4,6]],
		[[6,6]]
	]

	# clear everything
	current_ship_index = 0
	
	for ship_coords in test_layout:
		network.out_mutex.lock()
		network.out_queue.append({
			"type": Msg.MsgType.PLACE_REQUEST,
			"coords": ship_coords,
			"ship_id": current_ship_index
		})
		network.out_mutex.unlock()
		
		# waiting for server if it needs some time to process all ships in short amount of time
		await get_tree().create_timer(0.1).timeout
	
# BATTLE UI LOGIC
func start_battle_phase(packet: Dictionary):
	show_screen(ScreenState.BATTLE)
	
	if network.my_player_id == 1:
		opponent_name = packet.get("p2_name")
	else:
		opponent_name = packet.get("p1_name")
	
	player_name_label.text = "Player: " + my_player_name
	opponent_name_label.text = "Opponent: " + opponent_name

	my_turn = (packet.get("first_turn") == network.my_player_id)
	update_turn_ui()
	
	_initialize_enemy_grid()
	_sync_ships_to_battle_grid()	# copying ships to the battle screen

func update_turn_ui():
	if my_turn:
		turn_label.text = "YOUR TURN"
	else:
		turn_label.text = "WAITING FOR OPPONENT'S MOVE..."

func _sync_ships_to_battle_grid():
	var battle_buttons = battle_grid_player.get_children()

	for coord in grid_data:
		var index = int(coord.y * 10 + coord.x)
		var ship_id = grid_data[coord]
		
		battle_buttons[index].mark_as_ship(ship_id)

func _initialize_enemy_grid():
	var buttons = battle_grid_opponent.get_children()
	
	for i in range(buttons.size()):
		var x = i % 10
		var y = i / 10
		var btn = buttons[i]
		btn.set_coordinate(Vector2(x, y))
		btn.pressed.connect(_on_enemy_square_pressed.bind(btn))		# connecting to a function for firing

func _on_enemy_square_pressed(btn):
	if not my_turn:
		print("CLIENT: Wait for your turn")
		return
	
	var pos = btn.coordinate
	print("CLIENT: Firing at ", pos)
	network.send_fire(int(pos.x), int(pos.y))
	btn.disabled = true		# can't shot the same spot twice
	#my_turn = false
	#update_turn_ui()
	
func handle_fire_result(packet):
	var x = int(packet["x"])
	var y = int(packet["y"])
	var outcome = packet["outcome"]
	var btn = battle_grid_opponent.get_child(y * 10 + x)
	
	if outcome == "hit":
		btn.modulate = Color.RED
		btn.text = "X"
	else:
		btn.modulate = Color.WHITE
		btn.text = "0"
	
	#my_turn = false
	#update_turn_ui()

func handle_incoming_hit(packet):
	var x = packet["x"]
	var y = packet["y"]
	var outcome = packet["outcome"]
	var btn = battle_grid_player.get_child(y * 10 + x)
	btn.text = "X"
	
	#my_turn = true
	#update_turn_ui()

func handle_ship_sunk(packet):
	var owner_id = packet["owner_id"]
	var cells = packet["cells"]
	
	var target_grid
	
	# if opponent ship sunk -> enemy board
	if owner_id != network.my_player_id:
		target_grid = battle_grid_opponent
	else:
		target_grid = battle_grid_player
	
	for c in cells:
		var x = int(c[0])
		var y = int(c[1])
		
		var btn = target_grid.get_child(y * 10 + x)
		btn.modulate = Color.DARK_RED
		btn.text = "S"

func handle_game_over(packet):
	var winner_id = packet["winner_id"]
	
	# disable enemy grid
	for btn in battle_grid_opponent.get_children():
		btn.disabled = true
	
	if winner_id == network.my_player_id:
		turn_label.text = "YOU WIN!"
		playerWin_screen.show()
		battle_screen.hide()
	else:
		turn_label.text = "YOU LOSE!"
		playerLose_screen.show()
		battle_screen.hide()

func handle_turn_change(packet):
	var next_turn = packet["next_turn"]
	my_turn = (next_turn == network.my_player_id)
	update_turn_ui()

func handle_server_disconnect():
	show_screen(ScreenState.DISCONNECTED)

func show_screen(state: ScreenState):
	current_screen = state
	
	# hide everything first
	start_screen.hide()
	waiting_screen_player.hide()
	waiting_screen_server.hide()
	setup_phase.hide()
	battle_screen.hide()
	disconnected_screen.hide()

	# show requested screen
	match state:
		ScreenState.WAITING_SERVER:
			waiting_screen_server.show()

		ScreenState.START:
			start_screen.show()

		ScreenState.SETUP:
			setup_phase.show()

		ScreenState.WAITING_PLAYER:
			waiting_screen_player.show()

		ScreenState.BATTLE:
			battle_screen.show()

		ScreenState.DISCONNECTED:
			disconnected_screen.show()

func draw_ship_list():
	# clear old UI
	for child in ships_list.get_children():
		child.queue_free()

	# create UI rows
	for i in range(ships_to_place.size()):
		var ship_size = ships_to_place[i]

		var row = HBoxContainer.new()

		# ship label
		var label = Label.new()
		label.text = "Ship %d (size %d)" % [i + 1, ship_size]
		label.custom_minimum_size.x = 120

		row.add_child(label)

		# ship preview squares
		for j in range(ship_size):
			var rect = ColorRect.new()
			rect.custom_minimum_size = Vector2(20, 20)
			rect.color = Color(0.53, 0.43, 0.94, 1.00)

			row.add_child(rect)

		# mark placed ships
		if i < current_ship_index:
			row.modulate = Color(0.5, 0.5, 0.5)

		ships_list.add_child(row)
