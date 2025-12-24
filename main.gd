extends Node2D
@onready var game_board: GameBoard = $GameBoard
@onready var camera: CameraController = $CameraController
@onready var hud: CanvasLayer = $HUD # (Opcional, se já tiver criado)

func _ready() -> void:
	_setup_camera_view()
	pass
	

func _setup_camera_view() -> void:
	if not camera: return
	
	# Pega o tamanho do mapa diretamente do GameBoard
	var map_rect = game_board.get_used_rect()
	
	if map_rect.size == Vector2i.ZERO:
		push_warning("Main: O mapa está vazio! Câmera não ajustada.")
		return
		
	# Calcula o centro em pixels (usando função nativa do TileMapLayer)
	var center_pos = game_board.map_to_local(map_rect.get_center())
	
	# Pega o tamanho do tile para calcular o zoom ideal
	var tile_size = game_board.tile_set.tile_size.x
	
	# Manda a câmera se ajustar
	camera.setup_camera_on_grid(center_pos, tile_size)
