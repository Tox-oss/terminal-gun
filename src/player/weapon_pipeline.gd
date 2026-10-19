extends RefCounted
## Pipeline RAM dei nodi di codice. -gameplay.
##
## Slot limitati: superare la capacita' o creare una combinazione instabile
## provoca un Buffer Overflow (autodanno + surriscaldamento dell'arma).

const CAPACITY := 4
const MODIFIERS := ["-r", "-f", "sudo"]
const OPERATORS := ["|", "&&"]
const COMMANDS := ["echo", "grep", "ping", "curl", "rm"]

var player = null
var weapon = null
var capacity: int = CAPACITY
var slots: Array[String] = []
var overflowed := false

func _init() -> void:
	slots = []

func _is_operator(id: String) -> bool:
	return OPERATORS.has(id)

func _is_modifier(id: String) -> bool:
	return MODIFIERS.has(id)

func _is_command(id: String) -> bool:
	return COMMANDS.has(id)

func is_stable(slots_in: Array = []) -> bool:
	var s: Array = slots if slots_in.is_empty() else slots_in
	if s.size() > capacity:
		return false
	if s.is_empty():
		return true
	# Un operatore non puo' stare in testa o in coda, ne' accanto a un altro.
	for i in s.size():
		if _is_operator(str(s[i])):
			if i == 0 or i == s.size() - 1:
				return false
			if _is_operator(str(s[i - 1])) or _is_operator(str(s[i + 1])):
				return false
	# Un modificatore deve seguire un comando (o un altro modificatore attaccato
	# a un comando).
	if _is_modifier(str(s[0])):
		return false
	for i in range(1, s.size()):
		if _is_modifier(str(s[i])) and not (_is_command(str(s[i - 1])) or _is_modifier(str(s[i - 1]))):
			return false
	return true

func add_node(id: String) -> bool:
	if slots.size() >= capacity:
		return false
	slots.append(id)
	if not is_stable():
		slots.pop_back()
		return false
	return true

func assign(slot_index: int, id: String) -> bool:
	if slot_index < 0:
		return false
	while slots.size() <= slot_index:
		slots.append("")
	# Rimuovi stringhe vuote in coda per non contare slot vuoti come pieni.
	# (Gli slot vuoti non sono nodi.)
	var cleaned: Array[String] = []
	for v in slots:
		if str(v) != "":
			cleaned.append(str(v))
	slots = cleaned
	if slot_index >= capacity:
		return false
	# Inserisci nell'ordine desiderato.
	if slot_index >= slots.size():
		slots.append(id)
	else:
		slots.insert(slot_index, id)
		# Se c'erano gia' capacity nodi, overflow.
	if slots.size() > capacity:
		slots.pop_back()
		return false
	if not is_stable():
		# rimuovi l'ultimo inserito
		if slots.size() > 0:
			slots.pop_back()
		return false
	return true

func set_slots(nodes: Array) -> bool:
	var nuovo: Array[String] = []
	for n in nodes:
		nuovo.append(str(n))
	if nuovo.size() > capacity:
		return false
	if not is_stable(nuovo):
		return false
	slots = nuovo
	return true

func clear() -> void:
	slots.clear()
	overflowed = false