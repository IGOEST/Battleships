extends Control

@onready var start_screen = $StartScreen
@onready var username_input = $StartScreen/StartNodes/username_input
@onready var start_button = $StartScreen/StartNodes/start_button

@onready var waiting_screen = $WaitingScreen

@onready var setup_phase = $SetupPhase
@onready var grid_container = $SetupPhase/MainLayout/BoardContainer/Board/MainLayout/BoardRow/GridContainer
@onready var ship_label = $SetupPhase/MainLayout/SidebarPanel/SidebarStack/ship_label
@onready var rotate_button = $SetupPhase/MainLayout/SidebarPanel/SidebarStack/rotate_button
@onready var ready_button = $SetupPhase/MainLayout/SidebarPanel/SidebarStack/ready_button

# data connected with placing ships
var grid_data = {} # dictonary with key-(x, y) and value-ship_id or nulll
var ships_to_place = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1] # ship sizes
var current_ship_index = 0
var is_horizontal: bool = true

func _ready():
	# when the game starts, only the start screen is visible
	start_screen.show()
	waiting_screen.hide()
	setup_phase.hide()
	
	# start button begins as disabled, waits for username input
	start_button.disabled = true
	
	_initialize_grid_coordinates()
	update_placement_label()
	update_ship_preview()
	
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
	start_screen.hide()
	waiting_screen.show()
	await get_tree().create_timer(2.0).timeout # placeholder
	waiting_screen.hide()
	setup_phase.show()
	
	
func _on_rotate_button_pressed():
	is_horizontal = !is_horizontal
	
func update_placement_label():
	if current_ship_index < ships_to_place.size():
		ship_label.text = "Placing ship with " + str(ships_to_place[current_ship_index]) + " fields"
	else:
		ship_label.text = "All ships placed, press start"

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

# PLACEMENT LOGIC
func _on_square_pressed(btn):
	if current_ship_index >= ships_to_place.size():
		return # = all ships places
	var size = ships_to_place[current_ship_index]
	var coords = []
	# calculating full ship coordinates, including rotation
	for i in range(size):
		if is_horizontal:
			coords.append(btn.coordinate + Vector2(i, 0)) # adding vector to create new coord with same y, new x 
		else:
			coords.append(btn.coordinate + Vector2(0, i)) # same but in different direction
	
	# if everything is okay, we are marking the field as ship		
	if is_placement_valid(coords):
		for c in coords:
			var target_btn = grid_container.get_child(int(c.y * 10 + c.x))
			target_btn.mark_as_ship(current_ship_index)
			grid_data[c] = current_ship_index
		current_ship_index += 1
		update_placement_label()
		update_ship_preview()
	else:
		print("invalid placement")
		
func is_placement_valid(coords):
	for c in coords:
		# checking if coords are out of bounds
		if c.x < 0 or c.x > 9 or c.y < 0 or c.y > 9: return false
		
		# checking if ship will overlap with another one
		
		for x_buff in [-1, 0, 1]:
			for y_buff in [-1, 0, 1]:
				var check_pos = c + Vector2(x_buff, y_buff)
				if grid_data.has(check_pos):
					return false
	return true
