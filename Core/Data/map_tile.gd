class_name MapTile
extends Resource

@export var tile_id: String = "1A" # Ex: "Tile 4B"
@export var texture: Texture2D # A imagem de fundo do tile (arte 3x3)

# Um Array que DEVE ter 9 itens (para um grid 3x3)
# Ordem sugerida: 0=TopoEsq, 1=TopoCentro, 2=TopoDir, ..., 8=BaixoDir
@export var cells: Array[CellData]

# Validação para ajudar no editor
#func validate():
	#if cells.size() != 9:
		#push_warning("MapTile " + tile_id + " deve ter exatamente 9 células!")
# --- NOVO: Tamanho do Tile ---
@export var dimensions: Vector2i = Vector2i(3, 3)

# Helper para saber se é um tile padrão
func is_standard() -> bool:
	return dimensions == Vector2i(3, 3)
