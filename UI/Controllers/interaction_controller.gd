class_name InteractionController
extends Node

const CURSOR_ARROW_TEX = preload("res://Assets/Cursor/PNG/Basic/Default/arrow_nw.png")
const CURSOR_ATTACK_TEX = preload("res://Assets/Cursor/PNG/Basic/Default/tool_sword_a.png") # Espada
const CURSOR_HAND_TEX = preload("res://Assets/Cursor/PNG/Basic/Default/hand_point.png")    # Mãozinha
const CURSOR_HELP_TEX = preload("res://Assets/Cursor/PNG/Basic/Default/cursor_help.png")  # Opcional

# --- CONFIGURAÇÃO DO HOTSPOT (O PONTO DO CLIQUE) ---
# O Vector2 indica onde é a "ponta" do mouse na imagem.
# Se a imagem é 32x32 e a ponta é no topo esquerdo: Vector2(0, 0)
# Se a imagem é uma mira centralizada: Vector2(16, 16)
const HOTSPOT_ARROW = Vector2(0, 0)
const HOTSPOT_ATTACK = Vector2(0, 0) # Ajuste se a ponta da espada não for no canto
const HOTSPOT_HAND = Vector2(10, 0)  # Geralmente o indicador fica um pouco para a direita

# Referências
@export var game_board: GameBoard
@export var hand_ui: Control 
@export var dice_roller: Control 

# Estados de Input
enum InputState { MAP_IDLE, CARD_DRAGGING, WAITING_ANIMATION }
var current_state = InputState.MAP_IDLE

func _init(board: GameBoard = null):
	if board:
		game_board = board
		name = "InteractionController"

func _ready():
	# 1. Substitui a Seta Padrão
	if CURSOR_ARROW_TEX:
		Input.set_custom_mouse_cursor(CURSOR_ARROW_TEX, Input.CURSOR_ARROW, HOTSPOT_ARROW)
	
	# 2. Substitui a Cruz (Usaremos para Inimigos/Ataque)
	if CURSOR_ATTACK_TEX:
		Input.set_custom_mouse_cursor(CURSOR_ATTACK_TEX, Input.CURSOR_CROSS, HOTSPOT_ATTACK)
		
	# 3. Substitui a Mãozinha (Usaremos para Portas/Interação)
	if CURSOR_HAND_TEX:
		Input.set_custom_mouse_cursor(CURSOR_HAND_TEX, Input.CURSOR_POINTING_HAND, HOTSPOT_HAND)
	
	# Se tiver o de ajuda/aliado:
	if CURSOR_HELP_TEX:
		Input.set_custom_mouse_cursor(CURSOR_HELP_TEX, Input.CURSOR_HELP, Vector2(16, 16))
	
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return

	match current_state:
		InputState.MAP_IDLE:
			_handle_map_click()
		InputState.CARD_DRAGGING:
			pass

func _process(_delta: float) -> void:
	# 1. Pergunta ao GameBoard quem está sob o mouse
	var obj = get_physics_object_under_mouse()
	
	# 2. Lógica do Cursor (Feedback Visual)
	if obj:
		if obj is Enemy:
			Input.set_default_cursor_shape(Input.CURSOR_CROSS) # Espada
		elif obj is Unit and not obj is Enemy:
			Input.set_default_cursor_shape(Input.CURSOR_HELP)
		elif obj is Door and not obj.is_open:
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		else:
			Input.set_default_cursor_shape(Input.CURSOR_MOVE)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _handle_map_click():
	var active_hero = TurnManager.active_unit
	if not active_hero: return

	var obj = get_physics_object_under_mouse()
	
	# --- CASO 1: INTERAÇÃO COM UNIDADES ---
	if obj and obj is Unit and obj != active_hero:
		
		# A) É Inimigo? ATACAR!
		if obj is Enemy:
			# Lógica alterada: Verifica se já estamos NA MESMA CÉLULA (Stacking)
			if active_hero.grid_pos == obj.grid_pos:
				# Ataque direto (já estou em cima)
				print("Combate: Ataque à queima-roupa!")
				var cmd = AttackCommand.new(active_hero, game_board, obj)
				await CommandInvoker.execute_command(cmd)
			else:
				# Longe: Tenta andar para CIMA dele e atacar
				await _handle_stack_attack(active_hero, obj)
			return
			
		# B) É Aliado?
		else:
			print("Clicou em aliado: ", obj.name)
			return

	# --- CASO 2: OBJETO INTERATIVO (PORTA) ---
	if obj and obj is Door:
		if active_hero.grid_pos == obj.coord_a or active_hero.grid_pos == obj.coord_b:
			var cmd = InteractCommand.new(active_hero, game_board, obj)
			await CommandInvoker.execute_command(cmd)
		else:
			await _handle_distant_interaction(active_hero, obj)
		return

	# --- CASO 3: MOVIMENTO NO CHÃO ---
	if game_board:
		var mouse_pos = game_board.get_global_mouse_position()
		var clicked_cell = game_board.local_to_map(game_board.to_local(mouse_pos))
		
		# Só move se clicou num tile válido
		if game_board.grid.has(clicked_cell):
			var cmd = MoveCommand.new(active_hero, game_board, clicked_cell)
			await CommandInvoker.execute_command(cmd)

# --- QUERY SYSTEM (Detecção de Áreas) ---
func get_physics_object_under_mouse() -> Node:
	if not game_board: return null
	
	var space_state = game_board.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = game_board.get_global_mouse_position()
	query.collision_mask = 2147483647
	
	# Habilita colisão com ÁREAS (SelectionArea)
	query.collide_with_bodies = true
	query.collide_with_areas = true 
	
	var result = space_state.intersect_point(query)
	
	if result.size() > 0:
		# Prioriza inimigos se houver sobreposição
		for hit in result:
			var collider = hit["collider"]
			if collider.name == "SelectionArea":
				var parent = collider.get_parent()
				if parent is Enemy: return parent # Prioridade para Enemy
				
		# Se não achou Enemy, retorna o primeiro que encontrar
		var collider = result[0]["collider"]
		if collider.name == "SelectionArea":
			return collider.get_parent()
		return collider
		
	return null

# --- LÓGICA DE MOVER PARA CIMA E ATACAR ---
func _handle_stack_attack(hero: Unit, enemy: Unit) -> void:
	print("Combat: Calculando rota de ataque (Stacking)...")
	
	# 1. Pega caminho até o inimigo
	var full_path = game_board.get_path_stack(hero.grid_pos, enemy.grid_pos)
	
	if full_path.is_empty():
		EventManager.dispatch(GameEvents.MOVEMENT_FAILED, {"reason": "Sem caminho"})
		return
		
	# --- DIFERENÇA PRINCIPAL ---
	# NÃO removemos o último passo. O destino É a célula do inimigo.
	# target_tile = enemy.grid_pos
	
	# 2. Simula Custos
	var sim = TurnManager.calculate_movement_cost(full_path)
	
	if not sim.success:
		EventManager.dispatch(GameEvents.MOVEMENT_FAILED, {"reason": "Sem alcance"})
		return
		
	# 3. Verifica AP para ataque (Assumindo custo 1 ou 2)
	# O ataque acontece DEPOIS de gastar o movimento para chegar lá
	var attack_cost = 1 
	var can_attack = (sim.final_ap >= attack_cost)
	
	if not can_attack:
		print("Combat: Chego lá, mas sem energia para bater.")
		EventManager.dispatch(GameEvents.INTERACTION_FAILED, {"reason": "Sem AP para atacar"})
		return

	# 4. Executa Movimento
	# O destino é o último tile válido do caminho (que deve ser o do inimigo)
	var move_target = sim.path.back()
	
	var move_cmd = MoveCommand.new(hero, game_board, move_target)
	var moved = await CommandInvoker.execute_command(move_cmd)
	
	# 5. Executa Ataque (Se chegou NO MESMO TILE)
	if moved:
		if hero.grid_pos == enemy.grid_pos:
			var attack_cmd = AttackCommand.new(hero, game_board, enemy)
			await CommandInvoker.execute_command(attack_cmd)
		else:
			print("Combat: Movimento interrompido ou incompleto.")

# --- Helper de Porta ---
func _handle_distant_interaction(hero: Unit, door: Door) -> void:
	# (Mantém a lógica da porta igual, parando adjacente)
	var start_pos = hero.grid_pos
	var target_pos = Vector2i(-1, -1)
	var best_path: Array[Vector2i] = []
	
	var path_a = _get_clean_path(start_pos, door.coord_a)
	var path_b = _get_clean_path(start_pos, door.coord_b)
	
	var valid_a = not path_a.is_empty()
	var valid_b = not path_b.is_empty()
	
	if valid_a and valid_b:
		if path_a.size() <= path_b.size():
			best_path = path_a; target_pos = door.coord_a
		else:
			best_path = path_b; target_pos = door.coord_b
	elif valid_a: best_path = path_a; target_pos = door.coord_a
	elif valid_b: best_path = path_b; target_pos = door.coord_b
	else: return

	var sim = TurnManager.calculate_movement_cost(best_path)
	if not sim.success: return
	
	var move_cmd = MoveCommand.new(hero, game_board, target_pos)
	if await CommandInvoker.execute_command(move_cmd):
		var interact_cmd = InteractCommand.new(hero, game_board, door)
		await CommandInvoker.execute_command(interact_cmd)

func _get_clean_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var raw = game_board.get_path_stack(from, to)
	# get_path_stack do GameBoard já deve remover o tile atual, 
	# mas por segurança verificamos se o primeiro tile é onde já estamos
	if not raw.is_empty() and raw[0] == from:
		raw.pop_front()
	return raw
