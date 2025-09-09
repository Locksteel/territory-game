extends Node



var territories: Dictionary = {}
var players: Array[Player] = []
var units: Array[Unit] = []
var turn: int = 0

var dead_units: Array[Unit] = []

var priority_action_queue: Array[Callable] = []
var action_queue: Array[Callable] = []
var last_action_queue: Array[Callable] = []

func get_territory_by_id(id: int) -> Territory:
	return territories.get(id)

func get_unit_owner(unit: Unit) -> Player:
	for player in players:
		if unit in player.units_owned:
			return player
	
	return null

func add_player(player: Player):
	players.append(player)

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
