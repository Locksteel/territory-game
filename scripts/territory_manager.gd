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


# Returns a dictionary with these parameters:
# 	Keys = All players that own a territory in the territory list
# 	Values = The number of territories that player owns
func get_player_territory_counts() -> Dictionary:
	var counts: Dictionary = {}
	
	if territories.is_empty():
		return counts
	
	for territory: Territory in territories.values():
		if territory.id == 0:
			continue
		if territory.owner == players[0]:
			continue
		
		if territory.owner not in counts.keys():
			counts[territory.owner] = 1
		else:
			counts[territory.owner] += 1
	
	return counts

func get_player_home_base(player: Player) -> Territory:
	if player not in players:
		print("Player to get home base not in player list")
		return null
	
	var base_count = 0
	var base: Territory
	for territory: Territory in territories.values():
		if territory.owner == player and territory.home_base:
			base = territory
			base_count += 1
	
	if not base:
		print("Player has no home base")
		return null
	if base_count > 1:
		print("Player has multiple home bases")
		return null
	
	return base


func create_unit(type: Unit.UnitType, name: String, territory: Territory = null) -> Unit:
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
	
	return new_unit

func recruit_troop(owner: Player, type: Unit.UnitType, territory: Territory, name: String) -> Unit:
	if owner not in players:
		print("Passed player is not in player list")
		return null
	if territory not in territories:
		print("Passed territory not territory list")
		return null
	
	var new_unit: Unit = add_pending_unit(owner, type, name)
	if not assign_unit(new_unit, territory):
		print("Recruitment failed")
		owner.pending_units.erase(new_unit)
		return null
	
	return new_unit

# Creates a unit and adds it to the pending unit list, returns the new unit
func add_pending_unit(owner: Player, type: Unit.UnitType, name: String) -> Unit:
	if owner not in players:
		print("Cannot add pending unit, passed player not in player list")
		return null
	
	# Create new unit with null territory (indicates pending unit)
	var new_unit: Unit = create_unit(type, name)
	# Append unit to passed player's pending units
	owner.units_owned.append(new_unit)
	
	return new_unit

func assign_unit(unit: Unit, territory: Territory) -> bool:
	# If unit has current territory, it is not pending
	if unit.current_territory:
		print("Unit already assigned")
		return false
	
	# Assign unit's territory to passed territory
	unit.current_territory = territory
	# Add unit to main unit list
	units.append(unit)
	
	return true

func assign_units_to_home() -> bool:
	for player: Player in players:
		var home_base: Territory = get_player_home_base(player)
		for unit: Unit in player.units_owned:
			if not unit.current_territory:
				if not assign_unit(unit, home_base):
					return false
				print("Assigned unit '%s' to home base territory %s" % [unit.name, home_base.id])
	return true

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
