class_name RecoverCommand
extends Command

var heal_amount_applied: int = 0
var hp_before: int = 0

func _init(_actor: Unit, _board: GameBoard):
	super(_actor, _board)
	
	# DEFINA O CUSTO AQUI
	# Supondo que Recuperar custe todos os APs restantes ou 2 AP
	# Se for "Full Action", você pode calcular dinamicamente no execute, 
	# mas vamos padronizar para 2 por enquanto ou usar TurnManager.current_ap
	cost_ap = 2 
	cost_mp = 0

# --- CORREÇÃO: Retorno alterado para bool ---
func execute() -> bool:
	# 1. Snapshot (Estado antes)
	hp_before = actor.stats.current_health
	
	# Se a vida já estiver cheia, não deixa executar
	if hp_before >= actor.stats.max_health:
		print("Vida já está cheia.")
		return false
	
	# 2. Pagamento
	# Se quiser gastar TUDO o que tem:
	# cost_ap = TurnManager.current_ap 
	
	if not TurnManager.spend_ap(cost_ap):
		print("Sem AP para recuperar.")
		return false
	
	# 3. Execução
	actor.perform_recover()
	
	# 4. Snapshot Pós-Execução (Para Undo preciso)
	var hp_after = actor.stats.current_health
	heal_amount_applied = hp_after - hp_before
	
	print("Recover executado. Curou: ", heal_amount_applied)
	
	success = true
	return true

func undo() -> void:
	print("Desfazendo Recover...")
	
	# 1. Reverte a Vida
	actor.stats.current_health -= heal_amount_applied
	# Clamp para segurança
	actor.stats.current_health = clampi(actor.stats.current_health, 0, actor.stats.max_health)
	
	# 2. Devolve AP (Feito automaticamente pelo pai via super.undo())
	super.undo()
