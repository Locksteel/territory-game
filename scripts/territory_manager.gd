extends Node



var territories: Dictionary = {}
var players: Array[Player] = []
var units: Array[Unit] = []
var turn: int = 0

var dead_units: Array[Unit] = []

var priority_action_queue: Array[Callable] = []
var action_queue: Array[Callable] = []
var last_action_queue: Array[Callable] = []

func cleanup() -> void:
	for key in territories.keys():
		territories[key].check_independence()
	
	for unit in units:
		if unit.health <= 0:
			units.erase(unit)
			if unit is not Band or unit.band_unit:
				dead_units.append(unit)
	
	clear_actions()

func clear_actions() -> void:
	priority_action_queue.clear()
	action_queue.clear()
	last_action_queue.clear()

func get_territory_by_id(id: int) -> Territory:
	return territories.get(id)

func get_unit_owner(unit: Unit) -> Player:
	for player in players:
		if unit in player.units_owned:
			return player
	
	return null

func get_unit_by_name(name: String, player: Player = null) -> Unit:
	for unit in units:
		if unit.name == name and (not player or unit in player.units_owned):
			return unit
	return null

func get_unit_by_id(id: int) -> Unit:
	for unit in units:
		if unit.id == id:
			return unit
	return null

func add_player(player: Player):
	players.append(player)

func get_player_by_name(name: String) -> Player:
	for player in players:
		if player.name == name:
			return player
	
	return null

func recruit_troop(owner: Player, type: Unit.UnitType, territory: Territory, name: String) -> Unit:
	if owner not in players:
		print("Passed player is not in player list")
		return null
	if territory not in territories:
		print("Passed territory not territory list")
		return null
	for unit in units:
		if unit.name == name:
			print("Unit recruit failed due to non-unique name")
			return null
	
	var new_unit: Unit
	
	match type:
		Unit.UnitType.STANDARD:
			new_unit = StandardTroop.new(name, territory)
		Unit.UnitType.HEAVY:
			new_unit = HeavyTroop.new(name, territory)
		Unit.UnitType.SCOUT:
			new_unit = Scout.new(name, territory)
		Unit.UnitType.DEFENDER:
			new_unit = Defender.new(name, territory)
		Unit.UnitType.SIEGEMASTER:
			new_unit = Siegemaster.new(name, territory)
		Unit.UnitType.DUNEWALKER:
			new_unit = Dunewalker.new(name, territory)
		Unit.UnitType.HIGHLANDER:
			new_unit = Highlander.new(name, territory)
		Unit.UnitType.SPY:
			new_unit = Spy.new(name, territory)
	
	units.append(new_unit)
	return new_unit

func kill_troop(troop: Unit):
	dead_units.append(troop)
	units.erase(troop)
	pass

func band_troops(troops: Array[Unit], band_name: String) -> Band:
	var territory: Territory = troops[0].current_territory
	for troop in troops:
		if troop.current_territory != territory:
			print("Units passed to band are not on the same territory")
			return null
	
	var band := Band.new(band_name, territory)
	if not band.band(troops):
		print("Banding failed")
		return null
	
	return band

# Check if enemy spy is on territory
# If spy present, kill it
# Returns number of spies killed
func uncover(territory: Territory) -> int:
	var killed: int = 0
	for unit in units:
		if (unit.current_territory == territory and
			unit is Spy and
			unit not in territory.owner.units_owned
		):
			kill_troop(unit)
			killed += 1
	
	return killed

func unique_name(name: String) -> bool:
	for unit in units:
		if unit.name == name:
			return false
	return true


func save_game_state(path: String, map_display: Image, map_index: Image) -> bool:
	var state = GameState.new()
	state.players = players.duplicate(true)
	state.territories = territories.duplicate(true)
	state.units = units.duplicate(true)
	state.next_unit_id = Globals.next_unit_id
	state.current_turn = turn
	state.priority_queue = priority_action_queue.duplicate(true)
	state.action_queue = action_queue.duplicate(true)
	state.map_display = map_display
	state.map_index = map_index
	
	var err = ResourceSaver.save(state, path)
	if err != OK:
		push_error("Failed to save game: %s" % error_string(err))
		return false
	
	return true

func load_game_state(path: String) -> GameState:
	var loaded = ResourceLoader.load(path)
	if loaded and loaded is GameState:
		players = loaded.players.duplicate(true)
		territories = loaded.territories.duplicate(true)
		units = loaded.units.duplicate(true)
		Globals.next_unit_id = loaded.next_unit_id
		turn = loaded.current_turn
		priority_action_queue = loaded.priority_queue.duplicate(true)
		action_queue = loaded.action_queue.duplicate(true)
		
		return loaded
	else:
		push_error("Failed to load game state.")
		return null
