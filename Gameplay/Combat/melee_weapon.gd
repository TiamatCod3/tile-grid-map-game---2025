class_name MeleeWeapon
extends WeaponStrategy

func execute_attack(attacker: Unit, target: Unit, board: GameBoard) -> int:
	print(attacker.name + " ataca com " + name + " (Melee)!")
	
	# 1. Animação Visual (O "Tranco" do Zombicide)
	var tween = attacker.create_tween()
	var direction = (target.position - attacker.position).normalized()
	if direction == Vector2.ZERO: direction = Vector2.UP # Caso estejam no mesmo tile
	
	var jump_vector = direction * 16.0 # Pula 16px
	
	tween.tween_property(attacker, "position", attacker.position + jump_vector, 0.1)
	tween.tween_property(attacker, "position", attacker.position, 0.1)
	
	await tween.finished
	
	# 2. Reorganiza o Grid (pois o attacker se mexeu visualmente)
	if board:
		board.reorganize_units_on_tile(attacker.grid_pos)
	
	# 3. Aplica o Dano
	if target.stats:
		target.stats.take_damage(damage)
		
	# --- APLICA EFEITOS ESPECIAIS ---
	# Chamamos a função da classe pai que criamos acima
	if try_apply_effects(target):
		print("Efeito Crítico: Desarmar aplicado!")
		
	return damage # <--- O RETORNO IMPORTANTE
