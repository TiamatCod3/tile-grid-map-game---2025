extends Resource
class_name Inventory

@export_category("Equipment")
#@export equipped_armour
#@export var equipped_helmet: ItemData
#@export var equipped_armor: ItemData
#@export var equipped_boots: ItemData
#@export var equipped_left_hand: ItemData
#@export var equipped_right_hand: ItemData
#@export var equipped_both_hand: ItemData
#@export var equipped_miscelaneous: ItemData
#@export var backpack: Array[ItemData]
@export var equipment:Dictionary = {
	"helmet": null,
	"armor": null
}

func equip_item(item: ItemData):
	print(item.slot_type)

func _to_string():
	return 
