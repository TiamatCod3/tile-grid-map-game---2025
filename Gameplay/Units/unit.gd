class_name Unit
extends Node2D

# --- CONSTANTES ---
const DEFAULT_WEAPON_PATH = "res://Gameplay/Combat/Data/unarmed.tres"

# --- CONFIGURAÇÃO (Inspector) ---
@export var stats: UnitStats # A ficha do personagem (Resource)
@export var equipped_weapon: WeaponStrategy # A estratégia de ataque
@export var move_speed: float = 0.2

# --- ESTADO (Runtime) ---
# Onde estou no Grid Lógico? (A "Verdade" do jogo)
var grid_pos: Vector2i = Vector2i.ZERO

# Recursos Atuais (Resetam ou mudam durante o turno)
var current_ap: int = 0
var current_mp: int = 0

# Controle de Estado
var is_moving: bool = false
var is_dead: bool = false

# --- VISUAIS ---
@onready var visual_sprite: Sprite2D = $Visual # Certifique-se que o nó chama "Visual" no Editor

func _ready() -> void:
	# 1. Configura Stats (Cria cópia única para não alterar o arquivo original do projeto)
	if stats:
		stats = stats.duplicate()
		if not stats.health_depleted.is_connected(_on_death):
			stats.health_depleted.connect(_on_death)
		
		# Aplica textura se definida no recurso
		if stats.sprite and has_node("Visual"):
			$Visual.texture = stats.sprite
			
		# Inicializa AP/MP
		reset_turn_resources()
	else:
		push_warning("Unit %s sem Stats definidos! Usando valores padrão." % name)
		current_ap = 3 # Valor padrão se não tiver Stats
		
	# 2. Configura Arma Padrão se estiver vazio
	if not equipped_weapon:
		equipped_weapon = load(DEFAULT_WEAPON_PATH)

# --- RECURSOS DO TURNO ---
func reset_turn_resources():
	if stats:
		# Puxa os valores definidos no arquivo .tres
		current_ap = stats.max_ap
		current_mp = stats.max_mp
	else:
		# Fallback de segurança se esquecer de colocar o stats
		current_ap = 3 
		current_mp = 2

# --- SISTEMA DE MOVIMENTO (Chamado pelo MoveCommand) ---

# Percorre uma lista de coordenadas visualmente
func traverse_path_visual(path: Array, board: GameBoard) -> void:
	if is_moving: return
	is_moving = true
	
	for step in path:
		# 1. Cria o Tween para este passo
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_LINEAR)
		
		# 2. Move visualmente para o centro do tile
		var target_pixel = board.map_to_local(step)
		tween.tween_property(self, "position", target_pixel, move_speed)
		
		# 3. Aguarda chegar no tile
		await tween.finished
		
		# 4. Atualiza a lógica no Board passo a passo
		# O 'true' indica atualização visual instantânea dentro do tile (stacking)
		board.register_unit_position(self, step, true)
			
	is_moving = false

# Teletransporte (Para Spawn inicial ou Undo)
func snap_to_grid(new_grid_pos: Vector2i, board: GameBoard) -> void:
	grid_pos = new_grid_pos
	position = board.map_to_local(new_grid_pos)
	board.register_unit_position(self, new_grid_pos, true)
	is_moving = false

# --- SISTEMA DE COMBATE ---

# Delega o ataque para a Arma (Strategy Pattern)
func attack_target(target_unit: Unit, board: GameBoard) -> int:
	if equipped_weapon:
		# A arma sabe como calcular dano, alcance e aplicar efeitos
		return await equipped_weapon.execute_attack(self, target_unit, board)
	else:
		print("Erro: %s tentou atacar sem arma!" % name)
		return 0

# Recebe dano (Proxy para o Stats)
func take_damage(amount: int):
	if stats:
		stats.take_damage(amount)
		_play_hit_effect()

func perform_recover():
	var heal_amount = 2
	if stats:
		stats.heal(heal_amount)
	
	# Efeito visual
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.GREEN, 0.2)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)

# --- MORTE E RESSURREIÇÃO (UNDO) ---

func _on_death():
	if is_dead: return
	is_dead = true
	
	print("💀 %s morreu!" % name)
	
	# Desativa lógica
	set_process(false)
	set_process_unhandled_input(false)
	
	# Animação de Morte
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.5)
	
	await tween.finished
	
	# Esconde e avisa o Board para arrumar o tile
	hide()
	
	var board = get_parent() as GameBoard
	if board:
		board.reorganize_visuals(grid_pos)

func revive():
	if not is_dead: return
	is_dead = false
	
	print("✨ %s reviveu!" % name)
	
	show()
	modulate.a = 1.0
	scale = Vector2.ONE
	
	set_process(true)
	set_process_unhandled_input(true)
	
	# Reorganiza o visual (pois ele voltou a ocupar espaço)
	var board = get_parent() as GameBoard
	if board:
		board.reorganize_visuals(grid_pos)

# --- EFEITOS VISUAIS EXTRAS ---

func disarm() -> void:
	if equipped_weapon and equipped_weapon.resource_path == DEFAULT_WEAPON_PATH:
		return

	print("%s foi desarmado!" % name)
	_play_hit_effect(Color.ORANGE)
	equipped_weapon = load(DEFAULT_WEAPON_PATH)

func _play_hit_effect(color: Color = Color.RED):
	var tween = create_tween()
	tween.tween_property(self, "modulate", color, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
