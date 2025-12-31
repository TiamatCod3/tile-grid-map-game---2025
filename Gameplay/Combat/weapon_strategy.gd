class_name WeaponStrategy
extends Resource

# Atributos comuns a todas as armas
@export var name: String = "Weapon"
@export var damage: int = 1
@export var max_range: int = 1
@export var min_range: int = 0 
@export var ap_cost: int = 1 

# Chance de aplicar efeito (0.0 a 1.0)
@export_range(0.0, 1.0) var disarm_chance: float = 0.0

# Função Virtual: Executa o ataque
func execute_attack(attacker: Unit, target: Unit, board: GameBoard) -> int:
	push_error("WeaponStrategy: execute_attack deve ser implementado!")
	return 0
	
# Tenta aplicar efeitos especiais baseados na sorte
func try_apply_effects(target: Unit) -> bool:
	if disarm_chance > 0.0:
		if randf() <= disarm_chance:
			if target.has_method("disarm"):
				target.disarm()
				return true
	return false
