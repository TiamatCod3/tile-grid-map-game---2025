class_name MoveCommand
extends Command

# Referências
var destination: Vector2i

# --- MEMÓRIA PARA UNDO/REDO ---
var path_taken: Array[Vector2i] = []
var start_pos: Vector2i

# Snapshots de Recursos
var snapshot_start_ap: int = 0
var snapshot_start_mp: int = 0
var snapshot_end_ap: int = 0
var snapshot_end_mp: int = 0

# Flag para saber se é a primeira vez ou um Redo
var is_first_run: bool = true

func _init(_actor: Unit, _board: GameBoard, _destination: Vector2i):
	# Chama o construtor do pai
	super(_actor, _board)
	destination = _destination
	start_pos = _actor.grid_pos

# EXECUTE: Chamado tanto na primeira vez quanto no Redo
func execute() -> bool: # <--- Mudado para bool
	
	# --- CASO 1: REDO (Já temos o caminho calculado) ---
	if not is_first_run:
		print("cmd: Refazendo Movimento (Redo)...")
		
		# 1. Restaura posição inicial
		actor.position = board.map_to_local(start_pos)
		board.register_unit_position(actor, start_pos, true) # true = instantaneo
		
		# 2. Re-executa animação
		await _perform_movement_animation()
		
		# 3. Restaura recursos finais exatos
		_restore_turn_manager_state(snapshot_end_ap, snapshot_end_mp)
		return true

	# --- CASO 2: PRIMEIRA EXECUÇÃO ---
	print("cmd: Calculando Movimento Novo...")
	
	# 1. Snapshot Inicial
	snapshot_start_ap = TurnManager.current_ap 
	snapshot_start_mp = TurnManager.current_mp
	
	# 2. Obter caminho
	var raw_path = board.get_path_stack(actor.grid_pos, destination)
	
	# Remove posição atual se estiver inclusa
	if raw_path.size() > 0 and raw_path[0] == actor.grid_pos:
		raw_path.pop_front()

	if raw_path.is_empty(): 
		print("cmd: Caminho vazio.")
		return false # <--- Retorna falso
	
	# 3. SIMULAÇÃO DE CUSTO (Lógica Massive Darkness)
	var sim_ap = snapshot_start_ap
	var sim_mp = snapshot_start_mp
	var approved_path: Array[Vector2i] = []
	
	for step in raw_path:
		# Lógica: Usa MP se tiver. Se não, queima 1 AP para ganhar 2 MP (e gasta 1)
		if sim_mp >= 1:
			sim_mp -= 1
			approved_path.append(step)
		elif sim_ap > 0:
			sim_ap -= 1  # Gasta ação
			sim_mp += 2  # Ganha 2 movimentos
			sim_mp -= 1  # Paga o passo atual
			approved_path.append(step)
		else:
			break # Sem recursos para continuar
	
	if approved_path.is_empty(): 
		print("cmd: Sem recursos para mover.")
		return false
	
	# 4. APLICAÇÃO
	path_taken = approved_path
	is_first_run = false # Marca que já rodou uma vez
	
	# Salva como vai ficar o TurnManager no final
	snapshot_end_ap = sim_ap
	snapshot_end_mp = sim_mp
	
	# Executa animação
	await _perform_movement_animation()
	
	# Aplica os custos calculados
	_restore_turn_manager_state(snapshot_end_ap, snapshot_end_mp)
	
	# NOTA: Não chamamos record_command aqui. O Invoker fará isso ao receber 'true'.
	return true 

# UNDO: Chamado pelo Invoker
func undo() -> void:
	print("cmd: Desfazendo Movimento...")
	
	# 1. Teleporta visualmente para o início
	# (Se quiser animar voltando, use tween aqui, mas teleport é padrão em táticos)
	actor.position = board.map_to_local(start_pos)
	board.register_unit_position(actor, start_pos, true) 
	
	# 2. Restaura estado inicial
	_restore_turn_manager_state(snapshot_start_ap, snapshot_start_mp)

# --- FUNÇÕES AUXILIARES ---

func _perform_movement_animation():
	actor.is_moving = true
	
	for step in path_taken:
		var tween = actor.create_tween()
		tween.tween_property(actor, "position", board.map_to_local(step), 0.2)
		await tween.finished
		
		# Atualiza a lógica do grid passo a passo (importante para triggers de armadilhas, etc)
		board.register_unit_position(actor, step)
			
	actor.is_moving = false

func _restore_turn_manager_state(ap: int, mp: int):
	# Força os valores no Gerenciador
	TurnManager.current_ap = ap
	TurnManager.current_mp = mp
	
	# Emite sinal para UI (se o TurnManager não emitir automaticamente no setter)
	if TurnManager.has_signal("resources_changed"):
		TurnManager.resources_changed.emit()
