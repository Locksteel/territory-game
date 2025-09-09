extends Resource
class_name Territory

enum TerrainType { FLATLAND, MOUNTAIN, DESERT }

const TERRAIN_DICT: Dictionary = {
	TerrainType.FLATLAND: "Flatland",
	TerrainType.MOUNTAIN: "Mountain",
	TerrainType.DESERT: "Desert"
}

@export var id: int = 0
@export var owner: Player
@export var home_base: bool = false

@export var terrain: TerrainType = TerrainType.FLATLAND
@export var fortification: int = 0
@export var units_stationed: Array[Unit]
@export var defending: bool = false

# Store ids of bordering territories
@export var borders: Array[int] = []

@export var pixels: PackedVector2Array = []

func _init(home_base: bool = false) -> void:
	self.home_base == home_base

# Checks for independence and changes ownership if necessary, returns whether independent
func check_independence() -> bool:
	if self.fortification <= 0:
		self.fortification = 0
		self.owner = null
		for unit in self.units_stationed:
			unit.unstation(self)
		return true
	return false

# Adds passed fortification at resource cost
# Returns whether fortification was added
func fortify(amount: int = 1) -> bool:
	if owner and owner.resources >= self.fortification:
		owner.resources -= self.fortification
		self.fortification += amount
		return true
	return false

# Removes fortifications, returns whether independent
func defortify(damage: int) -> bool:
	if self.defending:
		damage = int(ceil(damage / 2))
	self.fortification -= damage
	return check_independence()

func get_terrain_string() -> String:
	return TERRAIN_DICT[self.terrain]

func defend():
	self.defending = true

func stop_defending():
	self.defending = false
