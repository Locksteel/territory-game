extends Unit
class_name Band

@export var members: Array[Unit] = []

func _init(name: String, territory: Territory) -> void:
	super(name, territory)
	# self.band == self implies unit is a band itself
	self.band_unit = self

# Band array of units, returns whether or not successful
func band(units : Array[Unit]) -> bool:
	if not units:
		print("Passed unit array is empty")
		return false
	
	var member_list: Array[Unit] = []
	
	var band_offense = 0
	var band_defense = 0
	var band_health = 0
	for unit in units:
		if unit is not Unit:
			print("Passed non-unit to unit array")
			return false
		if unit.stationed:
			print("Passed stationed unit. Unstation all units to band")
			return false
		
		# Unit can be banded
		band_offense += unit.offense
		band_defense += unit.defense
		band_health += unit.health
	
	# Banding successful
	var band_ability: AbilityType = units[0].ability
	for unit in units:
		if unit.ability != units[0].ability:
			band_ability = AbilityType.NONE
		
		# Check if banding units are bands themselves
		if unit is Band and unit.band_unit == unit:
			# Assign band members to new band
			for member: Unit in unit.members:
				member_list.append(member)
				member.band_unit = self
			# Set old band to dead
			unit.health = 0
			unit.band_unit = null
		else:
			member_list.append(unit)
			unit.band_unit = self
	
	self.ability = band_ability
	self.offense = band_offense
	self.defense = band_defense
	self.health = band_health
	self.members = member_list
	return true


# Station current territory, returns whether or not successful
func station(territory: Territory) -> bool:
	var succeeded: Array[Unit] = []
	for member in members:
		if not member.station(territory):
			print("Stationing band failed on territory %s, check error urgently" % territory.id)
			for undo in succeeded:
				member.unstation(territory)
			return false
		succeeded.append(member)
	
	self.stationed = true
	return true

func unstation(territory: Territory) -> bool:
	var succeeded: Array[Unit] = []
	for member in members:
		if not member.unstation(territory):
			print("Unstationing band failed on territory %s, check error urgently" % territory.id)
			for undo in succeeded:
				member.station(territory)
			return false
		succeeded.append(member)
	
	self.stationed = false
	return true
