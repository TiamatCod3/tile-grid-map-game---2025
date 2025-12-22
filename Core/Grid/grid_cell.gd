class_name GridCell
extends RefCounted

# --- DADOS BÁSICOS ---
var coord: Vector2i
var world_pos: Vector2

# --- CONTEÚDO ---
# Quem está neste quadrado? (Muito mais rápido que varrer get_children())
var units: Array[Unit] = []

# Referência direta ao objeto interativo (Porta, Baú) se houver
var interactable: Node = null 

# --- NAVEGAÇÃO & PAREDES ---
# Cache de direções: Diz para onde posso ir a partir daqui.
# Ex: { Vector2i.UP: true, Vector2i.RIGHT: false }
var connections: Dictionary = {}

# --- NOVO: Variável que faltava ---
var is_walkable: bool = true 
# ---------------------------------


func _init(_coord: Vector2i, _world_pos: Vector2):
	coord = _coord
	world_pos = _world_pos

# --- GERENCIAMENTO DE UNIDADES ---
func add_unit(unit: Unit):
	if not units.has(unit):
		units.append(unit)

func remove_unit(unit: Unit):
	units.erase(unit)

func has_units() -> bool:
	return units.size() > 0

# Verifica se tem parede impedindo o movimento PARA uma direção específica
func is_blocked_to(direction: Vector2i) -> bool:
	# Se a direção não estiver no dicionário, assume bloqueado por segurança
	return not connections.get(direction, false)

func get_enemy() -> Unit:
	for u in units:
		if u.is_in_group("Enemies") and not u.get("is_dead"):
			return u
	return null
