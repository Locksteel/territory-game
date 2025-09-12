extends Node2D

signal territory_selected(territory: Territory)

enum FileType { PRETTY, INDEX }
var file_to_load: FileType
var maps_ready: bool = false
var map_clickable: bool = true

enum GameplayState { SETUP, PLAY, MAPFILL }
var current_state: GameplayState

var territory_setting: Territory

var map_index: Image
var map_display: Image
var map_permanent: Image
var map_texture: Texture2D

var selected_territories: Array[Territory] = []

enum CallPriority { LOW, NORM, HIGH }

@onready var REMINDER_TEXT: Label = $CanvasLayer/UI/ReminderText

# Scene templates
var player_resource_element = preload("res://scenes/templates/player_resource_element.tscn")

#var last_selected_id: int = -1

#var selected_territory: Territory


# Signal Handling
var _wait_done := false
var _wait_result: Dictionary = {}

func wait_for_continue_or_selection(continue_b: Button) -> Dictionary:
	_wait_done = false
	_wait_result = {}

	# start two coroutines
	call_deferred("_wait_continue", continue_b)
	call_deferred("_wait_selection")

	while not _wait_done:
		await get_tree().process_frame

	return _wait_result


func _finish(outcome: Dictionary) -> void:
	if not _wait_done:
		_wait_done = true
		_wait_result = outcome


func _wait_continue(continue_b: Button) -> void:
	await continue_b.pressed
	_finish({"type": "continue"})


func _wait_selection() -> void:
	var terr = await self.territory_selected
	_finish({"type": "territory", "territory": terr})



func _ready() -> void:
	$CanvasLayer/SaveLoadUI/LoadDialog.hide()
	$CanvasLayer/SaveLoadUI/LoadNew/LoadNewContainer/HBoxContainer/Continue.hide()
	$CanvasLayer/UI/CreatePlayerDialog.hide()
	
	current_state = GameplayState.SETUP
	
	
	$TerritoryManager.players.append(Player.new())
	$TerritoryManager.players[0].name = "None"
	$TerritoryManager.players[0].color = Color.WHITE

# File loading logic
func _on_load_pretty_pressed() -> void:
	file_to_load = FileType.PRETTY
	$CanvasLayer/SaveLoadUI/LoadDialog.title = "Open a Pretty Map"
	$CanvasLayer/SaveLoadUI/LoadDialog.popup_centered()

func _on_load_index_pressed() -> void:
	file_to_load = FileType.INDEX
	$CanvasLayer/SaveLoadUI/LoadDialog.title = "Open an Index Map"
	$CanvasLayer/SaveLoadUI/LoadDialog.popup_centered()

func _on_file_dialog_file_selected(path: String) -> void:
	if file_to_load == FileType.PRETTY:
		map_display = Image.load_from_file(path)
		map_permanent = map_display.duplicate()
		map_texture = ImageTexture.create_from_image(map_display)
		$CanvasLayer/PrettyMap.texture = map_texture
		$CanvasLayer/PrettyMap.visible = true
	elif file_to_load == FileType.INDEX:
		map_index = Image.load_from_file(path)
	
	if map_texture and map_index:
		$CanvasLayer/SaveLoadUI/LoadNew/LoadNewContainer/HBoxContainer/Continue.show()

func _on_continue_pressed() -> void:
	generate_territories_from_image()
	maps_ready = true
	$CanvasLayer/SaveLoadUI/LoadNew.hide()
	
	set_territory_info()
	
	$CanvasLayer/SaveLoadUI/Save.show()
	$CanvasLayer/UI.show()
	


func get_all_children(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result += get_all_children(child)
	return result

# Click detection logic
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		#print("Hovered:", get_viewport().gui_get_hovered_control().name)
		if get_viewport().gui_get_hovered_control() != null:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if map_clickable:
				var additive = event.ctrl_pressed or (current_state == GameplayState.MAPFILL)
				handle_map_click(event.position, additive)
			else:
				return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_D:
			deselect_territories()

func set_map_clickable(clickable: bool):
	map_clickable = clickable
	print("Set map_clickable to " + str(map_clickable))

# Handles map clicks, returns territory
func handle_map_click(global_pos: Vector2, additive: bool = false) -> Territory:
	# Update territories list for null owners
	for territory_id in $TerritoryManager.territories:
		var territory = $TerritoryManager.get_territory_by_id(territory_id)
		if not territory.owner:
			territory.owner = $TerritoryManager.players[0]
	
	if not maps_ready:
		return null
	
	# Get mouse position relative to map
	var local_pos = $CanvasLayer/PrettyMap.get_local_mouse_position()
	
	# Correct position based on scaling
	var tex_size = $CanvasLayer/PrettyMap.texture.get_size()
	var rect_size = $CanvasLayer/PrettyMap.size
	
	var scale_x = tex_size.x / rect_size.x
	var scale_y = tex_size.y / rect_size.y
	
	var image_pos = Vector2(local_pos.x * scale_x, local_pos.y * scale_y)
	
	image_pos.x = clamp(image_pos.x, 0, tex_size.x - 1)
	image_pos.y = clamp(image_pos.y, 0, tex_size.y - 1)
	
	# Get color of index image at position
	var color: Color = map_index.get_pixelv(image_pos)
	
	var territory_id = int(color.r * 255)
	print("Territory %s clicked" % territory_id)
	
	# Move territory editor to above click position
	$CanvasLayer/UI/TerritoryEditor.position = global_pos + Vector2(0, -$CanvasLayer/UI/TerritoryEditor.size.y)
	# Move territory inspector to above click position
	$CanvasLayer/UI/TerritoryInspector.position = global_pos + Vector2(0, -$CanvasLayer/UI/TerritoryInspector.size.y)
	
	var territory = $TerritoryManager.get_territory_by_id(territory_id)
	
	if territory_setting and current_state == GameplayState.MAPFILL and territory == territory_setting:
		return null
	
	if territory and territory in selected_territories:
		deselect_territories(territory)
		return territory
	
	if territory:
		select_territory(territory, additive)
		highlight_territory(territory_id, additive)
		return territory
	
	return null

func select_territory(territory: Territory, additive: bool = false) -> bool:
	#selected_territory = territory
	
	if not additive:
		selected_territories.clear()
	
	if selected_territories:
		$CanvasLayer/UI/TerritoryEditor/VBoxContainer/HomeBase.hide()
	else:
		$CanvasLayer/UI/TerritoryEditor/VBoxContainer/HomeBase.hide()
	
	selected_territories.append(territory)
	emit_signal("territory_selected", territory)
	#print("Territories selected: " + str(selected_territories))
	
	if selected_territories[0].owner == $TerritoryManager.players[0]:
		$CanvasLayer/UI/TerritoryEditor/VBoxContainer/HomeBase.hide()
	
	if current_state == GameplayState.SETUP:
		update_player_selector($CanvasLayer/UI/TerritoryEditor/VBoxContainer/Player/PlayerSelector)
		var selector = $CanvasLayer/UI/TerritoryEditor/VBoxContainer/Player/PlayerSelector
		var player_index = $TerritoryManager.players.find(territory.owner)
		if player_index != -1:
			selector.select(player_index)
		
		var terrain_selector = $CanvasLayer/UI/TerritoryEditor/VBoxContainer/Terrain/TerrainSelector
		var terrain_index = territory.terrain
		terrain_selector.select(terrain_index)
		
		$CanvasLayer/UI/TerritoryEditor/VBoxContainer/HomeBase.button_pressed = selected_territories[0].home_base
		
		$CanvasLayer/UI/TerritoryEditor.show()
		print("Clicked territory borders: " + str(territory.borders))
	elif current_state == GameplayState.PLAY:
		var terrain_string: String = territory.get_terrain_string()
		var home_base_string: String = "False"
		
		if territory.home_base:
			home_base_string = "True"
		
		$CanvasLayer/UI/TerritoryInspector/VBoxContainer/Terrain/Data.text = terrain_string
		$CanvasLayer/UI/TerritoryInspector/VBoxContainer/Player/Data.text = territory.owner.name
		$CanvasLayer/UI/TerritoryInspector/VBoxContainer/HomeBase/Data.text = home_base_string
		
		$CanvasLayer/UI/TerritoryInspector.show()
	elif current_state == GameplayState.MAPFILL:
		# Add here if you want to do something when selecting on map fill phase
		pass
	
	return true

func deselect_territories(territory: Territory = null):
	if territory:
		selected_territories.erase(territory)
		remove_highlights()
		for other_territory in selected_territories:
			highlight_territory(other_territory.id, true)
		if territory_setting:
			highlight_with_custom_color(territory_setting, Color.GREEN)
	else:
		selected_territories.clear()
		remove_highlights()
	
	$CanvasLayer/UI/TerritoryEditor.hide()
	$CanvasLayer/UI/TerritoryInspector.hide()

func set_territory_info() -> void:
	var prev_state: GameplayState = current_state
	current_state = GameplayState.MAPFILL
	
	deselect_territories()
	
	$CanvasLayer/UI/TerritorySetup/VBoxContainer/Label.text = "Select Bordering Territories"
	$CanvasLayer/UI/TerritorySetup.show()
	
	for territory_id in $TerritoryManager.territories:
		var territory: Territory = $TerritoryManager.get_territory_by_id(territory_id)
		territory_setting = territory
		highlight_with_custom_color(territory, Color.GREEN)
		
		for sub_id in $TerritoryManager.territories:
			var sub_territory: Territory = $TerritoryManager.get_territory_by_id(sub_id)
			if territory.id in sub_territory.borders:
				select_territory(sub_territory, true)
				highlight_territory(sub_id, true)
		
		while true:
			await $CanvasLayer/UI/TerritorySetup/VBoxContainer/Done.pressed
			if selected_territories:
				break
			REMINDER_TEXT.show_message("Please select all bordering territories")
		
		territory.terrain = $CanvasLayer/UI/TerritorySetup/VBoxContainer/Terrain/TerrainSelector.get_selected_id()
		territory.fortification = $CanvasLayer/UI/TerritorySetup/VBoxContainer/Fortification/FortificationBox.value
		for selected_territory: Territory in selected_territories:
			territory.borders.append(selected_territory.id)
		deselect_territories()
		
		print("Set territory %s traits:\n*Terrain: %s\n*Fortification: %s\n*Bordering Territories: %s" %
			  [territory.id, territory.get_terrain_string(), str(territory.fortification), str(territory.borders)])
	
	current_state = prev_state
	territory_setting = null
	$CanvasLayer/UI/TerritorySetup.hide()

func _on_home_base_toggled(toggled_on: bool) -> void:
	if toggled_on and not selected_territories[0].home_base:
		for territory_id in $TerritoryManager.territories:
			var territory = $TerritoryManager.get_territory_by_id(territory_id)
			if territory.owner == selected_territories[0].owner and territory.home_base:
				REMINDER_TEXT.show_message("Player %s already has a home base" % territory.owner.name)
				$CanvasLayer/UI/TerritoryEditor/VBoxContainer/HomeBase.button_pressed = false
				return
	return

func _on_apply_pressed() -> void:
	#if not selected_territory:
		#return
	if not selected_territories:
		return
	
	$CanvasLayer/UI/TerritoryEditor.hide()
	
	# Set home base to new value
	selected_territories[0].home_base = $CanvasLayer/UI/TerritoryEditor/VBoxContainer/HomeBase.button_pressed
	
	# Revert to blank texture after apply
	map_display.copy_from(map_permanent)
	
	var fortification_box = $CanvasLayer/UI/TerritoryEditor/VBoxContainer/Fortification/FortificationBox
	var fortification_value = fortification_box.value
	
	var player_selector = $CanvasLayer/UI/TerritoryEditor/VBoxContainer/Player/PlayerSelector
	var player_selected_index = player_selector.get_selected_id()
	
	var terrain_selector = $CanvasLayer/UI/TerritoryEditor/VBoxContainer/Terrain/TerrainSelector
	var terrain_selected_index = terrain_selector.get_selected_id()
	
	for cur_territory in selected_territories:
		cur_territory.fortification = fortification_value
		cur_territory.owner = $TerritoryManager.players[player_selected_index]
		cur_territory.terrain = terrain_selected_index
		
		print("Updated territory: ", cur_territory.id, " owner: ", cur_territory.owner.name, " terrain: ", cur_territory.terrain)
		
		highlight_with_custom_color(cur_territory, cur_territory.owner.color)
	
	map_permanent.copy_from(map_display)
	
	selected_territories.clear()

func highlight_with_custom_color(territory: Territory, new_color: Color):	
	for pixel in territory.pixels:
		var base_color = map_display.get_pixelv(pixel)
		map_display.set_pixelv(pixel, new_color)
	
	map_texture.update(map_display)


func highlight_territory(territory_id: int, additive: bool = false):
	var territory = $TerritoryManager.get_territory_by_id(territory_id)
	var color: Color = Color.LIGHT_YELLOW
	
	if current_state == GameplayState.MAPFILL:
		color = Color.YELLOW
	
	if not additive:
		map_display.copy_from(map_permanent)
	
	#if last_selected_id != -1:
		#map_display.copy_from(map_permanent)
	#
	## Backup original
	#map_permanent = map_display.duplicate()
	
	highlight_with_custom_color(territory, territory.owner.color.lerp(color, 0.5))
	
	#last_selected_id = territory_id

func remove_highlights():
	map_display.copy_from(map_permanent)
	map_texture.update(map_display)


func generate_territories_from_image(loading: bool = false):
	var width = map_index.get_width()
	var height = map_index.get_height()
	
	var pixel_map: Dictionary = {}
	
	for y in range(height):
		for x in range(width):
			var color = map_index.get_pixel(x, y)
			var id = int(color.r * 255)
			
			if id <= 0:
				continue
			
			if not pixel_map.has(id):
				pixel_map[id] = PackedVector2Array()
			
			pixel_map[id].append(Vector2i(x, y))
	
	var terr_count = 0
	for id in pixel_map.keys():
		var territory = Territory.new()
		territory.id = id
		territory.owner = $TerritoryManager.players[0]
		territory.pixels = pixel_map[id]
		
		$TerritoryManager.territories[id] = territory
		terr_count += 1
	
	print("Generated %s territories" % terr_count)


func _on_save_pressed() -> void:
	$CanvasLayer/SaveLoadUI/SaveDialog.popup_centered()

func _on_save_dialog_file_selected(path: String) -> void:
	if not (path.to_lower().ends_with(".tres") or path.to_lower().ends_with(".res")):
		path += ".tres"
	
	if $TerritoryManager.save_game_state(path, map_display, map_index):
		$CanvasLayer/SaveLoadUI/SaveSuccess.show_message()

func _on_load_game_pressed() -> void:
	$CanvasLayer/SaveLoadUI/LoadStateDialog.popup_centered()

func _on_load_state_dialog_file_selected(path: String) -> void:
	var state: GameState = $TerritoryManager.load_game_state(path)
	if state is not GameState:
		return
	
	map_display = state.map_display
	map_permanent = map_display.duplicate()
	map_texture = ImageTexture.create_from_image(map_display)
	$CanvasLayer/PrettyMap.texture = map_texture
	$CanvasLayer/PrettyMap.visible = true
	map_index = state.map_index
	
	#generate_territories_from_image()
	maps_ready = true
	$CanvasLayer/SaveLoadUI/MainLoad.hide()
	$CanvasLayer/SaveLoadUI/Save.show()
	$CanvasLayer/UI.show()


func update_player_selector(selector: OptionButton, skip_none: bool = false):
	selector.clear()
	for player in $TerritoryManager.players:
		if skip_none and player == $TerritoryManager.players[0]:
			continue
		selector.add_item(player.name)

# Update given selector
# If player and territory is passed, show all units on territory belonging to player
# Otherwise if player is passed, show all units belonging to player
# Otherwise if territory is passed, show all units on that territory
# Otherwise update with all units
# If show_owner is true, append owner to front of unit (ignored if player is null)
# Shows only units that fulfill passed condition
func update_unit_selector(
	selector: OptionButton,
	player: Player = null,
	territory: Territory = null,
	show_owner: bool = false,
	condition: Callable = func(unit: Unit): return true
):
	selector.clear()
	
	var unit_list: Array[Unit] = []
	if player:
		unit_list = player.units_owned
	else:
		unit_list = $TerritoryManager.units
	
	for unit: Unit in unit_list:
		if territory and unit.current_territory != territory:
			continue
		if not condition.call(unit):
			continue
		
		var name: String = ""
		if show_owner:
			name += $TerritoryManager.get_unit_owner(unit).name
			name += ": "
		name += unit.name
		
		selector.add_item(name, unit.id)
	
	#if player and territory:
		#for unit: Unit in player.units_owned:
			#var name: String = ""
			#if unit.current_territory == territory and condition.call(unit):
				#if show_owner:
					#name += (player.name + ": ")
				#name += unit.name
				#selector.add_item(name, unit.id)
	#elif player:
		#for unit: Unit in player.units_owned:
			#if condition.call(unit):
				#var name: String = ""
				#if show_owner:
					#name += (player.name + ": ")
				#name += unit.name
				#selector.add_item(name, unit.id)
	#elif territory:
		#for unit: Unit in $TerritoryManager.units:
			#var name: String = ""
			#if unit.current_territory == territory and condition.call(unit):
				#selector.add_item(unit.name, unit.id)
	#else:
		#for unit: Unit in $TerritoryManager.units:
			#if condition.call(unit):
				#selector.add_item(unit.name, unit.id)


func _on_edit_players_pressed() -> void:
	$CanvasLayer/UI/CreatePlayerDialog.popup_centered()


func _on_create_pressed() -> void:
	if $CanvasLayer/UI/CreatePlayerDialog/VBoxContainer/PlayerName.text == "" or $CanvasLayer/UI/CreatePlayerDialog/VBoxContainer/PlayerColor.color == Color.WHITE:
		return
	
	var new_player = Player.new()
	new_player.name = $CanvasLayer/UI/CreatePlayerDialog/VBoxContainer/PlayerName.text
	new_player.color = $CanvasLayer/UI/CreatePlayerDialog/VBoxContainer/PlayerColor.color
	
	$TerritoryManager.add_player(new_player)
	
	update_player_selector($CanvasLayer/UI/TerritoryEditor/VBoxContainer/Player/PlayerSelector)
	$CanvasLayer/UI/CreatePlayerDialog.hide()

func _on_cancel_pressed() -> void:
	$CanvasLayer/UI/CreatePlayerDialog.hide()


func _on_create_player_dialog_close_requested() -> void:
	$CanvasLayer/UI/CreatePlayerDialog.hide()

func _on_new_game_pressed() -> void:
	$CanvasLayer/SaveLoadUI/MainLoad.hide()
	$CanvasLayer/SaveLoadUI/LoadNew.show()

func _on_back_pressed() -> void:
	$CanvasLayer/SaveLoadUI/LoadNew.hide()
	$CanvasLayer/SaveLoadUI/MainLoad.show()





# Gameplay Management

var current_player: Player

func _on_play_button_pressed() -> void:
	if $TerritoryManager.players.size() < 2:
		REMINDER_TEXT.show_message("Add at least one player to play")
		return
	
	$CanvasLayer/UI/PlayButton.hide()
	deselect_territories()
	set_map_clickable(false)
	
	update_player_selector($CanvasLayer/UI/ActionPanel/VBoxContainer/Player/PlayerSelector, true)
	current_player = $TerritoryManager.players[1]
	$CanvasLayer/UI/ActionPanel.visible = true

func set_player_actions(player: Player) -> void:
	var action_dict: Dictionary = {}
	
	action_dict["anonymous"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/Messages/HBoxContainer/Anonymous.button_pressed
	action_dict["signed"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/Messages/HBoxContainer/Signed.button_pressed
	action_dict["attack_territory"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/AttackDefend/Attack/AttackTerritory.button_pressed
	action_dict["attack_unit"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/AttackDefend/Attack/AttackUnit.button_pressed
	action_dict["fortify"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/AttackDefend/Defend/Fortify.button_pressed
	action_dict["defend_territory"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/AttackDefend/Defend/DefendTerritory.button_pressed
	action_dict["defend_unit"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/AttackDefend/Defend/DefendUnit.button_pressed
	action_dict["recruit"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/Recruitment/HBoxContainer/Recruit.button_pressed
	action_dict["move"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/MoveRegroup/HBoxContainer/Move.button_pressed
	action_dict["regroup"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/MoveRegroup/HBoxContainer/Regroup.button_pressed
	action_dict["station"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/Stationing/HBoxContainer/Station.button_pressed
	action_dict["unstation"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/Stationing/HBoxContainer/Unstation.button_pressed
	action_dict["band"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/Banding/HBoxContainer/Band.button_pressed
	action_dict["assess"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/Spying/HBoxContainer/Assess.button_pressed
	action_dict["uncover"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/Spying/HBoxContainer/Uncover.button_pressed
	action_dict["sign"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/Treaties/HBoxContainer/Sign.button_pressed
	action_dict["break"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/Treaties/HBoxContainer/Break.button_pressed
	action_dict["request"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/ResourceRequests/HBoxContainer/Request.button_pressed
	action_dict["deny"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/ResourceRequests/HBoxContainer/Deny.button_pressed
	action_dict["fulfill"] = $CanvasLayer/UI/ActionPanel/VBoxContainer/ResourceRequests/HBoxContainer/Fulfill.button_pressed
	
	player.actions = action_dict
	
	return

func fill_player_actions(player: Player) -> void:
	player.actions["anonymous"] = false
	player.actions["signed"] = false
	player.actions["attack_territory"] = false
	player.actions["attack_unit"] = false
	player.actions["fortify"] = false
	player.actions["defend_territory"] = false
	player.actions["defend_unit"] = false
	player.actions["recruit"] = false
	player.actions["move"] = false
	player.actions["regroup"] = false
	player.actions["station"] = false
	player.actions["unstation"] = false
	player.actions["band"] = false
	player.actions["assess"] = false
	player.actions["uncover"] = false
	player.actions["sign"] = false
	player.actions["break"] = false
	player.actions["request"] = false
	player.actions["deny"] = false
	player.actions["fulfill"] = false

func _on_player_selector_action_item_selected(index: int) -> void:
	set_player_actions(current_player)
	current_player = $TerritoryManager.players[index + 1]
	
	if current_player.actions.is_empty():
		fill_player_actions(current_player)
	
	$CanvasLayer/UI/ActionPanel/VBoxContainer/Messages/HBoxContainer/Anonymous.button_pressed = current_player.actions["anonymous"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/Messages/HBoxContainer/Signed.button_pressed = current_player.actions["signed"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/AttackDefend/Attack/AttackTerritory.button_pressed = current_player.actions["attack_territory"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/AttackDefend/Attack/AttackUnit.button_pressed = current_player.actions["attack_unit"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/AttackDefend/Defend/Fortify.button_pressed = current_player.actions["fortify"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/AttackDefend/Defend/DefendTerritory.button_pressed = current_player.actions["defend_territory"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/AttackDefend/Defend/DefendUnit.button_pressed = current_player.actions["defend_unit"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/Recruitment/HBoxContainer/Recruit.button_pressed = current_player.actions["recruit"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/MoveRegroup/HBoxContainer/Move.button_pressed = current_player.actions["move"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/MoveRegroup/HBoxContainer/Regroup.button_pressed = current_player.actions["regroup"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/Stationing/HBoxContainer/Station.button_pressed = current_player.actions["station"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/Stationing/HBoxContainer/Unstation.button_pressed = current_player.actions["unstation"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/Banding/HBoxContainer/Band.button_pressed = current_player.actions["band"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/Spying/HBoxContainer/Assess.button_pressed = current_player.actions["assess"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/Spying/HBoxContainer/Uncover.button_pressed = current_player.actions["uncover"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/Treaties/HBoxContainer/Sign.button_pressed = current_player.actions["sign"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/Treaties/HBoxContainer/Break.button_pressed = current_player.actions["break"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/ResourceRequests/HBoxContainer/Request.button_pressed = current_player.actions["request"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/ResourceRequests/HBoxContainer/Deny.button_pressed = current_player.actions["deny"]
	$CanvasLayer/UI/ActionPanel/VBoxContainer/ResourceRequests/HBoxContainer/Fulfill.button_pressed = current_player.actions["fulfill"]

func _on_continue_action_pressed() -> void:
	$CanvasLayer/UI/ActionPanel.visible = false
	set_player_actions(current_player)
	
	current_state = GameplayState.PLAY
	set_map_clickable(true)
	
	turn()
	


# Go to the next turn, returns new turn number or -1 if error
func turn() -> int:
	var boxes := {}
	
	for child in $CanvasLayer/UI/ActionInfo/VBoxContainer.get_children():
		if child is VBoxContainer:
			boxes[child.name] = child
	
	# Action info window
	var action_info: Window = $CanvasLayer/UI/ActionInfo
	# Action info main label
	var action_info_label: Label = $CanvasLayer/UI/ActionInfo/VBoxContainer/Label
	# Action info element containers
	var text_edit: TextEdit = $CanvasLayer/UI/ActionInfo/VBoxContainer/TextEdit
	var continue_b: Button = $CanvasLayer/UI/ActionInfo/VBoxContainer/HBoxContainer/Continue
	
	$TerritoryManager.cleanup()
	
	# For each player
	for player: Player in $TerritoryManager.players:
		# For each entry in that player's actions
		for key in player.actions.keys():
			var entry: bool = player.actions[key]
			
			# Function call to append to action queue
			var calls: Array[Callable]
			# Whether function call is priority (defensive)
			var priority: CallPriority
			
			# If that action is set to false, ignore
			if not entry:
				action_info.hide()
				continue
			
			for box in boxes.values():
				box.hide()
			text_edit.hide()
			action_info.popup_centered()
			
			# Based on action, get additional info and determine which Callable to append
			match key:
				"anonymous", "signed":
					var destination: Player
					var message: String
					var anonymous: bool = false
					
					if key == "anonymous":
						anonymous = true
						action_info_label.text = "%s: Send an Anonymous Message" % player.name
					else:
						action_info_label.text = "%s: Send a Signed Message" % player.name
					
					
					update_player_selector(boxes["Player"].get_node("PlayerSelector"), true)
					
					boxes["Player"].show()
					text_edit.show()
					
					await continue_b.pressed
					
					var dest_index: int = boxes["Player"].get_node("PlayerSelector").get_selected_id() + 1
					destination = $TerritoryManager.players[dest_index]
					message = text_edit.text
					
					# Send Message
					#player.send_message(destination, message, anonymous)
					calls.append(Callable(player, "send_message").bind(destination, message, anonymous))
					priority = CallPriority.NORM
					
					print("Sent message from %s to %s:\n%s\nFrom: %s" %
						  [player.name, destination.name, message, "Anonymous" if anonymous else player.name])
				"attack_territory":
					var attacker: Unit
					var target: Territory

					# Check if player has any units
					if not player.units_owned:
						REMINDER_TEXT.show_message("You can't attack with no units!")
						continue

					action_info_label.text = "%s: Attack a Territory" % player.name
					boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Choose a Territory"
					boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").hide()

					# Show UI
					boxes["FriendlyUnit"].show()
					boxes["Territory"].show()
					action_info.show()

					while true:
						var outcome = await wait_for_continue_or_selection(continue_b)

						if outcome.type == "territory":
							var terr: Territory = outcome.territory
							# Disallow selecting own territory
							if terr.owner == player:
								REMINDER_TEXT.show_message("You cannot attack your own territory")
								continue
							
							# Disallow attacking territory with no units
							var units_present: bool = false
							for unit: Unit in player.units_owned:
								if unit.current_territory == terr:
									units_present = true
									break
							if not units_present:
								REMINDER_TEXT.show_message("You have no units on that territory")
								continue

							target = terr
							boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Territory " + str(target.id)

							# Populate friendly unit selector
							update_unit_selector(boxes["FriendlyUnit"].get_node("FriendlyUnitSelector"), player)
							boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").show()

						elif outcome.type == "continue":
							if target:
								var selected_id: int = boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").get_selected_id()
								var selected_name: String = boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").get_item_text(selected_id)

								# Find attacker
								attacker = $TerritoryManager.get_unit_by_name(selected_name, player)

								if attacker:
									#attacker.attack_territory(target)
									calls.append(Callable(attacker, "attack_territory").bind(target))
									priority = CallPriority.NORM
									
									print("Unit '%s' attacks territory %s owned by %s" % [attacker.name, target.id, target.owner.name])
									break
								else:
									REMINDER_TEXT.show_message("Please select a unit before continuing")
							else:
								REMINDER_TEXT.show_message("Please select a territory before continuing")
				"attack_unit":
					var attacker: Unit
					var target: Unit
					var territory: Territory

					# Check if player has any units
					if not player.units_owned:
						REMINDER_TEXT.show_message("You can't attack with no units!")
						continue

					action_info_label.text = "%s: Attack a Unit" % player.name
					boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Choose a Territory"
					boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").hide()
					boxes["EnemyUnit"].get_node("EnemyUnitSelector").hide()

					# Show UI
					boxes["FriendlyUnit"].show()
					boxes["EnemyUnit"].show()
					boxes["Territory"].show()
					action_info.show()

					while true:
						var outcome = await wait_for_continue_or_selection(continue_b)

						if outcome.type == "territory":
							var terr: Territory = outcome.territory
							
							# Check if there are any units at all
							var has_units := false
							for unit: Unit in $TerritoryManager.units:
								if unit.current_territory == territory:
									has_units = true
									break
							if not has_units:
								REMINDER_TEXT.show_message("That territory has no units")
								continue
							
							territory = terr

							boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Territory " + str(territory.id)

							# Populate unit selectors
							update_unit_selector(boxes["FriendlyUnit"].get_node("FriendlyUnitSelector"), player, territory, true)
							# Reset enemy selector
							boxes["EnemyUnit"].get_node("EnemyUnitSelector").clear()
							for enemy in $TerritoryManager.players:
								if enemy == player:
									continue
								update_unit_selector(boxes["EnemyUnit"].get_node("EnemyUnitSelector"), enemy, territory, true)

							boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").show()
							boxes["EnemyUnit"].get_node("EnemyUnitSelector").show()

						elif outcome.type == "continue":
							if not territory:
								REMINDER_TEXT.show_message("Select a territory first")
								continue

							var friendly_id: int = boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").get_selected_id()
							var friendly_name: String = boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").get_item_text(friendly_id)
							var enemy_id: int = boxes["EnemyUnit"].get_node("EnemyUnitSelector").get_selected_id()
							var enemy_name: String = boxes["EnemyUnit"].get_node("EnemyUnitSelector").get_item_text(enemy_id)

							if friendly_name == "" or enemy_name == "":
								REMINDER_TEXT.show_message("Select both a friendly and enemy unit before continuing")
								continue

							# Find attacker
							attacker = $TerritoryManager.get_unit_by_name(friendly_name, player)

							# Find target + owner
							var enemy_owner: Player
							for other_player: Player in $TerritoryManager.players:
								for other_unit in other_player.units_owned:
									if other_unit.name == enemy_name:
										target = other_unit
										enemy_owner = other_player
										break

							if attacker and target and enemy_owner:
								#attacker.attack_unit(target)
								calls.append(Callable(attacker, "attack_unit").bind(target))
								priority = CallPriority.NORM
								
								print("Unit '%s' attacks unit '%s' owned by %s" % [attacker.name, target.name, enemy_owner.name])
								break
							else:
								REMINDER_TEXT.show_message("Invalid unit selection, try again")
				"fortify":
						var territory: Territory

						action_info_label.text = "%s: Fortify a Territory" % player.name
						boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Choose a Territory"
						boxes["Territory"].show()

						action_info.show()

						while true:
							var outcome = await wait_for_continue_or_selection(continue_b)

							if outcome.type == "territory":
								var terr: Territory = outcome.territory
								if terr.owner != player:
									REMINDER_TEXT.show_message("%s does not own that territory" % player.name)
									continue
								elif player.resources < terr.fortification:
									REMINDER_TEXT.show_message("%s does not have enough resources to fortify that territory" % player.name)
									continue
								
								territory = terr
								boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Territory " + str(territory.id)

							elif outcome.type == "continue":
								if territory:
									#territory.fortify()
									calls.append(Callable(territory, "fortify"))
									priority = CallPriority.HIGH
									
									print("Territory %s fortified" % territory.id)
									break
								else:
									REMINDER_TEXT.show_message("Select a territory before continuing")
				"defend_territory":
					var target: Territory

					action_info_label.text = "%s: Defend a Territory" % player.name
					boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Choose a Territory"

					# Show UI
					boxes["Territory"].show()
					action_info.show()

					while true:
						var outcome = await wait_for_continue_or_selection(continue_b)

						if outcome.type == "territory":
							var terr: Territory = outcome.territory
							# Disallow selecting own territory
							if terr.owner != player:
								REMINDER_TEXT.show_message("You can only defend your own territories")
								continue

							target = terr
							boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Territory " + str(target.id)

						elif outcome.type == "continue":
							if target:
								#target.defend()
								calls.append(Callable(target, "defend"))
								priority = CallPriority.HIGH
								
								print("Territory %s, owned by %s, defends" % [target.id, target.owner.name])
								break
							else:
								REMINDER_TEXT.show_message("Please select a territory before continuing")
				"defend_unit":
					var target: Unit
					var territory: Territory

					# Check if player has any units
					if not player.units_owned:
						REMINDER_TEXT.show_message("You can't defend with no units!")
						continue

					action_info_label.text = "%s: Defend a Unit" % player.name
					boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Choose a Territory"
					boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").hide()

					# Show UI
					boxes["FriendlyUnit"].show()
					boxes["Territory"].show()
					action_info.show()

					while true:
						var outcome = await wait_for_continue_or_selection(continue_b)

						if outcome.type == "territory":
							var terr: Territory = outcome.territory
							
							# Check if there are any units at all
							var has_units := false
							for unit: Unit in $TerritoryManager.units:
								if unit.current_territory == territory:
									has_units = true
									break
							if not has_units:
								REMINDER_TEXT.show_message("That territory has no units")
								continue
							
							territory = terr

							boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Territory " + str(territory.id)

							# Populate unit selectors
							update_unit_selector(boxes["FriendlyUnit"].get_node("FriendlyUnitSelector"), player, territory, true)

							boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").show()

						elif outcome.type == "continue":
							if not territory:
								REMINDER_TEXT.show_message("Select a territory first")
								continue

							var friendly_id: int = boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").get_selected_id()
							var friendly_name: String = boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").get_item_text(friendly_id)

							if friendly_name == "":
								REMINDER_TEXT.show_message("Select a friendly unit before continuing")
								continue

							# Find attacker
							target = $TerritoryManager.get_unit_by_name(friendly_name, player)

							if target:
								#attacker.attack_unit(target)
								calls.append(Callable(target, "defend"))
								priority = CallPriority.HIGH
								
								print("Unit '%s', owned by %s, defends" % [target.name, player.name])
								break
							else:
								REMINDER_TEXT.show_message("Invalid unit selection, try again")
				"recruit":
					var territory: Territory

					action_info_label.text = "%s: Recruit a Unit" % player.name
					boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Choose a Territory"

					# Show UI
					boxes["Territory"].show()
					boxes["UnitType"].show()
					boxes["Name"].show()
					action_info.show()

					while true:
						var outcome = await wait_for_continue_or_selection(continue_b)
						
						var unit_type: Unit.UnitType = boxes["UnitType"].get_node("UnitTypeSelector").get_selected_id()
						var name: String = boxes["Name"].get_node("NameText").text

						if outcome.type == "territory":
							var terr: Territory = outcome.territory
							territory = terr

							boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Territory " + str(territory.id)

						elif outcome.type == "continue":
							# Check if territory selected
							if not territory:
								REMINDER_TEXT.show_message("Select a territory first")
								continue
							# Check if player has enough resources
							if player.resources < Unit.COST_DICT[unit_type]:
								REMINDER_TEXT.show_message("You don't have enough resources for that unit")
								continue
							# Check if unit type selected
							if unit_type is not Unit.UnitType:
								REMINDER_TEXT.show_message("Select a unit type before continuing")
								continue
							# Check if name entered and is unique
							if not (name and $TerritoryManager.unique_name(name)):
								REMINDER_TEXT.show_message("Enter a unique name")
								continue
							
							
							if unit_type and territory and name:
								calls.append(Callable($TerritoryManager, "recruit_troop").bind(player, unit_type, territory, name))
								priority = CallPriority.NORM
								
								print("Unit '%s' of type %s is recruited by %s" % [name, Unit.TYPE_DICT[unit_type], player.name])
								break
							else:
								print("Invalid recruitment")
								continue
				"move":
					var target: Unit
					var source: Territory
					var destination: Territory

					# Check if player has any units
					if not player.units_owned:
						REMINDER_TEXT.show_message("You have no units to move!")
						continue

					action_info_label.text = "%s: Move a Unit" % player.name
					boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Choose a Territory"
					boxes["Territory"].get_node("Territory2/SelectedTerritory").text = "Choose a Territory"
					boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").hide()

					# Show UI
					boxes["FriendlyUnit"].show()
					boxes["Territory"].show()
					boxes["Territory"].get_node("Territory1/Enable").show()
					boxes["Territory"].get_node("Territory2/Enable").show()
					action_info.show()

					while true:
						var outcome = await wait_for_continue_or_selection(continue_b)

						if outcome.type == "territory":
							var terr: Territory = outcome.territory
							if boxes["Territory"].get_node("Territory1/Enable").button_pressed:
								source = terr
							elif boxes["Territory"].get_node("Territory2/Enable").button_pressed:
								destination = terr
							else:
								REMINDER_TEXT.show_message("Select source or destination before choosing a territory")
								continue

							# Check if there are any units at all
							var has_units := false
							for unit: Unit in $TerritoryManager.units:
								if unit.current_territory == terr:
									has_units = true
									break
							if not has_units:
								REMINDER_TEXT.show_message("That territory has no units")
								continue
							
							if boxes["Territory"].get_node("Territory1/Enable").button_pressed:
								boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Territory " + str(source.id)
								
								update_unit_selector(boxes["FriendlyUnit"].get_node("FriendlyUnitSelector"), player, source, true,
									func(unit: Unit) -> bool: return not unit.stationed)
								boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").show()
							
							elif boxes["Territory"].get_node("Territory2/Enable").button_pressed:
								boxes["Territory"].get_node("Territory2/SelectedTerritory").text = "Territory " + str(destination.id)

						elif outcome.type == "continue":
							# Check if source and destination selected
							if not (source and destination):
								REMINDER_TEXT.show_message("Select a source and destination")
								continue
							
							# Check if territories border
							if not (destination.id in source.borders and source.id in destination.borders):
								REMINDER_TEXT.show_message("Selected territories do not border")
								continue
							elif destination.id in source.borders or source.id in destination.borders:
								REMINDER_TEXT.show_message("Selected territories do not border")
								print("Bordering error, inconsistent borders")
								continue

							var friendly_id: int = boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").get_selected_id()
							var friendly_name: String = boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").get_item_text(friendly_id)

							if friendly_name == "":
								REMINDER_TEXT.show_message("Select a friendly unit before continuing")
								continue

							# Find unit to move
							target = $TerritoryManager.get_unit_by_name(friendly_name, player)

							if true: #target:
								calls.append(Callable(target, "move").bind(destination))
								priority = CallPriority.LOW
								
								print("Unit '%s', owned by %s, moves from territory %s to %s" % [target.name, player.name, source.id, destination.id])
								
								boxes["Territory"].get_node("Territory1/Enable").hide()
								boxes["Territory"].get_node("Territory2/Enable").hide()
								
								break
							else:
								REMINDER_TEXT.show_message("Invalid unit selection, try again")
				"regroup":
					var target: Unit
					var territory: Territory

					# Check if player has any units
					if not player.units_owned:
						REMINDER_TEXT.show_message("You can't regroup with no units!")
						continue

					action_info_label.text = "%s: Regroup a Unit" % player.name
					boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Choose a Territory"
					boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").hide()

					# Show UI
					boxes["FriendlyUnit"].show()
					boxes["Territory"].show()
					action_info.show()

					while true:
						var outcome = await wait_for_continue_or_selection(continue_b)

						if outcome.type == "territory":
							var terr: Territory = outcome.territory
							
							# Check if there are any units at all
							var has_units := false
							for unit: Unit in $TerritoryManager.units:
								if unit.current_territory == territory:
									has_units = true
									break
							if not has_units:
								REMINDER_TEXT.show_message("That territory has no units")
								continue
							
							territory = terr

							boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Territory " + str(territory.id)

							# Populate unit selectors
							update_unit_selector(boxes["FriendlyUnit"].get_node("FriendlyUnitSelector"), player, territory, true)

							boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").show()

						elif outcome.type == "continue":
							if not territory:
								REMINDER_TEXT.show_message("Select a territory first")
								continue

							var friendly_id: int = boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").get_selected_id()
							var friendly_name: String = boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").get_item_text(friendly_id)

							if friendly_name == "":
								REMINDER_TEXT.show_message("Select a friendly unit before continuing")
								continue

							# Find unit
							target = $TerritoryManager.get_unit_by_name(friendly_name, player)

							if target:
								#attacker.attack_unit(target)
								calls.append(Callable(target, "regroup"))
								priority = CallPriority.LOW
								
								print("Unit '%s', owned by %s, regroups" % [target.name, player.name])
								break
							else:
								REMINDER_TEXT.show_message("Invalid unit selection, try again")
				"station":
					var target: Unit
					var territory: Territory

					# Check if player has any units
					if not player.units_owned:
						REMINDER_TEXT.show_message("You can't station with no units!")
						continue

					action_info_label.text = "%s: Station a Territory" % player.name
					boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Choose a Territory"
					boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").hide()

					# Show UI
					boxes["FriendlyUnit"].show()
					boxes["Territory"].show()
					action_info.show()

					while true:
						var outcome = await wait_for_continue_or_selection(continue_b)

						if outcome.type == "territory":
							var terr: Territory = outcome.territory
							
							# Check if player owns selected territory
							if terr.owner != player:
								REMINDER_TEXT.show_message("You can only station your own territories")
								continue
							
							# Check if there are any units at all
							var has_units := false
							for unit: Unit in $TerritoryManager.units:
								if unit.current_territory == terr:
									has_units = true
									break
							if not has_units:
								REMINDER_TEXT.show_message("That territory has no units")
								continue
							
							territory = terr

							boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Territory " + str(territory.id)

							# Populate unit selectors
							update_unit_selector(boxes["FriendlyUnit"].get_node("FriendlyUnitSelector"), player, territory, true,
								func(unit: Unit): return not unit.stationed)

							boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").show()

						elif outcome.type == "continue":
							if not territory:
								REMINDER_TEXT.show_message("Select a territory first")
								continue

							var friendly_id: int = boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").get_selected_id()
							var friendly_name: String = boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").get_item_text(friendly_id)

							if friendly_name == "":
								REMINDER_TEXT.show_message("Select a friendly unit before continuing")
								continue

							# Find friendly unit
							target = $TerritoryManager.get_unit_by_name(friendly_name, player)

							if target:
								calls.append(Callable(target, "station").bind(territory))
								priority = CallPriority.HIGH
								
								print("Unit '%s', owned by %s, defends" % [target.name, player.name])
								break
							else:
								REMINDER_TEXT.show_message("Invalid unit selection, try again")
				"unstation":
					var target: Unit
					var territory: Territory

					# Check if player has any units
					if not player.units_owned:
						REMINDER_TEXT.show_message("You can't unstation with no units!")
						continue

					action_info_label.text = "%s: Unstation a Unit" % player.name
					boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Choose a Territory"
					boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").hide()

					# Show UI
					boxes["FriendlyUnit"].show()
					boxes["Territory"].show()
					action_info.show()

					while true:
						var outcome = await wait_for_continue_or_selection(continue_b)

						if outcome.type == "territory":
							var terr: Territory = outcome.territory
							
							# Check if player owns selected territory
							if terr.owner != player:
								REMINDER_TEXT.show_message("You can only unstation on your own territories")
								continue
							
							# Check if there are any stationed units at all
							var has_units := false
							for unit: Unit in $TerritoryManager.units:
								if unit.current_territory == terr and unit.stationed:
									has_units = true
									break
							if not has_units:
								REMINDER_TEXT.show_message("That territory has no stationed units")
								continue
							
							territory = terr

							boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Territory " + str(territory.id)

							# Populate unit selectors
							update_unit_selector(boxes["FriendlyUnit"].get_node("FriendlyUnitSelector"), player, territory, true,
								func(unit: Unit): return unit.stationed)

							boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").show()

						elif outcome.type == "continue":
							if not territory:
								REMINDER_TEXT.show_message("Select a territory first")
								continue

							var friendly_id: int = boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").get_selected_id()
							var friendly_name: String = boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").get_item_text(friendly_id)

							if friendly_name == "":
								REMINDER_TEXT.show_message("Select a friendly unit before continuing")
								continue

							# Find friendly unit
							target = $TerritoryManager.get_unit_by_name(friendly_name, player)

							if target:
								calls.append(Callable(target, "unstation").bind(territory))
								priority = CallPriority.HIGH
								
								print("Unit '%s' on territory %s, owned by %s, unstations" %
									[target.name, territory.id, player.name])
								break
							else:
								REMINDER_TEXT.show_message("Invalid unit selection, try again")
				"band":
					var unit1: Unit
					var unit2: Unit
					var territory: Territory

					# Check if player has any units
					if player.units_owned.size() < 2:
						REMINDER_TEXT.show_message("You can't band with fewer than two units!")
						continue

					action_info_label.text = "%s: Band Units" % player.name
					boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Choose a Territory"
					boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").hide()
					boxes["FriendlyUnit2"].get_node("FriendlyUnitSelector").hide()

					# Show UI
					boxes["FriendlyUnit"].show()
					boxes["FriendlyUnit2"].show()
					boxes["Territory"].show()
					boxes["Name"].show()
					action_info.show()

					while true:
						var outcome = await wait_for_continue_or_selection(continue_b)
						
						var name: String = boxes["Name"].get_node("NameText").text

						if outcome.type == "territory":
							var terr: Territory = outcome.territory
							
							# Check if there are enough friendly units on territory
							var friendly_unit_count := 0
							for unit: Unit in $TerritoryManager.units:
								if (unit.current_territory == territory and
									$TerritoryManager.get_unit_owner(unit) == player
								):
									friendly_unit_count += 1
							if friendly_unit_count < 2:
								REMINDER_TEXT.show_message("That territory doesn't have enough troops to band")
								continue
							
							territory = terr

							boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Territory " + str(territory.id)

							# Populate unit selectors
							update_unit_selector(boxes["FriendlyUnit"].get_node("FriendlyUnitSelector"), player, territory, true)
							update_unit_selector(boxes["FriendlyUnit2"].get_node("FriendlyUnitSelector"), player, territory, true)

							boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").show()
							boxes["FriendlyUnit2"].get_node("FriendlyUnitSelector").show()

						elif outcome.type == "continue":
							if not territory:
								REMINDER_TEXT.show_message("Select a territory first")
								continue
							if not (name and $TerritoryManager.unique_name(name)):
								REMINDER_TEXT.show_message("Enter a unique name")
								continue

							var unit1_id: int = boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").get_selected_id()
							var unit1_temp: Unit = $TerritoryManager.get_unit_by_id(unit1_id)
							var unit2_id: int = boxes["FriendlyUnit2"].get_node("FriendlyUnitSelector").get_selected_id()
							var unit2_temp: Unit = $TerritoryManager.get_unit_by_id(unit2_id)
							
							# Check choice validity
							if not (unit1_temp and unit2_temp):
								REMINDER_TEXT.show_message("Select both two friendly units before continuing")
								continue
							if unit1_temp == unit2_temp:
								REMINDER_TEXT.show_message("Select different units")
								continue
							
							# Assign to stable variables
							unit1 = unit1_temp
							unit2 = unit2_temp
							
							
							calls.append(Callable($TerritoryManager, "band_troops").bind([unit1, unit2], name))
							priority = CallPriority.LOW
							
							print("Units '%s' and '%s' owned by %s, band into '%s'" % [unit1.name, unit2.name, player.name, name])
							break
				"assess":
					var target: Spy
					var territory: Territory

					# Check if player has any spies on unowned territories
					var has_spies: bool = false
					for unit in player.units_owned:
						if unit is Spy and unit.current_territory.owner != player:
							has_spies = true
							break
					if not has_spies:
						REMINDER_TEXT.show_message("You don't have any spies on unowned territories")
						continue

					action_info_label.text = "%s: Assess a Territory" % player.name
					boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Choose a Territory"
					boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").hide()

					# Show UI
					boxes["FriendlyUnit"].show()
					boxes["Territory"].show()
					action_info.show()

					while true:
						var outcome = await wait_for_continue_or_selection(continue_b)

						if outcome.type == "territory":
							var terr: Territory = outcome.territory
							
							# Check if player owns selected territory
							if terr.owner == player:
								REMINDER_TEXT.show_message("You cannot assess your own territories")
								continue
							
							# Check if player owns spies there
							var has_spies_here := false
							for unit: Unit in player.units_owned:
								if (unit.current_territory == terr and unit is Spy):
									has_spies_here = true
									break
							if not has_spies_here:
								REMINDER_TEXT.show_message("You don't own any spies there")
								continue
							
							territory = terr

							boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Territory " + str(territory.id)

							# Populate unit selectors
							update_unit_selector(boxes["FriendlyUnit"].get_node("FriendlyUnitSelector"), player, territory, true,
								func(unit: Unit): return not unit.stationed and unit is Spy)

							boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").show()

						elif outcome.type == "continue":
							if not territory:
								REMINDER_TEXT.show_message("Select a territory first")
								continue

							
							var target_id: int = boxes["FriendlyUnit"].get_node("FriendlyUnitSelector").get_selected_id()
							var target_temp: Unit = $TerritoryManager.get_unit_by_id(target_id)

							if not (target_temp and target_temp is Spy):
								REMINDER_TEXT.show_message("Select a friendly spy before continuing")
								continue

							# Assign permanent var
							target = target_temp

							calls.append(Callable(player, "gain_intel").bind(territory))
							priority = CallPriority.NORM
							
							print("Unit '%s', owned by %s, assesses territory %s" % [target.name, player.name, territory.id])
							break
				"uncover":
					var target: Territory

					action_info_label.text = "%s: Uncover a Territory" % player.name
					boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Choose a Territory"

					# Show UI
					boxes["Territory"].show()
					action_info.show()

					while true:
						var outcome = await wait_for_continue_or_selection(continue_b)

						if outcome.type == "territory":
							var terr: Territory = outcome.territory
							
							if terr.owner != player:
								REMINDER_TEXT.show_message("You can only uncover your own territories")
								continue

							target = terr
							boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Territory " + str(target.id)

						elif outcome.type == "continue":
							if target:
								calls.append(Callable($TerritoryManager, "uncover").bind(target))
								priority = CallPriority.NORM
								
								print("Territory %s, owned by %s, uncovers" % [target.id, target.owner.name])
								break
							else:
								REMINDER_TEXT.show_message("Please select a territory before continuing")
				"sign":
					pass
					#var target: Player
					#var enemy_players: Array[Player]
					#
					#for enemy in $TerritoryManager.players:
						#if enemy != $TerritoryManager.players[0] and enemy != player:
							#enemy_players.append(enemy)
#
					#action_info_label.text = "%s: Uncover a Territory" % player.name
					#boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Choose a Territory"
#
					## Show UI
					#boxes["Territory"].show()
					#action_info.show()
#
					#while true:
						#var outcome = await wait_for_continue_or_selection(continue_b)
#
						#if outcome.type == "territory":
							#var terr: Territory = outcome.territory
							#
							#if terr.owner not in enemy_players:
								#REMINDER_TEXT.show_message("You must select an enemy territory")
								#continue
#
							#target = terr.owner
							#boxes["Territory"].get_node("Territory1/SelectedTerritory").text = "Territory " + str(terr.id)
#
						#elif outcome.type == "continue":
							#if target:
								#calls.append(Callable(player, "sign_treaty").bind(target))
								#priority = CallPriority.HIGH
								#
								#print("Player %s signs treaty with %s" % [player.name, target.name])
								#break
							#else:
								#REMINDER_TEXT.show_message("Please select a territory before continuing")
				"break":
					pass
				"request":
					var requests: Dictionary = {}
					var parent = $CanvasLayer/UI/ActionInfo/VBoxContainer/ResourceRequest
					
					# Create elements
					var elements = create_resource_elements(parent, player)
					
					boxes["ResourceRequest"].show()
					
					await continue_b.pressed
					
					for element: PlayerResourceElement in elements:
						if element.get_node("CheckButton").button_pressed:
							var name = element.get_node("CheckButton").text
							var target = $TerritoryManager.get_player_by_name(name)
							var signature = element.get_node("LineEdit").text
							var amount = element.get_node("SpinBox").value
							
							var call := Callable(player, "request_resources").bind(target, signature, amount)
							calls.append(call)
					
					priority = CallPriority.NORM
					
				"deny":
					pass
				"fulfill":
					pass
			$CanvasLayer/UI/ActionInfo.hide()

			if calls is Array[Callable]:
				if priority == CallPriority.LOW:
					$TerritoryManager.last_action_queue += calls
				elif priority == CallPriority.NORM:
					$TerritoryManager.action_queue += calls
				elif priority == CallPriority.HIGH:
					$TerritoryManager.priority_action_queue += calls
			else:
				print("Invalid calls to append")
			
			calls.clear()
	
	run_actions()
	
	$TerritoryManager.turn += 1
	return $TerritoryManager.turn

# Create a resource element for each player as children of passed node
# Returns an array of instantiated elements
func create_resource_elements(parent: Node, caller: Player) -> Array[PlayerResourceElement]:
	var elements: Array[PlayerResourceElement] = []
	
	# Clear old selectors
	for child: Node in parent.get_children():
		if child is PlayerResourceElement:
			child.queue_free()
	
	for player in $TerritoryManager.players:
		if player != caller and player != $TerritoryManager.players[0]:
			var element = player_resource_element.instantiate()
			parent.add_child(element)
			
			var button = element.get_node("CheckButton")
			var lineedit = element.get_node("LineEdit")
			var spinbox = element.get_node("SpinBox")
			
			button.text = player.name
			lineedit.text = caller.name
			spinbox.value = 0
			
			elements.append(element)
	
	return elements

func run_actions():
	for action: Callable in $TerritoryManager.priority_action_queue:
		action.call()
	
	for action: Callable in $TerritoryManager.action_queue:
		action.call()
	
	for action: Callable in $TerritoryManager.last_action_queue:
		action.call()
	
	$TerritoryManager.priority_action_queue.clear()
	$TerritoryManager.action_queue.clear()
	$TerritoryManager.last_action_queue.clear()

func update_map():
	pass # TO-DO: Upade visuals of map based on new game state
