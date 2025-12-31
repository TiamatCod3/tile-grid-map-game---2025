class_name MeleeWeapon
extends WeaponStrategy

func execute_attack(attacker: Unit, target: Unit, board: GameBoard) -> int:
	print("%s ataca %s com %s (Melee)!" % [attacker.name, target.name, name])
	
	# 1. Animação Visual (O "Tranco")
	# Movemos a unidade levemente na direção do alvo e voltamos
	var tween = attacker.create_tween()
	var direction = (target.position - attacker.position).normalized()
	
	# Caso estejam no mesmo tile (Stacking), empurra para cima apenas visualmente
	if direction == Vector2.ZERO: 
		direction = Vector2.UP 
	
	var jump_vector = direction * 16.0 # Pula 16px (meio tile)
	
	# Vai
	tween.tween_property(attacker, "position", attacker.position + jump_vector, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Volta
	tween.tween_property(attacker, "position", attacker.position, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await tween.finished
	
	# 2. Reorganiza o Grid 
	# (Importante para garantir que eles voltem para a posição perfeita da pilha)
	if board:
		board.reorganize_visuals(attacker.grid_pos, false)
	
	# 3. Aplica o Dano
	if target.has_method("take_damage"):
		target.take_damage(damage)
		
	# 4. Tenta aplicar efeitos (Desarmar)
	if try_apply_effects(target):
		print(">> Efeito Crítico: Desarmar aplicado!")
		
	return damage
