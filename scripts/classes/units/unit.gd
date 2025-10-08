extends Resource
class_name Unit

enum AbilityType { NONE, SCOUT, DEFENDER, SIEGEMASTER, DUNEWALKER, HIGHLANDER, SPY }
enum UnitType { STANDARD, HEAVY, SCOUT, DEFENDER, SIEGEMASTER, DUNEWALKER, HIGHLANDER, SPY }

const COST_DICT: Dictionary = {
	UnitType.STANDARD: 2,
	UnitType.HEAVY: 3,
	UnitType.SCOUT: 2,
	UnitType.DEFENDER: 3,
	UnitType.SIEGEMASTER: 3,
	UnitType.DUNEWALKER: 2,
	UnitType.HIGHLANDER: 2,
	UnitType.SPY: 4
}
const TYPE_DICT: Dictionary = {
	UnitType.STANDARD: "Standard Troop",
	UnitType.HEAVY: "Heavy Troop",
	UnitType.SCOUT: "Scout",
	UnitType.DEFENDER: "Defender",
	UnitType.SIEGEMASTER: "Siegemaster",
	UnitType.DUNEWALKER: "Dunewalker",
	UnitType.HIGHLANDER: "Highlander",
	UnitType.SPY: "Spy"
}

@export var id: int = 0
#@export var name: String = ""

@export var current_territory: Territory
@export var offense: int = 0
@export var defense: int = 0
@export var health: int = 0
@export var stationed: bool = false
@export var band_unit: Unit = null
@export var ability: AbilityType = AbilityType.NONE
@export var cost: int = 0
@export var defending: bool = false

@export var mtn_prepped: bool = false


func _init(name: String, territory: Territory = null) -> void:
	self.id = Globals.generate_unit_id()
	self.name = name
	self.current_territory = territory

static func fill_unit_selector(selector: OptionButton) -> void:
	for type in UnitType.values():
		selector.add_item(TYPE_DICT[type], type)


func move(destination: Territory) -> bool:
	if destination.id not in current_territory.borders:
		print("Destination territory does not border current unit's territory")
		return false
	if self.stationed:
		print("Cannot move while stationed")
		return false
	if current_territory.terrain == current_territory.TerrainType.MOUNTAIN and not self.mtn_prepped:
		print("Not prepped for mountain, prepping")
		self.mountain_prep()
		return false
	
	self.stop_defend()
	
	self.mtn_prepped = false
	self.current_territory = destination
	return true

func mountain_prep() -> void:
	self.stop_defend()
	self.mtn_prepped = true

func regroup() -> void:
	self.health = self.defense

func attack_unit(enemy: Unit) -> bool:
	if self.current_territory.id != enemy.current_territory.id:
		print("Unit is on a different territory")
		return false
	
	self.stop_defend()
	
	enemy.hurt(self.offense)
	return true

func attack_territory(territory: Territory) -> bool:
	if self.current_territory.id != territory.id:
		print("Unit is not on passed territory")
		return false
	
	self.stop_defend()
	
	if territory.defending:
		territory.defortify(int(ceil(self.offense / 2)))
		var to_hurt = 0
		for unit in territory.units_stationed:
			to_hurt += unit.offense
		to_hurt = int(ceil(to_hurt / 2))
		self.hurt(to_hurt)
	else:
		territory.defortify(self.offense)
	return true

# Defend action halves received damage this turn
func defend() -> void:
	self.defending = true

func stop_defend() -> void:
	self.defending = false

# Deal damage to this unit, returns whether or not damage was lethal
func hurt(damage: int) -> bool:
	if self.defending:
		damage = int(ceil(damage / 2))
	self.health -= damage
	if self.health <= 0:
		self.health = 0
		return true
	return false

# Station current territory, returns whether or not successful
func station(territory: Territory) -> bool:
	if self.current_territory.id != territory.id:
		print("Unit is not on passed territory")
		return false
	
	if self.stationed:
		print("Unit on %s is already stationed" % self.current_territory.id)
		return false
	
	self.stop_defend()
	
	territory.units_stationed.append(self)
	territory.fortification += self.defense
	self.stationed = true
	return true

# Unstation from current territory, returns whether or not successful
func unstation(territory: Territory) -> bool:
	if self.current_territory.id != territory.id:
		print("Unit is not on passed territory")
		return false
	
	if not self.stationed:
		print("Unit on %s is not stationed" % self.current_territory.id)
		return false
	
	self.stop_defend()
	
	territory.units_stationed.erase(self)
	territory.fortification -= self.defense
	territory.check_independence()
	self.stationed = false
	return true
