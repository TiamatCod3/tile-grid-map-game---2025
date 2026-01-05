class_name UseConsumableCommand
extends Command

var unit: Unit
var item: ItemData

func _init(p_unit: Unit, p_item: ItemData):
	unit = p_unit
	item = p_item

func execute() -> bool:
	# Validações
	if item.slot_type != ItemData.SlotType.CONSUMABLE: return false
	if unit.stats.current_ap < 1: 
		print("Sem AP para usar item.")
		return false
	
	print("%s usou %s" % [unit.name, item.item_name])
	
	# Executar efeitos das habilidades do item
	for ab in item.granted_abilities:
		if ab.trigger == Ability.Trigger.ACTION:
			# Efeitos de Stats
			if ab.stat_modifiers.has("heal"):
				unit.heal(ab.stat_modifiers["heal"])
			if ab.stat_modifiers.has("mana_restore"):
				unit.modify_mana(ab.stat_modifiers["mana_restore"])
	
	# Remover do inventário
	var inv = unit.get_node("InventoryComponent")
	inv.backpack.erase(item) # Ou equipados, se você permitir equipar poção
	inv.emit_signal("inventory_changed")
	
	# Gastar AP
	unit.stats.current_ap -= 1
	return true
