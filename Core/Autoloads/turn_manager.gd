# TurnManager.gd (Autoload)
extends Node

signal turn_started
signal turn_ended
signal resources_changed # Útil para atualizar UI

var max_ap: int = 3
var max_mp: int = 0

var current_ap: int = 0
var current_mp: int = 0

func start_turn():
	current_ap = max_ap
	current_mp = max_mp
	emit_signal("turn_started")
	emit_signal("resources_changed")
	print("🔄 Turno Iniciado | AP: %d | MP: %d" % [current_ap, current_mp])

# Tenta gastar AP. Retorna true se conseguiu.
func spend_ap(amount: int) -> bool:
	if current_ap >= amount:
		current_ap -= amount
		emit_signal("resources_changed")
		return true
	return false

# Tenta gastar MP. Retorna true se conseguiu.
func spend_mp(amount: int) -> bool:
	if current_mp >= amount:
		current_mp -= amount
		emit_signal("resources_changed")
		return true
	return false

# Devolve recursos (usado pelo Undo)
func refund_resources(ap: int, mp: int):
	current_ap += ap
	current_mp += mp
	emit_signal("resources_changed")
