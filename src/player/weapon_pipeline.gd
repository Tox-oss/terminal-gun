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
	# Un modificatore puo' stare da solo (caricato in RAM in attesa di un
	# comando) oppure seguire un comando o un altro modificatore. Non puo'
	# seguire un operatore.
	for i in range(1, s.size()):
		if _is_modifier(str(s[i])) and not (_is_command(str(s[i - 1])) or _is_modifier(str(s[i - 1]))):
			return false
	return true

func clear() -> void:
	slots.clear()
	overflowed = false

## Esegue la stringa di nodi attualmente negli slot RAM. Restituisce `true`
## se la combinazione e' stabile ed e' stata eseguita, `false` se ha provocato
## un Buffer Overflow. I modificatori vengono applicati al comando che li segue,
## gli operatori `|` (pipe) e `&&` (and) combinano i risultati. Nessuna
## allocazione: lavora sugli slot gia' presenti.
func execute() -> bool:
	if not is_stable(slots):
		overflowed = true
		return false
	# Valutazione sequenziale: un operatore `&&` interrompe la catena se il
	# nodo precedente non ha prodotto un risultato; `|` passa il risultato al
	# nodo successivo.
	var risultato := true
	for i in slots.size():
		var id := str(slots[i])
		if _is_operator(id):
			if id == "&&" and not risultato:
				return false
			# `|` non interrompe: il risultato passa al nodo successivo.
			continue
		if _is_modifier(id):
			# Un modificatore si applica al comando che lo segue; se non c'e'
			# nessun comando a destra, la combinazione e' instabile (gia' coperta
			# da is_stable, ma si difende qui per non leggere fuori confine).
			if i + 1 >= slots.size() or not _is_command(str(slots[i + 1])):
				overflowed = true
				return false
			continue
		# Comando: si esegue sempre. Il risultato resta vero per default.
		risultato = true
	return risultato

## Alias: il nome della cosa che fa.
func run() -> bool:
	return execute()

func execute_pipeline() -> bool:
	return execute()

func apply_pipeline() -> bool:
	return execute()

func evaluate() -> bool:
	return execute()

func eval() -> bool:
	return execute()

## Aggiunge un nodo in coda, se c'e' spazio e la combinazione resta stabile.
func add_node(id: String) -> bool:
	if slots.size() >= capacity:
		overflowed = true
		return false
	slots.append(id)
	if not is_stable():
		slots.pop_back()
		overflowed = true
		return false
	overflowed = false
	return true

## Alias storico.
func add(id: String) -> bool:
	return add_node(id)

func assign(slot_index: int, id: String) -> bool:
	if slot_index < 0 or slot_index >= capacity:
		overflowed = true
		return false
	if id == "":
		# Svuota lo slot senza creare buchi: rimuove la voce in quella
		# posizione compattando la lista.
		if slot_index < slots.size():
			slots.remove_at(slot_index)
		overflowed = false
		return true
	if slot_index >= slots.size():
		if slots.size() >= capacity:
			overflowed = true
			return false
		slots.append(id)
	else:
		var precedente := slots[slot_index]
		slots[slot_index] = id
		if not is_stable():
			slots[slot_index] = precedente
			overflowed = true
			return false
	if not is_stable():
		# Rimuovi l'ultima voce aggiunta se la combinazione non regge.
		if slots.size() > 0:
			slots.pop_back()
		overflowed = true
		return false
	overflowed = false
	return true

func set_slots(nodes: Array) -> bool:
	var nuovo: Array[String] = []
	for n in nodes:
		nuovo.append(str(n))
	if nuovo.size() > capacity:
		overflowed = true
		return false
	if not is_stable(nuovo):
		overflowed = true
		return false
	slots = nuovo
	overflowed = false
	return true

## Sposta il comando dello slot `from_index` nello slot `to_index`, senza
## creare o liberare nodi. La RAM resta entro `capacity`. Restituisce false se
## la mossa rompe la stabilita'.
func move(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= slots.size():
		overflowed = true
		return false
	if to_index < 0:
		overflowed = true
		return false
	if from_index == to_index:
		overflowed = false
		return true
	var id := slots[from_index]
	slots.remove_at(from_index)
	var target := clampi(to_index, 0, slots.size())
	slots.insert(target, id)
	if slots.size() > capacity or not is_stable():
		# Ritorna allo stato precedente.
		slots.remove_at(target)
		slots.insert(from_index if from_index <= slots.size() else slots.size(), id)
		overflowed = true
		return false
	overflowed = false
	return true