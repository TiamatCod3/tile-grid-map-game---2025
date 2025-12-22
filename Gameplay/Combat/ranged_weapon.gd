class_name RangedWeapon
extends WeaponStrategy

@export var projectile_speed: float = 0.2

func execute_attack(attacker: Unit, target: Unit, board: GameBoard) -> int:
	print(attacker.name + " dispara com " + name + " (Ranged)!")
	
	# 1. Animação Visual (Simulando um projétil simples)
	# Num jogo polido, instanciaríamos uma cena "Arrow.tscn"
	# Para o MVP, vamos criar um Sprite temporário voando
	
	var projectile = Sprite2D.new()
	projectile.texture = load("res://icon.svg") # Use uma textura de flecha/bala se tiver
	projectile.scale = Vector2(0.2, 0.2)
	projectile.position = attacker.position
	projectile.modulate = Color.YELLOW
	board.add_child(projectile) # Adiciona ao mundo
	
	var tween = board.create_tween()
	tween.tween_property(projectile, "position", target.position, projectile_speed)
	
	await tween.finished
	
	projectile.queue_free() # Destroi a flecha
	
	# 2. Aplica Dano
	if target.stats:
		target.stats.take_damage(damage)

	return damage # <--- O RETORNO IMPORTANTE
