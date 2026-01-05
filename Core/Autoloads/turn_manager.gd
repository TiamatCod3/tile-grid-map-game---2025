extends Node

# --- SINAIS ---
signal turn_started
signal turn_ended
signal resources_changed
# Mantemos este sinal para compatibilidade caso algum script antigo ainda o use,
# mas o foco agora é o EventManager.
signal unit_turn_started(unit) 

# --- FASES DO JOGO ---
enum GamePhase { HERO_PHASE = 0, ENEMY_PHASE = 1, LEVEL_UP_PHASE = 2, DARKNESS_PHASE = 3 }
var current_phase: int = GamePhase.HERO_PHASE
var round_number: int = 1

# --- GERENCIAMENTO DE UNIDADES ---
# Usamos Arrays genéricos para evitar Dependência Cíclica com a classe Unit
var heroes_roster: Array = []
var enemies_roster: Array = [] 
var activation_queue: Array = [] 
var active_unit: Node2D = null 

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
	# Conecta com o sinal de fim de turno da UI (Botão End Turn)
	if EventManager.has_signal("ui_request_end_turn"):
		EventManager.ui_request_end_turn.connect(_on_ui_end_turn)

# --- LOOP DE JOGO ---
# Atualizado para receber também a lista de inimigos
func start_game(heroes: Array, enemies: Array):
	heroes_roster = heroes
	enemies_roster = enemies
	
	round_number = 1
	_start_round()

func _start_round():
	print("\n=== RODADA %d ===" % round_number)
	current_phase = GamePhase.HERO_PHASE
	
	# Reinicia a fila com os heróis vivos
	activation_queue = []
	for h in heroes_roster:
		if not h.is_dead:
			activation_queue.append(h)
			
	_activate_next_hero()

func _activate_next_hero():
	# Se acabou a fila de heróis, começa a vez dos monstros
	if activation_queue.is_empty():
		_run_enemy_phase()
		return

	active_unit = activation_queue.pop_front()
	
	# Reseta AP/MP baseados nos Stats do herói
	if active_unit.has_method("reset_turn_resources"):
		active_unit.reset_turn_resources()
	
	print(">>> Turno de Herói: %s" % active_unit.name)
	_notify_resources()
	
	# Avisa a Câmera e UI
	EventManager.dispatch(GameEvents.UNIT_TURN_STARTED, { "unit": active_unit })

# Chamado quando o jogador clica em "Passar Turno"
func _on_ui_end_turn(_payload):
	if current_phase == GamePhase.HERO_PHASE:
		var cmd = TurnEndCommand.new()
		await CommandInvoker.execute_command(cmd)

# Chamado pelo TurnEndCommand após execução bem sucedida
func end_current_turn():
	if active_unit:
		print("Fim do turno de: %s" % active_unit.name)
	
	active_unit = null
	_activate_next_hero()

# --- FASE DOS INIMIGOS (Implementada) ---
func _run_enemy_phase():
	current_phase = GamePhase.ENEMY_PHASE
	print("\n>>> 🧟 FASE DOS INIMIGOS INICIADA")
	
	# Pequena pausa dramática
	await get_tree().create_timer(0.5).timeout
	
	# Itera por todos os inimigos da fase
	for enemy in enemies_roster:
		# Pula inimigos mortos
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		
		# Define como ativo (Isso faz a câmera focar nele automaticamente!)
		active_unit = enemy
		
		# Reseta os recursos dele (Ex: Zumbi ganha 2 AP)
		if active_unit.has_method("reset_turn_resources"):
			active_unit.reset_turn_resources()
			
		# Dispara evento para a Câmera focar
		EventManager.dispatch(GameEvents.UNIT_TURN_STARTED, { "unit": active_unit })
		
		# Espera a câmera chegar no monstro
		await get_tree().create_timer(0.5).timeout
		
		# Executa a IA
		# Pegamos o Board através do pai do inimigo (já que o TurnManager é global)
		var board = enemy.get_parent()
		
		if board and enemy.has_method("execute_turn"):
			# O monstro decide: andar ou atacar
			await enemy.execute_turn(heroes_roster, board)
		
		# Pausa entre um monstro e outro para o jogador entender o que houve
		await get_tree().create_timer(0.4).timeout
	
	print(">>> Fim da Fase dos Inimigos. Voltando aos Heróis.")
	
	# Prepara próxima rodada
	active_unit = null
	round_number += 1
	_start_round()

# --- CÁLCULO DE CUSTO (Lógica de AP/MP) ---
func calculate_movement_cost(path: Array) -> Dictionary:
	var temp_ap = current_ap 
	var temp_mp = current_mp
	var approved_path: Array[Vector2i] = []
	var success = false
	
	# Simula o custo passo a passo
	for step in path:
		if temp_mp >= 1:
			# Tem movimento livre? Usa.
			temp_mp -= 1
			approved_path.append(step)
		elif temp_ap > 0:
			# Acabou o movimento? Queima 1 AP para ganhar recarga (ex: +2 MP)
			temp_ap -= 1
			temp_mp += 2 # Regra de conversão: 1 AP = 2 Passos
			
			# Gasta 1 desse novo MP para dar o passo atual
			temp_mp -= 1
			approved_path.append(step)
		else:
			# Acabou tudo, para aqui.
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
