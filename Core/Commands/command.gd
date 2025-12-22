class_name Command
extends RefCounted

var actor: Unit
var board: GameBoard
var cost_ap: int = 0
var cost_mp: int = 0

# Não precisamos mais da variável 'executed_successfully' obrigatória, 
# mas podemos mantê-la se quisermos consultar o histórico depois.
var success: bool = false 

func _init(_actor: Unit, _board: GameBoard):
	actor = _actor
	board = _board

# Alterado para retornar bool
func execute() -> bool:
	push_error("Sobrescreva execute() retornando true ou false")
	return false

func undo() -> void:
	TurnManager.refund_resources(cost_ap, cost_mp)
