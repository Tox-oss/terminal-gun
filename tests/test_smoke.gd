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
class FakeLeaf extends Node:
	var marker: Node3D
	var calls: int = 0

	func nearest_enemy(from: Vector3, radius: float) -> Node3D:
		calls += 1
		return marker

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
	h.near(game.arena_radius, 28.0, 0.0001, "arena_radius di default")
	h.check(game.player == null, "player deve partire da null: nessuna foglia e' ancora registrata")
	h.check(game.horde == null, "horde deve partire da null: nessuna foglia e' ancora registrata")

## 2b. Un metodo non ancora registrato non deve crashare il gioco: dà un valore
## neutro e avvisa una volta sola. Su un'istanza separata, per non sporcare il
## singleton che le altre sezioni di questo test usano.
func _stubs_are_neutral(h) -> void:
	var probe = CONTRACTS.new()
	h.near(probe.arena_radius, 28.0, 0.0001, "arena_radius di default su un'istanza nuova")
	h.check(probe.nearest_enemy(Vector3(5.0, 0.0, 5.0), 10.0) == null,
		"nearest_enemy non registrato deve dare null, non crashare")
	h.check(probe.spawn_projectile(Vector3.ZERO, Vector3.FORWARD, 30.0) == null,
		"spawn_projectile non registrato deve dare null, non crashare")
	h.vec_near(probe.player_position(), Vector3.ZERO, 0.0001,
		"player_position non registrato deve dare ZERO, non crashare")
	# Il punto di spawn neutro è pericoloso: ZERO è anche sotto il giocatore,
	# quindi va segnalato, non restituito di nascosto.
	h.vec_near(probe.random_spawn_point(), Vector3.ZERO, 0.0001,
		"random_spawn_point non registrato non deve inventare un punto")
	# damage_enemy restituisce void: non si può confrontare il valore di ritorno,
	# si verifica che l'istanza sopravviva alla chiamata (e che non sia crashata).
	probe.damage_enemy(0, 10.0, Vector3.FORWARD)
	h.check(is_instance_valid(probe), "damage_enemy non registrato deve essere un no-op, non un crash")
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
	game.register_impl("nearest_enemy", leaf.nearest_enemy)
	game.register_impl("player_position", leaf)  # forma corta: metodo omonimo
	h.check(game.has_impl("nearest_enemy"), "register_impl deve registrare l'API")
	h.check(game.nearest_enemy(Vector3.ZERO, 100.0) == marker,
		"registrazione metodi: Game.nearest_enemy deve chiamare l'impl di -orda")
	h.vec_near(game.player_position(), Vector3(1.0, 2.0, 3.0), 0.0001,
		"registrazione metodi: Game.player_position deve chiamare l'impl di -gameplay")
	h.eq(leaf.calls, 2, "le chiamate devono arrivare all'implementazione registrata")
	h.check(not game.has_impl("damage_enemy"), "le API non registrate restano stub")
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