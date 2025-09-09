extends Unit
class_name Spy

#@export var current_territory: Territory
#@export var offense: int = 0
#@export var defense: int = 0
#@export var health: int = 0
#@export var stationed: bool = false
#@export var band_unit: Unit = null
#@export var ability: AbilityType = AbilityType.NONE
#@export var cost: int = 0
#@export var defending: bool = false

@export var last_assessed: Territory
@export var assess_count: int = 0

func _init(name: String, territory: Territory) -> void:
	super(name, territory)
	self.offense = 1
	self.defense = 1
	self.health = self.defense
	self.ability = AbilityType.SPY
	self.cost = 4
	
	self.stationed = false
	self.band_unit = null
	self.defending = false
	
	self.last_assessed = null
	self.assess_count = 0

# Assess territory's fortification without attacking
func assess(territory: Territory) -> Dictionary:
	if territory.id != last_assessed.id:
		self.assess_count = 0
	
	self.assess_count += 1
	
	# If home base has been assessed 7 times, return territory owner's name
	var owner: String = ""
	if territory.home_base and self.assess_count >= 7:
		owner += territory.owner.name
	
	self.last_assessed = territory
	return {"fortification": territory.fortification, "home_base": territory.home_base, "owner": owner}
