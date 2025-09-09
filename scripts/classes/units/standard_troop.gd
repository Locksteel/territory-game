extends Unit
class_name StandardTroop

#@export var current_territory: Territory
#@export var offense: int = 0
#@export var defense: int = 0
#@export var health: int = 0
#@export var stationed: bool = false
#@export var band_unit: Unit = null
#@export var ability: AbilityType = AbilityType.NONE
#@export var cost: int = 0
#@export var defending: bool = false

func _init(name: String, territory: Territory) -> void:
	super(name, territory)
	self.offense = 2
	self.defense = 2
	self.health = self.defense
	self.ability = AbilityType.NONE
	self.cost = 2
	
	self.stationed = false
	self.band_unit = null
	self.defending = false
