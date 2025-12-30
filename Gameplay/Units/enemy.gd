class_name Enemy
extends Unit 

func _ready() -> void:
	super()
	add_to_group("Enemies")
	move_speed = 0.3 

func execute_turn(board: GameBoard) -> void:
	#print(self.name + ": A calcular movimento...")
	#
	#var target = board.unit
	#
	#if target == null:
		#print("Não vejo heróis. Passo a vez.")
		#TurnManager.enemy_finished_action()
		#return
		#
	## Calcula Rota
	#var path = board.astar.get_id_path(grid_pos, target.grid_pos)
	#
	## --- CASO 1: JÁ ESTOU NO QUADRADO (ATAQUE IMEDIATO) ---
	#if path.size() == 1:
		## CORREÇÃO AQUI: Adicionado ', board' nos argumentos
		#await attack_target(target, board)
		#
		#print(self.name + ": Ataquei sem andar. Turno concluído.")
		#TurnManager.enemy_finished_action() 
		#return 
	#
	## --- CASO 2: PRECISO ANDAR ---
	#
	## Remove posição atual
	#path.pop_front()
	#
	## Se o caminho estiver vazio (pode acontecer se o alvo mudar), aborta
	#if path.is_empty():
		#TurnManager.enemy_finished_action()
		#return
	#
	## Pega próximo passo
	#var next_step = path[0] 
	#var path_to_walk: Array[Vector2i] = [next_step]
	#
	## Executa Movimento
	#await walk_path(path_to_walk, board)
	#
	## --- DEPOIS DE ANDAR ---
	#
	## Checa se caiu no mesmo quadrado do herói para atacar
	#if grid_pos == target.grid_pos:
		#await attack_target(target, board) # Aqui já estava correto
	#
	#print(self.name + ": Turno concluído.")
	#TurnManager.enemy_finished_action()
	pass
