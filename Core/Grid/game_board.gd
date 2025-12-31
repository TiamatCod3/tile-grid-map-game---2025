class_name GameBoard
extends TileMapLayer

# --- CONSTANTES ---
const CLUSTER_RADIUS: float = 16.0

# --- DEPENDÊNCIAS ---
@export var current_mission: MissionSetup
@export var debug_mode: bool = false

# --- SISTEMAS INTERNOS ---
var astar: AStar2D = AStar2D.new()
var grid: Dictionary = {}             # { Vector2i: GridCell }
var grid_to_astar_id: Dictionary = {} # { Vector2i: int }
var id_to_coord: Dictionary = {}      # { int: Vector2i }
# Variável para o Main acessar depois
var active_enemies: Array[Unit] = []

# Controlador de Input (Instanciado no setup)
var interaction_controller: InteractionController

func _ready() -> void:
	# Passivo: Espera o Main chamar setup_board
	pass	

# --- SETUP (Chamado pelo Main) ---
func setup_board(mission: MissionSetup) -> void:
	print("🗺️ GameBoard: Configurando mapa para missão '%s'..." % mission.resource_name)
	current_mission = mission
	
	# 1. Chama o Builder
	var build_data = GridBuilder.build(current_mission, self)
	
	if build_data.is_empty():
		push_error("GameBoard: Falha ao construir grid.")
		return

	# 2. Desempacota os dados
	grid = build_data["grid"]
	astar = build_data["astar"]
	grid_to_astar_id = build_data["grid_to_astar_id"]
	id_to_coord = build_data["id_to_coord"]
	
	# 3. Inicializa o Controller de Mouse
	if not interaction_controller:
		interaction_controller = InteractionController.new(self)
		add_child(interaction_controller)

	# Recupera a lista de inimigos criada
	active_enemies = build_data.get("enemies", [])
	
	# Organiza visualmente AGORA (Instantâneo)
	for enemy in active_enemies:
		reorganize_visuals(enemy.grid_pos, true)
		
	if debug_mode:
		queue_redraw()

# --- UTILS DE PATHFINDING E GRID ---

func open_passage_in_astar(pos_a: Vector2i, pos_b: Vector2i):
	var id_a = grid_to_astar_id.get(pos_a, -1)
	var id_b = grid_to_astar_id.get(pos_b, -1)
	
	if id_a != -1 and id_b != -1:
		if not astar.are_points_connected(id_a, id_b):
			astar.connect_points(id_a, id_b)
			print("Passagem aberta no AStar entre ", pos_a, " e ", pos_b)
			if debug_mode: queue_redraw()

func get_path_stack(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var start_id = grid_to_astar_id.get(start, -1)
	var end_id = grid_to_astar_id.get(end, -1)
	
	if start_id == -1 or end_id == -1: return []
	
	var point_path = astar.get_point_path(start_id, end_id)
	var path_stack: Array[Vector2i] = []
	
	for point in point_path:
		path_stack.append(local_to_map(to_local(point)))
	
	if not path_stack.is_empty():
		path_stack.pop_front() # Remove o tile atual onde a unidade já está
		
	return path_stack

func get_physics_object_under_mouse() -> Node:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collision_mask = 2147483647
	query.collide_with_bodies = true
	
	var result = space_state.intersect_point(query)
	if result.size() > 0:
		return result[0]["collider"]
	return null

func get_unit_at_grid_pos(grid_pos: Vector2i) -> Unit:
	if grid.has(grid_pos):
		# Retorna a primeira unidade viva encontrada na célula
		for u in grid[grid_pos].units:
			if not u.get("is_dead"):
				return u
	return null

# --- GERENCIAMENTO VISUAL DE UNIDADES ---

func register_unit_position(unit: Unit, new_pos: Vector2i, instant: bool = false):
	# print(unit.name, " - ", new_pos)
	var old_pos = unit.grid_pos
	
	# Remove da célula antiga
	if grid.has(old_pos):
		grid[old_pos].remove_unit(unit)
		reorganize_visuals(old_pos, false) # Anima quem ficou para fechar a roda
		
	unit.grid_pos = new_pos
	
	# Adiciona na nova
	if grid.has(new_pos):
		# print("Unit: " , unit.name)
		grid[new_pos].add_unit(unit)
		reorganize_visuals(new_pos, instant)

func reorganize_visuals(coord: Vector2i, instant: bool = false):
	if not grid.has(coord): return
	
	var cell: GridCell = grid[coord]
	# Filtra apenas unidades vivas
	var active_units = cell.units.filter(func(u): return not u.get("is_dead"))
	
	var count = active_units.size()
	if count == 0: return
	
	var center_pixel = map_to_local(coord)
	
	if count == 1:
		if instant:
			active_units[0].position = center_pixel
		else:
			create_reposition_tween(active_units[0], center_pixel)
	else:
		# Distribui em círculo se tiver mais de um no mesmo tile
		var angle_step = TAU / count
		for i in range(count):
			var u = active_units[i]
			# Começa do topo (-PI/2) para ficar mais bonito visualmente
			var angle = i * angle_step - (PI / 2)
			var offset = Vector2(cos(angle), sin(angle)) * CLUSTER_RADIUS
			
			var target_pos = center_pixel + offset
			
			if instant:
				u.position = target_pos
			else:
				create_reposition_tween(u, target_pos)

# CORREÇÃO PRINCIPAL AQUI:
func create_reposition_tween(target_unit: Unit, target_pos: Vector2):
	# Removemos a verificação 'if not target_unit.is_moving'
	# Motivo: Quando a unidade chega no tile, ela ainda está tecnicamente marcada como 'moving'
	# pelo sistema de pathfinding, mas precisamos ajustar a posição final dela na pilha agora.
	
	# Cria um novo tween sobrepondo qualquer movimento residual
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(target_unit, "position", target_pos, 0.2)

# --- DEBUG ---
func _draw():
	if not debug_mode: return

	for cell_pos in grid.keys():
		var cell = grid[cell_pos]
		var pos = to_local(cell.world_pos)
		
		# Desenha conexões AStar
		var id = grid_to_astar_id.get(cell_pos, -1)
		if id != -1:
			for neighbor_id in astar.get_point_connections(id):
				var neighbor_pos = to_local(astar.get_point_position(neighbor_id))
				draw_line(pos, neighbor_pos, Color(0, 1, 0, 0.3), 2)

		# Desenha Paredes
		if tile_set:
			var size = tile_set.tile_size.x / 2.0
			if cell.is_blocked_to(Vector2i.RIGHT):
				draw_line(pos + Vector2(size, -size), pos + Vector2(size, size), Color.RED, 3)
			if cell.is_blocked_to(Vector2i.LEFT):
				draw_line(pos + Vector2(-size, -size), pos + Vector2(-size, size), Color.RED, 3)
			if cell.is_blocked_to(Vector2i.DOWN):
				draw_line(pos + Vector2(-size, size), pos + Vector2(size, size), Color.RED, 3)
			if cell.is_blocked_to(Vector2i.UP):
				draw_line(pos + Vector2(-size, -size), pos + Vector2(size, -size), Color.RED, 3)
