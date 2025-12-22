class_name GridBuilder
extends RefCounted

# O Builder retorna um Dicionário com todo o mapa processado
static func build(mission: MissionSetup, board: TileMapLayer) -> Dictionary:
	# 1. VALIDAÇÃO INICIAL
	if not mission or not board:
		push_error("GridBuilder: Missão ou Board inválidos.")
		return {}

	print("🏗️ GridBuilder: Iniciando construção 'Canvas Livre' para ", mission.resource_path)

	# 2. PREPARAÇÃO
	# Limpa visuais antigos do grupo "MapVisuals"
	board.get_tree().call_group("MapVisuals", "queue_free")
	
	# Estrutura de dados principal
	var data = {
		"grid": {},             # Dictionary[Vector2i, GridCell]
		"astar": AStar2D.new(), # Grafo de navegação
		"grid_to_astar_id": {}, # De Coord -> ID
		"id_to_coord": {},      # De ID -> Coord
		"hero": null            # Referência à unidade do jogador
	}

	# 3. CONSTRUÇÃO DO MAPA (TILES UNIFICADOS)
	# Iteramos sobre o layout unificado. Não existe mais multiplicação por 3 obrigatória.
	# O MissionSetup fornece coordenadas absolutas: (0,0), (0,3), (4,6), etc.
	for grid_coord in mission.layout.keys():
		var tile_resource: MapTile = mission.layout[grid_coord]
		var rot = mission.layout_rotation.get(grid_coord, 0)
		
		# Processa o tile nessa coordenada exata
		_process_tile(tile_resource, grid_coord, rot, board, data)

	# 4. INDEXAÇÃO ORDENADA (IDs DETERMINÍSTICOS)
	# Ordenamos todas as coordenadas criadas para garantir que os IDs
	# sigam a lógica de leitura: Cima -> Baixo, Esquerda -> Direita.
	var sorted_coords = data.grid.keys()
	sorted_coords.sort_custom(func(a, b):
		if a.y != b.y:
			return a.y < b.y # Prioridade para Linhas (Y)
		return a.x < b.x     # Depois Colunas (X)
	)
	
	var id_counter = 0
	
	# Atribui IDs sequenciais
	for pos in sorted_coords:
		var cell = data.grid[pos]
		
		# Se a célula for andável, adiciona ao AStar
		if cell.is_walkable:
			data.astar.add_point(id_counter, cell.world_pos)
			
			# Cria o mapeamento bidirecional
			data.grid_to_astar_id[pos] = id_counter
			data.id_to_coord[id_counter] = pos
			
			id_counter += 1

	# 5. CONEXÕES (ASTAR)
	# Conecta os nós vizinhos se houver passagem
	_connect_astar(data.grid, data.astar, data.grid_to_astar_id)
	
	# 6. OBJETOS (PORTAS)
	# Instancia portas verificando paredes reais (Lógica robusta)
	_spawn_objects(mission, data.grid, board, data.id_to_coord, data.astar)
	
	# 7. HEROIS
	# Posiciona o jogador
	#_spawn_heroes(mission, data, board)

	print("✅ GridBuilder: Construção concluída com %d nós navegáveis." % id_counter)
	return data

# --- FUNÇÕES CORE (PROCESSAMENTO DE TILES) ---

static func _process_tile(tile: MapTile, base_pos: Vector2i, rot: int, board: Node2D, data: Dictionary):
	# A. Spawn Visual Dinâmico (Centraliza sprite independente do tamanho 1x1, 1x2, 3x3...)
	_spawn_visual_dynamic(base_pos, tile, rot, board)
	
	# B. Criação das Células Lógicas
	for i in range(tile.cells.size()):
		var cell_data = tile.cells[i]
		
		# 1. Calcula Coordenada Local (dentro do tile)
		# Usa as dimensões originais do Resource para saber quando quebrar linha
		var dim_original = tile.dimensions # Ex: (1, 2)
		var src_x = i % dim_original.x
		var src_y = i / dim_original.x
		var local_pos = Vector2i(src_x, src_y)
		
		# 2. Aplica Rotação na Coordenada Local
		# Aqui a coordenada muda baseado na rotação (Ex: (0,1) vira (1,0) se girar 90º num 1x2)
		var rotated_local_pos = _rotate_generic(local_pos, tile.dimensions, rot)
		
		# 3. Calcula Posição Final no Mundo (Global Grid)
		var final_grid_pos = base_pos + rotated_local_pos
		var world_pos = board.map_to_local(final_grid_pos)
		
		# 4. Instancia a Célula
		var new_cell = GridCell.new(final_grid_pos, world_pos)
		new_cell.is_walkable = cell_data.is_walkable
		
		# 5. Configura Paredes (Também rotacionadas)
		var walls = _get_rotated_walls(cell_data, rot)
		new_cell.connections[Vector2i.UP]    = not walls[Vector2i.UP]
		new_cell.connections[Vector2i.DOWN]  = not walls[Vector2i.DOWN]
		new_cell.connections[Vector2i.LEFT]  = not walls[Vector2i.LEFT]
		new_cell.connections[Vector2i.RIGHT] = not walls[Vector2i.RIGHT]
		
		# 6. Salva no Dicionário Principal
		# (Se houver sobreposição de tiles, o último a ser processado vence)
		data.grid[final_grid_pos] = new_cell

# --- HELPERS MATEMÁTICOS E VISUAIS ---

static func _spawn_visual_dynamic(base_grid_pos: Vector2i, tile: MapTile, rot: int, board: Node2D):
	if not tile or not tile.texture: return
	
	var visual = Sprite2D.new()
	visual.texture = tile.texture
	visual.centered = true
	visual.rotation_degrees = rot * 90
	visual.z_index = -1
	visual.add_to_group("MapVisuals")
	
	# Detecta dimensões atuais (se girou 90/270, inverte X e Y)
	var dim = tile.dimensions
	if rot % 2 != 0: 
		dim = Vector2i(dim.y, dim.x)
	
	# Calcula o centro geométrico em "unidades de grid"
	# Ex: Tile 2x1 em (0,0) -> Centro X é 0.5, Centro Y é 0.0
	var logical_center_x = base_grid_pos.x + (float(dim.x) - 1.0) / 2.0
	var logical_center_y = base_grid_pos.y + (float(dim.y) - 1.0) / 2.0
	
	# Interpolação para Pixel Perfect
	# Pega a posição global das células vizinhas ao centro e tira a média
	var pos_a = board.map_to_local(Vector2i(floor(logical_center_x), floor(logical_center_y)))
	var pos_b = board.map_to_local(Vector2i(ceil(logical_center_x), ceil(logical_center_y)))
	
	visual.position = (pos_a + pos_b) / 2.0
	board.add_child(visual)

static func _rotate_generic(pos: Vector2i, size: Vector2i, steps: int) -> Vector2i:
	var p = pos
	var w = size.x
	var h = size.y
	
	# Aplica rotação N vezes
	for _n in range(steps):
		# Rotação 90º Horário: (x, y) -> (H - 1 - y, x)
		var old_x = p.x
		var old_y = p.y
		
		p.x = h - 1 - old_y
		p.y = old_x
		
		# Inverte dimensões para o próximo passo
		var temp = w
		w = h
		h = temp
		
	return p

static func _get_rotated_walls(cell_data: CellData, steps: int) -> Dictionary:
	var walls = [cell_data.wall_top, cell_data.wall_right, cell_data.wall_bottom, cell_data.wall_left]
	# Rotaciona o array de paredes
	for _n in range(steps):
		walls.push_front(walls.pop_back())
		
	return {
		Vector2i.UP: walls[0], Vector2i.RIGHT: walls[1],
		Vector2i.DOWN: walls[2], Vector2i.LEFT: walls[3]
	}

# --- LÓGICA DE CONEXÕES E OBJETOS ---

static func _connect_astar(grid, astar, ids):
	var dirs = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for pos in grid:
		if not ids.has(pos): continue 
		var cell = grid[pos]
		var id_a = ids[pos]
		
		for dir in dirs:
			# Se minha célula diz que tem passagem nessa direção...
			if cell.connections.get(dir, false):
				var neighbor_pos = pos + dir
				
				# ... e o vizinho existe e diz que tem passagem na direção oposta...
				if grid.has(neighbor_pos) and grid[neighbor_pos].connections.get(-dir, false):
					var id_b = ids.get(neighbor_pos, -1)
					
					# ... Conecta!
					if id_b != -1 and not astar.are_points_connected(id_a, id_b):
						astar.connect_points(id_a, id_b)

static func _spawn_objects(mission: MissionSetup, grid: Dictionary, board: TileMapLayer, id_to_coord: Dictionary, astar: AStar2D):
	var door_scene = load("res://Gameplay/World/Door.tscn")
	print("\n🚪 --- INÍCIO SPAWN DE PORTAS ---")
	
	for door_ids in mission.doors:
		# Validação de IDs (Segurança)
		if not id_to_coord.has(door_ids.x) or not id_to_coord.has(door_ids.y):
			push_error("❌ Erro Porta: ID %s ou %s não encontrado no mapa." % [door_ids.x, door_ids.y])
			continue
		
		var grid_coord_a = id_to_coord[door_ids.x]
		var grid_coord_b = id_to_coord[door_ids.y]
		
		# Validação de Adjacência
		if grid_coord_a.distance_squared_to(grid_coord_b) != 1:
			push_warning("⚠️ Aviso Porta: Células %s e %s não são vizinhas. Ignorando." % [door_ids.x, door_ids.y])
			continue
			
		var dir = grid_coord_b - grid_coord_a
		var cell_a = grid[grid_coord_a]
		var cell_b = grid[grid_coord_b]
		
		# --- VERIFICAÇÃO DE PAREDE ROBUSTA ---
		var is_open_a = cell_a.connections.get(dir, false)  # A diz que está aberto?
		var is_open_b = cell_b.connections.get(-dir, false) # B diz que está aberto?
		
		# Se AMBOS dizem que está aberto, é um corredor. Não spawna porta.
		if is_open_a and is_open_b:
			print("🚫 Pulei porta entre %s e %s: Corredor totalmente aberto." % [door_ids.x, door_ids.y])
			continue
		
		# Se chegou aqui, pelo menos um dos lados tem parede. Criamos a porta.
		print("✅ Criando porta entre %s e %s." % [door_ids.x, door_ids.y])
		
		var pos_a = board.map_to_local(grid_coord_a)
		var pos_b = board.map_to_local(grid_coord_b)
		if mission.doors[door_ids]:
			var id_a = door_ids.x
			var id_b = door_ids.y
			if not astar.are_points_connected(id_a, id_b):
					astar.connect_points(id_a, id_b)
					print("Passagem aberta no AStar entre ", pos_a, " e ", pos_b)
			#if not astar.are_points_connected(id_a, id_b):
			#if id_a != -1 and id_b != -1:
				
					#if debug_mode: queue_redraw()
			board.open_passage_in_astar(pos_a, pos_b)
		
		var door = door_scene.instantiate()
		board.add_child(door)
		
		door.position = (pos_a + pos_b) / 2
		door.coord_a = grid_coord_a
		door.coord_b = grid_coord_b
		door.is_open = mission.doors[door_ids]
		
		#print()
		var is_open = mission.doors[door_ids]
		var is_vertical = dir.x == 0
		# Rotação Visual (Assumindo que o Sprite original da porta é em Pé / Vertical)
		if is_open != is_vertical: 
			door.rotation_degrees += 90 # Vizinhos Verticais -> Parede Horizontal -> Gira Sprite
		
		
		#if mission.doors[door_ids]:
			#print("Door rotation")
			
		grid[grid_coord_a].interactable = door
		grid[grid_coord_b].interactable = door
		
	print("🚪 --- FIM SPAWN DE PORTAS ---\n")

static func spawn_heroes(heroes_stats: Array[UnitStats], mission: MissionSetup, board: GameBoard) -> Array[Unit]:
	var spawned_units: Array[Unit] = []
	print(heroes_stats)
	var hero_scene = load("res://Gameplay/Units/Unit.tscn") # Sua cena base genérica
	
	for i in range(heroes_stats.size()):
		if i >= mission.heroes_spawn_points.size():
			push_warning("Mais heróis do que pontos de spawn!")
			break
			
		var stats = heroes_stats[i]
		var spawn_grid_pos = mission.heroes_spawn_points[i]
		
		# Instancia
		var hero_instance = hero_scene.instantiate()
		
		# Configura
		hero_instance.name = stats.unit_name
		hero_instance.stats = stats # Injeta o Resource (o _ready da Unit fará o resto)
		hero_instance.grid_pos = spawn_grid_pos
		hero_instance.position = board.map_to_local(spawn_grid_pos)
		
		# Adiciona à cena
		board.add_child(hero_instance)
		
		# Registra no Board
		board.register_unit_position(hero_instance, spawn_grid_pos, true)
		
		spawned_units.append(hero_instance)
		
	return spawned_units
