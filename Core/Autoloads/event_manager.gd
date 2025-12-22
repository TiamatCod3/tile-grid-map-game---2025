extends Node

# --- DEFINIÇÃO DE PRIORIDADES ---
enum Priority {
	LOW = 0,
	NORMAL = 1,
	HIGH = 2,
	CRITICAL = 3
}

# --- CLASSE DE EVENTO ---
class GameEvent:
	var name: String
	var payload: Dictionary # Mudou de Array para Dictionary
	var priority: int
	
	func _init(evt_name: String, evt_payload: Dictionary, evt_priority: int):
		name = evt_name
		payload = evt_payload
		priority = evt_priority

# --- SINAIS PADRONIZADOS ---
# Regra de Ouro: Todo sinal recebe APENAS um argumento 'payload'
signal door_state_changed(payload) # payload: { "node": Door, "is_open": bool }
signal door_locked_interaction(payload) # payload: { "node": Door }

# Outros exemplos
signal player_took_damage(payload) # { "amount": 10, "source": "Lava" }
signal debug_message(payload)      # { "msg": "Ola" }

signal player_moved(payload)

# Sinais de UI/Dados
signal resources_updated(payload)
signal history_updated(payload)

# Sinais de Comandos de UI
signal ui_request_end_turn(payload)
signal ui_request_recover(payload)
signal ui_request_undo(payload)
signal ui_request_redo(payload)

# --- FILA ---
var _event_queue: Array[GameEvent] = []
const MAX_EVENTS_PER_FRAME = 10 

func _ready():
	_validar_sinais()
	
func _validar_sinais():
	# Lista de todos os sinais que DEVEM existir
	var required_signals = [
		GameEvents.DOOR_STATE_CHANGED,
		GameEvents.DOOR_LOCKED_INTERACTION
	]

	
	for sig in required_signals:
		if not has_signal(sig):
			push_error("ERRO CRÍTICO: O sinal '%s' definido em GameEvents não foi declarado no EventManager!" % sig)
			get_tree().quit() # Fecha o jogo na cara do desenvolvedor para ele arrumar
			
# --- DISPATCH ---
# Agora recebe um Dictionary. O padrão é vazio {} para eventos sem dados.
func dispatch(signal_name: String, payload: Dictionary = {}, priority: int = Priority.NORMAL) -> void:
	if not has_signal(signal_name):
		push_error("Evento inexistente: " + signal_name)
		return
		
	var new_event = GameEvent.new(signal_name, payload, priority)
	_event_queue.append(new_event)
	_event_queue.sort_custom(func(a, b): return a.priority > b.priority)

# --- PROCESSAMENTO ---
func _process(_delta):
	if _event_queue.is_empty():
		return
		
	var processed_count = 0
	while not _event_queue.is_empty() and processed_count < MAX_EVENTS_PER_FRAME:
		var event = _event_queue.pop_front()
		
		# --- A GRANDE VANTAGEM ---
		# Não precisamos mais de callv ou arrays dinâmicos.
		# A chamada é sempre idêntica e segura.
		emit_signal(event.name, event.payload)
		
		_debug_event(event)
		processed_count += 1

func _debug_event(event):
	if event.priority >= Priority.NORMAL:
		# Imprime o dicionário formatado
		print("[EventBus] %s | Data: %s" % [event.name, event.payload])
