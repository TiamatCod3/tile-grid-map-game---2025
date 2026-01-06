class_name UnitStats
extends Resource

# Usamos @export para que esses campos apareçam no editor do Godot
# --- IDENTIDADE ---
@export_group("Identidade")
@export var unit_name: String = "Heroi"
@export var job_class: String = "Guerreiro" # Ex: Mago, Ladino
@export var portrait: Texture2D # Para usar no HUD
@export var sprite: Texture2D   # Para usar no boneco no mapa

# --- VITALIDADE ---
@export_group("Vitalidade")
@export var max_health: int = 5
@export var current_health: int = 5

# --- RECURSOS DE TURNO ---
@export_group("Recursos")
@export var max_ap: int = 3
@export var max_mp: int = 0 # Geralmente começa com 0 e ganha convertendo AP
@export var inventory:= Inventory.new()

@export_group("Combate")
#@export var attack_damage: int = 1
#@export var attack_range: int = 1 # 1 = Corpo a corpo
@export var equipped_weapon: WeaponStrategy

@export_group("Movimento")
@export var move_speed: int = 3 # Quantas ações custa ou quantos quadrados anda


# SINAL NOVO
signal health_depleted

# Função auxiliar para tomar dano (Lógica de dados pura)
func take_damage(amount: int):
	current_health -= amount
	current_health = clampi(current_health, 0, max_health)
	print("Vida atualizada: ", current_health, "/", max_health)
	
	if current_health == 0:
		print("Stats: Vida zerada! Emitindo sinal de morte.")
		health_depleted.emit() # <--- O GRITO

func heal(amount: int):
	current_health += amount
	current_health = clampi(current_health, 0, max_health)
	print("Curado! Vida: ", current_health, "/", max_health)
	# Poderíamos emitir um sinal 'health_changed' aqui para atualizar barra de vida UI
