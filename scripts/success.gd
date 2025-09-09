extends Label

func show_message(text: String = "Game Saved!", duration: float = 2.0) -> void:
	self.text = text
	self.visible = true
	self.modulate.a = 1.0
	
	await get_tree().create_timer(duration).timeout
	
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	self.visible = false
