extends Node

# --- SINAIS ---
signal turn_started
signal turn_ended
signal resources_changed

# --- FASES DO JOGO ---
enum GamePhase { HERO_PHASE = 0, ENEMY_PHASE = 1, LEVEL_UP_PHASE = 2, DARKNESS_PHASE = 3 }
var current_phase: int = GamePhase.HERO_PHASE
var round_number: int = 1

# --- GERENCIAMENTO DE UNIDADES ---
var heroes_roster = []
var activation_queue = [] 
var active_unit = null

# --- PROXY DE RECURSOS (Lê/Escreve direto na Unidade Ativa) ---
var current_ap: int:
	get:
		return active_unit.current_ap if active_unit else 0
	set(value):
		if active_unit:
			active_unit.current_ap = value
			_notify_resources()

var current_mp: int:
	get:
		return active_unit.current_mp if active_unit else 0
	set(value):
		if active_unit:
			active_unit.current_mp = value
			_notify_resources()

func _ready() -> void:
	# Conecta com o sinal de fim de turno da UI
	if EventManager.has_signal("ui_request_end_turn"):
		EventManager.ui_request_end_turn.connect(_on_ui_end_turn)

# --- LOOP DE JOGO ---
func start_game(heroes):
	heroes_roster = heroes
	round_number = 1
	_start_round()

func _start_round():
	print("\n=== RODADA %d ===" % round_number)
	current_phase = GamePhase.HERO_PHASE
	# Enche a fila com todos os heróis da lista
	activation_queue = heroes_roster.duplicate()
	_activate_next_hero()

func _activate_next_hero():
	if activation_queue.is_empty():
		_run_enemy_phase()
		return

	active_unit = activation_queue.pop_front()
	
	if active_unit.has_method("reset_turn_resources"):
		active_unit.reset_turn_resources()
	
	print(">>> Turno de: %s" % active_unit.name)
	_notify_resources()
	
	# --- AQUI: Usamos o dispatch do seu sistema atual ---
	# GameEvents.UNIT_TURN_STARTED deve ser a string "unit_turn_started"
	EventManager.dispatch(GameEvents.UNIT_TURN_STARTED, { "unit": active_unit })

# Chamado quando o botão da UI é clicado
func _on_ui_end_turn(_payload):
	if current_phase == GamePhase.HERO_PHASE:
		var cmd = TurnEndCommand.new()
		await CommandInvoker.execute_command(cmd)

# Chamado pelo TurnEndCommand
func end_current_turn():
	print("Fim do turno de: %s" % active_unit.name)
	active_unit = null
	_activate_next_hero()

func _run_enemy_phase():
	print(">>> Fase dos Inimigos...")
	await get_tree().create_timer(1.0).timeout
	# Aqui entraria a IA dos inimigos
	
	# Passa para próxima fase (simplificado)
	round_number += 1
	_start_round()

# --- A FUNÇÃO QUE FALTAVA (CORREÇÃO DO ERRO) ---
func calculate_movement_cost(path: Array) -> Dictionary:
	var temp_ap = current_ap 
	var temp_mp = current_mp
	var approved_path: Array[Vector2i] = []
	var success = false
	
	for step in path:
		if temp_mp >= 1:
			temp_mp -= 1
			approved_path.append(step)
		elif temp_ap > 0:
			temp_ap -= 1
			temp_mp += 2
			temp_mp -= 1
			approved_path.append(step)
		else:
			break 
			
	if not approved_path.is_empty():
		success = true
		
	return {
		"success": success,
		"path": approved_path,
		"final_ap": temp_ap,
		"final_mp": temp_mp
	}

func _notify_resources():
	var payload = {"ap": current_ap, "mp": current_mp}
	EventManager.dispatch(GameEvents.RESOURCES_UPDATED, payload)
