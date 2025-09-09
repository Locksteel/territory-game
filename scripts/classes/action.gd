extends Resource
class_name Action

@export var player: Player
@export var to_call: Callable

func _init(to_call: Callable) -> void:
	self.to_call = to_call
