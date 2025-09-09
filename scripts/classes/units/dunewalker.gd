extends Unit
class_name Dunewalker

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
	self.defense = 1
	self.health = self.defense
	self.ability = AbilityType.DUNEWALKER
	self.cost = 2
	
	self.stationed = false
	self.band_unit = null
	self.defending = false

func attack_unit(enemy: Unit) -> bool:
	if self.current_territory.id != enemy.current_territory.id:
		print("Unit is on a different territory")
		return false
	
	var damage: int = self.offense
	# Dunewalkers deal double damage in deserts
	if self.current_territory.terrain == self.current_territory.TerrainType.DESERT:
		damage *= 2
		
	enemy.hurt(damage)
	return true

func attack_territory(territory: Territory) -> bool:
	if self.current_territory.id != territory.id:
		print("Unit is not on passed territory")
		return false
	
	var to_defortify = self.offense
	# Dunewalkers deal double damage in deserts
	if self.current_territory.terrain == self.current_territory.TerrainType.DESERT:
		to_defortify *= 2
	
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
