# Caminho: res://UI/Controllers/InteractionController.gd
class_name InteractionController
extends Node

# Referências para os sistemas que ele controla
# (Você vai conectar isso no Editor ou via código na inicialização)
@export var game_board: GameBoard
@export var hand_ui: Control # Futuro: Sua mão de cartas
@export var dice_roller: Control # Futuro: Seus dados

# Estados de Input
enum InputState { MAP_IDLE, CARD_DRAGGING, WAITING_ANIMATION }
var current_state = InputState.MAP_IDLE

func _init(board: GameBoard = null):
	if board:
		game_board = board
		name = "InteractionController" # Nomeia o nó para ficar bonito no Remote Debug
		
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return

	match current_state:
		InputState.MAP_IDLE:
			_handle_map_click()
			
		InputState.CARD_DRAGGING:
			# Deixa o script da carta resolver, ou solta a carta aqui
			pass
func _process(_delta: float) -> void:
	# 1. Pergunta ao GameBoard qual objeto físico está sob o mouse
	# (Essa função helper ficou lá no GameBoard, então reutilizamos ela)
	var obj = game_board.get_physics_object_under_mouse()
	
	# 2. Lógica do Cursor
	# Se for Porta FECHADA -> Mãozinha
	if obj and obj is Door and not obj.is_open:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	
	# Se for Inimigo (Exemplo futuro) -> Espada
	# elif obj and obj.is_in_group("Enemies"):
	# 	Input.set_default_cursor_shape(Input.CURSOR_CROSS) # ou customizado
	
	# Nada relevante -> Seta Padrão
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		
func _handle_map_click():
	var active_hero = TurnManager.active_unit
	if not active_hero: return

	var obj = get_physics_object_under_mouse()
	
	# --- CASO 1: OBJETO INTERATIVO (PORTA) ---
	if obj and obj != active_hero:
		if obj is Door:
			# Verifica se já estamos do lado (Lógica Padrão)
			if active_hero.grid_pos == obj.coord_a or active_hero.grid_pos == obj.coord_b:
				var cmd = InteractCommand.new(active_hero, game_board, obj)
				await CommandInvoker.execute_command(cmd)
			
			# LÓGICA NOVA: Porta Distante
			else:
				await _handle_distant_interaction(active_hero, obj)
			return

	# --- CASO 2: MOVIMENTO NO CHÃO ---
	if game_board:
		var mouse_pos = game_board.get_global_mouse_position()
		var clicked_cell = game_board.local_to_map(game_board.to_local(mouse_pos))
		
		if game_board.grid.has(clicked_cell):
			var cmd = MoveCommand.new(active_hero, game_board, clicked_cell)
			await CommandInvoker.execute_command(cmd)
			
# --- Helpers ---
func get_physics_object_under_mouse() -> Node:
	# Acessa o mundo 2D através do game_board
	if not game_board: return null
	
	var space_state = game_board.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = game_board.get_global_mouse_position()
	query.collision_mask = 2147483647 
	query.collide_with_bodies = true
	var result = space_state.intersect_point(query)
	
	if result.size() > 0: return result[0]["collider"]
	return null

## Exemplo de chamada no InteractionController
#func _on_something_clicked():
	#var cmd = MoveCommand.new(unit, board, destino)
	#
	## O Invoker assume o controle a partir daqui
	#await CommandInvoker.execute_command(cmd)
#
## Exemplo para mapear teclas de atalho (Ctrl+Z, Ctrl+Y)
#func _unhandled_input(event):
	#if event.is_action_pressed("ui_undo"): # Configure isso no InputMap
		#CommandInvoker.undo_last_command()
	#elif event.is_action_pressed("ui_redo"):
		#CommandInvoker.redo_last_command()
# --- FUNÇÃO NOVA: GERENCIA O "ANDAR E ABRIR" ---
func _handle_distant_interaction(hero: Unit, door: Door) -> void:
	print("Interact: Porta distante detectada. Calculando rota...")
	
	# 1. Descobrir qual lado da porta é acessível e mais perto
	var start_pos = hero.grid_pos
	var target_pos = Vector2i(-1, -1)
	var best_path: Array[Vector2i] = []
	
	# Pega caminhos para os dois lados da porta
	var path_a = _get_clean_path(start_pos, door.coord_a)
	var path_b = _get_clean_path(start_pos, door.coord_b)
	
	# Compara qual é o melhor
	var valid_a = not path_a.is_empty()
	var valid_b = not path_b.is_empty()
	
	if valid_a and valid_b:
		# Se ambos acessíveis, pega o mais curto
		if path_a.size() <= path_b.size():
			best_path = path_a
			target_pos = door.coord_a
		else:
			best_path = path_b
			target_pos = door.coord_b
	elif valid_a:
		best_path = path_a
		target_pos = door.coord_a
	elif valid_b:
		best_path = path_b
		target_pos = door.coord_b
	else:
		print("Interact: Nenhum caminho possível para a porta.")
		EventManager.dispatch(GameEvents.MOVEMENT_FAILED, {"reason": "Caminho Bloqueado"})
		return

	# 2. Simular Custos (Para não andar e morrer na praia sem AP pra abrir)
	var sim = TurnManager.calculate_movement_cost(best_path)
	
	if not sim.success:
		EventManager.dispatch(GameEvents.MOVEMENT_FAILED, {"reason": "Sem recursos para chegar lá"})
		return
		
	# Sobrou recurso para interagir? (Interação custa 1 MP ou converte 1 AP)
	# Precisamos de pelo menos 1 MP sobrando OU 1 AP para converter
	var can_interact = (sim.final_mp >= 1) or (sim.final_ap >= 1)
	
	if not can_interact:
		print("Interact: Consigo chegar, mas não sobra energia para abrir.")
		EventManager.dispatch(GameEvents.INTERACTION_FAILED, {"reason": "Sem AP suficiente para abrir"})
		return

	# 3. EXECUTAR A SEQUÊNCIA
	print("Interact: Auto-Walk iniciado para %s" % target_pos)
	
	# A) Move
	var move_cmd = MoveCommand.new(hero, game_board, target_pos)
	var moved = await CommandInvoker.execute_command(move_cmd)
	
	# B) Abre (Apenas se o movimento completou com sucesso)
	if moved:
		# Pequeno delay visual opcional para ficar natural
		# await get_tree().create_timer(0.1).timeout 
		var interact_cmd = InteractCommand.new(hero, game_board, door)
		await CommandInvoker.execute_command(interact_cmd)

# Helper para pegar caminho limpo (sem o ponto inicial)
func _get_clean_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var raw = game_board.get_path_stack(from, to)
	if raw.size() > 0 and raw[0] == from:
		raw.pop_front()
	return raw
