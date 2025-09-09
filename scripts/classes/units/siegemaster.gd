extends Unit
class_name Siegemaster

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
	self.ability = AbilityType.SIEGEMASTER
	self.cost = 3
	
	self.stationed = false
	self.band_unit = null
	self.defending = false

func attack_territory(territory: Territory) -> bool:
	if self.current_territory.id != territory.id:
		print("Unit is not on passed territory")
		return false
	
	# Siegemasters deal double damage to territories
	var to_defortify: int = self.offense * 2
	
	if territory.defending:
		territory.defortify(int(ceil(to_defortify / 2)))
		var to_hurt = 0
		for unit in territory.units_stationed:
			to_hurt += unit.offense
		to_hurt = int(ceil(to_hurt / 2))
		self.hurt(to_hurt)
	else:
		territory.defortify(to_defortify)
	return true
