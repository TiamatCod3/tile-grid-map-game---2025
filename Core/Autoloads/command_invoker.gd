extends Node

# --- HISTÓRICO ---
var undo_stack: Array[Command] = []
var redo_stack: Array[Command] = []

# --- FUNÇÃO PRINCIPAL ---
func execute_command(cmd: Command) -> bool: # Agora retorna bool!
	# 1. Limpa o Redo (se você fez algo novo, perdeu o futuro alternativo)
	if not redo_stack.is_empty():
		redo_stack.clear()
	
	# 2. Executa e CAPTURA O RESULTADO
	# Se o comando falhar (ex: sem mana), ele retorna false
	var success = await cmd.execute()
	
	# 3. Se deu certo, salva no histórico
	if success:
		undo_stack.append(cmd)
		print("✅ Invoker: Comando registrado. Undo: %d" % undo_stack.size())
	else:
		print("❌ Invoker: Comando falhou ou foi cancelado.")
		
	# 4. Avisa a UI (independente se falhou ou não, é bom atualizar)
	_notify_history_change()
	
	return success

# --- UNDO (Desfazer) ---
func undo_last_command():
	if undo_stack.is_empty():
		return
	
	# 1. Tira do topo da pilha de Undo
	var cmd = undo_stack.pop_back()
	print("⏪ Invoker: Desfazendo ", cmd)
	
	# 2. Executa a lógica inversa
	await cmd.undo()
	
	# 3. Joga para a pilha de Redo
	redo_stack.append(cmd)
	_notify_history_change()

# --- REDO (Refazer) ---
func redo_last_command():
	if redo_stack.is_empty():
		return
	
	# 1. Tira do topo da pilha de Redo
	var cmd = redo_stack.pop_back()
	print("⏩ Invoker: Refazendo ", cmd)
	
	# 2. Re-executa o comando
	await cmd.execute()
	
	# 3. Joga de volta para a pilha de Undo
	undo_stack.append(cmd)
	_notify_history_change()

# --- UTILITÁRIOS ---

# Função chamada pelo TurnEndCommand para "queimar" o histórico
func clear_history():
	undo_stack.clear()     # <--- CORREÇÃO AQUI (Era 'history')
	redo_stack.clear()
	_notify_history_change()

func has_undo() -> bool:
	return not undo_stack.is_empty()

func has_redo() -> bool:
	return not redo_stack.is_empty()

# --- NOTIFICAÇÃO VIA EVENT MANAGER ---
func _notify_history_change():
	var payload = {
		"has_undo": has_undo(),
		"has_redo": has_redo()
	}
	# Dispara o evento global que o HUD está escutando
	EventManager.dispatch(GameEvents.HISTORY_UPDATED, payload)
