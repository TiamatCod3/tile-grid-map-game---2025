class_name Enemy
extends Unit

# Configurações de IA
const AGGRO_RANGE: int = 10 # Distância máxima para "ver" o herói
const MOVE_RANGE: int = 3   # Quantos tiles ele anda por turno

func _ready() -> void:
	super()
	add_to_group("Enemies")

# A CORREÇÃO É AQUI: Adicione 'heroes: Array' como primeiro argumento
func execute_turn(heroes: Array, board: GameBoard) -> void:
	if is_dead: return
	
	print("%s: A calcular turno..." % name)
	
	# 1. Encontrar o alvo mais próximo
	var target: Unit = _find_nearest_hero(heroes)
	
	if not target:
		print("%s: Nenhum herói à vista. Aguardando..." % name)
		return

	# 2. Verificar se JÁ estou na mesma célula que ele (Ataque Imediato)
	if grid_pos == target.grid_pos:
		print("%s: Já estou em cima do %s! ATACANDO!" % [name, target.name])
		await attack_target(target, board)
		return

	# 3. Calcular Caminho (Direto para o tile do alvo)
	var path_stack = board.get_path_stack(grid_pos, target.grid_pos)
	
	if not path_stack.is_empty():
		# Corta o caminho se o destino for muito longe (limita ao movimento dele)
		if path_stack.size() > MOVE_RANGE:
			path_stack = path_stack.slice(0, MOVE_RANGE)
		
		# Move visualmente
		await traverse_path_visual(path_stack, board)
		
		# 4. Chegou? Ataca!
		# Depois de andar, verificamos se alcançamos a mesma posição do alvo
		if grid_pos == target.grid_pos:
			print("%s: Alcancei %s! ATACANDO!" % [name, target.name])
			await attack_target(target, board)
		else:
			print("%s: Ainda a caminho..." % name)

# --- FUNÇÕES AUXILIARES ---

func _find_nearest_hero(heroes: Array) -> Unit:
	var nearest: Unit = null
	var min_dist: float = INF
	
	for hero in heroes:
		# Pula heróis mortos ou inválidos
		if not is_instance_valid(hero) or hero.is_dead: 
			continue
		
		var dist = grid_pos.distance_to(hero.grid_pos)
		
		if dist < min_dist and dist <= AGGRO_RANGE:
			min_dist = dist
			nearest = hero
			
	return nearest
