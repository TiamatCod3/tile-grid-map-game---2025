class_name TreasureChest
extends Node2D

@export var is_locked: bool = false
var has_been_looted: bool = false

# Chamado quando o herói interage (Ação de abrir)
func interact(hero: Unit):
	if has_been_looted:
		print("Este baú está vazio.")
		return
		
	if is_locked:
		print("O baú está trancado!")
		# Lógica de gastar chave ou teste de ladinagem viria aqui
		return

	# 1. Sorteia o Token
	var rarity_token = LootManager.draw_token()
	var rarity_name = LootManager.Rarity.keys()[rarity_token]
	print("Você encontrou um token: %s" % rarity_name)
	
	# 2. Compra a Carta
	var item_drop = LootManager.draw_item_card(rarity_token)
	
	if item_drop:
		print("Item obtido: %s" % item_drop.item_name)
		
		# 3. Adiciona ao Inventário do Herói
		var inventory = hero.get_node("InventoryComponent")
		if inventory:
			inventory.add_to_backpack(item_drop)
			# Tocar som de loot
			# Mostrar popup na UI: "Você encontrou [Icone] Espada!"
			
	has_been_looted = true
	queue_free() # Ou mudar sprite para baú aberto
