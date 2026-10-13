extends SceneTree
## Test di fumo di terminal-gun. È il primo dei quattro, ed è l'unico che non
## verifica il gioco: verifica lo scheletro. Se questo test non passa, gli
## altri tre non hanno nemmeno un posto dove scrivere.
##
## Verifica tre cose:
##   1. il progetto è impostato come deve (scena, renderer, finestra, autoload);
##   2. il contratto dichiara davvero l'API su cui le altre foglie faranno conto,
##      sia come dati sia come metodi registrabili;
##   3. **il gate funziona**: lo rilancia in un processo separato e pretende che
##      lo scopra, lo esegua, ne legga il codice di uscita e stampi GATE: N/M.
##
## (3) è ricorsivo per costruzione ed è la parte che si rompe in silenzio: se
## il gate smette di lanciare i processi figli, tutti gli altri test continuano
## a passare e il gate dichiara 0/0 verde. Per questo il fumo lo verifica.

const H = preload("res://tools/test_harness.gd")
const CONTRACTS := preload("res://src/core/contracts.gd")
## Come stringa: su uno Script precaricato `resource_path` non è visibile al
## compilatore, perché la costante è tipizzata come la classe, non come Resource.
const CONTRACTS_PATH := "res://src/core/contracts.gd"

## Figlio finto: una foglia che registra sul contratto ciò che possiede.
## Serve a provare che il meccanismo di registrazione funziona, non l'orda.
## Le firme sono quelle del contratto vigente (piano §5.2): indice e non nodo
## per i nemici, bool per danno e proiettile.
class FakeLeaf extends Node:
	var marker: Node3D
	var calls: int = 0
	# Valori di risposta e traccia degli argomenti ricevuti.
	var enemy_index: int = 7
	var killed: bool = false
	var slot_taken: bool = true
	var last_index: int = -99
	var last_amount: float = -1.0
	var last_knockback: Vector3 = Vector3.ZERO

	func nearest_enemy(from: Vector3, radius: float) -> int:
		calls += 1
		return enemy_index

	func damage_enemy(index: int, amount: float, knockback: Vector3) -> bool:
		calls += 1
		last_index = index
		last_amount = amount
		last_knockback = knockback
		return killed

	func spawn_projectile(pos: Vector3, dir: Vector3, speed: float) -> bool:
		calls += 1
		return slot_taken

	func player_position() -> Vector3:
		calls += 1
		return Vector3(1.0, 2.0, 3.0)

func _initialize() -> void:
	var h := H.new()
	_project_settings(h)
	_autoload_is_registered(h)
	_stubs_are_neutral(h)
	_leaves_can_register(h)
	_gate_runs_this_test(h)
	quit(h.finish("smoke"))

## 1. Le impostazioni su cui il vertice e le altre foglie contano.
func _project_settings(h) -> void:
	h.eq(ProjectSettings.get_setting("application/run/main_scene", ""),
		"res://scenes/arena_main.tscn",
		"la scena principale va dichiarata anche se il file non esiste ancora (w1)")
	h.eq(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""),
		"gl_compatibility", "renderer")
	h.eq(ProjectSettings.get_setting("display/window/size/viewport_width", 0), 1280, "larghezza finestra")
	h.eq(ProjectSettings.get_setting("display/window/size/viewport_height", 0), 720, "altezza finestra")
	h.check(ProjectSettings.has_setting("autoload/Game"), "l'autoload Game deve esistere")
	if ProjectSettings.has_setting("autoload/Game"):
		h.eq(ProjectSettings.get_setting("autoload/Game"), "*res://src/core/contracts.gd", "autoload Game")

## 2a. L'autoload è vivo e ha i valori iniziali giusti.
func _autoload_is_registered(h) -> void:
	var game := _game()
	if not h.check(game != null, "l'autoload Game non e' stato istanziato: i test delle altre foglie non possono usarlo"):
		return
	h.eq(game.get_script().resource_path, CONTRACTS_PATH, "Game deve essere src/core/contracts.gd")
	## Il 46.0 qui è un PERNO e resta scritto a mano (piano §1.12-bis, m9).
	## Non leggerlo dal contratto ne' da arena.gd: letto dalla fonte non puo'
	## piu' fallire, e un test che non puo' fallire non e' un test (§11.11).
	## Il criterio diverso — "le copie del raggio non divergono" — sta in
	## tests/test_arena.gd, perche' e' di -arena e puo' solo confrontarle fra loro.
	h.near(game.arena_radius, 46.0, 0.0001, "arena_radius di default")
	h.check(game.player == null, "player deve partire da null: nessuna foglia e' ancora registrata")
	h.check(game.horde == null, "horde deve partire da null: nessuna foglia e' ancora registrata")

## 2b. Un metodo non ancora registrato non deve crashare il gioco: dà un valore
## neutro e avvisa una volta sola. Su un'istanza separata, per non sporcare il
## singleton che le altre sezioni di questo test usano.
##
## Il TIPO conta quanto il valore, ed è la metà del motivo di questa sezione:
## uno stub che restituisce `null` dove il contratto dichiara `int` o `bool`
## spazza il chiamante sul `as int`/`as bool` del callee, lontano da qui, e
## nessun confronto di valori se ne accorgerebbe. -1 non è un indice valido e
## false non è un uccisione: sono valori che non possono creare un falso bersaglio.
func _stubs_are_neutral(h) -> void:
	var probe = CONTRACTS.new()
	h.near(probe.arena_radius, 46.0, 0.0001, "arena_radius di default su un'istanza nuova")

	var nearest := probe.nearest_enemy(Vector3(5.0, 0.0, 5.0), 10.0)
	h.eq(nearest, -1, "nearest_enemy non registrato deve dare -1 (nessun nemico), non crashare")
	h.check(typeof(nearest) == TYPE_INT,
		"nearest_enemy deve restituire int, ha restituito " + type_string(typeof(nearest)))

	# I due che non potevano funzionare: `as bool` su un null era un errore a
	# runtime nel callee di ogni chiamante.
	var killed := probe.damage_enemy(0, 10.0, Vector3.FORWARD)
	h.eq(killed, false, "damage_enemy non registrato deve dare false (nessuna uccisione)")
	h.check(typeof(killed) == TYPE_BOOL,
		"damage_enemy deve restituire bool, ha restituito " + type_string(typeof(killed)))

	var slot := probe.spawn_projectile(Vector3.ZERO, Vector3.FORWARD, 30.0)
	h.eq(slot, false, "spawn_projectile non registrato deve dare false (nessuno slot preso)")
	h.check(typeof(slot) == TYPE_BOOL,
		"spawn_projectile deve restituire bool, ha restituito " + type_string(typeof(slot)))

	var pos := probe.player_position()
	h.vec_near(pos, Vector3.ZERO, 0.0001, "player_position non registrato deve dare ZERO, non crashare")
	h.check(typeof(pos) == TYPE_VECTOR3,
		"player_position deve restituire Vector3, ha restituito " + type_string(typeof(pos)))

	# Il punto di spawn neutro è pericoloso: ZERO è anche sotto il giocatore,
	# quindi va segnalato, non restituito di nascosto.
	var spawn := probe.random_spawn_point()
	h.vec_near(spawn, Vector3.ZERO, 0.0001, "random_spawn_point non registrato non deve inventare un punto")
	h.check(typeof(spawn) == TYPE_VECTOR3,
		"random_spawn_point deve restituire Vector3, ha restituito " + type_string(typeof(spawn)))

	# Chiamare uno stub non deve corrompere l'istanza: è la prova che la
	# chiamata è tornata indietro invece di essere esplosa.
	h.check(is_instance_valid(probe), "uno stub non registrato deve essere un no-op, non un crash")
	probe.free()

## 2c. Il meccanismo su cui si regge tutto il piano §5: la foglia registra e il
## contratto smette di essere uno stub. Va provato qui, perché se questo non
## funziona ogni altra foglia si blocca nel suo _ready().
##
## Nota il metodo: NON `Game.nearest_enemy = self._nearest_enemy`. GDScript
## rifiuta l'assegnazione a un nome che è già un func dello script, e il codice
## si ferma lì con un errore: la foglia che lo scrive pensa di aver registrato
## e non ha registrato niente. La forma che funziona è `register_impl`.
func _leaves_can_register(h) -> void:
	var game := _game()
	if game == null:
		h.fail("registrazione: niente singleton su cui provare")
		return
	var marker := Node3D.new()
	root.add_child(marker)
	var leaf := FakeLeaf.new()
	leaf.marker = marker
	root.add_child(leaf)

	# Dati: assegnazione diretta dei campi pubblici.
	game.player = marker
	game.horde = leaf
	game.arena_radius = 12.0
	h.check(game.player == marker, "registrazione dati: Game.player = self")
	h.check(game.horde == leaf, "registrazione dati: Game.horde = self")
	h.near(game.arena_radius, 12.0, 0.0001, "arena_radius e' scrivibile")

	# Metodi: la foglia registra con register_impl, nelle due forme.
	h.check(not game.has_impl("nearest_enemy"), "prima della registrazione l'API deve risultare assente")
	game.register_impl("nearest_enemy", leaf.nearest_enemy)      # forma lunga
	game.register_impl("damage_enemy", leaf.damage_enemy)        # forma lunga
	game.register_impl("spawn_projectile", leaf.spawn_projectile)  # forma lunga
	game.register_impl("player_position", leaf)                  # forma corta: metodo omonimo
	h.check(game.has_impl("nearest_enemy"), "register_impl deve registrare l'API")
	h.check(game.has_impl("damage_enemy"), "register_impl deve registrare l'API")
	h.check(game.has_impl("spawn_projectile"), "register_impl deve registrare l'API")
	h.check(game.has_impl("player_position"), "register_impl deve registrare l'API")

	# Le risposte devono arrivare dall'implementazione, con i tipi del contratto.
	leaf.calls = 0
	h.eq(game.nearest_enemy(Vector3.ZERO, 100.0), leaf.enemy_index,
		"registrazione metodi: Game.nearest_enemy deve restituire l'indice dell'impl di -orda")
	h.eq(game.damage_enemy(2, 12.0, Vector3(0.0, 0.0, 3.5)), leaf.killed,
		"registrazione metodi: Game.damage_enemy deve restituire il bool dell'impl di -orda")
	h.eq(game.spawn_projectile(Vector3.ZERO, Vector3.FORWARD, 30.0), leaf.slot_taken,
		"registrazione metodi: Game.spawn_projectile deve restituire il bool dell'impl di -gameplay")
	h.vec_near(game.player_position(), Vector3(1.0, 2.0, 3.0), 0.0001,
		"registrazione metodi: Game.player_position deve chiamare l'impl di -gameplay")
	h.eq(leaf.calls, 4, "tutte e quattro le chiamate devono arrivare all'implementazione registrata")

	# Gli argomenti passano invariati. `knockback` e' un impulso in m/s gia'
	# scalato dal chiamante: se il contratto lo normalizzasse, un modulo 3.5
	# tornerebbe 1.0 e il knockback di 0.3 unita' del criterio n. 4 vorrebbe
	# dire tre cose diverse a seconda di chi misura.
	h.eq(leaf.last_index, 2, "il contratto deve passare l'indice del nemico invariato")
	h.near(leaf.last_amount, 12.0, 0.0001, "il contratto deve passare il danno invariato")
	h.near(leaf.last_knockback.length(), 3.5, 0.0001,
		"knockback deve restare un impulso col suo modulo, non diventare un vettore unitario")

	# Stato misto, che e' la realta' di w2: quattro API registrate e una no.
	# Lo stub deve continuare a dare il suo valore neutro, senza warning di
	# nuovo e senza rompere il conteggio delle chiamate.
	h.check(not game.has_impl("random_spawn_point"), "random_spawn_point resta non registrata: e' lo stub")
	h.vec_near(game.random_spawn_point(), Vector3.ZERO, 0.0001,
		"uno stub deve dare ZERO anche quando le altre API sono registrate")
	h.eq(leaf.calls, 4, "chiamare uno stub non deve arrivare a nessuna implementazione")
	# Il rifiuto di un'API fuori contratto (contracts.gd stampa un push_error)
	# non viene provato qui di proposito: farebbe rumore in stderr, e il gate
	# tratta un ERROR come un FAIL.

## 3. Il gate. Rilanciato in un processo separato, come fa il vertice: deve
## uscire 0, scoprire questo test, echi la sua riga di verdetto e chiudere
## con `GATE: N/M` tutto intero.
func _gate_runs_this_test(h) -> void:
	if _is_gate_child():
		print("smoke: sono il figlio del gate, la prova del gate non gira qui")
		return

	OS.set_environment("GATE_CHILD", "1")
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tools/gate.gd",
		"--", "--only", "test_smoke", "--gate-child",
	]), output, true, false)
	OS.unset_environment("GATE_CHILD")

	var text := "\n".join(output.map(func(line: Variant) -> String: return str(line).strip_edges()))
	if not h.check(code == 0, "il gate deve uscire 0; e' uscito %d. Output:\n%s" % [code, text]):
		return
	h.check(text.contains("PASS test_smoke"), "il gate deve eseguire questo test e riportarne il PASS:\n%s" % text)

	var ratio := ""
	for line in text.split("\n", false):
		var row := str(line).strip_edges()
		if row.begins_with("GATE: ") and row.contains("/"):
			ratio = row
	h.check(ratio != "", "il gate deve chiudere con una riga GATE: N/M:\n%s" % text)
	var parts := ratio.trim_prefix("GATE: ").split("/")
	if parts.size() != 2:
		h.fail("riga GATE: malformata: \"%s\"" % ratio)
		return
	h.check(parts[0].strip_edges() == parts[1].strip_edges(),
		"tutti i test eseguiti devono passare, altrimenti il gate doveva uscire 1: \"%s\"" % ratio)

# --- Interno -------------------------------------------------------------------

func _game() -> Node:
	return root.get_node_or_null("Game")

## Due guardie indipendenti contro la ricorsione, perché i test di fumo lanciano
## il gate che li rilancia: variabile d'ambiente (ereditata dai processi figli)
## e argomento utente (inoltrato dal gate). Se ne cadesse una sola, il test
## continuerebbe a lanciarsi all'infinito.
func _is_gate_child() -> bool:
	return OS.get_environment("GATE_CHILD") == "1" or "--gate-child" in OS.get_cmdline_user_args()