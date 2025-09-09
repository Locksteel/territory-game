extends Resource
class_name GameState

#state.players = players.duplicate(true)
#state.territories = territories.duplicate(true)
#state.units = units.duplicate(true)
#state.current_turn = turn
#state.priority_queue = priority_action_queue.duplicate(true)
#state.action_queue = action_queue.duplicate(true)
#state.map_display = map_display
#state.map_index = map_index

@export var players: Array[Player] = []
@export var territories: Dictionary = {}
@export var units: Array[Unit]
@export var next_unit_id: int = 0
@export var current_turn: int = 0

@export var priority_queue: Array[Callable]
@export var action_queue: Array[Callable]

@export var map_index: Image
@export var map_display: Image
