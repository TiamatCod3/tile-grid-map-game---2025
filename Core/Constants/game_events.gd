@icon("res://Assets/Icons/wifi-signal.png") # Opcional
class_name GameEvents
extends RefCounted
# O valor da string DEVE ser exatamente o nome do sinal no EventManager
const DOOR_STATE_CHANGED = "door_state_changed"
const DOOR_LOCKED_INTERACTION = "door_locked_interaction"

# Outros exemplos futuros
const PLAYER_TOOK_DAMAGE = "player_took_damage"
const GAME_OVER = "game_over"

# --- Sinais de DADOS (Vêm do sistema para a UI) ---
const RESOURCES_UPDATED = "resources_updated"  # payload: { "ap": int, "mp": int }
const HISTORY_UPDATED = "history_updated"      # payload: { "has_undo": bool, "has_redo": bool }

# --- Sinais de INTENÇÃO (Vêm da UI para o sistema) ---
const UI_REQUEST_END_TURN = "ui_request_end_turn" # payload: {}
const UI_REQUEST_RECOVER = "ui_request_recover"   # payload: {}
const UI_REQUEST_UNDO = "ui_request_undo"         # payload: {}
const UI_REQUEST_REDO = "ui_request_redo"         # payload: {}
