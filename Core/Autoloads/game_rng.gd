class_name Ability
extends Resource

enum Trigger {
	PASSIVE,        # Ativo sempre (ex: +1 Vida, +1 Movimento)
	ACTION,         # Gasta uma ação para usar (Active Skill)
	FREE_ACTION,    # Ação livre (1x por turno geralmente)
	ON_ATTACK,      # Gatilho: Ao rolar dados de ataque
	ON_DEFENSE,     # Gatilho: Ao rolar dados de defesa
	ON_MOVE,        # Gatilho: Ao entrar numa zona
	ROUND_START,    # Gatilho: Inicio do Round
	ROUND_END       # Gatilho: Fim do Round
}

enum Target { SELF, ONE_ENEMY, ALL_ENEMIES_IN_ZONE, ALLIES_IN_ZONE }

@export_category("General Info")
@export var name: String = "Ability Name"
@export var icon: Texture2D
@export_multiline var description: String = "Description..."
@export var level_requirement: int = 0 # Usado para Skill Trees de heróis

@export_category("Mechanics")
@export var trigger: Trigger = Trigger.PASSIVE
@export var target: Target = Target.SELF
@export var requires_shadow: bool = false # Mecânica de Sombra do MD2

@export_category("Costs")
@export var mana_cost: int = 0
@export var action_point_cost: int = 0
@export var health_cost: int = 0
@export var movement_point_cost: int = 0


@export_category("Effects & Bonuses")
# Dicionário flexível para stats. Ex: {"yellow_dice": 1, "max_health": 2, "movement": 1}
@export var stat_modifiers: Dictionary = {}

# Se a habilidade for complexa demais para dados (ex: Teleporte), 
# podemos anexar um script que executa a lógica.
@export var custom_effect_script: Script
