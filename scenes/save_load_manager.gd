extends Node

func save_game_state(path: String, state: GameState) -> void:
	var err = ResourceSaver.save(state, path)
	if err != OK:
		push_error("Failed to save game: %s" % error_string(err))
