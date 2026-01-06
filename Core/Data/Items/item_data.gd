class_name ItemData
extends Resource

enum Rarity { COMMON, RARE, EPIC, LEGENDARY, MOB, STARTING }
enum SlotType { HEAD, CHEST, FEET, ACCESSORY, TWO_HAND,  HAND, CONSUMABLE }

@export_category("Visuals")
@export var item_name: String = "Item Name"
@export var icon: Texture2D

@export_category("Properties")
@export var rarity: Rarity = Rarity.COMMON
@export var slot_type: SlotType = SlotType.HAND

# Dados básicos de combate que o item PROVÊ (fixos)
@export_category("Base Stats")
@export var yellow_dice: int = 0
@export var orange_dice: int = 0
@export var red_dice: int = 0
@export var blue_dice: int = 0

# Lista de Habilidades (Passivas ou Ativas) que o item concede
@export_category("Abilities")
@export var granted_abilities: Array[Ability] = []

# Função auxiliar unificada
func get_dice_contribution() -> Dictionary:
	var pool = { "yellow": yellow_dice, "orange": orange_dice, "red": red_dice, "blue": blue_dice }
	
	# Somar dados vindos das habilidades PASSIVAS do item
	for ability in granted_abilities:
		if ability.trigger == Ability.Trigger.PASSIVE:
			if ability.stat_modifiers.has("yellow_dice"): pool["yellow"] += ability.stat_modifiers["yellow_dice"]
			if ability.stat_modifiers.has("blue_dice"): pool["blue"] += ability.stat_modifiers["blue_dice"]
			# ... etc
	return pool
