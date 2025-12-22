# Caminho: res://Core/Autoloads/CommandInvoker.gd
# Configurar no Project Settings -> Globals -> Autoload como "CommandInvoker"
extends Node

# --- SINAIS ---
# Útil para a UI atualizar os botões de Undo/Redo (habilitar/desabilitar)
signal history_changed 

# --- HISTÓRICO ---
var undo_stack: Array[Command] = []
var redo_stack: Array[Command] = []

# --- FUNÇÃO PRINCIPAL ---
# Chamada pelo InteractionController para realizar qualquer ação
func execute_command(cmd: Command) -> void:
	# 1. Limpa o Redo (Nova linha do tempo)
	if not redo_stack.is_empty():
		print("Invoker: Limpando pilha de Redo.")
		redo_stack.clear()
		history_changed.emit()
	
	# 2. Executa e CAPTURA O RESULTADO (Aqui está a correção)
	# Como mudamos o execute() para retornar bool, pegamos o valor aqui.
	@warning_ignore("redundant_await")
	var success = await cmd.execute()
	
	# 3. Verifica se deu certo usando a variável local 'success'
	if success:
		undo_stack.append(cmd)
		print("✅ Invoker: Comando registrado. Undo: %d" % undo_stack.size())
		history_changed.emit()
	else:
		print("❌ Invoker: Comando falhou ou foi cancelado.")

# --- UNDO (Desfazer) ---
func undo_last_command():
	if undo_stack.is_empty():
		print("Invoker: Nada para desfazer.")
		return
	
	# 1. Tira do topo da pilha de Undo
	var cmd = undo_stack.pop_back()
	print("⏪ Invoker: Desfazendo ", cmd)
	
	# 2. Executa a lógica inversa (Devolve MP, move boneco de volta, etc)
	cmd.undo()
	
	# 3. Joga para a pilha de Redo (caso o jogador se arrependa de desfazer)
	redo_stack.append(cmd)
	history_changed.emit()

# --- REDO (Refazer) ---
func redo_last_command():
	if redo_stack.is_empty():
		print("Invoker: Nada para refazer.")
		return
	
	# 1. Tira do topo da pilha de Redo
	var cmd = redo_stack.pop_back()
	print("⏩ Invoker: Refazendo ", cmd)
	
	# 2. Re-executa o comando
	# NOTA: O comando deve ser inteligente! Se ele usa RNG (dados),
	# ele deve usar o valor salvo na memória, e não rolar o dado de novo.
	await cmd.execute()
	
	# 3. Joga de volta para a pilha de Undo
	undo_stack.append(cmd)
	history_changed.emit()

# --- UTILITÁRIOS ---
func clear_history():
	undo_stack.clear()
	redo_stack.clear()
	history_changed.emit()

func has_undo() -> bool:
	return not undo_stack.is_empty()

func has_redo() -> bool:
	return not redo_stack.is_empty()
