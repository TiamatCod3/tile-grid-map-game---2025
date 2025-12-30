class_name TurnEndCommand
extends Command

# Não precisamos de argumentos específicos no _init, 
# mas mantemos a assinatura do pai se necessário.
func _init(_actor = null, _board: GameBoard = null):
	super(_actor, _board)

func execute() -> bool:
	# 1. Validação: Só pode passar turno na fase de Heróis
	if TurnManager.current_phase != TurnManager.GamePhase.HERO_PHASE:
		return false
		

	# 2. Finaliza a lógica no Manager (que chama o próximo player)
	TurnManager.end_current_turn()
	
	# 3. Limpa histórico de Undo (Novo jogador não pode desfazer ações do anterior)
	CommandInvoker.clear_history()
	
	return false # Não entra na pilha

func undo() -> void:
	# Impossível desfazer o fim de turno (normalmente)
	pass
