extends Node

# Configuração da "Bag" (Saco de Tesouros)
var treasure_bag: Array[int] = [] # 0 = Common, 1 = Rare, 2 = Epic, 3 = Legendary

# Database de Itens (Carregados dos arquivos .tres)
var common_deck: Array[ItemData] = []
var rare_deck: Array[ItemData] = []
var epic_deck: Array[ItemData] = []
var starting_deck: Array[ItemData] = []

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
	
func _ready():
	_load_item_database()
	reset_bag_level_1() # Configuração inicial (Nível 1-2)

# Configuração inicial baseada no MD2 (Exemplo: 10 Comuns, 5 Raros)
func reset_bag_level_1():
	treasure_bag.clear()
	for i in range(10): treasure_bag.append(Rarity.COMMON)
	for i in range(5):  treasure_bag.append(Rarity.RARE)
	treasure_bag.shuffle()
	print("Loot Bag Inicializada: %d tokens." % treasure_bag.size())

# Simula puxar um token da sacola
func draw_token() -> int:
	if treasure_bag.is_empty():
		push_warning("A sacola de loot está vazia! Reabastecendo com comuns...")
		return Rarity.COMMON # Fallback
	
	# Pega e remove o token (pop_front ou pop_back)
	var token = treasure_bag.pop_back()
	
	# Regra do MD2: O token volta pra sacola depois de desenhar a carta?
	# Geralmente sim, a menos que o jogo diga o contrário. 
	# Se quiser que volte, descomente a linha abaixo:
	# treasure_bag.insert(0, token); treasure_bag.shuffle()
	
	return token

# Pega um item aleatório do baralho correspondente ao token
func draw_item_card(rarity: int) -> ItemData:
	var deck = []
	match rarity:
		Rarity.COMMON: deck = common_deck
		Rarity.RARE: deck = rare_deck
		Rarity.EPIC: deck = epic_deck
	
	if deck.is_empty():
		push_warning("Baralho de raridade %d está vazio!" % rarity)
		return null
		
	# Em jogos de carta, você compraria do topo. Aqui faremos pick_random.
	return deck.pick_random().duplicate()

# Carregamento fictício (na prática, usaria load_resource de pastas)
func _load_item_database():
	# Carregar itens da pasta gerada
	var path = "res://Core/Data/Items/Starting/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var item = load(path + file_name)
				if item is ItemData:
					starting_deck.append(item)
			file_name = dir.get_next()
		print("Starting Deck carregado com %d itens." % starting_deck.size())
