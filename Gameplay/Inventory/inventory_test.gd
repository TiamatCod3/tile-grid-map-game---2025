extends Node2D

@export var inventory: Inventory

func _ready():
	var dagger = load("res://Core/Data/Items/Starting/dagger.tres")
	inventory.equip_item(dagger)
