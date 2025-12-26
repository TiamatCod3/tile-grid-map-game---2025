extends Node2D
@export var mission_data: MissionSetup 
@export var heroes_to_spawn: Array[UnitStats] = [
	preload("res://Gameplay/Stats/warior_stats.tres"),
	preload("res://Gameplay/Stats/mage_stats.tres")
]

@onready var game_board: GameBoard = $GameBoard
@onready var camera: CameraController = $CameraController
@onready var hud: CanvasLayer = $HUD # (Opcional, se já tiver criado)

func _ready() -> void:
	# Segurança: Verifica se tem missão
	if not mission_data:
		push_error("Main: Nenhuma MissionSetup definida no Inspector!")
		return

	# Aguarda um frame para estabilidade da árvore
	await get_tree().process_frame
	
	_start_initialization_sequence()

func _start_initialization_sequence() -> void:
	print("🎬 Main: Iniciando sequência de carregamento...")
	
	# 1. ORDEM: Tabuleiro (Cria o chão, paredes e portas)
	game_board.setup_board(mission_data)
	
	# 2. ORDEM: Heróis (Cria as unidades nos pontos de spawn)
	# Nota: GridBuilder.spawn_heroes é estático, passamos os dados necessários
	var active_units = GridBuilder.spawn_heroes(heroes_to_spawn, mission_data, game_board)
	
	if active_units.is_empty():
		push_error("Main: Nenhum herói foi spawnado!")
	
	# 3. ORDEM: Câmera (Foca no mapa e no herói)
	_setup_camera_view(active_units)
	
	# 4. ORDEM: Game Loop (Inicia o gerenciador de turnos)
	TurnManager.start_game(active_units)
	print("✅ Main: Jogo iniciado.")

func _setup_camera_view(units: Array[Unit]) -> void:
	if not camera: return
	
	# Pega limites do mapa
	var map_rect = game_board.get_used_rect()
	if map_rect.size == Vector2i.ZERO: return
	
	# Calcula centro e zoom
	var center_pos = game_board.map_to_local(map_rect.get_center())
	var tile_size = game_board.tile_set.tile_size.x
	
	# Configura a câmera
	camera.setup_camera_on_grid(center_pos, tile_size)
	
	# Se tiver herói, foca no primeiro imediatamente
	if units.size() > 0:
		camera.position = units[0].position
		camera.follow_target = units[0]
		camera.is_following = true
