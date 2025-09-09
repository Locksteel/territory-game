extends Node

var next_unit_id: int = 0

func generate_unit_id() -> int:
	next_unit_id += 1
	return next_unit_id
