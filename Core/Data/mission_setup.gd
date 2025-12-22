class_name MissionSetup
extends Resource

@export var mission_name: String = "Nova Missão"
@export var description: String = "Descrição da missão."
# AGORA SÓ EXISTE ISSO:
# Chave: A coordenada exata da Célula Superior Esquerda no mundo (0,0), (0,3), (3,3)...
# Valor: O recurso do Tile
@export var layout: Dictionary[Vector2i, MapTile] = {} 

# Rotações para as mesmas coordenadas
@export var layout_rotation: Dictionary[Vector2i, int] = {}

# Objetos e Spawns continuam iguais
@export var doors: Dictionary[Vector2i, bool] = {}
# Lista de coordenadas onde os heróis podem nascer (Ex: Zona Inicial)
@export var heroes_spawn_points: Array[Vector2i] = [Vector2i(0, 0)]

# Cada item é um Dict: { "scene": "path", "pos": Vector2i, "rot": 0, "props": {} }
@export var doors_data: Array[Dictionary] = []
@export var chests_data: Array[Dictionary] = []
@export var enemies_data: Array[Dictionary] = []
