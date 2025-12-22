extends Node2D
class_name Door

# Variáveis que o GridBuilder vai preencher
var coord_a: Vector2i
var coord_b: Vector2i

var is_open: bool = false
var is_locked: bool = false

func open_door() -> Tween: # Agora retorna o Tween!
	if is_locked or is_open: return null
	is_open = true
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target_rotation = rotation_degrees + 90
	tween.tween_property(self, "rotation_degrees", target_rotation, 0.4)
	
	return tween # Devolve o controlador da animação

# Função opcional caso precise trancar a porta visualmente depois
func close_door():
	if not is_open: return
	is_open = false
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Gira de volta 90 graus negativos
	tween.tween_property(self, "rotation_degrees", rotation_degrees - 90, 0.4)
