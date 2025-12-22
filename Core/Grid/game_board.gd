class_name GameBoard
extends TileMapLayer

# --- CONSTANTES ---
const CLUSTER_RADIUS: float = 16.0

# --- DEPENDÊNCIAS ---
@export var current_mission: MissionSetup
@export var debug_mode: bool = false
# Se tiver UI, pode referenciar aqui
# @onready var cursor_visual: Sprite2D = $Cursor 

# --- SISTEMAS INTERNOS ---
var astar: AStar2D = AStar2D.new()
var grid: Dictionary = {}           # { Vector2i: GridCell }
var grid_to_astar_id: Dictionary = {} # { Vector2i: int }
var id_to_coord: Dictionary = {}      # { int: Vector2i }

# Unidade controlada atualmente (Player)
var unit: Node2D 

# O NOVO CONTROLADOR
var interaction_controller: InteractionController

var selected_heroes_resources: Array[UnitStats] = [
	preload("res://Gameplay/Stats/warior_stats.tres"), 
	preload("res://Gameplay/Stats/mage_stats.tres")
]

func _ready() -> void:
	await get_tree().process_frame
	
	if not current_mission: # Mudou de 'mission' para 'current_mission' baseado no seu arquivo
		push_error("ERRO: Nenhuma missão carregada!")
		return

	# 1. Constrói o Grid Lógico (Paredes, Chão)
	build_logical_grid()
	
	# ... (Spawn de Objetos se houver) ...
	
	# 3. Spawna HERÓIS (Chamada Correta)
	# selected_heroes_resources deve ser preenchido (simulado por enquanto)
	var active_heroes = GridBuilder.spawn_heroes(selected_heroes_resources, current_mission, self)
	
	# 4. Inicializa Controller
	interaction_controller = InteractionController.new(self)
	add_child(interaction_controller)
	
	# 5. Inicia o Turn Manager
	TurnManager.start_game(active_heroes)	

func _process(_delta: float) -> void:
	# Verifica o que está embaixo do mouse neste momento
	var obj = get_physics_object_under_mouse()
	
	# Se for uma Porta e ela NÃO estiver aberta, muda o cursor
	if obj and obj is Door and not obj.is_open:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		# Caso contrário, volta para a seta padrão
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		
# --- 1. CONSTRUÇÃO (Via Builder) ---
func build_logical_grid():
	var build_data = GridBuilder.build(current_mission, self)
	
	if build_data.is_empty():
		push_error("GameBoard: Falha ao construir grid.")
		return

	# Recebe os dados processados
	grid = build_data["grid"]
	astar = build_data["astar"]
	grid_to_astar_id = build_data["grid_to_astar_id"]
	id_to_coord = build_data["id_to_coord"]
	
	# Localiza o herói
	if grid.has(current_mission.heroes_spawn_points):
		var spawn_cell = grid[current_mission.player_spawns]
		if not spawn_cell.units.is_empty():
			unit = spawn_cell.units[0]

	# --- CORREÇÃO AQUI ---
	# Avisa ao Godot: "Os dados mudaram, desenhe as linhas de debug agora!"
	if debug_mode:
		queue_redraw()

# --- 2. INPUT HANDLER ---
#func _unhandled_input(event: InputEvent) -> void:
	## Filtra apenas clique esquerdo do mouse
	#if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		#return
#
	## A: Tenta interagir com objetos físicos (Portas, Alavancas)
	#var clicked_object = get_physics_object_under_mouse()
	#if clicked_object and clicked_object is Door:
		#handle_door_interaction(clicked_object)
		#return
#
	## B: Converte clique do mouse para Grid
	#var clicked_cell_pos = local_to_map(to_local(get_global_mouse_position()))
#
	## Se clicou fora do mapa, ignora
	#if not grid.has(clicked_cell_pos):
		#return
#
	## C: Tenta Combate
	#if await try_combat_action(clicked_cell_pos): 
		#return
	#
	## D: Tenta Movimento (Última opção)
	#handle_player_movement(unit, clicked_cell_pos)

# --- 3. LÓGICA DE INTERAÇÃO (PORTAS) ---
func handle_door_interaction(door: Door):
	if door.is_open: 
		print("Porta já está aberta.")
		return
	
	# Verifica distância (Regra de Proximidade)
	var dist = unit.global_position.distance_to(door.global_position)
	var max_dist = tile_set.tile_size.x * 1.5 # 1.5 tiles de distância
	
	if dist <= max_dist:
		# Gasta ponto de ação/movimento (Se seu sistema usar TurnManager)
		if TurnManager.spend_mp(1):
			# 1. Abre visualmente
			door.open_door()
			
			# 2. Conecta os nós no AStar (A Mágica acontece aqui)
			open_passage_in_astar(door.coord_a, door.coord_b)
		else:
			print("Sem pontos de movimento!")
	else:
		print("Muito longe para interagir!")

# Conecta dois pontos no AStar dinamicamente
func open_passage_in_astar(pos_a: Vector2i, pos_b: Vector2i):
	print("open_passage")
	var id_a = grid_to_astar_id.get(pos_a, -1)
	var id_b = grid_to_astar_id.get(pos_b, -1)
	print(id_a, id_b)
	if id_a != -1 and id_b != -1:
		if not astar.are_points_connected(id_a, id_b):
			astar.connect_points(id_a, id_b)
			print("Passagem aberta no AStar entre ", pos_a, " e ", pos_b)
			if debug_mode: queue_redraw()

# --- 4. MOVIMENTO E COMBATE ---
func handle_player_movement(hero_unit: Unit, destination: Vector2i):
	if not grid.has(destination): return
	print(grid_to_astar_id[destination])
	var path_stack = get_path_stack(hero_unit.grid_pos, destination)
	
	if path_stack.is_empty():
		print("Caminho bloqueado ou destino inválido.")
		return

	# Cria o comando de movimento (Pattern Command)
	var cmd = MoveCommand.new(hero_unit, self, destination)
	
	# Executa e aguarda terminar
	await cmd.execute()
	

func try_combat_action(cell_pos: Vector2i) -> bool:
	if not grid.has(cell_pos): return false
	
	var target_unit = get_unit_at_grid_pos(cell_pos) 
	
	# Se tem alguém lá e é inimigo
	if target_unit and target_unit.is_in_group("Enemies"):
		var weapon = unit.equipped_weapon
		if weapon == null:
			print("Sem arma equipada!")
			return false
		
		# Verifica alcance via AStar (Distance Map)
		var id_start = grid_to_astar_id.get(unit.grid_pos, -1)
		var id_end = grid_to_astar_id.get(cell_pos, -1)
		
		if id_start == -1 or id_end == -1: return false
			
		var point_path = astar.get_point_path(id_start, id_end)
		if point_path.is_empty(): return false
			
		var distance = point_path.size() - 1 # Distância em passos
		
		if distance >= weapon.min_range and distance <= weapon.max_range:
			if TurnManager.spend_action(1):
				await unit.attack_target(target_unit, self)
				return true 
		else:
			print("Alvo fora de alcance!")
			return true # Retorna true para consumir o clique (não tentar mover)
			
	return false

# --- 5. HELPERS (Utilitários) ---

func get_path_stack(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var start_id = grid_to_astar_id.get(start, -1)
	var end_id = grid_to_astar_id.get(end, -1)
	
	if start_id == -1 or end_id == -1: return []
	
	var point_path = astar.get_point_path(start_id, end_id)
	var path_stack: Array[Vector2i] = []
	
	for point in point_path:
		path_stack.append(local_to_map(to_local(point)))
	
	if not path_stack.is_empty():
		path_stack.pop_front() # Remove o tile atual onde o herói já está
		
	return path_stack

func get_physics_object_under_mouse() -> Node:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collision_mask = 2147483647 # Máscara completa (todos os layers)
	query.collide_with_bodies = true
	
	var result = space_state.intersect_point(query)
	if result.size() > 0: 
		return result[0]["collider"]
	return null

func get_unit_at_grid_pos(grid_pos: Vector2i) -> Unit:
	# Método otimizado: olha direto na célula lógica
	if grid.has(grid_pos):
		for u in grid[grid_pos].units:
			if u != unit and not u.get("is_dead"):
				return u
	return null

# Atualiza posição lógica e visual
# Atualize a assinatura da função para aceitar 'instant'
func register_unit_position(hero_unit: Unit, new_pos: Vector2i, instant: bool = false):
	var old_pos = hero_unit.grid_pos
	
	if grid.has(old_pos):
		grid[old_pos].remove_unit(hero_unit)
		reorganize_visuals(old_pos) 
		
	hero_unit.grid_pos = new_pos
	
	if grid.has(new_pos):
		grid[new_pos].add_unit(hero_unit)
		# Passamos o parâmetro instant para a visualização
		reorganize_visuals(new_pos, instant)
# Reorganiza visualmente unidades empilhadas no mesmo tile
# Atualize também o reorganize_visuals
func reorganize_visuals(coord: Vector2i, instant: bool = false):
	if not grid.has(coord): return
	
	var cell: GridCell = grid[coord]
	var active_units = cell.units.filter(func(u): return not u.get("is_dead"))
	
	var count = active_units.size()
	if count == 0: return
	
	var center_pixel = map_to_local(coord)
	
	if count == 1:
		# Se for instantâneo, seta direto. Se não, usa Tween.
		if instant:
			active_units[0].position = center_pixel
		else:
			create_reposition_tween(active_units[0], center_pixel)
	else:
		var angle_step = TAU / count 
		for i in range(count):
			var u = active_units[i]
			var angle = i * angle_step
			var offset = Vector2(cos(angle), sin(angle)) * CLUSTER_RADIUS
			
			if instant:
				u.position = center_pixel + offset
			else:
				create_reposition_tween(u, center_pixel + offset)
				
func create_reposition_tween(target_unit: Unit, target_pos: Vector2):
	if not target_unit.is_moving: # Só ajusta quem está parado
		var tween = create_tween()
		tween.tween_property(target_unit, "position", target_pos, 0.2)

# --- 6. DEBUG ---
func _draw():
	if not debug_mode: return

	for cell_pos in grid.keys():
		var cell = grid[cell_pos]
		var pos = to_local(cell.world_pos)
		
		# Desenha conexões AStar (Opcional - para ver onde pode andar)
		# Se quiser ver se a porta abriu, verifique se há linha verde passando por ela
		var id = grid_to_astar_id[cell_pos]
		for neighbor_id in astar.get_point_connections(id):
			var neighbor_pos = to_local(astar.get_point_position(neighbor_id))
			draw_line(pos, neighbor_pos, Color(0, 1, 0, 0.3), 2)

		# Desenha Bloqueios (Paredes)
		var size = tile_set.tile_size.x / 2.0
		if cell.is_blocked_to(Vector2i.RIGHT):
			draw_line(pos + Vector2(size, -size), pos + Vector2(size, size), Color.RED, 3)
		if cell.is_blocked_to(Vector2i.LEFT):
			draw_line(pos + Vector2(-size, -size), pos + Vector2(-size, size), Color.RED, 3)
		if cell.is_blocked_to(Vector2i.DOWN):
			draw_line(pos + Vector2(-size, size), pos + Vector2(size, size), Color.RED, 3)
		if cell.is_blocked_to(Vector2i.UP):
			draw_line(pos + Vector2(-size, -size), pos + Vector2(size, -size), Color.RED, 3)
