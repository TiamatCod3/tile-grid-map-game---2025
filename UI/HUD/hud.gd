extends CanvasLayer

@onready var label_ap: Label = $VBoxContainer/LabelAP
@onready var label_mp: Label = $VBoxContainer/LabelMP
@onready var btn_end_turn: Button = $Finish
@onready var btn_recover: Button = $HBoxContainer/BtnRecover
@onready var btn_undo: Button = $HBoxContainer/BtnUndo
@onready var btn_redo: Button = $HBoxContainer/BtnRedo

func _ready() -> void:
	# 1. ESCUTAR ATUALIZAÇÕES (O HUD reage passivamente)
	# Quando o TurnManager mudar AP/MP, ele avisa aqui
	EventManager.resources_updated.connect(_update_labels)
	
	# Quando o Invoker mudar a pilha, ele avisa aqui
	EventManager.history_updated.connect(_update_undo_buttons)
	
	# 2. CONECTAR BOTÕES (O HUD despacha intenções)
	btn_end_turn.pressed.connect(func(): 
		EventManager.dispatch(GameEvents.UI_REQUEST_END_TURN)
	)
	
	btn_recover.pressed.connect(func(): 
		EventManager.dispatch(GameEvents.UI_REQUEST_RECOVER)
	)
	
	btn_undo.pressed.connect(func(): 
		EventManager.dispatch(GameEvents.UI_REQUEST_UNDO)
	)
	
	btn_redo.pressed.connect(func(): 
		EventManager.dispatch(GameEvents.UI_REQUEST_REDO)
	)

	# 3. Solicitar estado inicial (Opcional, mas boa prática para UI não começar zerada)
	# Você pode ter um sinal 'request_refresh' ou ler uma vez dos singletons
func _update_labels(payload: Dictionary):
	# O payload já traz tudo mastigado. O HUD não calcula nada.
	var ap = payload.get("ap", 0)
	var mp = payload.get("mp", 0)
	
	label_ap.text = "AP: " + str(ap)
	label_mp.text = "MP: " + str(mp)
	
	# Lógica puramente visual (cor) permanece aqui
	if ap == 0 and mp == 0:
		label_ap.modulate = Color.RED
	elif ap > 0:
		label_ap.modulate = Color.YELLOW
	else:
		label_ap.modulate = Color.GRAY

func _update_undo_buttons(payload: Dictionary):
	if btn_undo: btn_undo.disabled = not payload.get("has_undo", false)
	if btn_redo: btn_redo.disabled = not payload.get("has_redo", false)
