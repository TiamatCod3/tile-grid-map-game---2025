class_name MissionSetup
extends Resource

# AGORA SÓ EXISTE ISSO:
# Chave: A coordenada exata da Célula Superior Esquerda no mundo (0,0), (0,3), (3,3)...
# Valor: O recurso do Tile
@export var layout: Dictionary[Vector2i, MapTile] = {} 

# Rotações para as mesmas coordenadas
@export var layout_rotation: Dictionary[Vector2i, int] = {}

# Objetos e Spawns continuam iguais
@export var doors: Dictionary[Vector2i, bool] = {}
@export var player_spawns: Vector2i
