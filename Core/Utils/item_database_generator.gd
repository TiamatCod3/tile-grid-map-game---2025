@tool
extends Node

# Caminho onde os itens serão salvos
const SAVE_PATH = "res://Core/Data/Items/Starting/"

func _ready():
	# Só roda se for chamado explicitamente ou via plugin, 
	# mas aqui vamos colocar num nó temporário na cena e rodar.
	if not Engine.is_editor_hint():
		create_starting_items()

func create_starting_items():
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(SAVE_PATH):
		dir.make_dir_recursive(SAVE_PATH)
	
	print("--- Gerando Itens Iniciais ---")

	# 1. Leather Armor (Chest, 1 Blue)
	_create_item("leather_armor", "Leather Armor", ItemData.SlotType.CHEST, ItemData.Rarity.STARTING, 
		false, {}, {"blue": 1})

	# 2. Magic Staff (2H, 1 Yellow, Ability: Attack +1 Mana)
	var staff_ab = _create_ability("Mana Recharge", Ability.Trigger.ON_ATTACK, {}, {"mana_recover": 1})
	_create_item("magic_staff", "Magic Staff", ItemData.SlotType.TWO_HAND, ItemData.Rarity.STARTING, 
		true, {"yellow": 1}, {}, [staff_ab])

	# 3. Short Bow (2H, 2 Yellow)
	# Nota: O texto diz "1 Yellow 1 Yellow", então são 2 amarelos
	_create_item("short_bow", "Short Bow", ItemData.SlotType.TWO_HAND, ItemData.Rarity.STARTING, 
		true, {"yellow": 2})

	# 4. Light Axe (2H, 1 Orange)
	_create_item("light_axe", "Light Axe", ItemData.SlotType.TWO_HAND, ItemData.Rarity.STARTING, 
		true, {"orange": 1})

	# 5. Magic Wand (1H, 1 Yellow, Ability: Attack(1 Mana) -> +1 Hit)
	var wand_ab = _create_ability("Arcane Bolt", Ability.Trigger.ON_ATTACK, {"mana": 1}, {"hits": 1})
	_create_item("magic_wand", "Magic Wand", ItemData.SlotType.HAND, ItemData.Rarity.STARTING, 
		false, {"yellow": 1}, {}, [wand_ab])

	# 6. Rusty Sword (1H, 1 Yellow, Ability: Attack -> 1 Reroll)
	# Reroll é uma mecânica especial, passamos no modificador
	var sword_ab = _create_ability("Clumsy Strike", Ability.Trigger.ON_ATTACK, {}, {"reroll": 1})
	_create_item("rusty_sword", "Rusty Sword", ItemData.SlotType.HAND, ItemData.Rarity.STARTING, 
		false, {"yellow": 1}, {}, [sword_ab])

	# 7. Dagger (1H, 1 Yellow, Ability: Attack(1 Mana) -> Defender -1 Save/Pierce)
	var dagger_ab = _create_ability("Piercing Thrust", Ability.Trigger.ON_ATTACK, {"mana": 1}, {"pierce": 1})
	_create_item("dagger", "Dagger", ItemData.SlotType.HAND, ItemData.Rarity.STARTING, 
		false, {"yellow": 1}, {}, [dagger_ab])

	# 8. Mana Potion (Consumable, +2 Mana)
	# Usamos Trigger.ACTION (gasta ação para beber)
	var mana_pot_ab = _create_ability("Drink Mana", Ability.Trigger.ACTION, {}, {"mana_restore": 2})
	_create_item("mana_potion", "Mana Potion", ItemData.SlotType.CONSUMABLE, ItemData.Rarity.STARTING, 
		false, {}, {}, [mana_pot_ab])

	# 9. Health Potion (Consumable, Heal 3)
	var health_pot_ab = _create_ability("Drink Health", Ability.Trigger.ACTION, {}, {"heal": 3})
	_create_item("health_potion", "Health Potion", ItemData.SlotType.CONSUMABLE, ItemData.Rarity.STARTING, 
		false, {}, {}, [health_pot_ab])

	print("--- Concluído! Verifique a pasta %s ---" % SAVE_PATH)

# Função auxiliar para criar Ability
func _create_ability(name: String, trigger: Ability.Trigger, costs: Dictionary, modifiers: Dictionary) -> Ability:
	var ab = Ability.new()
	ab.name = name
	ab.trigger = trigger
	ab.stat_modifiers = modifiers
	
	if costs.has("mana"): ab.mana_cost = costs["mana"]
	if costs.has("action"): ab.action_point_cost = costs["action"]
	
	return ab

# Função auxiliar para criar ItemData
func _create_item(file_name: String, item_name: String, slot: ItemData.SlotType, rarity: ItemData.Rarity, 
	two_handed: bool, attack_dice: Dictionary = {}, defense_dice: Dictionary = {}, abilities: Array[Ability] = []):
	
	var item = ItemData.new()
	item.item_name = item_name
	item.slot_type = slot
	item.rarity = rarity
	item.is_two_handed = two_handed
	
	# Configurar dados
	item.yellow_dice = attack_dice.get("yellow", 0)
	item.orange_dice = attack_dice.get("orange", 0)
	item.red_dice = attack_dice.get("red", 0)
	item.blue_dice = defense_dice.get("blue", 0)
	
	# Configurar Habilidades
	item.granted_abilities = abilities
	
	# Salvar no disco
	var full_path = SAVE_PATH + file_name + ".tres"
	var error = ResourceSaver.save(item, full_path)
	if error == OK:
		print("Salvo: " + full_path)
	else:
		printerr("Erro ao salvar " + full_path)
