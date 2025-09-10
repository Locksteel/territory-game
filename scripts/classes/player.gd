extends Resource
class_name Player

@export var color: Color = Color.WHITE
@export var name: String = ""
@export var resources: int = 0
@export var units_owned: Array[Unit] = []
# Array of tuples of strings with the format [Sender, Message] (Sender == "Anonymous" if anonymous)
@export var messages: Array[Array]
# Dictionary with the format [Territory ID: int] = Fortification: int
@export var territory_data: Dictionary = {}

@export var allies: Array[Player] = []

@export var actions: Dictionary = {}

func _init() -> void:
	self.actions["anonymous"] = false
	self.actions["signed"] = false
	self.actions["attack_territory"] = false
	self.actions["attack_unit"] = false
	self.actions["fortify"] = false
	self.actions["defend_territory"] = false
	self.actions["defend_unit"] = false
	self.actions["recruit"] = false
	self.actions["move"] = false
	self.actions["regroup"] = false
	self.actions["station"] = false
	self.actions["unstation"] = false
	self.actions["band"] = false
	self.actions["assess"] = false
	self.actions["uncover"] = false
	self.actions["sign"] = false
	self.actions["break"] = false
	self.actions["request"] = false
	self.actions["deny"] = false
	self.actions["fulfill"] = false

func sign_treaty(ally: Player) -> void:
	self.allies.append(ally)
	ally.allies.append(self)

func break_treaty(player: Player) -> bool:
	if not (player in self.allies and self in player.allies):
		print("Invalid treaty break")
		return false
	
	self.allies.erase(player)
	player.allies.erase(self)
	
	return true

# Sends a message to a specified player, returns the array sent to that player
func send_message(destination: Player, message: String, anonymous: bool) -> Array[String]:
	var to_send: Array[String]
	
	if anonymous:
		to_send = ["Anonymous", message]
	else:
		to_send = [self.name, message]
	
	destination.messages.append(to_send)
	return to_send

func dismiss_message(index: int = 0) -> void:
	self.messages.remove_at(index)

func dismiss_all_messages() -> void:
	self.messages.clear()

# Gain fortification info on territory
# Return fortification of territory
func gain_intel(territory: Territory) -> int:
	var fortification: int = territory.fortification
	self.territory_data[territory.id] = fortification
	return fortification

func dismiss_intel(territory: Territory) -> void:
	self.territory_data.erase(territory.id)

func dismiss_all_intel() -> void:
	self.territory_data.clear()
