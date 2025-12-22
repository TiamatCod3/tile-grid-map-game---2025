class_name Interactable
extends StaticBody2D

# Sinais para avisar o mundo (abriu porta, quebrou algo)
signal state_changed

@export var is_solid: bool = true     # Bloqueia movimento?
@export var blocks_vision: bool = true # Bloqueia visão? (Fog of War)
# NOVO: Checkbox no editor para decidir se centraliza ou não
@export var snap_to_center: bool = true

# Todo objeto interativo precisa saber onde está
var grid_pos: Vector2i

func _ready() -> void:
	add_to_group("Interactables")
	
	# Habilita detecção do mouse via código por garantia
	# Habilita detecção do mouse via código por garantia
	input_pickable = true
	
	var board = get_tree().root.find_child("GameBoard", true, false)
	
	if board:
		# 1. Lógica de Posicionamento (Mantemos isso!)
		var local_pos_in_board = board.to_local(global_position)
		grid_pos = board.local_to_map(local_pos_in_board)
		
		if snap_to_center:
			var centered_local = board.map_to_local(grid_pos)
			global_position = board.to_global(centered_local)
			print(name, " centralizado em: ", grid_pos)
		else:
			print(name, " mantido na posição original (Borda/Custom). Grid Ref: ", grid_pos)

		# 2. LÓGICA DE BLOQUEIO REMOVIDA
		# Não precisamos mais chamar set_point_solid ou is_in_boundsv.
		# Se este objeto tiver um CollisionShape2D na Layer 1 (World),
		# o setup_pathfinding() do GameBoard vai detectá-lo sozinho.
		
	else:
		# Verifica modo de teste isolado
		if get_tree().current_scene != self:
			push_warning(name + ": GameBoard não encontrado!")
	
	# Conecta os sinais de mouse
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
func _on_mouse_entered():
	# Muda para a "Mãozinha" de link
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_mouse_exited():
	# Volta para a "Seta" padrão
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	
# Função virtual que os filhos vão sobrescrever
func interact(user: Unit):
	print("Interagindo com ", name)
