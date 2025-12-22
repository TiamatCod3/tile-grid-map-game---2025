class_name InteractCommand
extends Command

var target_obj: Node

# --- MEMÓRIA PARA UNDO/REDO ---
# Snapshots de Recursos (Para garantir precisão no Undo)
var snapshot_start_ap: int = 0
var snapshot_start_mp: int = 0
var snapshot_end_ap: int = 0
var snapshot_end_mp: int = 0

# Flag para controle de fluxo
var is_first_run: bool = true

func _init(_actor: Unit, _board: GameBoard, _target: Node):
	# Inicializa a classe base (Command)
	super(_actor, _board)
	target_obj = _target

# EXECUTE: Chamado pelo CommandInvoker
# Core/Commands/interact_command.gd

func execute() -> bool:
	
	# --- CASO 1: REDO ---
	if not is_first_run:
		# ... (lógica de Redo mantém igual) ...
		await _perform_interaction()
		_update_game_state(snapshot_end_ap, snapshot_end_mp)
		return true

	# --- CASO 2: PRIMEIRA EXECUÇÃO ---
	
	# 1. Validações Básicas
	if not target_obj or not is_instance_valid(target_obj):
		return false

	# --- CORREÇÃO AQUI: VALIDAÇÃO DE ALCANCE ---
	if target_obj is Door:
		# A porta conecta duas coordenadas (A e B).
		# O jogador precisa estar em uma delas para abrir.
		var player_pos = actor.grid_pos
		if player_pos != target_obj.coord_a and player_pos != target_obj.coord_b:
			print("InteractCmd: Falha. Jogador longe da porta.")
			EventManager.dispatch(GameEvents.INTERACTION_FAILED, {"reason": "Fora de alcance"})
			return false
	
	# Outra validação: Porta já aberta
	if target_obj is Door and target_obj.is_open:
		return false

	# 2. Snapshot Inicial
	snapshot_start_ap = TurnManager.current_ap
	snapshot_start_mp = TurnManager.current_mp

	# ... (Resto do código de Custo e Aplicação mantém igual) ...
	
	# Lógica de Custo resumida aqui para contexto:
	var sim_ap = snapshot_start_ap
	var sim_mp = snapshot_start_mp
	var cost_mp_needed = 1
	
	if sim_mp >= cost_mp_needed:
		sim_mp -= cost_mp_needed
	elif sim_ap >= 1:
		sim_ap -= 1
		sim_mp += 2
		sim_mp -= cost_mp_needed
	else:
		EventManager.dispatch(GameEvents.INTERACTION_FAILED, {"reason": "Sem recursos"})
		return false

	# 4. APLICAÇÃO
	is_first_run = false
	snapshot_end_ap = sim_ap
	snapshot_end_mp = sim_mp
	
	await _perform_interaction()
	_update_game_state(snapshot_end_ap, snapshot_end_mp)
	
	return true

# UNDO: Chamado pelo CommandInvoker ao pressionar "Desfazer"
func undo() -> void:
	print("InteractCmd: Desfazendo ação...")
	
	# 1. Reverte o Estado Visual e Lógico
	if target_obj is Door:
		# Nota: O script da porta (Door.gd) já deve emitir 'door_state_changed' ao fechar
		if target_obj.has_method("close_door"):
			target_obj.close_door()
		
		# Reverte o Grid (Fecha a passagem no AStar)
		board.close_passage_in_astar(target_obj.coord_a, target_obj.coord_b)
	
	# 2. Restaura recursos iniciais e atualiza UI
	_update_game_state(snapshot_start_ap, snapshot_start_mp)

# --- FUNÇÕES AUXILIARES ---

func _perform_interaction():
	# Lógica Visual
	if target_obj.has_method("open_door"):
		var tween = target_obj.open_door()
		
		# Aguarda animação se existir
		if tween and tween.is_valid():
			await tween.finished
		else:
			await board.get_tree().process_frame
	
	# Lógica Tática (Atualiza o Pathfinding)
	if target_obj is Door:
		board.open_passage_in_astar(target_obj.coord_a, target_obj.coord_b)

func _update_game_state(ap: int, mp: int):
	# 1. Atualiza os dados no Singleton
	TurnManager.current_ap = ap
	TurnManager.current_mp = mp
	
	# 2. Despacha evento para atualizar HUD
	var payload = {
		"ap": ap,
		"mp": mp
	}
	EventManager.dispatch(GameEvents.RESOURCES_UPDATED, payload)
