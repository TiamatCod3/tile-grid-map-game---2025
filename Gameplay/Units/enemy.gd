class_name Enemy
extends Unit

# Configurações de IA
const AGGRO_RANGE: int = 10 
const MOVE_RANGE: int = 3   

func _ready() -> void:
	super()
	add_to_group("Enemies")

func execute_turn(heroes: Array, board: GameBoard) -> void:
	if is_dead: return
	
	print("%s: A calcular turno..." % name)
	
	# 1. Encontrar o alvo mais próximo (AGORA PASSAMOS O BOARD)
	var target: Unit = _find_nearest_hero(heroes, board)
	
	if not target:
		print("%s: Nenhum herói acessível ou à vista." % name)
		return

	# 2. Verificar se JÁ estou na mesma célula (Ataque Imediato)
	if grid_pos == target.grid_pos:
		print("%s: Já estou em cima do %s! ATACANDO!" % [name, target.name])
		await attack_target(target, board)
		return

	# 3. Calcular Caminho (Direto para o tile do alvo)
	var path_stack = board.get_path_stack(grid_pos, target.grid_pos)
	
	if not path_stack.is_empty():
		# Corta o caminho se for muito longe (limita ao movimento do turno)
		if path_stack.size() > MOVE_RANGE:
			path_stack = path_stack.slice(0, MOVE_RANGE)
		
		# Move visualmente
		await traverse_path_visual(path_stack, board)
		
		# 4. Chegou? Ataca!
		if grid_pos == target.grid_pos:
			print("%s: Alcancei %s! ATACANDO!" % [name, target.name])
			await attack_target(target, board)
		else:
			print("%s: Aproximei-me..." % name)

# --- FUNÇÕES AUXILIARES ---

# Alterada para receber 'board' e calcular PATHFINDING REAL
func _find_nearest_hero(heroes: Array, board: GameBoard) -> Unit:
	var nearest: Unit = null
	var min_path_size: int = 9999 # Valor alto inicial (infinito)
	
	for hero in heroes:
		# Pula heróis mortos
		if not is_instance_valid(hero) or hero.is_dead: 
			continue
		
		# Otimização: Se a distância em linha reta for GIGANTE, nem tenta o AStar.
		# (Evita lag calculando rota para o outro lado do mapa que sabemos que está longe)
		if grid_pos.distance_to(hero.grid_pos) > AGGRO_RANGE * 2:
			continue

		# --- A CORREÇÃO MÁGICA ---
		# Calcula o caminho real até este herói
		var path = board.get_path_stack(grid_pos, hero.grid_pos)
		
		# Se o caminho for vazio e NÃO estamos no mesmo tile, é inalcançável (parede total)
		if path.is_empty() and grid_pos != hero.grid_pos:
			continue
			
		var real_dist = path.size()
		
		# Verifica se é o menor caminho encontrado até agora
		if real_dist < min_path_size and real_dist <= AGGRO_RANGE:
			min_path_size = real_dist
			nearest = hero
			
	return nearest
