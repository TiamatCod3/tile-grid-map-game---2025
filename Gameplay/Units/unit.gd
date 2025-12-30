class_name Unit
extends Node2D

@export var stats: UnitStats # Seu recurso atual
var current_ap: int = 0
var current_mp: int = 0
# Aqui conectamos o Resource. 
# O "Stats" é a ficha do personagem.


# DADOS: Onde estou no Grid Lógico? (A Verdade)
# Isso é diferente de 'position' (que é visual/pixels)
@onready var grid_pos: Vector2i = Vector2i(0, 0)

# CONFIGURAÇÃO: Velocidade da animação
@export var move_speed: float = 0.3

# Referência aos nós visuais (opcional, se quiser animar o sprite virando)
@onready var visual: Sprite2D = $Visual

# Variável de controle para não aceitar comandos enquanto anda
var is_moving: bool = false

# NOVO SLOT DE ESTRATÉGIA
@export var equipped_weapon: WeaponStrategy

# Variável para saber se está "morto logicamente" mas ainda na memória
var is_dead: bool = false

# Defina o caminho para o arquivo que você acabou de criar
const DEFAULT_WEAPON_PATH = "res://Gameplay/Combat/Data/Unarmed.tres"

func _ready() -> void:
	if stats:
		# Cria uma cópia única para esse boneco (para não alterar o arquivo original se tomar dano)
		stats = stats.duplicate()
		
		# CONECTA A MORTE
		if not stats.health_depleted.is_connected(_on_death):
			stats.health_depleted.connect(_on_death)
		
		# --- NOVO: CONFIGURAÇÃO VISUAL ---
		# Se tivermos um sprite definido no Stats, aplicamos no nó visual
		if stats.sprite and has_node("Visual"): # Assumindo que o Sprite2D chama "Visual"
			$Visual.texture = stats.sprite
			
		# Inicializa Recursos
		current_ap = stats.max_ap
		current_mp = 0 # ou stats.max_mp se quiser começar com movimento
	else:
		stats = UnitStats.new()
		# Valores padrão de fallback
		current_ap = 3
		
# A FUNÇÃO DE MORTE
func _on_death():
	if is_dead: return # Evita morrer duas vezes
	is_dead = true
	
	print(name + " morreu! Desativando...")
	
	# Desativa processamento e input
	set_process(false)
	set_process_unhandled_input(false)
	
	# Desativa Colisão (para o mouse não clicar mais nele)
	# Assumindo que você tem um CollisionShape2D ou Area2D
	# $Area2D/CollisionShape2D.set_deferred("disabled", true) 
	
	# Animação
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.5)
	
	await tween.finished
	
	# --- ALTERAÇÃO: NÃO FAZEMOS MAIS QUEUE_FREE AQUI ---
	# Em vez de deletar, apenas escondemos.
	hide()
	
	# Avisa o board para reorganizar
	var board = get_parent()
	if board.has_method("reorganize_units_on_tile"):
		board.reorganize_units_on_tile(grid_pos)
		
# Função Pública: O Grid ou TurnManager vai chamar isso.
func walk_to(new_grid_pos: Vector2i, new_world_pos: Vector2) -> void:
	# 1. Atualiza a lógica imediatamente (o jogo sabe que eu já cheguei lá)
	grid_pos = new_grid_pos
	
	# 2. Cria o Tween (O animador temporário)
	var tween = create_tween()
	
	# 3. Configura a Curva (Aqui entra o seu "toque profissional")
	# TRANS_SINE = Movimento orgânico
	# EASE_IN_OUT = Começa devagar, acelera, freia no final
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# 4. Define o movimento (Propriedade, Valor Final, Duração)
	tween.tween_property(self, "position", new_world_pos, move_speed)
	
	# Opcional: Se quiser esperar o movimento acabar para fazer algo:
	# await tween.finished
func walk_path(path_stack: Array[Vector2i], board_layer: TileMapLayer) -> void:
	if is_moving:
		return # Ignora cliques se já estiver andando
	
	is_moving = true
	
	# Guarda de onde saiu para reorganizar quem ficou lá
	var start_tile = grid_pos
	
	# Loop para consumir cada passo da lista
	for next_step in path_stack:
		# 1. Calcula a posição visual (Pixel) do próximo passo
		var target_pixel = board_layer.map_to_local(next_step)
		
		# 2. Executa o movimento de UM passo
		await move_single_step(next_step, target_pixel)
		
		# O loop só continua depois que o 'await' acima terminar!
	
	is_moving = false
	print("Cheguei ao destino!")
	# --- NOVO CÓDIGO ---
	# Avisa o board para reorganizar visualmente o tile de origem e destino
	if board_layer.has_method("reorganize_units_on_tile"):
		board_layer.reorganize_units_on_tile(start_tile) # Arruma quem ficou pra trás
		board_layer.reorganize_units_on_tile(grid_pos)   # Arruma a nova casa (comigo nela)
		
# Função auxiliar privada para mover 1 quadrado
func move_single_step(target_grid: Vector2i, target_pixel: Vector2) -> void:
	# Atualiza lógica
	grid_pos = target_grid
	
	# Cria animação
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR) # Linear fica melhor para caminhos contínuos
	tween.tween_property(self, "position", target_pixel, move_speed)
	
	# Espera o Tween terminar antes de liberar a função
	await tween.finished

# Função para definir a posição inicial instantaneamente (sem animar)
func snap_to_grid(new_grid_pos: Vector2i, new_world_pos: Vector2) -> void:
	grid_pos = new_grid_pos
	position = new_world_pos
	# Reseta qualquer tween ou estado anterior
	is_moving = false

# Função de ataque
# FUNÇÃO ATTACK REFATORADA (O Contexto)
# Agora ela delega a inteligência para a Strategy
func attack_target(target_unit: Unit, board: GameBoard) -> int:
	
	if equipped_weapon:
		# O herói não sabe COMO atacar, a arma sabe.
		# Repassa o valor que a arma retornou
		return await equipped_weapon.execute_attack(self, target_unit, board)
		#equipped_weapon.execute_attack(self, target_unit, board)
		
	else:
		print(name + " não tem arma equipada! (Implementar soco?)")
		return 0

func perform_recover():
	# Define quanto cura. No MD costuma ser curar tudo ou valor fixo.
	# Vamos pôr cura de 2 para testar.
	var heal_amount = 2
	
	# Animaçãozinha de cura (pisca verde)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.GREEN, 0.2)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	if stats:
		stats.heal(heal_amount)

# Nova função para RESSUSCITAR (Undo)
func revive():
	if not is_dead: return
	is_dead = false
	
	print(name + " ressuscitou pelo Undo!")
	
	show()
	modulate.a = 1.0
	scale = Vector2(1, 1) # Volta ao tamanho normal
	
	set_process(true)
	set_process_unhandled_input(true)
	# Reative colisão se tiver desativado
	
	# Reorganiza o tile (ele voltou a ocupar espaço)
	var board = get_parent()
	if board.has_method("reorganize_units_on_tile"):
		board.reorganize_units_on_tile(grid_pos)

func disarm() -> void:
	# Se já está desarmado (usando a arma padrão), ignora
	if equipped_weapon and equipped_weapon.resource_path == DEFAULT_WEAPON_PATH:
		return

	print(name + " FOI DESARMADO! A arma caiu.")
	
	# Efeito Visual (Opcional): Texto flutuante ou cor piscando
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.2)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	# Lógica do Inventário (No futuro, moveriamos a arma para a "Mochila")
	# Por enquanto, vamos simular que a arma foi perdida/destruída ou caiu no chão.
	
	# Carrega o Unarmed
	equipped_weapon = load(DEFAULT_WEAPON_PATH)

# Adicione esta função na sua classe Unit
func traverse_path_visual(path: Array, board: GameBoard) -> void:
	is_moving = true
	
	for step in path:
		var tween = create_tween()
		# Nota: Movi a lógica de tween para cá. 
		# O Command apenas diz "ande", a Unit decide "como" (velocidade, easing).
		tween.tween_property(self, "position", board.map_to_local(step), 0.2)
		await tween.finished
		
		# O registro no board acontece passo a passo
		#board.(self, step)
		board.register_unit_position(self, step)
			
	is_moving = false

func reset_turn_resources():
	if stats:
		current_ap = stats.max_ap
	else:
		current_ap = 3
	current_mp = 0
