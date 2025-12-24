class_name CameraController
extends Camera2D

# --- CONFIGURAÇÕES EXPORTADAS ---
@export_group("Movimento")
@export var move_speed: float = 600.0  # Velocidade ao usar WASD
@export var allow_wasd: bool = true    # Se permite o jogador mover livremente

@export_group("Zoom")
@export var min_zoom: float = 0.5
@export var max_zoom: float = 4.0
@export var zoom_speed: float = 0.1    # Quanto muda por rolagem do mouse
@export var zoom_smooth: float = 10.0  # Suavidade da transição de zoom

# --- ESTADO INTERNO ---
var target_zoom: Vector2 = Vector2.ONE * 3
var follow_target: Node2D = null
var is_following: bool = false

func _ready() -> void:
	make_current() # Garante que esta é a câmera ativa do jogo
	target_zoom = zoom * 3 # Começa com o zoom que estiver na cena
	
	# Habilita o smoothing nativo do Godot para movimento suave
	position_smoothing_enabled = true 
	position_smoothing_speed = 5.0

func _process(delta: float) -> void:
	_handle_input(delta)
	_apply_zoom(delta)
	_follow_target_logic()

func _unhandled_input(event: InputEvent) -> void:
	# Zoom via Scroll do Mouse
	if event.is_action_pressed("cam_zoom_in"):
		_change_zoom(zoom_speed)
	elif event.is_action_pressed("cam_zoom_out"):
		_change_zoom(-zoom_speed)
	
	# Barra de Espaço: Volta a focar no herói ativo
	if event.is_action_pressed("cam_focus"):
		focus_on_active_unit()

# --- LÓGICA DE INPUT (WASD) ---
func _handle_input(delta: float) -> void:
	if not allow_wasd: return
	
	# Pega o vetor de movimento (Ex: W+D = diagonal)
	var direction = Input.get_vector("cam_move_left", "cam_move_right", "cam_move_up", "cam_move_down")
	
	if direction != Vector2.ZERO:
		# Se o jogador apertou tecla de mover, paramos de seguir o boneco
		is_following = false
		follow_target = null
		
		# Movemos a câmera. Multiplicamos por (1.0 / zoom.x) para que a velocidade
		# pareça constante independente se estamos perto ou longe do chão.
		position += direction * move_speed * (1.0 / zoom.x) * delta

# --- LÓGICA DE SEGUIR ALVO ---
func _follow_target_logic():
	if is_following and is_instance_valid(follow_target):
		# Apenas atualizamos a posição para o alvo.
		# O 'Position Smoothing' do Camera2D fará a suavização visual.
		position = follow_target.position

# --- LÓGICA DE ZOOM ---
func _change_zoom(amount: float):
	target_zoom += Vector2(amount, amount)
	# Limita o zoom para não inverter ou ficar muito longe
	target_zoom.x = clamp(target_zoom.x, min_zoom, max_zoom)
	target_zoom.y = clamp(target_zoom.y, min_zoom, max_zoom)

func _apply_zoom(delta: float):
	# Interpolação suave (Lerp) para o zoom não "pular"
	zoom = zoom.lerp(target_zoom, zoom_smooth * delta)

# --- FUNÇÕES PÚBLICAS (CHAMADAS PELO MAIN) ---

# 1. Configuração Inicial: Centraliza no Mapa e calcula Zoom ideal
func setup_camera_on_grid(center_pos: Vector2, tile_size: int):
	# Posiciona no centro do mapa
	position = center_pos
	
	# Calcula o Zoom para ver uma área de 3x3 tiles + margem (aprox 3.5 tiles)
	# Isso garante que em qualquer resolução, o jogador veja a área relevante
	var viewport_width = get_viewport_rect().size.x
	var visible_width_pixels = tile_size * 4.5 # Ajuste este valor: maior = vê mais mapa
	
	var calculated_zoom = viewport_width / visible_width_pixels
	
	# Aplica imediatamente
	target_zoom = Vector2(calculated_zoom, calculated_zoom)
	zoom = target_zoom
	
	print("🎥 Câmera: Ajustada para centro %s com zoom %.2f" % [center_pos, calculated_zoom])

# 2. Foca no Herói Ativo (Chamado pelo 'Espaço' ou início de turno)
func focus_on_active_unit():
	var unit = TurnManager.active_unit
	if unit:
		follow_target = unit
		is_following = true
		print("🎥 Câmera: Seguindo %s" % unit.name)
