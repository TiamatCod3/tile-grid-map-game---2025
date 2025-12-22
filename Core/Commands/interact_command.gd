class_name InteractCommand
extends Command

var target_obj: Node

# --- MEMÓRIA PARA UNDO/REDO (Igual ao MoveCommand) ---
# Snapshots de Recursos
var snapshot_start_ap: int = 0
var snapshot_start_mp: int = 0
var snapshot_end_ap: int = 0
var snapshot_end_mp: int = 0

# Flag para saber se é a primeira vez ou um Redo
var is_first_run: bool = true

func _init(_actor: Unit, _board: GameBoard, _target: Node):
	super(_actor, _board)
	target_obj = _target
	# Removemos cost_mp e cost_ap fixos daqui, pois calcularemos dinamicamente

func execute() -> bool:
	# --- CASO 1: REDO (Já calculamos tudo antes) ---
	if not is_first_run:
		print("InteractCmd: Refazendo Interação (Redo)...")
		
		# 1. Re-executa visual e lógica
		await _perform_interaction()
		
		# 2. Restaura recursos finais exatos
		_restore_turn_manager_state(snapshot_end_ap, snapshot_end_mp)
		return true

	# --- CASO 2: PRIMEIRA EXECUÇÃO ---
	
	# 1. Validações Básicas
	if not target_obj or not is_instance_valid(target_obj): return false
	if target_obj is Door and target_obj.is_open: return false

	# 2. Snapshot Inicial
	snapshot_start_ap = TurnManager.current_ap
	snapshot_start_mp = TurnManager.current_mp

	# 3. LÓGICA DE CUSTO (Massive Darkness Style)
	# Aqui aplicamos a mesma regra do MoveCommand: 
	# Tenta gastar 1 MP. Se não der, gasta 1 AP (ganha 2 MP, sobra 1 MP).
	
	var sim_ap = snapshot_start_ap
	var sim_mp = snapshot_start_mp
	var cost_mp_needed = 1
	
	if sim_mp >= cost_mp_needed:
		sim_mp -= cost_mp_needed
	elif sim_ap >= 1:
		print("InteractCmd: Convertendo 1 AP em MP para abrir porta.")
		sim_ap -= 1         # Gasta 1 Ação
		sim_mp += 2         # Ganha 2 Movimentos
		sim_mp -= cost_mp_needed # Paga o custo
	else:
		print("InteractCmd: Falha. Sem recursos (MP ou AP) para interagir.")
		return false # Falha aqui

	# 4. APLICAÇÃO
	is_first_run = false
	snapshot_end_ap = sim_ap
	snapshot_end_mp = sim_mp
	
	# Executa a ação visual/lógica
	await _perform_interaction()
	
	# Aplica os custos calculados no TurnManager
	_restore_turn_manager_state(snapshot_end_ap, snapshot_end_mp)
	
	return true

func undo() -> void:
	print("InteractCmd: Desfazendo ação...")
	
	# 1. Reverte Estado Visual (Fecha a porta)
	if target_obj.has_method("close_door"):
		target_obj.close_door()
		
	# 2. Reverte Grid (Fecha a passagem no AStar)
	if target_obj is Door:
		board.close_passage_in_astar(target_obj.coord_a, target_obj.coord_b)
	
	# 3. RESTAURAÇÃO DE ESTADO (SNAPSHOT)
	# Restaura exatamente como estava antes, sem precisar calcular reembolso
	_restore_turn_manager_state(snapshot_start_ap, snapshot_start_mp)

# --- FUNÇÕES AUXILIARES (Padronizadas) ---

func _perform_interaction():
	# Visual
	if target_obj.has_method("open_door"):
		var tween = target_obj.open_door()
		# Se a porta retornar um Tween, esperamos. Se não, esperamos um frame.
		if tween and tween.is_valid():
			await tween.finished
		else:
			await board.get_tree().process_frame
	
	# Lógica (Grid)
	if target_obj is Door:
		board.open_passage_in_astar(target_obj.coord_a, target_obj.coord_b)

func _restore_turn_manager_state(ap: int, mp: int):
	TurnManager.current_ap = ap
	TurnManager.current_mp = mp
	
	if TurnManager.has_signal("resources_changed"):
		TurnManager.resources_changed.emit()
