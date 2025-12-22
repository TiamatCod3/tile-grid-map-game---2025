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

func _handle_map_click():
	# 1. Prioridade: UI flutuante (Portas, Ícones no mundo)
	var obj = get_physics_object_under_mouse()
	if obj and obj is Door:
		var cmd = InteractCommand.new(game_board.unit, game_board, obj)
		await CommandInvoker.execute_command(cmd)
		return

	# 2. Secundário: Chão (Movimento)
	# Precisamos garantir que game_board existe antes de chamar
	if game_board:
		var mouse_pos = game_board.get_global_mouse_position()
		var clicked_cell = game_board.local_to_map(game_board.to_local(mouse_pos))
		
		if game_board.grid.has(clicked_cell):
			var cmd = MoveCommand.new(game_board.unit, game_board, clicked_cell)
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
