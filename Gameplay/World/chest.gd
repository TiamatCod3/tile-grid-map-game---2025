class_name Chest
extends Unit 

var is_looted: bool = false

func interact(user: Unit):
	if is_looted:
		print("O baú está vazio.")
		return
		
	# REMOVIDO: if TurnManager.spend_action(1):
	# O GameBoard já pagou a conta antes de chamar essa função.
	loot_chest()

func loot_chest():
	is_looted = true
	$Sprite2D.modulate = Color.DARK_GRAY 
	print("Você encontrou uma Espada Lendária!")
	
	var board = get_parent()
	if board.has_method("reorganize_units_on_tile"):
		board.reorganize_units_on_tile(grid_pos)

# Funções desativadas (Sobrescrita)
func execute_turn(board: GameBoard) -> void:
	pass 

func take_damage(amount: int):
	pass
