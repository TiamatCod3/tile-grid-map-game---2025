class_name MoveCommand
extends Command

var destination: Vector2i
var path_taken: Array[Vector2i] = []
var start_pos: Vector2i

# Snapshots (Mantém a responsabilidade de Memento/Undo)
var snapshot_start: Dictionary = {}
var snapshot_end: Dictionary = {}

var is_first_run: bool = true

func _init(_actor: Unit, _board: GameBoard, _destination: Vector2i):
	print(_board.grid_to_astar_id[_destination])
	super(_actor, _board)
	destination = _destination
	start_pos = _actor.grid_pos

func execute() -> bool:
	# --- CASO 1: REDO ---
	if not is_first_run:
		_restore_visuals(start_pos)
		await actor.traverse_path_visual(path_taken, board) # Delegação Visual
		_apply_resources(snapshot_end)
		return true

	# --- CASO 2: PRIMEIRA EXECUÇÃO ---
	# 1. Snapshot Inicial
	snapshot_start = { "ap": TurnManager.current_ap, "mp": TurnManager.current_mp }
	
	# 2. Pathfinding
	var raw_path = board.get_path_stack(actor.grid_pos, destination)
	if raw_path.size() > 0 and raw_path[0] == actor.grid_pos:
		raw_path.pop_front() # Remove a própria célula

	# 3. Delegação de Regras (Aqui estava a lógica complexa)
	var calculation = TurnManager.calculate_movement_cost(raw_path)
	
	if not calculation.success:
		EventManager.dispatch(GameEvents.MOVEMENT_FAILED, {"reason": "Sem recursos"})
		return false
	
	# 4. Aplicação
	path_taken = calculation.path
	snapshot_end = { "ap": calculation.final_ap, "mp": calculation.final_mp }
	is_first_run = false
	
	# Delegação da Animação
	await actor.traverse_path_visual(path_taken, board)
	
	# [CORREÇÃO AQUI] O local exato é este: Logo após a animação terminar!
	# Força o tabuleiro a arrumar quem já estava lá junto com quem chegou.
	board.reorganize_visuals(destination)
	
	# Atualiza o Estado Global e Notifica
	_apply_resources(snapshot_end)
	EventManager.dispatch(GameEvents.PLAYER_MOVED, { "actor": actor, "from": start_pos, "to": destination })
	
	return true 

func undo() -> void:
	_restore_visuals(start_pos)
	_apply_resources(snapshot_start)

# --- HELPERS PRIVADOS (Apenas lógica interna do comando) ---

func _restore_visuals(pos: Vector2i):
	actor.position = board.map_to_local(pos)
	board.register_unit_position(actor, pos, true)

func _apply_resources(state: Dictionary):
	TurnManager.current_ap = state.ap
	TurnManager.current_mp = state.mp
	EventManager.dispatch(GameEvents.RESOURCES_UPDATED, state)
