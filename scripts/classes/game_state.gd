extends Resource
class_name GameState

	#state.players = players
	#state.territories = territories
	#state.units = units
	#state.next_unit_id = Globals.next_unit_id
	#state.current_turn = turn
	#state.priority_queue = priority_action_queue
	#state.action_queue = action_queue
	#state.last_queue = last_action_queue
	#state.map_display = map_display
	#state.map_index = map_index

@export var players: Array[Player] = []
@export var territories: Dictionary = {}
@export var units: Array = []
@export var next_unit_id: int = -1
@export var current_turn: int = -1

#@export var priority_queue: Array[Callable]
#@export var action_queue: Array[Callable]
#@export var last_queue: Array[Callable]

@export var map_index: Image
@export var map_display: Image
