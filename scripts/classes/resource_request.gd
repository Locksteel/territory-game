extends Resource
class_name ResourceRequest

enum RequestState {
	PENDING,
	FULFILLED,
	DENIED
}

var source: Player
var signature: String
var amount: int
var state: RequestState

func _init(source: Player, signature: String, amount: int) -> void:
	self.source = source
	self.signature = signature
	self.amount = amount
	self.state = RequestState.PENDING

func fulfill():
	source.resources += self.amount
	self.state = RequestState.FULFILLED

func deny():
	self.state = RequestState.DENIED
