class_name AttackCommand
extends Command

var target: Unit
var damage_dealt: int = 0
var killed_target: bool = false # Memória: Eu matei ele?

func _init(_actor: Unit, _board: GameBoard, _target: Unit):
	super(_actor, _board)
	target = _target

func execute() -> bool:
	# 1. Verificar Custo da Arma
	var weapon = actor.equipped_weapon
	if not weapon:
		push_error("Ator sem arma!")
		return false

	# Verifica se tem AP suficiente no TurnManager (Proxy para o actor)
	if TurnManager.current_ap < weapon.ap_cost:
		print("Sem AP suficiente para atacar.")
		return false

	# 2. Snapshot (Estado anterior)
	var ap_before = TurnManager.current_ap
	var was_alive_before = target.stats.current_health > 0
	
	# 3. Consumir Recursos
	TurnManager.current_ap -= weapon.ap_cost
	cost_ap = weapon.ap_cost # Guarda quanto custou para o Undo
	
	# 4. Executar Ataque (Async)
	# O retorno é o dano causado (para sabermos quanto curar no undo)
	damage_dealt = await actor.attack_target(target, board)
	print("Ataque com: ", actor.equipped_weapon.name)
	# 5. Verificação de Morte (Kill Confirmation)
	# Se ele estava vivo antes e agora morreu, marcamos a flag
	if was_alive_before and target.stats.current_health <= 0:
		killed_target = true
		print(">> Alvo abatido (Flag killed_target = true)")
	
	return true

func undo() -> void:
	print("Desfazendo Ataque...")
	
	# 1. Ressuscitar (se necessário)
	# Fazemos isso ANTES de devolver a vida, para o objeto reativar seus processos
	if killed_target:
		if target.has_method("revive"):
			target.revive()
		killed_target = false 
	
	# 2. Devolver Vida (Reverte o dano)
	if target.stats:
		# Aumentamos a vida direto, sem passar pelo take_damage para não triggar animação de hit
		target.stats.heal(damage_dealt) 
		print("Vida do alvo restaurada em: ", damage_dealt)
	
	# 3. Reembolso de AP
	# Usamos a função helper do TurnManager se existir, ou devolvemos direto
	TurnManager.current_ap += cost_ap
