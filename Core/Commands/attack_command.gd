class_name AttackCommand
extends Command

var target: Unit
var damage_dealt: int = 0
var killed_target: bool = false # Memória: Eu matei ele?

func _init(_actor: Unit, _board: GameBoard, _target: Unit):
	super(_actor, _board)
	target = _target

func execute() -> void:
	# 1. Snapshot da Economia
	var ap_before = TurnManager.current_actions
	
	# Verificamos se estava vivo ANTES do ataque
	var was_alive_before = target.stats.current_health > 0
	
	if TurnManager.spend_full_action():
		# 2. Execução e CAPTURA DO DANO REAL
		# Agora 'damage_dealt' recebe o valor direto da arma
		damage_dealt = await actor.attack_target(target, board)
		
		# 3. Verificação de Morte
		# Se ele estava vivo, tomou dano, e agora está com 0 ou menos...
		if was_alive_before and target.stats.current_health <= 0:
			killed_target = true
			print("Alvo abatido. Killed flag = true")
		
		cost_ap = ap_before - TurnManager.current_actions

func undo() -> void:
	print("Desfazendo Ataque...")
	
	# 1. Ressuscitar (se necessário)
	# Fazemos isso ANTES de devolver a vida, para o objeto estar ativo
	if killed_target:
		target.revive()
		killed_target = false # Reseta flag
	
	# 2. Devolver Vida
	# Aumentamos a vida sem tocar animação de dano
	target.stats.current_health += damage_dealt
	print("Vida do alvo restaurada para: ", target.stats.current_health)
	
	# 3. Reembolso
	TurnManager.refund_resources(cost_ap, cost_mp)
