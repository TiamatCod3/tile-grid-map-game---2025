class_name CellData
extends Resource

# Configuração simples de paredes
@export_group("Paredes Fixas")
@export var wall_top: bool = false
@export var wall_bottom: bool = false
@export var wall_left: bool = false
@export var wall_right: bool = false

# Terreno (Chão, Buraco, Água...)
@export var is_walkable: bool = true

var units: Array[Unit] = []

func add_unit(unit: Unit):
	if not units.has(unit):
		units.append(unit)

func remove_unit(unit: Unit):
	units.erase(unit)

func has_units() -> bool:
	return units.size() > 0

func get_enemy() -> Unit:
	for u in units:
		if u.is_in_group("Enemies") and not u.get("is_dead"):
			return u
	return null
