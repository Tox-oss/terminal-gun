extends SceneTree
## Test di arena di terminal-gun. E' il test del **criterio n. 3** della milestone:
##
##     il motore regge 200 nemici vivi, SENZA un nodo per nemico:
##     node_count < 120  con  horde.count == 200  **RAGGIUNTO DURANTE LA PARTITA**
##
## ## Perche' `== 200` non e' piu' una condizione del primo frame
##
## Il criterio diceva `horde.count == 200` **al primo frame**, e li' stava dentro
## una riga sola mescolando due cose diverse: che il motore regga 200 nemici
## senza un nodo per nemico (una **capacita'**, ed e' la cosa che questo test
## sa misurare) e che la partita **parta** con 200 nemici (una **scelta di
## design**, che nessuno aveva mai visto applicata finche' qualcuno non ha
## giocato e ha scritto che cosi' non riesce a muoversi). Il tetto di 120 e il
## numero 200 **non cambiano**: cambia **quando** si misurano.
##
## Quindi i 200 qui non sono un'attesa ma una **meta**: la sezione porta avanti la
## partita con l'API vera di -orda (`damage_enemy` per chiudere un'onda, `step`
## per far correre il tempo, `run` per la barra) e misura i nodi nell'istante in
## cui l'orda arriva a 200 vivi. Nessun record scritto a mano: se l'orda non ci
## arriva, il test lo dice e fallisce, invece di riempire l'array da solo e
## dichiarare misurato un numero che ha deciso lui.
##
## ## Perche' questo test carica `scenes/arena_main.tscn` per intero
##
## Nella prima stesura non poteva: `src/sim/horde.gd` (-orda) e
## `scenes/player.tscn` (-gameplay) si scrivevano in parallelo a questo file, e
## un test che li carica sarebbe fallito per un file non ancora finito. Il modo
## piu' veloce di farlo passare sarebbe stato sostituirli con un placeholder: la
## maniera piu' veloce di mentire alla porta. I due sono adesso finiti e verdi,
## quindi qui si carica la scena **vera**, con l'orda **vera**: nessun finto, e
## si controlla anche che le tre foglie si agganciano davvero.
##
## ## La trappola del `const preload` (piano 5.3)
##
## `scenes/arena_main.tscn` si carica con `load()` **dentro `_process()`**, mai
## con un `const`. Un `const preload` risolve i suoi script a tempo di
## compilazione, PRIMA che `Main` aggiunga gli autoload al nome globale, e a quel
## punto `Game` non e' ancora registrato: `player.gd` e `weapon_base.gd` usano
## l'identificatore nudo `Game` e non compilerebbero. Caricandoli a runtime
## l'identificatore c'e'. Solo `tools/test_harness.gd` e' in `const`, e non
## tocca il contratto.
##
## Stringhe a schermo solo ASCII: la console di Windows e il pipe di
## `OS.execute` sono in codepage e un accento diventa spazzatura proprio nel
## messaggio che serve a capire un fallimento.

const H = preload("res://tools/test_harness.gd")

const ARENA_SCENE := "res://scenes/arena_main.tscn"
const ARENA_SCRIPT := "res://src/render/arena.gd"
## Gli altri tre file che contengono una copia del raggio (piano 1.12-bis). Sono
## stringhe di percorso: il test le **legge**, non le scrive, e il fatto che la
## copia di `src/sim/horde.gd` non ci sia e' dichiarato dove serve.
const CAMERA_SCRIPT := "res://src/render/arena_camera.gd"
const GROUND_SCRIPT := "res://src/render/arena_ground.gd"
const CONTRACT_SCRIPT := "res://src/core/contracts.gd"
## -arena, m10: costruisce i dischi che `Game.obstacles` dichiara e li registra.
const OBSTACLES_SCRIPT := "res://src/render/arena_obstacles.gd"
## Il **produttore unico** dei numeri della mappa: di -orda, non di questo file.
## Il test lo preloada per una ragione sola, e la ragione e' scritta accanto a
## `_numeri_di_orda`: per rilegge i numeri dal produttore e verificare che
## `src/render/arena.gd` non ne abbia scritto una copia. Non e' una copia: e' una
## lettura, e il file di -orda non viene toccato.
const OBST := preload("res://src/sim/obstacles.gd")
## Tolleranza dei confronti fra il disco che **blocca** (`Game.obstacles[i].y`) e
## quello che e' **disegnato**: il centro passa per una `Basis` scalata e il
## raggio per una `float` a 32 bit, quindi il confronto non e' mai esatto. 1e-4 m
## e' un centesimo di millimetro, quattro ordini di grandezza sopra quel rumore e
## quattro ordini sotto il difetto che il criterio cerca (un disco disegnato
## diverso da quello che blocca).
const OBSTACLE_TOLERANCE := 0.0001
## Quanto puo' valere `directional_shadow_max_distance` **oltre** il minimo che la
## camera vera richiede. Il minimo e' derivato (vedi `_ombre`), non scritto qui;
## questo e' il margine dichiarato che lo distingue da una scelta e da un
## ometto: 1,25 vuol dire «il peggiore caso piu' un quarto», non «quanto basta».
const SHADOW_MARGIN := 1.25

## Il numero del criterio n. 3. Non e' il numero di nemici con cui la partita
## parte: e' il numero di nemici **vivi contemporaneamente** di cui si vuole
## provata la capacita' del motore, e il test lo **raggiunge** guidando la
## partita (vedi `_drive_to_full_arena`).
const ENEMY_TARGET := 200
const NODE_BUDGET := 120
## Lavoro che il test accetta di fare portando avanti la partita: passi di
## `horde.step()` piu' uccisioni, in un unico conteggio. Non e' un numero della
## curva delle onde -- quella e' di -orda e non la conosco -- e' il tetto oltre
## il quale il test smette di guidare e **riporta un ritorno** invece di girare.
const DRIVE_MAX_WORK := 400000
## Passi consecutivi senza che i nemici vivi crescano, quando l'orda e' gia' alla
## quota del criterio: e' il modo di accorgersi che il riempimento e' fermo e
## che la misura non arrivera' mai.
const DRIVE_STALL_STEPS := 30
## Quanta capienza fissa ha la MultiMesh dei nemici: se l'orda ne chiede di
## piu', il renderer deve fermarsi qui e non crescere.
const ENEMY_CAPACITY := 256
## Il raggio che m9 decise e che m11 ha cambiato. Il vertice ha misurato **prima**
## di sceglierlo, e due volte con due sonde diverse (piano 1.12,
## `docs/piramide/probe_arena_density.gd`, e piano 1.14-quinque,
## `docs/piramide/probe_survive.gd`).
##
## **Questa riga non e' una copia del raggio.** Le copie del numero sono le sei
## di 1.12-bis, e la sesta era proprio questa: un valore scritto qui che il
## terreno, il muro e la camera confrontavano con la fonte. Da m9 il test
## **legge la fonte** (`_source_radius()`) e non porta il numero con se', e le
## righe che restano qui sono due compiti diversi:
##   - `DECIDED_RADIUS` e' il **criterio n. 1**: il raggio e' quello deciso, e il
##     numero che l'ha prodotto (la tabella e il motivo) e' scritto accanto alla
##     fonte, in `src/render/arena.gd`. Se qualcuno cambiasse la fonte e non qui, la
##     porta va rossa: il raggio e' una scelta dichiarata, non un dettaglio.
##   - `RADIUS_TOLERANCE` e' la tolleranza dei confronti numerici sotto, e non un
##     raggio.
##
## Le copie **dichiarate** che il test confronta con la fonte sono nella sezione
## `_copie_del_raggio`: `arena_camera.gd`, `arena_ground.gd` e il default del
## contratto. La copia di `src/sim/horde.gd` non e' di questo test (la confronta
## `tests/test_orda.gd` col default del contratto, che qui a sua volta e'
## confrontato con la fonte: la catena e' chiusa e la copia e' guardata una volta
## sola, dalla foglia che ne e' proprietaria).
const DECIDED_RADIUS := 60.0
## Il raggio **sostituito** da m11: 46,0 m. Non e' una copia viva e non viene
## confrontato con nessuno — e' il numero che `_m11_raggio` mette **accanto** al
## nuovo nelle stampe, perche' un cambio di raggio che si vede solo nel numero di
## dopo non e' una misura: e' un annuncio.
##
## Le due sonde che lo hanno prodotto, i loro tre semi per raggio e i due casi a
## risposta nota sono scritti accanto alla fonte, in `src/render/arena.gd`
## (`ARENA_RADIUS`). In una riga: 46 m -> 55,33 s di sopravvivenza nel caso
## peggiore, 60 m -> **146,72 s** (fattore **2,65**), 75 m -> 156,33 s (fattore
## 1,07): il ginocchio e' a 60 m e il numero e' quello.
const PREVIOUS_RADIUS := 46.0
## Tolleranza dei confronti fra copie del raggio. `float` a 32 bit passato per
## una `Basis`: l'errore relativo e' dell'ordine di 1e-7, quindi 1e-4 e' tre
## ordini di grandezza sopra quel rumore e **ben** sotto la divergenza che
## questo criterio cerca (un numero cambiato di un metro).
const RADIUS_TOLERANCE := 0.0001
## Ampiezza dell'oscillazione verticale: sotto questa soglia il test non
## distingue il bob dal pavimento.
const BOB_TOLERANCE := 0.1
## Le API del contratto, e di chi sono.
const ORDA_APIS := ["nearest_enemy", "damage_enemy", "random_spawn_point"]
const GAMEPLAY_APIS := ["spawn_projectile", "player_position"]

var _h: H = null
var _ran: bool = false
## Quando il test e' partito. Serve solo al numero di costo stampato in fondo: il
## gate da 120 s a tutto il file, e un file che non dice quanto costa non permette
## a nessuno di sapere se il prossimo criterio entra nel margine.
var _t0: int = 0
## I due numeri della sezione m11-bis sulle casse: quante ne sono state confrontate
## e quante sono **diverse** fra la scena e un secondo terreno costruito li'
## accanto. `-1` quando il confronto non e' stato fatto, cosi' la stampa non
## racconta un numero che nessuno ha misurato.
var _crate_count: int = 0
var _crate_diff: int = -1
## I tre numeri che `_camera_al_bordo` ha **misurato** sulla scena vera, non
## calcolati: rapporto nel quadro, direzione peggiore e distanza di vista. Li
## tiene perche' la sezione di m11 deve poter confrontare la **misura** con la
## formula che usa per il raggio di prima: e' quello confronto che autorizza a
## stampare un numero che non e' piu' misurabile (a 46 m non c'e' piu' una scena).
## `-1.0` quando la sezione non e' girata, cosi' la stampa non racconta un numero
## che nessuno ha misurato.
var _frame_worst: float = -1.0
var _frame_deg: float = -1.0
var _frame_view: float = -1.0


## Niente qui dentro. Il corpo del test gira al **primo frame**, non in
## `_initialize()`: un nodo aggiunto a `root` durante `_initialize()` non ha
## ancora il `_ready` (la radice non e' ancora dentro la scena), e tutto quello
## che questo test verifica sta nel `_ready`: la registrazione di
## `Game.arena_radius`, la costruzione della MultiMesh, il terreno.
func _initialize() -> void:
	_h = H.new()
	_t0 = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true


func _run() -> void:
	var h := _h

	var game := root.get_node_or_null("Game")
	if not h.check(game != null, "l'autoload Game non e' stato istanziato: questo test non puo' girare"):
		quit(h.finish("test_arena"))
		return

	# Prima, da solo: che cosa registra arena quando gli altri nodi non ci sono.
	_arena_alone(h, game)

	# m9, criteri n. 1 e n. 2: il raggio e' quello deciso, e tutte le copie che
	# esistono dicono quello. Gira **prima** della scena vera perche' il confronto
	# fra copie e' fra file e non ha bisogno dell'albero, e cosi' una divergenza si
	# vede anche se la scena non si carica.
	_copie_del_raggio(h)

	var arena = _load_arena(h, game)
	if arena == null:
		quit(h.finish("test_arena"))
		return

	_wiring(h, arena, game)
	# m11-bis: **prima** di `_criterion_3`, che svuota l'orda. Qui la disposizione
	# e' ancora quella del primo frame, cioe' quella che `arena_main.tscn` consegna:
	# dopo, e' gia' stata riscritta piu' volte e il confronto non guarderebbe niente.
	_m11bis(h, arena)
	_criterion_3(h, arena, game)
	_terrain(h, arena)
	_milestone_10(h, arena, game)
	_camera(h, arena)
	# m11: il raggio e' passato da 46,0 m a 60,0 m. Sta **dopo** `_camera` perche'
	# confronta la formula dell'inquadratura con la misura fatta li' dentro: senza
	# la misura, il numero di 46 m sarebbe una ricorrenza e non una verifica.
	_m11_raggio(h, arena)
	_hud(h, arena, game)
	# Per ultima: e' l'unica sezione che cambia lo stato dell'orda e della
	# regolazione dell'arma, e non deve trovarsi in mezzo a quelle che contano i
	# nodi e le piastrelle.
	_criterion_4(h, arena, game)
	# m3: per ultima anche rispetto a `_criterion_4`, perche' riscrive la
	# disposizione dell'orda della scena vera e crea e libera piu' copie della
	# scena, quindi sposta `Game.horde` e `Game.player` su nodi diversi.
	_milestone_3(h, arena)
	# m8: per ultima. Riscrive l'orda (ripopola a `population`) e rimette a posto
	# quello che ha toccato, quindi puo' stare dopo tutto quello che conta i
	# nemici vivi.
	_milestone_8(h, arena)

	_cleanup(arena)
	print("test_arena: tutto il file in %d ms; la porta dà 120 s a questo test e ne resta %d, e m11-bis e m11 hanno costato le cifre stampate nelle loro righe" % [Time.get_ticks_msec() - _t0, 120000 - (Time.get_ticks_msec() - _t0)])
	quit(h.finish("test_arena"))

# --- 1. Che cosa registra arena, da solo ---------------------------------------

## Arena registra **un solo dato** e nessun metodo. Registrarne per procura le
## API delle altre foglie produrrebbe una doppia registrazione, e nel piano 5.1
## l'ultima che registra vince in silenzio: il difetto che nessun test vede.
##
## Il contratto e' pulito in questo momento (nessun altro nodo e' ancora dentro
## la scena), quindi "nessuna API registrata" qui vuol dire "arena non l'ha
## registrata" e non "qualcun altro l'ha registrata prima".
func _arena_alone(h, game: Node) -> void:
	game.arena_radius = 12.0
	var bare := Node3D.new()
	bare.name = "ArenaAlone"
	bare.set_script(load(ARENA_SCRIPT))
	root.add_child(bare)

	h.near(_contract_float(game, "arena_radius"), _source_radius(), RADIUS_TOLERANCE,
		"arena deve registrare Game.arena_radius = %.1f all'avvio, prima che i figli costruiscano"
			% _source_radius())
	h.check(game.get("player") == null, "arena non deve registrare Game.player: e' di -gameplay")
	h.check(game.get("horde") == null, "arena non deve registrare Game.horde: e' di -orda")
	for api in ORDA_APIS + GAMEPLAY_APIS:
		h.check(not game.has_impl(api),
			"arena non deve registrare l'API \"%s\": non e' sua" % api)

	root.remove_child(bare)
	bare.free()

# --- 1b. Le copie del raggio: nessuna puo' divergere dalla fonte (m9) -----------
#
# ## Il difetto che questa sezione chiude
#
# Il raggio era scritto **sei volte** in sei file (piano 1.12-bis) e tutte e sei
# volevano dire "il raggio dell'arena": la fonte in `src/render/arena.gd`, il
# default del contratto, il fallback dell'orda, i due fallback di -arena e la
# copia dentro questo test. Cinque potevano divergere dalla sesta **senza che
# nessuna porta lo vedesse**: il terreno si costruiva con 28 m e l'orda con 46,
# e la partita girava senza che nessuno sapesse dire quale dei due fosse vero.
#
# ## Perche' il criterio e' sulla DERIVA e non sull'assenza
#
# Un numero che sparisce non lascia traccia: fra due mesi qualcuno puo' rimettere
# `FALLBACK_RADIUS := 28.0` in un file e la porta resta verde perche' non cerca
# la stringa. Un numero che **diverge** lascia una porta rossa con i due valori
# nel messaggio. Quindi qui non si cerca `28.0` (e non si puo': il `28.0` della
# tabella storica dentro i commenti e' lecito, e un `grep` di stringhe sarebbe
# un test sul testo e non sul codice): si **leggono le copie** e si confrontano
# con la fonte.
#
# ## Perche' dal sorgente e non da un campo a runtime
#
# Un fallback, a runtime, non lo si vede: `arena_radius()` lo restituisce solo
# quando il contratto non c'e', quindi in partita il confronto leggerebbe sempre
# il contratto e passerebbe sempre, comunque il fallback dicesse. Le copie si
# leggono quindi **dal sorgente**, con la stessa forma usata da
# `tests/test_orda.gd` per la copia di -orda.

## Il raggio dichiarato nella fonte, letto dalla **costante** del suo script.
## `-1.0` se la costante non c'e' piu': una fonte che sparisce non e' una fonte
## silenziosamente uguale a qualcosa, e va detto.
func _source_radius() -> float:
	return _const_of(ARENA_SCRIPT, "ARENA_RADIUS")

## Una costante di uno script, letta dalla sua mappa delle costanti. `-1.0` se lo
## script non c'e', non e' uno `Script`, o non dichiara quel nome.
func _const_of(path: String, const_name: String) -> float:
	var scr = load(path)
	if scr == null or not (scr is Script):
		return -1.0
	if not scr.has_method("get_script_constant_map"):
		return -1.0
	var map: Dictionary = scr.get_script_constant_map()
	if not map.has(const_name):
		return -1.0
	var v = map[const_name]
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return -1.0

## Il valore di un **campo con default** in un file di sorgente. Serve per le due
## copie che non sono costanti ma variabili con valore iniziale
## (`var arena_radius: float = ...`): la mappa delle costanti non le contiene, e
## sono le stesse che `tests/test_orda.gd` legge allo stesso modo. `-1.0` se la
## riga non c'e' piu'.
func _field_default_of(path: String, field_prefix: String) -> float:
	if not FileAccess.file_exists(path):
		return -1.0
	var testo := FileAccess.get_file_as_string(path)
	for riga in testo.split("\n"):
		var t := str(riga).strip_edges()
		if t.begins_with(field_prefix) and t.contains("="):
			return float(t.split("=")[1].strip_edges())
	return -1.0

func _copie_del_raggio(h) -> void:
	var fonte := _source_radius()

	# Criterio n. 1: il raggio e' quello deciso dal vertice, e il numero che l'ha
	# prodotto e' scritto accanto alla fonte. Qui il confronto e' con un numero
	# **scritto**, non letto: e' l'unica riga del file che tiene memoria del
	# numero scelto, ed e' quello che distingue il raggio deciso da quello che c'era scritto.
	h.near(fonte, DECIDED_RADIUS, RADIUS_TOLERANCE,
		"criterio n. 1 di m9: il raggio nella fonte deve essere quello deciso (%.1f m), non quello sostituito da m11 (%.1f m); "
		% [DECIDED_RADIUS, PREVIOUS_RADIUS])
		

	# Le copie, una per una, con il numero accanto al nome: un FAIL deve dire
	# *quale* copia mente e *di quanto*.
	var copie := {
		"src/render/arena_camera.gd FALLBACK_RADIUS": _const_of(CAMERA_SCRIPT, "FALLBACK_RADIUS"),
		"src/render/arena_ground.gd FALLBACK_RADIUS": _const_of(GROUND_SCRIPT, "FALLBACK_RADIUS"),
		"src/core/contracts.gd arena_radius": _field_default_of(CONTRACT_SCRIPT, "var arena_radius"),
	}
	var lette: Array[String] = []
	for nome in copie.keys():
		var valore: float = copie[nome]
		lette.append("%s = %.3f" % [nome, valore])
		h.check(valore > 0.0,
			"la copia del raggio in %s non c'e' piu': una copia che non dice niente non puo' essere confrontata con la fonte (letto %.3f)"
				% [nome, valore])
		h.near(valore, fonte, RADIUS_TOLERANCE,
			"criterio n. 2 di m9: %s deve dire lo stesso numero della fonte src/render/arena.gd, non %.3f"
				% [nome, valore])

	print("test_arena: m11 raggio: %.1f m (fonte di m9, deciso allora, 55.33 s nel caso peggiore) -> %.1f m (fonte e deciso oggi, 146.72 s, fattore 2.65; a 75 m si avrebbe 156.33 s, fattore 1.07: il ginocchio e' a 60 m)"
		% [PREVIOUS_RADIUS, DECIDED_RADIUS])
	print("test_arena: m9 raggio: fonte %.3f m, deciso %.3f m; copie allineate: %s"
		% [fonte, DECIDED_RADIUS, ", ".join(lette)])

	# E il contratto, **prima** che l'arena si registri: il default del contratto
	# e' la copia che vive piu' a lungo di tutte le altre, perche' e' l'unica che
	# esiste prima che qualcuno abbia scritto qualcosa.
	var game := root.get_node_or_null("Game")
	if game != null:
		h.near(_contract_float(game, "arena_radius"), fonte, RADIUS_TOLERANCE,
			"il default del contratto deve essere quello della fonte prima che l'arena si registri: %.3f"
				% _contract_float(game, "arena_radius"))

# --- 2. La scena vera ----------------------------------------------------------

## `scenes/arena_main.tscn` caricata a runtime, non in `const` (vedi la trappola
## in testa al file). Il raggio parte da un valore che **non** e' quello deciso,
## cosi' l'asserzione dimostra che arena ha registrato e non che il contratto
## partiva gia' cosi'.
func _load_arena(h, game: Node):
	game.arena_radius = 12.0
	if not ResourceLoader.exists(ARENA_SCENE):
		h.fail("manca %s: senza la scena non c'e' niente da contare" % ARENA_SCENE)
		return null
	var res = load(ARENA_SCENE)
	if not (res is PackedScene):
		h.fail("%s non e' una PackedScene" % ARENA_SCENE)
		return null
	var arena = (res as PackedScene).instantiate()
	if not (arena is Node3D):
		h.fail("%s non istanzia un Node3D" % ARENA_SCENE)
		return null
	root.add_child(arena)
	return arena as Node3D

## I nodi che la scena deve avere, i file di -orda e -gameplay **incollati** (non
## dei finti) e il contratto popolato da tutte e tre le foglie. E' la verifica che
## nella prima stesura non si poteva fare: fino a ieri la scena non esisteva.
func _wiring(h, arena: Node3D, game: Node) -> void:
	for node_name in ["WorldEnvironment", "Sun", "Ground", "Horde", "Enemies",
			"Obstacles", "Player", "Camera", "Hud"]:
		h.check(arena.get_node_or_null(node_name) != null,
			"arena_main.tscn deve avere il nodo \"%s\"" % node_name)

	var obstacles = arena.get_node_or_null("Obstacles")
	if obstacles != null:
		h.eq(_script_path(obstacles), "res://src/render/arena_obstacles.gd",
			"il nodo Obstacles deve avere incollato src/render/arena_obstacles.gd: e' il file che costruisce i dischi registrati in Game.obstacles")

	var horde = arena.get_node_or_null("Horde")
	var player = arena.get_node_or_null("Player")
	if h.check(horde != null, "manca il nodo Horde") and h.check(player != null, "manca il nodo Player"):
		h.eq(_script_path(horde), "res://src/sim/horde.gd",
			"il nodo Horde deve avere incollato src/sim/horde.gd: un finto passerebbe lo stesso test e non giocherebbe")
		h.eq(_script_path(player), "res://src/player/player.gd",
			"il nodo Player deve venire da scenes/player.tscn")
		h.check(game.get("horde") == horde,
			"Game.horde deve essere il nodo Horde della scena: e' cosi' che il renderer trovi l'orda")
		h.check(game.get("player") == player,
			"Game.player deve essere il nodo Player della scena")

	for api in ORDA_APIS:
		h.check(game.has_impl(api),
			"caricando la scena, l'API \"%s\" di -orda deve risultare registrata" % api)
	for api in GAMEPLAY_APIS:
		h.check(game.has_impl(api),
			"caricando la scena, l'API \"%s\" di -gameplay deve risultare registrata" % api)

# --- 2b. m11-bis: la scena consegnata porta il seme, e lo porta davvero -------
#
# ## Il difetto, e chi lo possiede
#
# `src/sim/horde.gd:372-375` fa `_rng.randomize()` quando `seed == 0`, e
# `scenes/arena_main.tscn` montava il nodo `Horde` **senza la proprieta' `seed`**:
# ogni montaggio della scena vera era quindi una partita diversa. Il fatto era
# gia' in questo piano fin da m3 (riga 65); mancava la conseguenza, cioe' che
# ogni numero di durata misurato sulla scena vera e' un campione.
#
# ## Perche' qui NON si montano tre scene, che e' quello che fa -gameplay
#
# `tests/test_gameplay.gd`, sezione m11-bis, confronta tre **montaggi** della scena
# e costa ~1 s (misurato li': 745 ms senza, 1754-1762 ms con). Qui si confronta
# **la scena consegnata con il seme dichiarato**: una domanda diversa, che e' la
# domanda di -arena, e che costa una sola `_populate()` da 25 nemici. Se le due
# sezioni dicessero la stessa cosa, una delle due sarebbe un criterio che paga
# per vedere la stessa cosa.
#
# Tolleranza **zero** come in 8.1: due disposizioni sono uguali o non lo sono, e
# una banda qui coprirebbe esattamente il difetto che il criterio cerca.

## Il seme che la scena deve consegnare: `SEED_A`, il numero che questo file
## dichiara gia' dal m3 e che e' anche il seme della sonda di densita' di m9
## (riportato in `src/render/arena.gd`) e quello della riga `morso seme 4242` di
## `tests/test_orda.gd`. Non e' una copia di un raggio: e' lo **stesso fatto
## dichiarato** che il resto del progetto usa, e il criterio dice che la scena
## consegnata deve partire da li'. Nessun numero nuovo in questo file.
func _m11bis(h, arena: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var horde = arena.get_node_or_null("Horde")
	if not h.check(horde != null, "m11-bis: la scena vera non ha il nodo Horde"):
		return
	var ground = arena.get_node_or_null("Ground")
	if not h.check(ground != null, "m11-bis: la scena vera non ha il nodo Ground"):
		return

	# ## 2b.1 IL SEME DICHIARATO: la scena deve portarlo, e `0` e' il difetto
	#
	# `0` non e' "il seme zero": e' il valore che quell'API riserva a «randomizza»
	# (punto 2 del contratto di m3). Quindi `seed == 0` non e' un caso particolare
	# da tollerare: e' **esattamente** la riga mancante che questo criterio chiude,
	# e il messaggio lo dice perche' il FAIL deve dire il rimedio.
	var dichiarato: int = horde.seed
	h.check(dichiarato != 0,
		"m11-bis: scenes/arena_main.tscn monta il nodo Horde con seed = 0, e src/sim/horde.gd:372-375 fa _rng.randomize() quando seed == 0: ogni montaggio della scena e' una partita diversa. La riga da rimettere e' `seed = %d` accanto a `script = ExtResource(\"5_horde\")`, con la dichiarazione che c'e' gia' li'" % SEED_A)
	h.eq(dichiarato, SEED_A,
		"m11-bis: il seme che la scena consegna deve essere quello dichiarato dal progetto (%d, SEED_A qui sopra): e' %d" % [SEED_A, dichiarato])

	# ## 2b.2 IL SEME È ARRIVATO DAVVERO AL GENERATORE
	#
	# Il numero sulla scena e' una dichiarazione: qui si prova che l'orda **partita
	# da quel numero** e' identica, posizione per posizione, all'orda che nasce da
	# `reseed(SEED_A)`. Il confronto e' sul primo frame, quando la disposizione e'
	# ancora quella consegnata: se la riga mancasse, `reseed(SEED_A)` riscriverebbe
	# tutto e il confronto lo direbbe con i due numeri accanto.
	#
	# Effetto collaterale utile: dopo questa riga l'orda e' determinista **anche se
	# la scena non lo fosse**, quindi le sezioni che vengono dopo misurano un mondo
	# solo. Non e' un criterio (non lo asserisco) e non e' una riparazione: il
	# rimedio e' nella scena.
	var primitivo: PackedVector3Array = horde.transforms.duplicate()
	var colori_primitivo: PackedColorArray = horde.colors.duplicate()
	horde.reseed(SEED_A)
	var atteso: PackedVector3Array = horde.transforms.duplicate()
	h.eq(atteso.size(), primitivo.size(),
		"m11-bis: l'orda consegnata dalla scena e quella di reseed(%d) devono avere lo stesso numero di nemici: %d e %d"
			% [SEED_A, primitivo.size(), atteso.size()])
	h.check(atteso == primitivo,
		"m11-bis: la disposizione che la scena consegna NON e' quella del seme dichiarato %d: %d posizioni diverse su %d al primo frame, e la somma delle coordinate e' %.6f contro %.6f. Il difetto e' che seed = 0 sulla scena fa randomize()"
			% [SEED_A, _differing(primitivo, atteso), mini(primitivo.size(), atteso.size()),
				_checksum(primitivo), _checksum(atteso)])
	h.check(horde.colors == colori_primitivo,
		"m11-bis: anche i colori per specie devono essere quelli del seme %d: la scena consegna una disposizione diversa" % SEED_A)

	_casse_da_un_numero(h, ground)
	print("test_arena: m11-bis: seme consegnato %d (0 = randomizza, ed e' il difetto), disposizione al primo frame %d/%d diverse da reseed(%d); casse %d di %d diverse fra due costruzioni; la sezione ha costato %d ms"
		% [dichiarato, _differing(primitivo, atteso), primitivo.size(), SEED_A,
			_crate_diff, _crate_count, Time.get_ticks_msec() - t0])

## Le casse: la scena non deve essere casuale **a occhio**.
##
## Finora nessuna asserzione del progetto guardava la posizione delle 28 casse,
## quindi la casualita' scenografica stava **fuori da ogni porta**: si vedeva solo
## lanciando il gioco due volte. Il confronto e' fra la scena vera e un **secondo
## `Ground` costruito adesso**, dopo che tutta la simulazione di questo test ha
## gia' girato: se `rng.seed = CRATE_SEED` sparisce, il generatore nasce casuale
## (misurato in Godot 4.7: due `RandomNumberGenerator.new()` di fila danno semi
## diversi) e le due costruzioni divergono.
##
## Costo: una costruzione di terreno, cioe' 2500 + 290 + 28 scritture e tre mesh
## gia' in cache. Il numero misurato e' stampato sotto e dichiarato accanto al
## chiamante.
func _casse_da_un_numero(h, ground) -> void:
	var seme = _const_of(GROUND_SCRIPT, "CRATE_SEED")
	h.check(seme > 0.0,
		"m11-bis: src/render/arena_ground.gd deve dichiarare CRATE_SEED maggiore di zero: e' il numero da cui dipendono le 28 casse, e 0 e' il valore che in Godot significa 'non seminato'. Letto %.0f" % seme)
	_crate_count = int(ground.crate_instances())

	var secondo := Node3D.new()
	secondo.name = "GroundAlone"
	secondo.set_script(load(GROUND_SCRIPT))
	root.add_child(secondo)

	var stesse: int = _crate_count
	for i in mini(_crate_count, secondo.crate_instances()):
		if secondo.crate_transform(i) != ground.crate_transform(i):
			stesse -= 1
	_crate_diff = _crate_count - stesse

	h.eq(secondo.crate_instances(), _crate_count,
		"m11-bis: un secondo Ground costruito nella stessa scena deve mettere lo stesso numero di casse: %d contro %d" % [_crate_count, secondo.crate_instances()])
	h.near(secondo.arena_radius(), ground.arena_radius(), RADIUS_TOLERANCE,
		"m11-bis: i due terreni devono essere costruiti con lo stesso raggio, altrimenti le casse non si confrontano: %.3f e %.3f m"
			% [secondo.arena_radius(), ground.arena_radius()])
	h.eq(stesse, _crate_count,
		"m11-bis: le casse devono essere una funzione di CRATE_SEED anche a occhio: %d di %d sono in un punto diverso da quelle della scena, quindi la disposizione cambia a ogni montaggio (rng.seed = CRATE_SEED manca in src/render/arena_ground.gd)"
			% [_crate_diff, _crate_count])

	root.remove_child(secondo)
	secondo.free()

# --- 3. Il criterio n. 3 -------------------------------------------------------

## Il cuore del test: `node_count < 120` **con** `horde.count == 200`, e i nodi
## non crescono quando i nemici crescono. E' la differenza fra "disegnare 200
## nemici" e "avere 200 nemici".
##
## Il 200 **non** e' una condizione del primo frame: e' una condizione **da
## raggiungere**. Quindi qui l'ordine e' misurare il vuoto, poi guidare la
## partita fino al pieno, e contare i nodi **in quel momento**. Nessuna delle
## due misure e' inventata: il vuoto si fa svuotando l'orda con l'API di -orda,
## il pieno si fa giocando la partita con l'API di -orda.
func _criterion_3(h, arena: Node3D, game: Node) -> void:
	# Variabili senza tipo: `horde` e' un `Node` e i suoi tre campi non sono
	# campi di `Node`, quindi l'accesso deve restare dinamico.
	var horde = arena.get_node("Horde")
	var enemies = arena.get_node("Enemies")

	# Orologio congelato: con il tempo che scorre il renderer aggiunge il bob e
	# la rotazione, e la geometria scritta nel buffer smette di essere prevedibile.
	enemies.set_time(0.0)
	enemies.set_horde(horde)

	# ## Il PRIMA, misurato e non asserito
	#
	# Quanti nemici vivi ci sono quando la partita comincia. Non e' un numero su
	# cui scrivere un tetto: e' una scelta di design di -orda, ed e' il numero
	# che questa milestone cambia di proposito. Qui viene solo stampato e non
	# entra in nessuna asserzione: sotto, il 200 che conta e' il **massimo** che
	# la partita raggiunge, non quello con cui parte.
	print("test_arena: partenza misurata: %d nemici vivi al primo frame, population %d, onda %d"
		% [horde.count, horde.population, horde.wave])

	# Conto i nodi con l'orda **vuota**: e' il termine di paragone. Con l'orda
	# vuota e con l'orda piena il numero deve essere lo stesso, altrimenti si
	# puo' passare il tetto con un totale piccolo che pero' cresce.
	_kill_all(h, horde)
	enemies.refresh()
	var bare_nodes := _count_nodes(arena)

	# E il pieno, **raggiunto durante la partita**.
	var drive := _drive_to_full_arena(h, horde)
	enemies.refresh()
	var live: int = horde.count
	if live == ENEMY_TARGET:
		print("test_arena: i 200 nemici vivi sono arrivati all'onda %d, dopo %d passi di simulazione (%.2f s di partita) e %d uccisioni: curva %s"
			% [horde.wave, int(drive["steps"]), float(drive["steps"]) * DT,
				int(drive["kills"]), str(drive["curve"])])
	else:
		print("test_arena: i %d nemici vivi NON sono arrivati: %s (curva %s)"
			% [ENEMY_TARGET, str(drive["reason"]), str(drive["curve"])])

	# Il numero e' quello **raggiunto**, e il motivo del fallimento porta con se'
	# dove la partita si e' fermata: un "200 non raggiunti" senza altro dice che il
	# test e' rotto, non dove.
	h.eq(live, ENEMY_TARGET,
		"i 200 nemici vivi devono essere raggiunti DURANTE la partita: %s" % str(drive["reason"]))
	if live != ENEMY_TARGET:
		# Le sezioni sotto leggono il nemico 200 e chiamano `refresh()` su un'orda
		# piena: senza questo `return` avrebbero letto fuori dal vettore e il
		# fallimento verrebbe da li' invece che da qui.
		return

	var loaded_nodes := _count_nodes(arena)

	print("test_arena: criterio n. 3 misurato al pieno: node_count=%d horde.count=%d"
		% [loaded_nodes, live])

	h.eq(loaded_nodes, bare_nodes, "200 nemici non devono aggiungere ne' un nodo")
	h.check(loaded_nodes < NODE_BUDGET,
		"node_count deve essere < 120 con 200 nemici vivi: e' %d" % loaded_nodes)
	h.check(enemies.get_child_count() == 0,
		"il renderer dei nemici non deve avere figli: un nodo per nemico e' esattamente il difetto che il criterio vieta")

	var mm = enemies.multimesh
	h.eq(enemies.drawn_count(), ENEMY_TARGET,
		"il renderer deve aver disegnato tutti i 200 nemici")
	h.check(mm != null, "il renderer deve aver costruito la MultiMesh")
	if mm != null:
		h.check(mm.use_colors, "la MultiMesh deve avere i colori per istanza: e' cosi' che la tinta per specie arriva all'arena")
		h.eq(mm.visible_instance_count, ENEMY_TARGET,
			"la MultiMesh deve mostrare 200 istanze, non 200 nodi")
		h.check(mm.instance_count <= ENEMY_CAPACITY,
			"la capienza deve restare fissa, non crescere con l'orda")

		# La geometria deve arrivare dall'orda. Il controllo e' su
		# `instance_transform()`, la funzione che il ciclo di gioco chiama per
		# ogni nemico: il buffer della MultiMesh non si rilegge in headless (e'
		# uno storage buffer del RenderingDevice, che nel backend "dummy" non
		# esiste) e `get_instance_transform()` restituisce silenziosamente una
		# trasformazione vuota. Leggere indietro il buffer qui avrebbe fatto
		# passare il test su un renderer che non scrive niente.
		#
		# Il raggio che si passa e' `radii[last]`: da m8 la scala dell'istanza
		# **non** e' piu' una costante del renderer ma il raggio del corpo
		# moltiplicato per il fattore di calibrazione (sezione 9).
		var last := ENEMY_TARGET - 1
		var placed: Transform3D = enemies.instance_transform(horde.transforms[last], horde.radii[last], last)
		var expected: Vector3 = horde.transforms[last]
		h.near(placed.origin.x, expected.x, 0.001,
			"la posizione x del nemico deve arrivare dall'orda")
		h.near(placed.origin.z, expected.z, 0.001,
			"la posizione z del nemico deve arrivare dall'orda")
		h.near(placed.origin.y, expected.y + _lift_of(enemies, expected, horde.radii[last]), BOB_TOLERANCE,
			"la posizione y del nemico deve arrivare dall'orda piu' la sollevata")

	# ## Oltre la capienza fissa: si ferma, non cresce e non legge fuori dal
	# vettore. Lo si prova con un'orda **finta** e non scrivendo dentro
	# `transforms`/`colors`/`radii` dell'orda vera: dal m8 quegli array sono
	# quattro e allineati, e|londerli a mano per far salire `count` romperebbe
	# proprio l'invariante (`radii.size() == count`) che questa sezione vuole
	# vedere rispettato. La finte ha la **stessa forma** dei quattro campi di
	# massa ed e' iniettata con `set_horde()`, che e' esattamente la via che il
	# renderer mette a disposizione per questo.
	var fake := FakeHorde.new()
	fake.name = "FakeHorde1024"
	fake.fill(ENEMY_CAPACITY * 4)
	enemies.set_horde(fake)
	enemies.refresh()
	h.eq(enemies.drawn_count(), ENEMY_CAPACITY,
		"oltre la capienza fissa il renderer deve fermarsi alla capienza, non crescere")
	h.eq(fake.drawn_asked(), ENEMY_CAPACITY * 4,
		"l'orda finta deve aver chiesto 1024 nemici: altrimenti la prova sarebbe passata sul vuoto")
	h.eq(_count_nodes(arena), bare_nodes, "un'orda da 1024 non deve aggiungere nodi")
	enemies.set_horde(horde)
	fake.free()
	enemies.refresh()

## Un'orda finta con la **stessa forma** dei quattro campi di massa che il
## renderer legge (`count`, `transforms`, `colors`, `radii`). Non registra niente
## sul contratto e non e' nell'albero: vive solo per la durata della prova, e il
## numero di nodi che questa sezione confronta non cambia nemmeno di uno.
##
## `fill()` e' l'unica cosa che scrive i campi, e lo fa una volta sola.
class FakeHorde extends Node:
	var count: int = 0
	var transforms: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var radii: PackedFloat32Array = PackedFloat32Array()
	## Quanti nemici il renderer ha **chiesto** all'ultimo `refresh()`, cioe' il
	## `count` che aveva davanti. Serve perche' `drawn_count()` racconta di quanto
	## il renderer ne ha disegnati, e senza questo la prova passerebbe anche con
	## un'orda finta che non chiede niente.
	var asked: int = 0

	func fill(n: int) -> void:
		count = n
		asked = n
		transforms.resize(n)
		colors.resize(n)
		radii.resize(n)
		for i in n:
			transforms[i] = Vector3(float(i) * 0.25, 0.0, 0.0)
			colors[i] = Color.WHITE
			# Raggio crescente: se il renderer tornasse a una taglia costante,
			# questa finte da sola lo renderebbe visibile, perche' qui i raggi
			# non sono tutti uguali.
			radii[i] = 0.4 + 0.01 * float(i % 8)

	func drawn_asked() -> int:
		return asked

## Porta la partita avanti fino a `ENEMY_TARGET` nemici vivi, e dice quanto ci ha
## messo. Guida **solo** con l'API di -orda: `damage_enemy` per uccidere, `step`
## per far correre il tempo, `wave_remaining()` per sapere quanti ne restano da
## ammazzare, `population` per sapere quanti l'onda corrente ne puo' tenere.
## Nessun array scritto a mano e nessuna aritmetica sulla popolazione: se il
## test scrivesse `population = 200` per poi misurare i 200, il numero che
## misura sarebbe uno che ha decito lui.
##
## Il ciclo e' quello di **chi gioca**, non quello che -orda ha scritto in
## `run.gd`: uccidi quello che c'e', l'orda si riempie, la barra arriva a zero,
## l'onda finisce e comincia la successiva. Non conosce le cifre della curva e
## non deve: sono di -orda e cambiano in queste ore, e un test che le sapesse
## asserirebbe contro un numero che non e' suo. L'unica cosa che legge e' **se la
## quota dell'onda corrente e' gia' quella del criterio**: sotto quella soglia il
## numero non puo' arrivarci e uccidere non aiuta, quindi l'unica mossa possibile
## e' uccidere fino a chiudere l'onda; a quella soglia si smette di uccidere e si
## lascia che l'arena si riempia da sola, che e' quello che vede il giocatore a
## meta' onda.
##
## Restituisce solo numeri **misurati**: `steps` (passi di `step()`), `kills`
## (uccisioni), `curve` (quanti vivi e quanta quota a ogni onda attraversata),
## `reason` (perche' non e' arrivata, se non e' arrivata).
func _drive_to_full_arena(h, horde) -> Dictionary:
	var steps := 0
	var kills := 0
	var work := 0
	var fill_stalls := 0
	var last_wave: int = horde.wave
	var curve: Array[String] = []
	var reason := ""

	while work < DRIVE_MAX_WORK and horde.count < ENEMY_TARGET:
		if horde.is_game_over():
			reason = "la partita e' finita (game over) con %d nemici vivi" % horde.count
			break

		# 1. La quota dell'onda corrente e' quella che il criterio chiede: da
		#    qui in poi il conteggio cresce **da solo** e non si uccide piu'
		#    niente. Il tempo che ci mette e' la misura, non una pausa: e il
		#    numero di passi senza crescita sotto e' il modo di accorgersi che
		#    l'orda si e' fermata prima di arrivarci.
		if horde.population >= ENEMY_TARGET:
			var last: int = horde.count
			horde.step(DT)
			steps += 1
			work += 1
			if horde.count <= last:
				fill_stalls += 1
				if fill_stalls >= DRIVE_STALL_STEPS:
					reason = ("la quota dell'onda corrente e' %d ma l'orda si e' fermata a %d vivi: il riempimento non arriva al numero del criterio"
						% [horde.population, horde.count])
					break
			else:
				fill_stalls = 0
			continue

		# 2. Sotto la quota del criterio non si puo' misurare niente: l'unica
		#    strada per cambiare onda e' ammazzare, ed e' quello che fa il
		#    giocatore con l'arma. Uccide tutto quello che c'e' e lascia che il
		#    passo successivo rimetta sul campo il credito di spawn di -orda.
		kills += _kill_all_quiet(horde)
		horde.step(DT)
		steps += 1
		work += 1

		# 3. L'onda e' cambiata? La curva si **stampa**, non si asserisce: le
		#    sue cifre sono di -orda. Quello che si controlla, e che e' un
		#    invariante dichiarato, e' che nessuno dei due numeri superi mai il
		#    massimo che l'orda puo' tenere.
		if horde.wave != last_wave:
			last_wave = horde.wave
			curve.append("w%d %d/%d" % [last_wave, horde.count, horde.population])
			_watch_population(h, horde)

	if horde.count < ENEMY_TARGET and reason == "":
		reason = ("dopo %d passi e %d uccisioni l'orda e' a %d vivi su population %d, onda %d, senza mai arrivare a %d"
			% [steps, kills, horde.count, horde.population, horde.wave, ENEMY_TARGET])

	return {
		"reached": horde.count >= ENEMY_TARGET,
		"steps": steps,
		"kills": kills,
		"curve": curve,
		"reason": reason,
	}

## Gli invarianti che il vertice ha dichiarato per questa milestone (piano 1.4,
## criterio n. 3), controllati **mentre** la partita viene guidata:
## `population` non sale mai sopra `MAX_ENEMIES`, e i vivi non superano mai ne'
## il massimo ne' la popolazione della loro onda.
##
## La **forma** della curva non e' asserita qui e il motivo e' scritto sopra: le
## cifre sono di -orda e cambiano in queste stesse ore, e un test che le
## asserisse starebbe valutando un numero che non e' suo. Quello che qui si
## sorveglia e' che la curva, qualunque forma abbia, **non torni indietro** e non
## esca dal tetto dichiarato da -orda.
func _watch_population(h, horde) -> void:
	var cap := _max_enemies(horde)
	if cap <= 0:
		return
	h.check(horde.population <= cap,
		"population (%d) non deve mai superare MAX_ENEMIES (%d)" % [horde.population, cap])
	h.check(horde.count <= cap,
		"i nemici vivi (%d) non devono mai superare MAX_ENEMIES (%d)" % [horde.count, cap])
	h.check(horde.count <= horde.population,
		"i nemici vivi (%d) non devono superare la popolazione della loro onda (%d)"
			% [horde.count, horde.population])

## `MAX_ENEMIES` letto **dal codice di -orda**, non scritto qui. Il tetto e' suo,
## e il suo numero non e' un numero che questo test deve ricordare: se lo
## cambiasse, il confronto giusto cambia con lui e l'invariante resta quello.
## Restituisce -1 se la costante non c'e' piu': in quel caso il controllo viene
## saltato **e detto**, non aggirato in silenzio.
func _max_enemies(horde) -> int:
	var scr = horde.get_script()
	if scr == null or not scr.has_method("get_script_constant_map"):
		return -1
	var map: Dictionary = scr.get_script_constant_map()
	if not map.has("MAX_ENEMIES"):
		return -1
	return int(map["MAX_ENEMIES"])

## Svuota l'orda con l'API vera di -orda, `damage_enemy`, che toglie il nemico
## dal vettero subito. Non si scrive `horde.count = 0` a mano: cosi' il test
## verificherebbe se stesso invece di verificare il gioco.
##
## L'indice che si uccide viene rimpiazzato dall'ultimo, quindi una passata sola
## non basta: il ciclo esterno ripete finche' non e' vuoto.
func _kill_all(h, horde) -> void:
	var guard := 0
	while horde.count > 0 and guard < 64:
		guard += 1
		for i in range(horde.count):
			if horde.count == 0:
				break
			horde.damage_enemy(i, 1000000.0, Vector3.ZERO)
	h.check(horde.count == 0,
		"l'orda non si e' svuotata: %d nemici rimasti dopo %d passate" % [horde.count, guard])

## Come `_kill_all`, ma **senza asserzione** e con il numero delle uccisioni come
## risultato. La si chiama dentro il ciclo che guida la partita, dove la stessa
## asserzione verrebbe ripetuta centinaia di volte e il suo numero non direbbe
## niente; li' dentro il conteggio delle uccisioni e' invece la misura di quanto
## lavoro ha costato arrivare al pieno.
func _kill_all_quiet(horde) -> int:
	var killed := 0
	var guard := 0
	while horde.count > 0 and guard < 64:
		guard += 1
		killed += horde.count
		for i in range(horde.count):
			if horde.count == 0:
				break
			horde.damage_enemy(i, 1000000.0, Vector3.ZERO)
	return killed

# --- 4. Il terreno chiuso ------------------------------------------------------

## Il muro deve coprire la circonferenza e il pavimento il quadrato: se no,
## l'arena non e' chiusa e si vede il vuoto.
##
## Il raggio qui e' **quello che il terreno ha costruito**, letto da lui, e non il
## numero del test: se i due divergessero, il terreno avrebbe costruito un muro
## al raggio vecchio dentro l'arena di oggi e questa sezione passerebbe lo stesso,
## perche' il confronto sarebbe fra due numeri che il test ha scritti entrambi.
func _terrain(h, arena: Node3D) -> void:
	var ground = arena.get_node("Ground")
	var raggio: float = ground.arena_radius()
	h.eq(ground.get_child_count(), 3,
		"il terreno deve essere tre MultiMesh (pavimento, muro, casse): uno per mesh, non uno per piastrella")
	h.check(ground.floor_instances() > 0, "il pavimento deve avere piastrelle")
	h.check(ground.wall_instances() > 0, "il muro deve avere piastrelle")
	h.check(ground.crate_instances() > 0, "le casse devono essere disposte")
	h.check(ground.wall_coverage() >= TAU * raggio,
		"il muro deve coprire la circonferenza: %.1f m di piastrelle per %.1f m di circonferenza"
			% [ground.wall_coverage(), TAU * raggio])
	h.check(ground.floor_covered_side() >= raggio * 2.0,
		"il pavimento deve coprire almeno il diametro dell'arena: %.1f m per %.1f m"
			% [ground.floor_covered_side(), raggio * 2.0])
	# E il terreno deve essere stato costruito con il raggio **del contratto**, non
	# con il suo fallback: il fallback e' dichiarato per il caso in cui il
	# contratto non c'e', e su questa scena il contratto c'e'. Se il terreno
	# prendesse il fallback qui, avrebbe costruito un muro al raggio di prima
	# dentro l'arena di oggi e nessuna delle asserzioni qui sopra se ne accorgerebbero.
	h.near(raggio, _source_radius(), RADIUS_TOLERANCE,
		"il terreno deve essere stato costruito con il raggio della fonte (%.1f m), non con il fallback: costruito con %.1f m"
			% [_source_radius(), raggio])
	print("test_arena: m9 terreno: raggio %.1f m, pavimento %d piastrelle (%.1f m di lato), muro %d piastrelle (%.1f m di circonferenza su %.1f)"
		% [raggio, ground.floor_instances(), ground.floor_covered_side(),
			ground.wall_instances(), ground.wall_coverage(), TAU * raggio])

# --- 4b. Milestone 10: gli ostacoli esistono, sono dichiarati, e si vedono ------
#
# ## LA SEZIONE CHE METTE SU UN TAVOLO LA PIRAMIDE NON MONTATA
#
# La semantica congelata di m10 in `src/core/contracts.gd` (punto 5) dice che «un
# insieme vuoto e' un errore, non un mondo senza muri», e spiega perche': un array
# vuoto passerebbe **tutti** i test di m10, perche' «nessun ostacolo blocca
# nessuno» e' vero anche quando non c'e' niente. Quindi questa sezione comincia
# dall'alto, dal campo stesso, e non dai dischi: se il contratto non dichiara
# `obstacles` non c'e' niente da confrontare e il resto sarebbe un test sul nulla
# che passa.
#
# ## LA PARTE CHE RIGUARDO IO (criterio n. 6): SI VEDE DOVE E' SOLIDO
#
# Il criterio n. 6 e' «il giocatore si ferma **prima** del bordo del disco, e un
# proiettile **attraversa** un ostacolo». La prima meta' e' di -gameplay e la
# seconda e' di -gameplay: il giocatore e l'arma sono suoi. Ma il criterio vale
# solo se l'ostacolo che blocca e' **quello che si vede**: un disco che blocca e
# non si disegna e' un muro invisibile, e un test che guarda la geometria
# registrata senza guardare l'ostacolo disegnato e' un test sulla carta. Quindi
# qui si confronta il raggio **bloccante** (il contratto) con il raggio
# **disegnato** (quello che il renderer ha scritto nel buffer) e i due devono
# essere lo stesso numero.
#
# Il confronto e' su `written_transform()`, non su `obstacle_transform()`:
# il primo e' **quello che e' stato scritto**, il secondo e' la funzione che
# l'ha prodotto. In headless il `MultiMesh` non si rilegge (cfr. la nota in
# `horde_renderer.gd`), quindi rileggere la funzione sarebbe un test sulla
# formula, non sul risultato.
func _milestone_10(h, arena: Node3D, game: Node) -> void:
	# I dischi che la scena **dichiara**, letti dalla radice viva. Non dalla mappa
	# delle costanti: `OBSTACLE_LAYOUT` non e' una `const` (il numero e' di -orda
	# e arriva da una funzione del suo produttore), quindi la sorgente si legge
	# dove la scena la tiene. La riga che verifica che quei numeri siano proprio
	# quelli di `-orda` e' `_numeri_di_orda`, qui sotto.
	var layout = arena.get("OBSTACLE_LAYOUT")
	var layout_n: int = layout.size() if layout is PackedVector3Array else -1
	var registered = game.get("obstacles")
	var registered_n: int = registered.size() if registered is PackedVector3Array else -1

	# Lo stato, **misurato**, anche quando la sezione fallisce: un FAIL senza i
	# numeri accanto dice che qualcosa non torna, non dove.
	var drawn := arena.get_node_or_null("Obstacles")
	print("test_arena: m10 ostacoli: layout dichiarato %d, registrati in Game.obstacles %d, disegnati %d"
		% [layout_n, registered_n, drawn.drawn_count() if drawn != null else -1])

	# ## PRIMA le tre cose che NON dipendono dal contratto
	#
	# Il tetto dei nodi, le ombre tagliate di m9 e la funzione che disegna il
	# disco si verificano senza che un solo disco sia registrato. Vanno quindi
	# **prima** del ritorno anticipato: un campo che manca dal contratto non deve
	# coprire un difetto che ha a che fare con l'albero o con il sole, e una
	# sezione che si accende e si spegne tutta insieme e' una sezione che resta
	# spenta finche' non e' troppo tardi.
	_ostacoli_su_nodo(h, arena)
	_ombre(h, arena)
	_forma_del_disegno(h)

	# Punto 5 della semantica congelata: se il campo non c'e', il contratto non
	# restituisce un array vuoto in silenzio — dice che la piramide non e' montata.
	# E qui la dice, con il rimedio: il campo e' documentato in `contracts.gd` ma
	# non dichiarato, e quel file non e' di -arena.
	if not h.check(registered is PackedVector3Array,
			"il contratto deve dichiarare `var obstacles: PackedVector3Array`: la superficie di m10 e' DOCUMENTATA in src/core/contracts.gd ma il campo non e' dichiarato, quindi Game.obstacles non esiste e nessun ostacolo blocca nessuno. Il file e' del vertice"):
		return

	var ostacoli: PackedVector3Array = registered

	# Criterio n. 1: gli ostacoli esistono e sono dichiarati.
	h.check(not ostacoli.is_empty(),
		"criterio n. 1 di m10: Game.obstacles non puo' essere vuoto sulla scena vera. Un insieme vuoto non e' un mondo senza muri, e' la piramide non montata. I numeri sono di -orda (criterio n. 2) e li legge src/sim/obstacles.gd")

	# ## DOVE VENGONO I NUMERI: il produttore unico, riletto da qui
	_numeri_di_orda(h, layout)

	# Punto 3 della semantica: `elemento.y > 0.0` e' un **invariante**, non una
	# convenzione. Un raggio nullo e' un ostacolo che non esiste.
	for i in ostacoli.size():
		var e: Vector3 = ostacoli[i]
		h.check(e.y > 0.0,
			"criterio n. 1 di m10: Game.obstacles[%d] ha raggio %.4f in `y` e il raggio deve essere > 0. La convenzione e' Vector3(centro_x, RAGGIO, centro_z): `y` non e' un'altezza e `z` non e' una profondita'"
				% [i, e.y])
		h.finite(e.x, "Game.obstacles[%d].x non e' finito" % i)
		h.finite(e.z, "Game.obstacles[%d].z non e' finito" % i)

	# La registrazione e' **completa**: quello che la scena dichiara e quello che
	# il contratto espone. Un disco costruito e non registrato e' un muro che
	# l'orda non evita; il difetto e' invisibile perche' a occhio c'e'.
	h.eq(registered_n, layout_n,
		"gli ostacoli registrati devono essere tutti quelli che la scena dichiara in OBSTACLE_LAYOUT (src/render/arena.gd): %d registrati su %d dichiarati"
			% [registered_n, layout_n])

	# Il nodo che li disegna c'e', ed e' quello giusto: `tests/test_arena.gd`
	# guarda l'albero, e un `MultiMeshInstance3D` con lo script giusto e' la prova
	# che i dischi sono **costruiti** e non solo dichiarati.
	if not h.check(drawn != null, "manca il nodo Obstacles nella scena vera"):
		return
	h.eq(drawn.drawn_count(), registered_n,
		"gli ostacoli disegnati devono essere tutti quelli registrati: %d disegnati su %d registrati"
			% [drawn.drawn_count(), registered_n])
	h.eq(drawn.get_child_count(), 0,
		"il renderer degli ostacoli non deve avere figli: un nodo per ostacolo e' la stessa classe di difetto del nodo per nemico")
	h.check(drawn.multimesh != null and drawn.multimesh.mesh != null,
		"il renderer degli ostacoli deve avere una mesh: un disco che non si vede non blocca nessuno")
	h.eq(drawn.multimesh.visible_instance_count if drawn.multimesh != null else -1, registered_n,
		"tutte le istanze degli ostacoli devono essere visibili: quelle nascoste sono muri che il giocatore non vede")

	# ## QUI: quello che vedi e' quello che blocca
	for i in ostacoli.size():
		var e: Vector3 = ostacoli[i]
		var t: Transform3D = drawn.written_transform(i)
		var origine := t.origin
		# Il disco e' sul piano XZ: l'asse del cilindro cade sul **centro** del
		# disco, e in `y` non c'e' niente da confrontare (l'altezza e' la forma,
		# non il raggio).
		h.near(origine.x, e.x, OBSTACLE_TOLERANCE,
			"ostacolo %d: il cilindro disegnato e' centrato in x=%.4f ma il disco che blocca e' centrato in x=%.4f" % [i, origine.x, e.x])
		h.near(origine.z, e.z, OBSTACLE_TOLERANCE,
			"ostacolo %d: il cilindro disegnato e' centrato in z=%.4f ma il disco che blocca e' centrato in z=%.4f" % [i, origine.z, e.z])
		# Il raggio disegnato **deve essere** quello che blocca: non maggiore
		# (l'ostacolo blocca piu' di quanto sembra) e non minore (l'ostacolo e'
		# piu' piccolo di quanto sembra, e il giocatore ci entra dentro).
		h.near(drawn.drawn_radius(i), e.y, OBSTACLE_TOLERANCE,
			"ostacolo %d: il raggio **disegnato** e' %.4f m e il raggio che **blocca** e' %.4f m: quello che si vede deve essere quello che blocca"
				% [i, drawn.drawn_radius(i), e.y])
		# E sta in piedi sul pavimento: sotto il pavimento e sopra. Un disco a
		# meta' dentro il terreno non si distingue da nessuno.
		h.check(t.basis.get_scale().y > 0.0,
			"ostacolo %d: il cilindro ha altezza %.4f m: un disco piatto non si vede dalla camera" % [i, t.basis.get_scale().y])
		h.check(origine.y - 0.5 * t.basis.get_scale().y <= 0.0,
			"ostacolo %d: il fondo del cilindro e' a %.4f m e deve essere sotto il pavimento (y=0), non appoggiato sopra" % [i, origine.y - 0.5 * t.basis.get_scale().y])
		h.check(origine.y + 0.5 * t.basis.get_scale().y > 0.0,
			"ostacolo %d: il cilindro deve salire sopra il pavimento, non affondarci dentro" % i)

	_ostacoli_su_mappati(h, arena, ostacoli)

## ## I NUMERI SONO DI `-orda`: il controllo che nessuno li abbia ricopiati
##
## Il piano 3.11 fissa chi sceglie i numeri e chi costruisce: «la geometria la
## sceglie `-orda` e la costruisce `-arena`». Il canale e' dichiarato in
## `src/core/contracts.gd` ed e' una riga: il produttore unico e'
## `src/sim/obstacles.gd` -> `layout(arena_radius)`, e `-arena` lo chiama invece di
## scrivere i numeri.
##
## Qui il test **non ci crede**: rilegge il produttore e pretende che quello che la
## scena mette in scena sia lo stesso identico insieme, disco per disco. Il raggio
## passato al produttore e' la **fonte** letta da questo test (`_source_radius()`),
## non un numero scritto qui: se `-arena` costruisse la mappa con un raggio
## diverso, i due elenchi si separerebbero e questa sezione andrebbe rossa.
##
## Il confronto e' elemento per elemento e non per somma: due insiemi diversi
## possono avere la stessa somma, e una somma uguale non dimostra che siano gli
## stessi dischi — che e' il difetto che m9 ha gia' chiuso una volta.
func _numeri_di_orda(h, layout: Variant) -> void:
	if not (layout is PackedVector3Array):
		h.check(false,
			"criterio n. 1 di m10: OBSTACLE_LAYOUT (src/render/arena.gd) deve essere la lista di dischi letta da src/sim/obstacles.gd, e leggerla vale %s" % type_string(typeof(layout)))
		return
	var dichiarati: PackedVector3Array = layout
	var prodotti: PackedVector3Array = OBST.layout(_source_radius())
	h.eq(dichiarati.size(), prodotti.size(),
		"i dischi in scena devono essere tutti quelli che produce -orda: %d in scena su %d prodotti da src/sim/obstacles.gd"
			% [dichiarati.size(), prodotti.size()])
	var confrontati: int = mini(dichiarati.size(), prodotti.size())
	var peggiore: int = -1
	var scarto: float = 0.0
	for i in confrontati:
		h.vec_near(dichiarati[i], prodotti[i], RADIUS_TOLERANCE,
			"disco %d in scena diverso da quello prodotto da -orda: in scena (%.4f, %.4f, %.4f), prodotto (%.4f, %.4f, %.4f)"
				% [i, dichiarati[i].x, dichiarati[i].y, dichiarati[i].z, prodotti[i].x, prodotti[i].y, prodotti[i].z])
		var d: float = (dichiarati[i] - prodotti[i]).length()
		if d > scarto:
			scarto = d
			peggiore = i
	if confrontati > 0:
		var r: float = prodotti[0].y
		print("test_arena: m10 numeri: %d dischi di raggio %.4f m letti da src/sim/obstacles.gd, nessuna copia in src/render/ (scarto massimo %.9f m sul disco %d)"
			% [prodotti.size(), r, scarto, peggiore])

## Ogni disco deve stare **dentro** l'arena e **fuori** dal muro: un disco che
## esce dal muro e' un muro dentro un muro, e uno che sta fuori dal raggio utile
## e' geometria che il giocatore non incontra mai ma che l'orda continua a
## evitare per sempre.
func _ostacoli_su_mappati(h, arena: Node3D, ostacoli: PackedVector3Array) -> void:
	if ostacoli.is_empty():
		return
	var raggio: float = _source_radius()
	var peggiore := 0.0
	for i in ostacoli.size():
		var e: Vector3 = ostacoli[i]
		var distanza := Vector2(e.x, e.z).length()
		peggiore = maxf(peggiore, distanza + e.y)
		h.check(distanza + e.y <= raggio,
			"ostacolo %d: il disco (centro a %.1f m dal centro, raggio %.1f m) esce dal muro di %.1f m: il muro e' li' per chiudere l'arena, e un disco che lo scavalca si vede da fuori"
				% [i, distanza, e.y, raggio])
	print("test_arena: m10 mappa: il disco piu' esterno arriva a %.1f m dal centro, dentro il muro di %.1f m"
		% [peggiore, raggio])

## ## Il criterio n. 7: `node_count` resta sotto 120 **con** gli ostacoli.
##
## Il tetto e' un numero assoluto e gli ostacoli ci stanno dentro **senza costo**:
## sono istanze di una `MultiMesh`, quindi il numero di nodi dipende dal numero di
## dischi solo per **uno**, il nodo `Obstacles`. Quello e' il numero da dichiarare,
## ed e' quello che questa sezione misura confrontando la scena vera con la scena
## di una `MultiMeshInstance3D` sola.
func _ostacoli_su_nodo(h, arena: Node3D) -> void:
	var nodes := _count_nodes(arena)
	var ostacoli = arena.get_node_or_null("Obstacles")
	h.check(nodes < NODE_BUDGET,
		"node_count deve restare sotto %d anche con gli ostacoli: e' %d" % [NODE_BUDGET, nodes])
	h.eq(ostacoli.get_child_count(), 0,
		"un disco in piu' non deve costare un nodo in piu': il renderer ne ha esattamente uno")
	print("test_arena: m10 nodi: node_count=%d (tetto %d), gli ostacoli costano 1 nodo qualunque sia il loro numero"
		% [nodes, NODE_BUDGET])

## ## Il debito lasciato aperto da m9: le ombre tagliate a meta' arena.
##
## `directional_shadow_max_distance` e' la distanza **dalla camera** oltre la
## quale le ombre non sono piu' disegnate. Il numero non e' confrontato con una
## copia scritta qui: e' **derivato dalla camera vera**, che e' il posto donde
## viene. La catena e' chiusa e ogni passaggio e' un `grep`:
##   `arena.gd:ARENA_RADIUS` -> `arena_camera.gd:EDGE_MARGIN` = quanto il
##   bersaglio puo' spostarsi dal centro, `HEIGHT`/`BACK` = dove sta la camera.
## Il peggiore e' il punto del muro diametralmente opposto all'ancora:
##     orizzontale  (R - EDGE_MARGIN) + BACK + R,  verticale  HEIGHT
func _ombre(h, arena: Node3D) -> void:
	var sun = arena.get_node_or_null("Sun")
	if not h.check(sun != null, "manca il nodo Sun"):
		return
	var raggio := _source_radius()
	var margine := _const_of(CAMERA_SCRIPT, "EDGE_MARGIN")
	var altezza := _const_of(CAMERA_SCRIPT, "HEIGHT")
	var dietro := _const_of(CAMERA_SCRIPT, "BACK")
	if not h.check(raggio > 0.0 and margine > 0.0 and altezza > 0.0 and dietro > 0.0,
			"per derivare la distanza delle ombre servono ARENA_RADIUS, EDGE_MARGIN, HEIGHT e BACK: letti %.1f, %.1f, %.1f, %.1f"
				% [raggio, margine, altezza, dietro]):
		return
	var peggiore := sqrt(pow(dietro + raggio - margine + raggio, 2.0) + pow(altezza, 2.0))
	var impostato: float = sun.directional_shadow_max_distance
	h.check(impostato >= peggiore,
		"le ombre devono arrivare al punto del muro piu' lontano dalla camera, a %.1f m: directional_shadow_max_distance e' %.1f m, quindi meta' arena e' senza ombra" % [peggiore, impostato])
	# Il limite sopra e' quello che rende il numero una **decisione**: un tetto
	# che regge anche 10 km non dice niente, e su un progetto low-poly 10 km di
	# ombre sono un costo che nessuno ha misurato.
	h.check(impostato <= peggiore * SHADOW_MARGIN,
		"directional_shadow_max_distance non deve essere sproporzionato: %.1f m contro il minimo necessario di %.1f m" % [impostato, peggiore])
	print("test_arena: m9 ombre: directional_shadow_max_distance=%.1f m, il punto piu' lontano dalla camera e' a %.1f m (era 90.0 m all'arena da 28 m, 120.0 m a quella da 46 m: meta' arena senza ombra ogni volta che il raggio cresceva e il numero no)"
		% [impostato, peggiore])

## ## I DENTI DI -arena: la funzione che disegna il disco, chiamata con un input
## che qui non e' la geometria dell'arena.
##
## I numeri sotto sono un **ingresso di unita'**, non la mappa: servono perche' un
## test che usa solo i dischi veri non puo' coprire il caso del raggio nullo (che
## il contratto vieta e che quindi non arriverebbe mai) ne' quello del disco
## decentrato. Il raggio che blocca nell'arena e' un altro numero ed e' di -orda.
##
## E la prova che l'asserzione **sa cadere**: `obstacle_transform()` e' pubblica e
## pura, quindi questa sezione la chiama e ne confronta il risultato con la
## geometria che un disco dovrebbe avere. Se la funzione cambiasse forma — se
## introducesse un fattore di scala, o spostasse l'origine — le due righe qui
## sotto cadrebbero, e con loro tutta la sezione «quello che vedi e' quello che
## blocca» di sopra, che usa la stessa funzione.
func _forma_del_disegno(h) -> void:
	var solo = MultiMeshInstance3D.new()
	solo.name = "ObstaclesAlone"
	solo.set_script(load(OBSTACLES_SCRIPT))
	# Un disco finto: centro lontano dall'origine e raggio non ovvio, cosi' uno
	# scambio fra `x`/`z` o fra centro e raggio non puo' passare.
	var finto := Vector3(7.0, 2.5, -3.0)
	solo.build(PackedVector3Array([finto]))

	h.eq(solo.drawn_count(), 1, "un disco in ingresso deve produrre una sola istanza disegnata")
	h.near(solo.drawn_radius(0), finto.y, OBSTACLE_TOLERANCE,
		"il raggio disegnato deve essere il raggio in `y` del disco, non la sua x ne' la sua z: %.4f invece di %.4f" % [solo.drawn_radius(0), finto.y])
	var t: Transform3D = solo.written_transform(0)
	h.near(t.origin.x, finto.x, OBSTACLE_TOLERANCE, "il centro in x va disegnato dove sta, non spostato")
	h.near(t.origin.z, finto.z, OBSTACLE_TOLERANCE, "il centro in z va disegnato dove sta, non spostato")
	h.check(absf(t.basis.get_scale().x - t.basis.get_scale().z) < 0.0001,
		"il disco deve essere rotondo: scala x %.4f e scala z %.4f" % [t.basis.get_scale().x, t.basis.get_scale().z])

	# Il caso che il contratto vieta, chiamato comunque: `obstacle_transform()`
	# non deve tirare fuori una figura dal nulla da un raggio che non c'e'.
	var nullo := Vector3(1.0, 0.0, 1.0)
	solo.build(PackedVector3Array([nullo]))
	h.near(solo.drawn_radius(0), 0.0, OBSTACLE_TOLERANCE,
		"un disco di raggio nullo non deve essere disegnato con un ragchio qualunque: il contratto vieta `y <= 0` e la registrazione lo rifiuta")

	solo.free()

## # --- 5. La camera --------------------------------------------------------------

func _camera(h, arena: Node3D) -> void:
	var cam = arena.get_node("Camera")
	# L'altezza e il ritardo sono **letti** dalla camera e non scritti qui: erano
	# due numeri copiati a mano (34 e 24) che potevano divergere da quelli di
	# `src/render/arena_camera.gd` senza che nessuna asserzione lo vedesse, cioe'
	# due copie del raggio come altre due. Se la costante sparisce, la sezione lo
	# dichiara invece di confrontare il camera con se' stesso.
	var altezza := _const_of(CAMERA_SCRIPT, "HEIGHT")
	var dietro := _const_of(CAMERA_SCRIPT, "BACK")
	if not h.check(altezza > 0.0 and dietro > 0.0,
			"src/render/arena_camera.gd deve dichiarare HEIGHT e BACK: letti %.3f e %.3f" % [altezza, dietro]):
		return

	cam.track(Vector3(10.0, 0.0, 0.0), 1.0)
	h.near(cam.global_position.x, 10.0, 0.001,
		"la camera deve stare sopra il punto che guarda")
	h.near(cam.global_position.y, altezza, 0.001,
		"la camera deve guardare l'arena dall'alto: %.1f m" % altezza)
	h.check(cam.global_position.z > 0.0,
		"la camera deve stare indietro rispetto al bersaglio, altrimenti non si vede dove va il giocatore")
	h.check(cam.current, "la camera dell'arena deve essere quella attiva")

	# Oltre il muro la camera non guarda nel vuoto: spinge il punto guardato
	# indietro. Si controlla l'ancora e non la posizione della camera: la camera
	# porta con se' i suoi 24 metri di ritardo, quindi esce dal raggio anche
	# quando il punto che guarda e' dentro.
	cam.track(Vector3(500.0, 0.0, 500.0), 1.0)
	var anchor: Vector3 = cam.anchor()
	var anchor_flat := Vector2(anchor.x, anchor.z)
	h.check(anchor_flat.length() <= _source_radius() + 0.001,
		"il punto guardato non deve uscire dall'arena: %.1f m dal centro" % anchor_flat.length())
	h.near(cam.global_position.y, anchor.y + altezza, 0.001,
		"la camera deve restare %.1f m sopra il punto che guarda" % altezza)
	h.near(cam.global_position.z, anchor.z + dietro, 0.001,
		"la camera deve restare %.1f m indietro rispetto al punto che guarda" % dietro)

	# m9, criterio n. 3: al limite del clamp il giocatore deve restare
	# nell'inquadratura. E' l'unica sezione che **sposta il giocatore**, quindi
	# sta dopo tutto quello che conta i nodi e le piastrelle e rimette a posto la
	# posizione prima di restituire il nodo.
	_camera_al_bordo(h, arena, cam)

## ## Il criterio n. 3 di m9: al bordo il giocatore e' ANCORA IN QUADRO
##
## L'arena e' passata da 56 m a 92 m di diametro con m9 e poi a 120 m con m11,
## e la camera e' rimasta a 34 m di altezza e 24 m dietro. Il rischio dichiarato dal
## vertice era che il
## giocatore, al limite del clamp, **uscisse dall'inquadratura**. Il numero che
## decide la domanda e' uno solo e non e' il raggio: e' di quanto il giocatore
## puo' stare **fuori dal punto guardato** quando e' al muro, cioe'
## `EDGE_MARGIN - ARENA_MARGIN` = 6,0 - 0,8 = **5,2 m**, perche' la camera
## spinge indietro il punto guardato a `arena_radius - EDGE_MARGIN` mentre il
## giocatore si ferma a `arena_radius - ARENA_MARGIN`. Quel 5,2 m e' diviso per
## la distanza di visione (40,8 m) e il risultato e' confrontato con il
## semi-angolo orizzontale della camera: sotto, il numero **misurato**.
##
## Il passo e' `track(pos, 1.0)` e non un `await`: con `delta = 1.0` il
## `clampf(delta * FOLLOW_SPEED, 0, 1)` della camera da' 1, quindi il bersaglio e'
## esattamente quello e non una posizione che converge dalla precedente. Si
## misura la camera **ferma sul bersaglio**, che e' il caso peggiore: durante
## l'inseguimento l'ancora e' piu' vicina al centro e il giocatore sta quindi
## piu' vicino al centro dell'inquadratura.
##
## Otto direzioni (quattro assi e quattro diagonali), e **non sono equivalenti**:
## l'asse di visione della camera e' fisso (la camera guarda sempre verso -Z, non
## radialmente), quindi gli stessi 5,2 m di scarto dal punto guardato si
## scompongono in parti diverse a seconda della direzione: laterale (0 e 180),
## lungo il braccio (90 e 270) o in mezzo (le diagonali). Il caso peggiore non e'
## "quello radiale" ma quello in cui lo scarto **accorcia** la distanza di
## visione, cioe' il giocatore fra la camera e il punto guardato. Misurato con la
## camera **stringata** a 14 m e 10 m, lo sweep ha dato 0,503 (0 e 180 gradi),
## 0,409 (45 e 135), **0,562 (90, il peggiore)**, 0,315 e 0,287 (225 e 270); con
## la camera **vera** a 34 m e 24 m il peggiore e' invece 0,208 a 0 gradi e 90
## gradi vale 0,185. Per questo qui si asserisce il **massimo delle otto** e non
## una direzione sola scelta a occhio: il caso peggiore si sposta con i numeri
## della camera, e un test che ne avesse fissata una continuerebbe a passare
## mentre il gioco cambia.
##
## ## m11: PERCHE' QUESTO NUMERO **NON** PEGGIORA PASSANDO A 60 m
##
## Il raggio si cancella: il giocatore si ferma a `R - ARENA_MARGIN` e il punto
## guardato a `R - EDGE_MARGIN`, quindi i 5,2 m di scarto sono gli stessi a ogni
## raggio, e la distanza di vista pure (la camera nasce dall'ancora con un offset
## costante di HEIGHT e BACK). Il numero a 46 m e quello a 60 m coincidono **per
## costruzione**, e `_m11_raggio` lo verifica per entrambi e lo confronta con la
## misura di questa sezione: 0,208 a 46 m, 0,208 a 60 m. E' la ragione per cui la
## camera **non e' stata toccata** e il tetto **non e' stato spostato**: il rimedio
## che il piano prevede (allontanare la camera) sarebbe stato un numero cambiato
## per coprire un numero che non era peggiorato.

## Direzioni in cui il giocatore viene portato al limite del clamp: quattro assi
## e quattro diagonali, in gradi.
const BORDO_DIREZIONI := [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]

func _camera_al_bordo(h, arena: Node3D, cam) -> void:
	var player = arena.get_node_or_null("Player")
	if not h.check(player != null, "la scena vera non ha il nodo Player: il criterio n. 3 non si puo' misurare"):
		return

	# Il margine del giocatore **letto dal suo codice**, non scritto qui: se
	# -gameplay lo cambiasse, il "limite del clamp" da misurare cambierebbe con
	# lui, e questo test starebbe ancora misurando il numero di ieri.
	var player_script = player.get_script()
	if player_script == null or not player_script.has_method("get_script_constant_map"):
		h.fail("src/player/player.gd non espone la sua mappa delle costanti: il clamp del giocatore non e' piu' misurabile")
		return
	var margin_v = player_script.get_script_constant_map().get("ARENA_MARGIN")
	if not h.check(typeof(margin_v) == TYPE_FLOAT or typeof(margin_v) == TYPE_INT,
			"src/player/player.gd deve dichiarare ARENA_MARGIN: e' il numero che tiene il giocatore lontano dal muro"):
		return
	var margine := float(margin_v)
	var raggio := _source_radius()
	var limite := maxf(raggio - margine, 0.5)

	# Il viewport: serve per l'aspetto, e l'aspetto e' meta' della domanda. Lo si
	# **stampa** perche' in headless la dimensione arriva dalla configurazione e
	# non da un monitor, e un criterio che dipende da un numero non stampato non
	# si puo' ricontrollare.
	var vp: Viewport = cam.get_viewport()
	var size := Vector2(1.0, 1.0)
	if vp != null:
		size = vp.get_visible_rect().size
	h.check(size.x > 1.0 and size.y > 1.0,
		"il viewport deve avere una dimensione reale: %s" % str(size))
	var aspect := size.x / maxf(size.y, 1.0)

	var posizione_salvata: Vector3 = player.global_position
	var peggiore := 0.0
	var peggiore_grado := 0.0
	var peggiore_distanza := 0.0
	var fuori := 0
	var righe: Array[String] = []
	for grado in BORDO_DIREZIONI:
		var sul_bordo := _sul_bordo(limite, float(grado))
		player.global_position = sul_bordo
		cam.track(sul_bordo, 1.0)
		var dentro: bool = cam.is_position_in_frustum(player.global_position)
		var rapporto := _rapporto_in_quadro(cam, player.global_position)
		if not dentro:
			fuori += 1
		if rapporto > peggiore:
			peggiore = rapporto
			peggiore_grado = float(grado)
			peggiore_distanza = _distanza_di_vista(cam, player.global_position)
		righe.append("%d deg %.3f%s" % [int(grado), rapporto, "" if dentro else " FUORI"])
	player.global_position = posizione_salvata
	cam.track(player.global_position, 1.0)

	_frame_worst = peggiore
	_frame_deg = peggiore_grado
	_frame_view = peggiore_distanza

	# ## IL CRITERIO: al limite del clamp il giocatore e' dentro al frustum
	h.check(fuori == 0,
		"criterio n. 3 di m9: al limite del clamp (%.1f m dal centro, %.1f m di margine) il giocatore deve restare nell'inquadratura: fuori in %d direzioni su %d [%s]"
			% [limite, margine, fuori, BORDO_DIREZIONI.size(), ", ".join(righe)])

	# ## E IL MARGINE, dichiarato sul numero misurato qui sopra
	#
	# Il booleano da solo, a questi numeri, e' un'asserzione che **non puo'**
	# fallire: per uscire dall'inquadratura al muro la camera dovrebbe arrivare a
	# pochi metri dal giocatore, e nessuno ricala la camera di cosi' tanto di
	# proposito. Quindi qui si asserisce anche **dove** sta nel quadro, e il tetto
	# viene dalla misura delle otto direzioni qui sopra, non da un occhio.
	h.check(peggiore <= FRAME_LIMIT,
		"il giocatore al limite del clamp deve restare nella meta' centrale dell'inquadratura: misurato %.3f della semi-larghezza a %d gradi, tetto dichiarato %.2f [%s]"
			% [peggiore, int(peggiore_grado), FRAME_LIMIT, ", ".join(righe)])

	var semi := _semi_angoli(cam, aspect)
	var offset := _offset_al_bordo(cam, margine)
	print("test_arena: m9 camera al bordo: clamp a %.1f m dal centro (raggio %.1f - margine %.1f di player.gd); viewport %s, aspect %.3f; fov %.1f (keep_aspect %d); semi-angoli %.1f gradi in verticale e %.1f in orizzontale"
		% [limite, raggio, margine, str(size), aspect, cam.fov, int(cam.keep_aspect), semi.x, semi.y])
	print("test_arena: m9 camera al bordo: il giocatore al muro e' %.1f m fuori dal punto guardato (EDGE_MARGIN - ARENA_MARGIN), a %.1f m di distanza di visione: %.3f della semi-larghezza, peggiore su %d gradi, tetto %.2f"
		% [offset, peggiore_distanza, peggiore, int(peggiore_grado), FRAME_LIMIT])
	print("test_arena: m9 camera al bordo: con questi numeri il giocatore uscirebbe dall'inquadratura solo se la camera scendesse sotto i %.1f m di distanza di visione (oggi %.1f m): il booleano da solo non avrebbe denti, il tetto %.2f si"
		% [_limite_di_uscita(offset, semi.y), peggiore_distanza, FRAME_LIMIT])

## La posizione del limite del clamp in una data direzione, in gradi.
func _sul_bordo(limite: float, grado: float) -> Vector3:
	var a := deg_to_rad(grado)
	return Vector3(cos(a) * limite, 0.0, sin(a) * limite)

## Quanto il giocatore e' **fuori dal punto guardato** quando e' al muro: e' la
## differenza fra i due clamp, non un numero scritto qui. `EDGE_MARGIN` e' di
## `src/render/arena_camera.gd` e `ARENA_MARGIN` di `src/player/player.gd`: se un
## giorno la camera o il giocatore stringessero il proprio margine, questa
## misura direbbe quanto, invece di continuare a raccontare il numero di ieri.
## `-1.0` se la camera non dichiara `EDGE_MARGIN`: un margine che sparisce e' un
## margine che nessuno puo' piu' confrontare.
func _offset_al_bordo(cam, margine_giocatore: float) -> float:
	var edge := -1.0
	var scr = cam.get_script()
	if scr != null and scr.has_method("get_script_constant_map"):
		var v = scr.get_script_constant_map().get("EDGE_MARGIN")
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			edge = float(v)
	if edge < 0.0:
		return 0.0
	return maxf(edge - margine_giocatore, 0.0)

## I due semi-angoli del frustum in gradi, `x` verticale e `y` orizzontale. Il
## `fov` di Godot e' quello **verticale** con `keep_aspect = KEEP_HEIGHT` (il
## default): l'orizzontale si ricava dall'aspetto del viewport, che in headless
## viene dalla configurazione del progetto e non da un monitor.
func _semi_angoli(cam, aspect: float) -> Vector2:
	var semi_v := deg_to_rad(cam.fov) * 0.5
	var semi_h := atan(tan(semi_v) * aspect)
	if cam.keep_aspect == Camera3D.KEEP_WIDTH:
		semi_h = deg_to_rad(cam.fov) * 0.5
		semi_v = atan(tan(semi_h) / maxf(aspect, 0.0001))
	return Vector2(rad_to_deg(semi_v), rad_to_deg(semi_h))

## Quanto e' lontana la camera dal punto guardato **lungo l'asse di visione**: e'
## il denominatore del rapporto angolare. Non e' `distance_to` perche' quello
## include il disassamento radiale fra camera e ancora, che qui e' piccolo ma non
## deve esserlo per ipotesi.
func _distanza_di_vista(cam, pos: Vector3) -> float:
	var local: Vector3 = cam.global_transform.affine_inverse() * pos
	return maxf(-local.z, 0.001)

## Dove sta un punto rispetto al centro dell'inquadratura, come frazione della
## semi-larghezza (o dell'altezza) del quadro: `0` e' il centro esatto, `1` e'
## esattamente il bordo. E' la proiezione che `is_position_in_frustum` fa senza
## dirla, e serve per dichiarare un **margine** e non un booleano.
func _rapporto_in_quadro(cam, pos: Vector3) -> float:
	var semi := _semi_angoli(cam, _aspecto(cam))
	var semi_v := deg_to_rad(semi.x)
	var semi_h := deg_to_rad(semi.y)
	var depth := _distanza_di_vista(cam, pos)
	if depth <= 0.001:
		return INF
	var local: Vector3 = cam.global_transform.affine_inverse() * pos
	return maxf(absf(local.x / depth) / tan(semi_h), absf(local.y / depth) / tan(semi_v))

## L'aspetto del viewport della camera, con un minimo dichiarato: un aspetto zero
## produrrebbe un semi-angolo orizzontale nullo e un rapporto infinito, cioe' un
## FAIL che non parla di camera ma di viewport.
func _aspecto(cam) -> float:
	var vp: Viewport = cam.get_viewport()
	var size := Vector2(1.0, 1.0)
	if vp != null:
		size = vp.get_visible_rect().size
	return size.x / maxf(size.y, 1.0)

## La distanza di visenza a cui la camera dovrebbe arrivare **per perdere** il
## giocatore dall'inquadratura al muro: l'angolo col centro del quadro e'
## `offset / distanza` e il bordo e' quando diventa 1. E' il numero che dice se
## l'asserzione ha denti, e con `FRAME_LIMIT` dice quanto si puo' stringere la
## camera prima che la porta diventi rossa.
func _limite_di_uscita(offset: float, semi_h_gradi: float) -> float:
	if offset <= 0.0:
		return INF
	return offset / tan(deg_to_rad(semi_h_gradi))

## ## `FRAME_LIMIT`: quanto lontano dal centro dell'inquadratura puo' arrivare il
## giocatore al limite del clamp, come frazione della semi-larghezza del quadro.
##
## ## COME E' STATO DERIVATO (misura prima del numero)
##
## Sweep delle otto direzioni di `_camera_al_bordo`, scena vera, camera vera
## (34 m di altezza, 24 m dietro, `fov` 62, `KEEP_HEIGHT`), arena a **46 m** nel
## 2026-10-13:
##
##     il giocatore al muro e' a 45,2 m dal centro (46 - ARENA_MARGIN 0,8)
##     la camera spinge il punto guardato a 40,0 m (46 - EDGE_MARGIN 6,0)
##     quindi il giocatore e' 5,2 m fuori dal centro dell'inquadratura,
##     a 41,6 m di distanza di visione **misurata** (non 40,8 = sqrt(33^2+24^2):
##     la differenza e' il metro fra il giocatore a terra e il punto guardato a
##     LOOK_HEIGHT = 1 m, che accorcia l'asse di visione)
##     semi-angolo orizzontale 31,0 gradi  ->  tan = 0,6009
##     MISURATO: 5,2 / (41,6 x 0,6009) = 0,208 della semi-larghezza
##
## **m11: a 60 m il numero e' lo stesso, 0,208**, perche' l'offset al muro e'
## `EDGE_MARGIN - ARENA_MARGIN` = 5,2 m a ogni raggio e il raggio si cancella
## nella differenza. Rimisurato sulla scena vera a 60 m: clamp a 59,2 m (60 - 0,8),
## ancora a 54,0 m (60 - 6,0), distanza di vista **41,6 m** e rapporto **0,208**,
## peggiore su 0 gradi. Le due righe sotto sono le stesse di prima e non cambiano:
## il tetto e' un numero deciso, non una scommessa sul codice.
##
## e la stampa dice anche che, cosi', il giocatore uscirebbe dall'inquadratura
## solo se la camera scendesse sotto gli **8,7 m** di distanza di visione: cioe'
## il booleano `is_position_in_frustum`, da solo, non avrebbe denti (nessuno
## ricala la camera di quattro volte di proposito). Per questo il criterio ha due
## righe: il booleano che il vertice ha chiesto, e il margine sotto.
##
## **Perche' 0,50 e non il massimo misurato (0,208, a 46 m come a 60 m)**: un
## tetto poggiato sul
## massimo cadrebbe alla prima flessione di un pixel e direbbe piu' del gioco di
## quanto il gioco sappia fare. 0,50 mette il giocatore dentro la **meta'
## centrale** del quadro, che e' la richiesta di progetto ("non basta che ci sia,
## deve restare dove lo vedi"), e lascia **2,4 volte** la misura: in metri, il
## giocatore puo' stare fino a 12,5 m dal centro dell'inquadratura invece dei 5,2
## che c'e' oggi. Per arrivare a 0,50 la distanza di visione deve scendere da
## 41,6 m a **17,3 m**: una camera stringuta (per esempio 14 m di altezza e 10 m
## dietro, cioe' il 40% della distanza di oggi) la porta rossa.
##
## ## ATTENZIONE AL NUMERO MISURATO IN HEADLESS
##
## In headless il viewport e' **64x64**, aspetto **1,000**, e non i 1280x720 di
## `project.godot`: l'aspetto non viene da un monitor. Percio' il semi-angolo
## orizzontale e' 31 gradi, non i 46,9 di un 16:9, e il rapporto misurato
## (0,208 a 46 m e a 60 m) e' il **caso peggiore**: con la finestra vera a 1,778 di
## aspetto lo stesso giocatore sta a 0,117. La misura e' quindi conservativa per
## costruzione, e non un artefatto da correggere: e' il caso in cui il criterio e' piu'
## facile da violare.
const FRAME_LIMIT := 0.50

# --- 5b. m11: il raggio e' passato da 46,0 m a 60,0 m, e i numeri sono qui ------
#
# ## PERCHE' UNA SEZIONE E NON UN NUMERO CAMBIATO
#
# Un cambio di raggio non si verifica guardando il raggio: il raggio lo
# confronta gia' il criterio n. 1 e il criterio n. 2. Qui si verifica **tutto
# quello che il raggio si porta dietro** — pavimento, muro, ombre, inquadratura,
# nodi — e ogni numero viene stampato **accanto al suo numero di prima**, calcolato
# con lo stesso codice. Il criterio di m9 stampava `46.000` come «fonte»,
# `46.000` come «deciso» e le copie allineate: quello stile, con un numero in
# piu', e' il riferimento per un cambio di questo peso.
#
# ## LA REGOLA, E PERCHE' «100 m vanno bene anche a 60 m» non e' una regola
#
# Il pavimento e' un quadrato di `2 * R + FLOOR_MARGIN` e il muro chiude
# `TAU * R`: entrambe le misure sono **derivate dal raggio**, non scelte. La
# regola e' «coprire il disco piu' un margine», e sotto e' dichiarata anche la
# dentatura: se il raggio sale e il pavimento resta com'era, il gioco si vede
# oltre il muro e questa sezione va rossa.
#
# ## L'INQUADRATURA: UN INVARIANTE CHE DEVE ESSERE VISTO
#
# Il rapporto fra la posizione del giocatore e il centro dell'inquadratura, al
# limite del clamp, e' `offset / (distanza di vista * tan(semi-angolo))`, e
# l'`offset` e' `EDGE_MARGIN - ARENA_MARGIN` = 6,0 - 0,8 = **5,2 m**: la camera
# spinge il punto guardato a `R - EDGE_MARGIN` mentre il giocatore si ferma a
# `R - ARENA_MARGIN`, quindi il **raggio si cancella nella differenza**. Per
# questo il numero a 60 m e' lo stesso di quello a 46 m e la camera **non e'
# stata toccata**: spostarla avrebbe reso peggiore un numero che non peggiorava.
# Un invariante che non si vede e' un invariante che il prossimo rompe senza
# accorgersene, quindi qui e' stampato due volte e confrontato con la misura.

# ## I DENTI DI QUESTA SEZIONE: PROVATI E RIMOSSI
#
# Le due asserzioni con cui finisce (pavimento che copre il disco piu' il margine,
# muro che chiude la circonferenza del raggio di oggi) sono state provate il
# 2026-10-14 moltiplicando per 1,5 il raggio che questa sezione confronta con la
# scena — cioe' facendo finta che il raggio fosse salito e il terreno no. Le due
# sono cadute **una per una**, con i numeri accanto: pavimento 128,0 m misurati
# contro 188,0 m richiesti, muro 378 piastrelle contro 566 richieste. Uscita 1. Il
# blocco e' stato rimosso e non e' in questo file (verificato con `grep`), quindi
# quelle due righe portano davvero la geometria e non un costrutto di questa sezione.

## Il raggio di prima e quello di oggi. `PREVIOUS_RADIUS` e' il numero sostituito
## e non viene confrontato con nessuno: serve a stampare la coppia.
func _m11_raggio(h, arena: Node3D) -> void:
	var t0 := Time.get_ticks_usec()
	var vecchio := PREVIOUS_RADIUS
	var nuovo := _source_radius()

	# I numeri di cui ho bisogno sono **letti dai sorgenti**, mai ricopiati: e' la
	# tecnica che questo file usa gia' per `HEIGHT`/`BACK`/`EDGE_MARGIN`.
	var tile := _const_of(GROUND_SCRIPT, "TILE")
	var margine_pav := _const_of(GROUND_SCRIPT, "FLOOR_MARGIN")
	var file_muro := _const_of(GROUND_SCRIPT, "WALL_ROWS")
	var edge := _const_of(CAMERA_SCRIPT, "EDGE_MARGIN")
	var altezza := _const_of(CAMERA_SCRIPT, "HEIGHT")
	var dietro := _const_of(CAMERA_SCRIPT, "BACK")
	var look_h := _const_of(CAMERA_SCRIPT, "LOOK_HEIGHT")
	var suolo := _const_of(CAMERA_SCRIPT, "ARENA_FLOOR")
	if not h.check(tile > 0.0 and margine_pav >= 0.0 and file_muro > 0.0,
			"m11: per ricalcolare la geometria servono TILE, FLOOR_MARGIN e WALL_ROWS di src/render/arena_ground.gd: letti %.3f, %.3f, %.3f"
				% [tile, margine_pav, file_muro]):
		return

	var player = arena.get_node_or_null("Player")
	var margine_giocatore: float = _costante_di(player, "ARENA_MARGIN")
	if not h.check(edge > 0.0 and altezza > 0.0 and dietro > 0.0 and look_h >= 0.0
			and suolo >= 0.0 and float(margine_giocatore) > 0.0,
			"m11: per l'inquadratura servono EDGE_MARGIN, HEIGHT, BACK, LOOK_HEIGHT e ARENA_FLOOR di src/render/arena_camera.gd e ARENA_MARGIN di src/player/player.gd: letti %.3f, %.3f, %.3f, %.3f, %.3f, %.3f"
				% [edge, altezza, dietro, look_h, suolo, float(margine_giocatore)]):
		return
	var marg := float(margine_giocatore)

	# ## 5b.1 IL TERRENO: la regola e i due numeri, uno per lato
	#
	# `x` e' il numero di piastrelle per lato, `y` il totale del pavimento.
	var pav_vecchio := _pavimento_per(vecchio, tile, margine_pav)
	var pav_nuovo := _pavimento_per(nuovo, tile, margine_pav)
	# `x` e' il numero di segmenti che chiudono la circonferenza, `y` le
	# piastrelle in totale (segmenti per file di muro).
	var muro_vecchio := _muro_per(vecchio, tile, int(file_muro))
	var muro_nuovo := _muro_per(nuovo, tile, int(file_muro))

	var ground = arena.get_node_or_null("Ground")
	if h.check(ground != null, "m11: la scena vera non ha il nodo Ground"):
		var misurato: float = ground.floor_covered_side()
		# Il pavimento deve coprire il disco **piu' il margine dichiarato**, non
		# solo il diametro: e' questa la riga che resta rossa se il raggio sale e
		# il pavimento resta quello di prima (100,0 m su un disco di 128,0 m, e si
		# vede il vuoto oltre il muro).
		h.check(misurato >= nuovo * 2.0 + margine_pav - 0.001,
			"m11: il pavimento deve coprire il disco piu' il margine: %.1f m di lato per un raggio di %.1f m con FLOOR_MARGIN %.1f m, ne copre %.1f m. Il pavimento del raggio di prima misurava %.1f m"
				% [nuovo * 2.0 + margine_pav, nuovo, margine_pav, misurato, _lato_pavimento(PREVIOUS_RADIUS, tile, margine_pav)])
		# E il muro deve essere stato ricostruito sul raggio di oggi: contare le
		# piastrelle e' l'unico modo di vederlo in headless (il buffer del
		# `MultiMesh` non si rilegge, cfr. la nota in `horde_renderer.gd`).
		h.check(ground.wall_instances() >= muro_nuovo.y,
			"m11: il muro deve chiudere la circonferenza di %.1f m: servono %d piastrelle e ce ne sono %d, cioe' quelle del raggio di prima (che ne chiedeva %d su %.1f m)"
				% [TAU * nuovo, muro_nuovo.y, ground.wall_instances(), muro_vecchio.y, TAU * vecchio])
		print("test_arena: m11 terreno: pavimento %d piastrelle (%.1f m di lato) a %.1f m -> %d piastrelle (%.1f m di lato) a %.1f m; muro %d piastrelle (%.1f m di piastrelle) su %.1f m di circonferenza -> %d piastrelle (%.1f m) su %.1f m"
			% [pav_vecchio.y, pav_vecchio.x * tile, vecchio, pav_nuovo.y, pav_nuovo.x * tile, nuovo,
				muro_vecchio.y, float(muro_vecchio.y) * tile, TAU * vecchio,
				muro_nuovo.y, float(muro_nuovo.y) * tile, TAU * nuovo])
	print("test_arena: m11 terreno misurato sulla scena vera: %d piastrelle di pavimento (%.1f m di lato) e %d di muro (%.1f m su %.1f di circonferenza) a %.1f m di raggio"
		% [ground.floor_instances(), ground.floor_covered_side(), ground.wall_instances(),
			ground.wall_coverage(), TAU * nuovo, nuovo])

	# ## 5b.2 LE OMBRE: il punto piu' lontano si allontana, il numero no
	#
	# La catena e' la stessa di `_ombre`, che asserisce: ancora a
	# `R - EDGE_MARGIN`, camera a `ancora + (0, HEIGHT, BACK)`, e il punto peggiore
	# e' il muro diametralmente opposto all'ancora. Qui la catena viene calcolata
	# **per entrambi i raggi**, cosi' la stampa dice quanto il numero e' cresciuto
	# e dice che il tetto dichiarato («meta' arena senza ombra») e' stato
	# ricalcolato invece che moltiplicato per 60/46.
	var pegg_vecchio := _distanza_ombre(vecchio, edge, altezza, dietro)
	var pegg_nuovo := _distanza_ombre(nuovo, edge, altezza, dietro)
	var sole = arena.get_node_or_null("Sun")
	var impostato: float = sole.directional_shadow_max_distance if sole != null else -1.0
	print("test_arena: m11 ombre: il punto piu' lontano dalla camera e' a %.1f m a %.1f m di raggio e a %.1f m a %.1f m, contro %.1f m impostati: il tetto dichiarato e' meta' arena senza ombra, quindi il numero e' stato ricalcolato e non moltiplicato per 60/46 (%.2f)"
		% [pegg_vecchio, vecchio, pegg_nuovo, nuovo, impostato, nuovo / maxf(vecchio, 0.001)])

	# ## 5b.3 L'INQUADRATURA: il numero di prima accanto al numero di oggi
	#
	# Il numero calcolato sul raggio di oggi deve combaciare con quello **misurato**
	# da `_camera_al_bordo` sulla scena vera: e' il confronto che autorizza a usare
	# la stessa formula sul raggio di prima, dove la scena non esiste piu'.
	var cam = arena.get_node_or_null("Camera")
	if not h.check(cam != null, "m11: la scena vera non ha il nodo Camera"):
		return
	var semi := _semi_angoli(cam, _aspecto(cam))
	var cal_vecchio := _in_quadro(vecchio, marg, edge, altezza, dietro, look_h, suolo, semi)
	var cal_nuovo := _in_quadro(nuovo, marg, edge, altezza, dietro, look_h, suolo, semi)

	h.near(cal_nuovo.x, _frame_worst, 0.001,
		"m11: il rapporto in quadro calcolato per %.1f m deve combaciare con quello MISURATO sulla scena vera: calcolato %.4f, misurato %.4f. Se i due non combaciano, il numero stampato per il raggio di prima e' una ricorrenza e non una verifica"
			% [nuovo, cal_nuovo.x, _frame_worst])
	h.check(cal_vecchio.x <= FRAME_LIMIT,
		"m11: al raggio di %.1f m il giocatore al muro era %.3f della semi-larghezza, contro il tetto %.2f: il numero non e' peggiorato e la camera non va toccata"
			% [vecchio, cal_vecchio.x, FRAME_LIMIT])
	h.check(cal_nuovo.x <= FRAME_LIMIT,
		"m11: al raggio di %.1f m il giocatore al muro e' %.3f della semi-larghezza, contro il tetto %.2f: se e' oltre, il rimedio e' allontanare la camera e dichiarare di quanto, non spostare il tetto"
			% [nuovo, cal_nuovo.x, FRAME_LIMIT])

	print("test_arena: m11 inquadratura: a %.1f m il giocatore al muro era %.3f della semi-larghezza (peggiore su %d gradi, a %.1f m di distanza di vista), tetto %.2f"
		% [vecchio, cal_vecchio.x, int(cal_vecchio.z), cal_vecchio.y, FRAME_LIMIT])
	print("test_arena: m11 inquadratura: a %.1f m e' %.3f, MISURATO %.3f sulla scena vera: invariante perche' l'offset al muro e' EDGE_MARGIN - ARENA_MARGIN = %.1f - %.1f = %.1f m e il raggio si cancella nella differenza, quindi la camera NON e' stata toccata e resta %.1f m di distanza di vista e %.1f m sotto i quali si uscirebbe dal quadro"
		% [nuovo, cal_nuovo.x, _frame_worst, edge, marg, maxf(edge - marg, 0.0),
			cal_nuovo.y, _limite_di_uscita(maxf(edge - marg, 0.0), semi.y)])

	# ## 5b.4 I NODI: un raggio maggiore non deve costare un nodo
	var nodi := _count_nodes(arena)
	h.check(nodi < NODE_BUDGET,
		"m11: node_count deve restare sotto %d con l'arena a %.1f m: e' %d" % [NODE_BUDGET, nuovo, nodi])
	print("test_arena: m11 nodi: node_count=%d a %.1f m di raggio, tetto %d invariato: il raggio maggiore non costa un nodo (pavimento, muro e ostacoli sono istanze di MultiMesh, non nodi) e gli ostacoli sono sempre %d dischi su una sola MultiMeshInstance3D"
		% [nodi, nuovo, NODE_BUDGET, OBST.OBSTACLE_COUNT])

	print("test_arena: m11 raggio misurato: %.1f m -> %.1f m; la sezione ha costato %.1f ms (il file intero e' stampato in fondo)"
		% [vecchio, nuovo, float(Time.get_ticks_usec() - t0) / 1000.0])

## Le piastrelle per lato (`x`) e in tutto (`y`) del quadrato che copre il disco
## piu' `margine`, con lo stesso arrotondamento in eccesso di
## `arena_ground.gd`: un pavimento un pelo piu' largo costa quattro piastrelle, un
## pavimento piu' stretto costa il buco nero.
func _pavimento_per(raggio: float, tile: float, margine: float) -> Vector2i:
	var per_lato := int(ceil((raggio * 2.0 + margine) / tile))
	return Vector2i(per_lato, per_lato * per_lato)

## Il lato che il pavimento copre davvero: `ceil(lato / TILE) * TILE`.
func _lato_pavimento(raggio: float, tile: float, margine: float) -> float:
	return float(_pavimento_per(raggio, tile, margine).x) * tile

## I segmenti che chiudono la circonferenza (`x`) e le piastrelle in totale
## (`y`), uno per piastrella e `file` file di altezza, arrotondando in eccesso
## come `arena_ground.gd`: il muro deve chiudere davvero, senza buchi e senza
## sporgenze.
func _muro_per(raggio: float, tile: float, file: int) -> Vector2i:
	var segmenti := maxi(8, int(ceil(TAU * raggio / tile)))
	return Vector2i(segmenti, segmenti * file)

## Il punto del muro piu' lontano dalla camera, in metri. Stessa catena di
## `_ombre`: in orizzontale l'ancora sta a `R - EDGE_MARGIN` dalla parte della
## camera e il muro opposto a `R` dalla parte opposta, in verticale la camera e'
## a `HEIGHT`. Il raggio compare **due volte** e `EDGE_MARGIN` una: e' per questo
## che il numero cresce piu' che linearmente e non puo' essere moltiplicato.
func _distanza_ombre(raggio: float, edge: float, altezza: float, dietro: float) -> float:
	return sqrt(pow(dietro + raggio - edge + raggio, 2.0) + pow(altezza, 2.0))

## Il rapporto in quadro al limite del clamp per un raggio **qualsiasi**, senza
## mettere in scena un'arena: la stessa camera (`HEIGHT`, `BACK`, `LOOK_HEIGHT`,
## `EDGE_MARGIN`), lo stesso clamp e lo stesso `look_at` di `track()`, applicati
## alle stesse otto direzioni di `BORDO_DIREZIONI`. Restituisce
## `x` = rapporto peggiore, `y` = distanza di vista a quel punto, `z` = gradi.
##
## Serve al raggio di **prima**, dove non c'e' piu' una scena da montare: e il
## confronto fra questo numero e la misura fatta sul raggio di oggi e' l'unica
## cosa che gli dà diritto di esistere.
func _in_quadro(raggio: float, margine: float, edge: float, altezza: float, dietro: float,
		look_height: float, suolo: float, semi: Vector2) -> Vector3:
	var limite := maxf(raggio - margine, 0.5)
	var interno := maxf(raggio - edge, 0.0)
	var tv := tan(deg_to_rad(semi.x))
	var th := tan(deg_to_rad(semi.y))
	var peggiore := 0.0
	var distanza := 0.0
	var grado := 0.0
	for g in BORDO_DIREZIONI:
		var a := deg_to_rad(float(g))
		var p := Vector3(cos(a) * limite, 0.0, sin(a) * limite)
		# Lo stesso clamp di `_clamped()`: il punto guardato spinto dentro.
		var flat := Vector2(p.x, p.z)
		var ancora := Vector3(flat.x, suolo, flat.y)
		if flat.length() > interno:
			ancora = Vector3(flat.normalized().x * interno, suolo, flat.normalized().y * interno)
		var camera := ancora + Vector3(0.0, altezza, dietro)
		# Lo stesso `look_at`: `z` dalla camera al bersaglio, `x` in su, `y` residua.
		var zz := (camera - (ancora + Vector3.UP * look_height)).normalized()
		var xx := Vector3.UP.cross(zz).normalized()
		var yy := zz.cross(xx)
		var rel := p - camera
		var locale := Vector3(rel.dot(xx), rel.dot(yy), rel.dot(zz))
		var depth := maxf(-locale.z, 0.001)
		var rapporto := maxf(absf(locale.x / depth) / th, absf(locale.y / depth) / tv)
		if rapporto > peggiore:
			peggiore = rapporto
			distanza = depth
			grado = float(g)
	return Vector3(peggiore, distanza, grado)

## Una costante numerica dalla mappa delle costanti di uno script gia' vivo, o
## `-1.0`. Serve per i numeri di ** altre foglie** che questo test usa senza
## copiarli: se il nome sparisce, il valore e' `-1.0` e la sezione che lo
## aspettava lo dice invece di continuare con `0.0`.
func _costante_di(node, chiave: String) -> float:
	if node == null:
		return -1.0
	var scr = node.get_script()
	if scr == null or not scr.has_method("get_script_constant_map"):
		return -1.0
	var v = scr.get_script_constant_map().get(chiave)
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return -1.0

# --- 6. L'HUD ------------------------------------------------------------------

func _hud(h, arena: Node3D, game: Node) -> void:
	var hud = arena.get_node("Hud")
	h.check(hud.has_method("set_state"), "l'HUD deve accettare i numeri con set_state()")

	# Prima alimentata dalla scena vera: arena chiama `set_state()` dai numeri
	# che legge sul contratto, quindi qui si esegue il suo `_process` e si legge
	# quello che c'e' scritto. E' il collegamento HUD <-> contratto, verificato
	# con l'orda e il giocatore veri e non con un `set_state()` a mano.
	#
	# Il numero di nemici e' **quello che c'e' in questo momento**, letto adesso
	# dalla scena e non scritto qui: un 200 hardcoded passerebbe anche con la HUD
	# scollegata dall'orda, e fallirebbe con la HUD collegata quando l'orda e'
	# diversa -- cioe' passerebbe e fallirebbe per motivi che non sono il motivo.
	var horde = arena.get_node("Horde")
	var vivi: int = horde.count
	arena.call("_process", 0.0)
	h.check(vivi > 0, "la scena deve avere nemici vivi quando la HUD viene alimentata")
	h.check(hud.enemy_text().contains(str(vivi)),
		"la HUD alimentata dalla scena deve mostrare i %d nemici vivi dell'orda vera: \"%s\""
			% [vivi, hud.enemy_text()])
	h.check(hud.weapon_state_text().contains("DMG"),
		"la HUD alimentata dalla scena deve mostrare lo stato dell'arma vera: \"%s\"" % hud.weapon_state_text())

	# E adesso pilotata a mano, per i valori che la scena non produce da sola.
	hud.set_state(12.0, 100.0, 345, "DMG 10.0 every 0.35s", 200, 3)
	h.near(hud.health_ratio(), 0.12, 0.001, "la barra delle vite deve seguire i dati")
	h.check(hud.score_text().contains("345"), "il punteggio deve comparire nella HUD: \"%s\"" % hud.score_text())
	h.check(hud.enemy_text().contains("200"), "i nemici vivi devono comparire nella HUD: \"%s\"" % hud.enemy_text())
	h.check(hud.weapon_state_text().contains("DMG"), "lo stato dell'arma deve comparire nella HUD: \"%s\"" % hud.weapon_state_text())
	h.eq(hud.level, 3, "il livello deve arrivare alla HUD")

	# Vita a zero e vita negative: la barra e' un valore, non un'etichetta.
	hud.set_state(-5.0, 100.0, 0, "-", 0, 1)
	h.near(hud.health_ratio(), 0.0, 0.001, "vite negative non possono dare una barra negativa")

	# E `max_hp` a zero non deve dividere per zero.
	hud.set_state(50.0, 0.0, 0, "-", 0, 1)
	h.finite(hud.health_ratio(), "con max_hp a zero il rapporto vite resta un numero")

# --- 7. Il criterio n. 4, sull'orda vera ---------------------------------------

## Il tetto del criterio n. 4, in unita' di spostamento.
const KNOCKBACK_MIN := 0.3
## Il passo di simulazione. Uno solo per tutto il file: uno spostamento misurato
## con passi diversi non e' uno spostamento, e confronto con il test di -gameplay
## solo se il passo e' lo stesso.
const DT := 1.0 / 60.0
## La finestra e' **quella di `tests/test_gameplay.gd`**: 5 passi di durata fissa,
## misurati sulla posizione. Confronto e non casualita': se le due finestre
## divergessero, il numero di quel test e questo non sarebbero paragonabili e il
## primo non potrebbe fare da riferimento al secondo.
const KNOCKBACK_FRAMES := 5
## Frame di assestamento prima di sparare. Servono a far convergere la velocita'
## del nemico a regime: il suo tempo caratteristico e' `1/ACCEL` = 0.125 s.
const SETTLE_FRAMES := 60
## Tetto di frame perche' il colpo arrivi. A 26 m/s e 12 m di distanza bastano ~18
## frame: 240 e' un margine che non maschera un colpo che non parte.
const FIRE_FRAMES := 240
## Passi **dopo** l'impatto, senza piu' spari. Con `pierce` a 3 il proiettile
## continua a volare: e' la finestra in cui una guardia assente ripeterebbe il
## danno sullo stesso nemico.
const AFTER_HIT_FRAMES := 30
## Lontananza minima del nemico dal player quando nasce, in metri. Deve reggere
## l'assestamento (60 frame a 6.6 m/s sono 6.6 m persi) e il viaggio del
## proiettile senza mai entrare nella zona d'arrivo di `src/sim/enemy.gd`, dove il
## nemico insegue a meta' velocita' e la previsione sotto non vale piu'.
const MIN_SPAWN_DISTANCE := 14.0
## Distanza di partenza **imposta** dal test (vedi `_solo_enemy`): e' il punto in
## cui i due vincoli si incontrano, e i due sono letti, non indovinati.
##   - sotto `SPAWN_DISTANCE` non si puo' scendere: sotto `MIN_SPAWN_DISTANCE` il
##     runner entra nella zona d'arrivo durante i 60 frame di assestamento e la
##     previsione di `_predicted_moved` non vale piu';
##   - sopra non si puo' salire: l'arma mira solo entro `ACQUIRE_RADIUS` = 26 m
##     (`src/weapons/weapon_base.gd`), quindi a 46 m di raggio un nemico libero di
##     nascere dove vuole puo' restare **fuori portata di mira** e il colpo non
##     parte mai. 20 m sta dentro con 6 m di margine sotto il tetto di mira e
##     lascia al runner 13,4 m dopo l'assestamento, ben sopra `ARRIVE_RADIUS` = 3 m.
const SPAWN_DISTANCE := 20.0
## Passi di attesa che il test concede a -orda per fare **nascere** il nemico di
## prova con `population = 1`. Il riempimento e' graduale (m4) a 8 crediti/s, cioe'
## un credito ogni 7,5 passi: 240 passi (4 s) sono **trenta volte** il necessario,
## e il numero non serve a mascherare un'orda che non riempie — se il nemico non
## arriva, la sezione lo dice e restituisce un retto vuoto invece di proseguire
## con `kinds[0]` su un array vuoto, che e' un crash e non un fallimento.
const SPAWN_STEPS_MAX := 240
## Specie per cui il knockback **deve** funzionare: runner e grunt, che sono
## l'80% dell'onda (`Spawner.KIND_WEIGHTS`) e hanno resistenza 0 e 0.20.
const KINDS_MUST_KNOCK := [0, 1]
## Specie misurate ma **non** sottoposte al tetto: brute e boss hanno resistenza
## 0.55 e 0.90, sono cioe' **progettati** per non volare sotto i colpi. Il numero
## c'e' ed e' stampato, ma se la soglia di 0.3 debba valere anche per loro e' una
## domanda di piano, non di test: qui non si stringe l'asserzione per farla passare
## e non si allarga per farla fallire.
const KINDS_MEASURED := [2, 3]
## `ACCEL` e `SPEED_MAX` di `src/sim/enemy.gd`. Non sono campi dell'orda e non si
## possono leggere da qui: sono la costante di tempo del suo smorzamento e il
## tetto della sua velocita'. Servono solo alla previsione in `_predicted_moved`,
## e la previsione **controllata contro la misura**: se il codice di -orda
## cambiasse questi due numeri, l'asserzione di combaciazione qui sotto fallirebbe
## invece di passare in silenzio.
const REAL_ACCEL := 8.0
const REAL_SPEED_MAX := 18.0

## Il criterio n. 4 ("il player spara e uccide: danno una volta sola, knockback >=
## 0.3 unita'") finora l'aveva verificato solo `tests/test_gameplay.gd`, e
## **contro un orda finta**: una `FakeHorde` con `drag = 0.18` e `chase_speed =
## 3.0` scritti a mano, e una `KNOCKBACK` alzata da 14 a 18 perche' con quel finto
## si misuravano 0.2985 unita', sotto il tetto. Una messa a punto tarata su una
## fisica che non e' quella del gioco.
##
## Qui non c'e' niente di finto: l'arma chiama `Game.nearest_enemy` per mirare, il
## proiettile viaggia e chiama `Game.damage_enemy`, e il nemico che si sposta e' un
## record di `src/sim/horde.gd` mosso dalla sua stessa `step()` con le sue vere
## tabelle di specie.
##
## Il perimetro di questa sezione e' tutto di -gameplay e -orda, che non si tocca:
## qui si guidano i loro metodi pubblici (`step`, `damage_enemy`, `pool.reset`,
## `weapon.cooldown`, ...) e si misura il risultato.
func _criterion_4(h, arena: Node3D, game: Node) -> void:
	var horde = arena.get_node("Horde")
	var player = arena.get_node("Player")
	var weapon = player.get("weapon")
	if not h.check(weapon != null, "il player della scena deve avere un'arma"):
		return
	var pool = weapon.pool
	if not h.check(pool != null, "l'arma della scena deve avere il suo pool di proiettili"):
		return
	# Il player smette di leggere la tastiera e si guida a mano: altrimenti
	# l'input della testiera finirebbe dentro la misura.
	player.drive_manually()
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO

	# I valori toccati sono **campi**: salvati e rimessi a posto sempre, anche se
	# un'asserzione qui dentro fallisce, perche' `check()` non interrompe.
	var population_before: int = horde.population
	var respawn_before: bool = horde.auto_respawn
	var fire_before: float = weapon.fire_interval
	var pierce_before: int = weapon.pierce
	# Un colpo solo per tutta la sezione: qui si prova che **quel** proiettile non
	# ripete il danno, non che l'arma smetta di sparare.
	weapon.fire_interval = 10.0

	var knockback: float = weapon.knockback
	var damage: float = weapon.damage
	h.positive(knockback, "l'arma deve avere un knockback non nullo")
	h.positive(damage, "l'arma deve avere un danno non nullo")

	# ## DA m10 L'EVITAMENTO E' SPENTO **PER LA MISURA**, e si dichiara perche'
	#
	# Il criterio n. 4 qui dentro e' di m1 e misura **l'impulso e la sua
	# attenuazione**: `v += (wanted - v) * min(1, dt * ACCEL)`. Quel modello
	# presuppone che `wanted` — l'inseguimento — sia **una direzione costante**,
	# e fino a m10 lo era. Da m10 l'orda insegue lungo il campo di percorrenza:
	# quando un disco e' di mezzo, la direzione **ruota** dentro la finestra dei
	# 30 frame, e cio' che si misurerebbe non e' piu' l'attenuazione dell'impulso
	# ma la somma di attenuazione e sterzata. Non e' un difetto di -orda: e' il
	# criterio che e' nato in un mondo senza muri e che misurerebbe la cosa
	# sbagliata in un mondo con i muri.
	#
	# Quindi l'ambiente di misura viene **controllato**, come gli altri tre che
	# questa sezione gia' controlla (un nemico solo, una specie sola, il player
	# spostato a mano). `horde.flow_field` e' un campo **pubblico e dichiarato** di
	# -orda (la sua superficie di m10: `obstacles`, `flow_field`, `flow_problem`,
	# `flow_rebuilds`) e il suo `null` e' uno stato previsto, non un errore:
	# `src/sim/enemy.gd` scrive che con `flow = null` «questo passo e' identico a
	# quello di prima della milestone 10». Quindi qui non si tocca nessun file di
	# -orda e non si scrive nessun record a mano: si mette un campo suo a `null`,
	# lo si asserisce spento **durante** la misura, e lo si rimette.
	#
	# Cosa NON e': non e' allargare un tetto per farlo passare. I tre numeri di
	# sotto — `>= 0.9 * chase`, il tetto di 0,3 unita' e la combaciare con
	# `_predicted_moved()` — restano gli stessi di prima, con gli stessi denti.
	var campo = horde.get("flow_field")
	var campo_attivo: bool = bool(horde.call("flow_active"))
	horde.set("flow_field", null)
	var campo_spento: bool = not bool(horde.call("flow_active"))
	h.check(campo_spento,
		"la misura del knockback deve girare con l'evitamento spento: `flow_active()` dice che il campo di percorrenza e' ancora attivo, quindi la previsione a direzione costante non vale")

	var rows: Array[String] = []
	var charges: Array[String] = []
	for kind in KINDS_MUST_KNOCK + KINDS_MEASURED:
		var r := _knockback_of_kind(h, horde, player, weapon, pool, kind)
		if r.is_empty():
			continue
		var moved: float = r["moved"]
		var name := str(r["name"])
		rows.append("%s %.4f" % [name, moved])
		charges.append("%s %.4f/%.4f" % [name, r["measured_charge"], r["full_charge"]])
		if KINDS_MUST_KNOCK.has(kind):
			h.check(moved >= KNOCKBACK_MIN,
				"knockback >= %.1f unita' entro %d frame sul %s vero: misurate %.4f"
					% [KNOCKBACK_MIN, KNOCKBACK_FRAMES, name, moved])
			h.check(float(r["away_dot"]) > 0.0,
				"il %s deve essere spinto lontano dal player, non verso (dot %.4f, "
				% [name, r["away_dot"]]
				+ "distanza %.2f -> %.2f m, velocita' dopo l'impatto %.2f m/s, "
				% [r["d_before"], r["d_after"], r["v_after_hit"]]
				+ "spostamento %.4f)" % moved)
			# La misura deve combaciare con la previsione ricavata dalla fisica
			# vera di -orda: e' la prova che i tre numeri che il vertice chiede
			# sono quelli del codice in gioco e non una ricostruzione del test.
			h.near(moved, float(r["predicted"]), 0.01,
				"lo spostamento misurato sul %s deve combaciare con la previsione "
				% name
				+ "(%.4f dalla sua ACCEL %.1f e dal suo tetto %.1f m/s): se la "
				% [r["predicted"], REAL_ACCEL, REAL_SPEED_MAX]
				+ "fisica di src/sim/enemy.gd e' diversa, e' qui che si vede")

	# Riporta e lascia l'orda com'era: i campi toccati tornano ai valori veri e
	# un passo lascia all'orda il tempo di riprendere. **Anche il campo di
	# percorrenza**, che la sezione aveva spento: una sezione che lascia il mondo
	# senza muri dopo aver misurato su di esso costruirebbe, per tutto il resto
	# del test, una scena che non e' quella vera.
	horde.set("flow_field", campo)
	h.check(bool(horde.call("flow_active")) == campo_attivo,
		"la sezione knockback deve rimettere a posto il campo di percorrenza: era attivo %s e ora %s"
			% [campo_attivo, bool(horde.call("flow_active"))])
	horde.population = population_before
	horde.auto_respawn = respawn_before
	weapon.fire_interval = fire_before
	weapon.pierce = pierce_before
	horde.step(DT)
	# Qui il numero di vivi **non** e' un numero che questo test possa asserire:
	# la sezione ha appena ridotto l'orda a un nemico solo e un solo passo non
	# la riporta a 200, perche' da m4 il riempimento non avviene in un passo (ed
	# e' proprio questo il difetto che m4 chiude). Si asserisce invece che la
	# sezione abbia rimesso a posto quello che ha toccato e che la scena resti
	# coerente: e' la stessa domanda di prima, senza la cifra della curva dentro.
	h.eq(horde.population, population_before,
		"la sezione knockback deve rimettere a posto population")
	h.eq(horde.auto_respawn, respawn_before,
		"la sezione knockback deve rimettere a posto auto_respawn")
	h.eq(horde.transforms.size(), horde.count,
		"dopo la sezione knockback transforms resta allineata a count")
	h.eq(horde.colors.size(), horde.count,
		"dopo la sezione knockback colors resta allineata a count")
	h.check(horde.count > 0,
		"la sezione knockback deve lasciare l'orda viva, non vuota")

	print("criterio 4, knockback reale: %s unita' in %d frame (tetto %.1f)"
		% [", ".join(rows), KNOCKBACK_FRAMES, KNOCKBACK_MIN])
	print("criterio 4, fisica reale: KNOCKBACK %.1f m/s dall'arma, inseguimento %s m/s, impulso tenuto %s"
		% [knockback, _chase_list(horde), ", ".join(charges)])
	print("criterio 4, attenuazione: -orda non ha un 'drag' ma un ACCEL di %.1f 1/s "
		% REAL_ACCEL
		+ "(tempo caratteristico %.3f s) e un tetto SPEED_MAX di %.1f m/s; "
		% [1.0 / REAL_ACCEL, REAL_SPEED_MAX]
		+ "lo smorzamento e' cioe' quello di primo ordine v += (wanted - vel) * min(1, dt*ACCEL)")

## Un nemico solo, dell'orda vera, della specie `kind`.
##
## **Un** nemico perche' con 200 la misura non misurerebbe niente: la forza di
## separazione dell'orda vale 11 m/s ed e' piu' grande dell'inseguimento di
## qualsiasi specie, quindi dentro una folla lo spostamento di un singolo nemico e'
## rumore di folla, non knockback. Il nemico nasce dal percorso vero di -orda
## (`population = 1` e un passo della sua `step()`, che chiama `_top_up` ->
## `_spawn_one` -> `Spawner.spawn_point`): nessun record scritto a mano.
func _knockback_of_kind(h, horde, player, weapon, pool, kind: int) -> Dictionary:
	_solo_enemy(h, horde, player, weapon, kind)
	if horde.count != 1:
		return {}

	var name := str(horde.kind_name(0))
	var chase: float = horde.speed_of_kind(kind)
	h.positive(chase, "il %s deve avere una velocita' d'inseguimento" % name)

	# Prima di ogni misura il nemico deve essere **a regime**: la sua velocita' di
	# inseguimento ci mette `1/ACCEL` = 0.125 s a arrivarci, e leggere la
	# velocita' di un nemico appena nato significa leggere zero e non sapere niente
	# di quello che l'orda accetterebbe al suo posto.
	for i in SETTLE_FRAMES:
		horde.step(DT)

	# Quanto dell'impulso l'orda **tiene davvero**: `damage_enemy` somma
	# `knockback * (1 - KNOCKBACK_RESIST[kind])` e la resistenza e' di -orda.
	# La misuro invece di leggerla, perche' le sue tabelle sono `static var` di uno
	# script che non e' mio: e' la sonda `damage_enemy(0, 0.0, ...)`, che non
	# uccide niente e non muove niente tranne la velocita'.
	var away := _away_dir(horde, player)
	var settled: Vector3 = horde.velocities[0]
	var probed: bool = horde.damage_enemy(0, 0.0, away * weapon.knockback)
	var after_probe: Vector3 = horde.velocities[0]
	# Quanto dell'impulso e' finito davvero nella velocita', in m/s. E' il numero
	# che spiega perche' due specie con lo stesso colpo si spostano in modo diverso.
	var charged: float = (after_probe - settled).length()
	var kept: float = 0.0
	if weapon.knockback > 0.0001:
		kept = charged / weapon.knockback
	h.check(not probed, "una sonda con danno 0 non deve uccere nessuno")
	h.check(kept > 0.0 and kept <= 1.001,
		"il %s deve tenere una parte dell'impulso fra 0 e 1: tenuto %.3f" % [name, kept])
	h.check(absf(settled.dot(away)) >= 0.9 * chase,
		"il %s deve essere a regime e inseguire verso il player a %.1f m/s: misurati %.3f"
			% [name, chase, absf(settled.dot(away))])
	# La sonda e' una perturbazione: si rimette a posto la velocita' e basta. Un
	# passo solo, non un assestamento intero: `damage_enemy` non sposta il nemico,
	# e rimettere la velocita' rimette lo stato. Un secondo assestamento intero
	# qui dentro costerebbe 6.6 m al runner, che a quel punto e' addosso al player e
	# la misura non vale piu' niente.
	horde.velocities[0] = settled
	horde.timers[0] = 0.0
	horde.step(DT)

	# Il colpo, per il percorso vero: `player.step` -> `weapon.step` ->
	# `Game.nearest_enemy` per mirare, `Game.spawn_projectile` per partire, e nel
	# pool il segmento del proiettile contro `horde.transforms` e
	# `Game.damage_enemy` per colpire.
	pool.reset()
	weapon.pierce = 3
	weapon.cooldown = 0.0
	var hp_before: float = horde.hp[0]
	var frames := 0
	while frames < FIRE_FRAMES and horde.hp[0] >= hp_before:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
		frames += 1
	if not h.check(horde.hp[0] < hp_before,
			"il colpo sul %s non e' arrivato in %d frame (HP %.1f)" % [name, FIRE_FRAMES, hp_before]):
		return {}

	# **Danno una volta sola**: gli HP scendono di esattamente un colpo.
	var hp_after: float = horde.hp[0]
	h.near(hp_after, hp_before - weapon.damage, 0.0001,
		"il %s deve prendere UN colpo e non uno a frame: HP %.1f -> %.1f, un colpo fa %.1f"
			% [name, hp_before, hp_after, weapon.damage])

	# **La misura del criterio**: posizione subito dopo il frame d'impatto, poi
	# esattamente `KNOCKBACK_FRAMES` passi di orda di durata fissa, e la **delta di
	# posizione**. Il modulo dell'impulso non e' la misura (piano §5.2).
	#
	# Sta QUI e non dopo la finestra di nessun secondo colpo: l'impulso ha un tempo
	# caratteristico di 0.125 s, quindi dopo trenta frame di ordine e' gia' sparito
	# e quello che si misurerebbe e' l'inseguimento del nemico verso il player, non
	# il knockback. (E' successo, e la difesa era che il tempo caratteristico si
	# dichiara in testa al file invece di essere indovinato qui.)
	var before: Vector3 = horde.transforms[0]
	var v_at_before: Vector3 = horde.velocities[0]
	var d_before: float = _flat(before - player.global_position).length()
	for i in KNOCKBACK_FRAMES:
		horde.step(DT)
	var after: Vector3 = horde.transforms[0]
	var moved: float = before.distance_to(after)
	var d_after: float = _flat(after - player.global_position).length()
	var away_dot: float = _flat(after - before).dot(_flat(away))
	h.finite(moved, "lo spostamento del %s e' finito" % name)
	# Sotto `ARRIVE_RADIUS` il nemico rallenta perche' e' arrivato addosso al
	# player: la previsione sotto presuppone l'inseguimento a pieno regime, quindi
	# la misura e la previsione non sarebbero piu' confrontabili.
	h.check(d_before >= 3.5,
		"il %s deve essere colpito a pieno inseguimento: era a %.2f m dal player, "
		% [name, d_before]
		+ "sotto i 3.5 m il nemico rallenta e la previsione non vale")

	# E non ricomincia: il proiettile continua a volare perche' ha ancora pierce,
	# quindi questi frame sono la finestra in cui una guardia assente spammerebbe.
	for i in AFTER_HIT_FRAMES:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
	h.near(horde.hp[0], hp_after, 0.0001,
		"nessun secondo colpo sul %s nei %d frame dopo l'impatto: HP %.1f -> %.1f"
			% [name, AFTER_HIT_FRAMES, hp_after, horde.hp[0]])

	return {
		"name": name,
		"moved": moved,
		"away_dot": away_dot,
		"d_before": d_before,
		"d_after": d_after,
		"v_after_hit": v_at_before.length(),
		# Quanto impulso e' arrivato addosso al nemico, e quanto gliene avevano
		# dato. Il rapporto e' la resistenza di -orda, misurata e non letta.
		"measured_charge": charged,
		"full_charge": weapon.knockback,
		"predicted": _predicted_moved(settled, away, charged),
	}

## Riduce l'orda vera a **un** nemico della specie `kind`. Lo svuota con
## `damage_enemy` (l'API di -orda), abbassa `population` e lascia che sia la sua
## `step()` a rifarlo nascere: nessun record scritto a mano.
##
## ## Perche' da m9 la distanza di partenza e' **imposta**, e non piu' subita
##
## Prima la misura accettava **qualsiasi** spawn a piu' di 14 m dal giocatore e,
## quando il nemico nasceva troppo addosso, riprovava con un altro spawn. Con
## l'arena a 46 m l'arbitrio e' andato dalla parte opposta: `Spawner.spawn_point`
## puo' depositare il nemico a 45 m dal centro, `ACQUIRE_RADIUS` dell'arma e'
## 26 m, quindi l'arma **non ha un bersaglio da mirare** e il colpo non parte
## mai: il boss (inseguimento 1,7 m/s) non arrivava addosso al giocatore dentro
## la finestra di 240 frame e la sezione ha detto FAIL. Con l'arena a **60 m** il
## caso e' identico e peggiore (spawn possibile fino a 59 m dal centro): percio'
## questa correzione **non e' stata rimossa** e il numero non sale.
##
## La correzione non e' allungare la finestra (sarebbe allargare un tetto per far
## passare) e non e' muovere il nemico (sarebbe scrivere un record a mano):
## qui viene spostato **il giocatore**, che e' un nodo che questo test gia'
## guidava a mano (`player.position = Vector3.ZERO`), e il nemico resta quello
## che il percorso vero di -orda ha creato. La misura del knockback non
## dipende dalla distanza di partenza: dipende dal colpo, dalla specie e dalla
## fisica, e quelle tre restano vere.
func _solo_enemy(h, horde, player, weapon, kind: int) -> void:
	horde.population = 0
	_kill_all(h, horde)
	horde.population = 1
	# Il riempimento e' **graduale** (m4): `Run.SPAWN_RATE` = 8/s accoda un
	# credito di spawn ogni 7,5 passi, quindi un passo solo non fa nascere
	# nessuno e `kinds` sarebbe ancora vuoto. Si aspetta il nemico vero con un
	# tetto dichiarato, non con un numero di tentative a caso: se non arriva, la
	# sezione lo dice e smette.
	var passi := 0
	while horde.count == 0 and passi < SPAWN_STEPS_MAX:
		horde.step(DT)
		passi += 1
	if not h.check(horde.count == 1,
			"l'orda deve essere scesa a un nemico solo: dopo %d passi e population 1 ci sono %d vivi"
				% [passi, horde.count]):
		return
	# `horde.kinds` e' un `PackedInt32Array` (lo e' diventato in m8) e scrivere
	# `horde.kinds[0] = kind` attraverso una base non tipizzata viene **rifiutato
	# a runtime** ("Invalid assignment of index '0' ..."), non fallito: quindi qui
	# si passa da una copia locale dichiarata con il suo tipo e si rimette dentro.
	# Il nemico resta quello nato dal percorso vero di -orda; cambia solo la
	# specie che si misura, che e' la variabile della misura.
	var kinds: PackedInt32Array = horde.kinds
	kinds[0] = kind
	horde.kinds = kinds
	horde.velocities[0] = Vector3.ZERO

	# Il giocatore a `SPAWN_DISTANCE` dal nemico, lungo la direzione che lo
	# riporta verso il centro dell'arena: cosi' il punto di partenza e' dentro il
	# campo per qualunque posizione di spawn, anche le piu' esterne.
	var pos: Vector3 = horde.transforms[0]
	var dal_centro := Vector2(pos.x, pos.z)
	var dir := Vector2(1.0, 0.0)
	if dal_centro.length() > 0.001:
		dir = dal_centro.normalized()
	player.global_position = pos - Vector3(dir.x, 0.0, dir.y) * SPAWN_DISTANCE
	player.velocity = Vector3.ZERO

	var d := _flat(horde.transforms[0] - player.global_position).length()
	h.near(d, SPAWN_DISTANCE, 0.001,
		"il nemico di prova deve partire a %.1f m dal player: lo spawn di -orda e' "
			% SPAWN_DISTANCE
			+ "casuale su un disco da %.0f m e il colpo non puo' arrivare oltre %.0f m"
			% [horde.arena_radius, _acquire_radius(weapon)])
	h.check(d <= _acquire_radius(weapon),
		"il nemico di prova deve essere a portata di mira: %.1f m contro %.1f m di %s"
			% [d, _acquire_radius(weapon), "ACQUIRE_RADIUS"])
	h.check(horde.count == 1,
		"l'orda deve essere scesa a un nemico solo, ne' sono rimasti %d" % horde.count)

## Il raggio di acquisizione dell'arma, **letto dal suo codice** (e' di
## -gameplay). Serve a dichiarare `SPAWN_DISTANCE`: se la smessa di prendere a 26
## m, la distanza di partenza va abbassata e la porta deve dirlo qui invece di
## fallire piu' avanti con "il colpo non e' arrivato", che non dice perche'.
## `-1.0` se la costante non c'e' piu': il controllo viene saltato **e detto**.
func _acquire_radius(weapon) -> float:
	var scr = weapon.get_script()
	if scr == null or not scr.has_method("get_script_constant_map"):
		return -1.0
	var map: Dictionary = scr.get_script_constant_map()
	if not map.has("ACQUIRE_RADIUS"):
		return -1.0
	return float(map["ACQUIRE_RADIUS"])

## Lo spostamento che la fisica vera di `src/sim/enemy.gd` prevede per questi
## numeri, calcolato a passi discreti con la sua stessa formula:
## `vel += (wanted - vel) * min(1, delta * ACCEL)` e il tetto `SPEED_MAX`.
##
## Non serve a misurare: serve a **controllare** la misura. Se i due combaciano,
## i tre numeri che il vertice chiede (`KNOCKBACK`, inseguimento, attenuazione)
## sono quelli del codice in gioco; se non combaciano, la differenza e' la prova
## che la fisica reale non e' quella che il test crede.
##
## `at_impact` e' la velocita' subito prima che il colpo la tocchi: quella a
## regime piu' l'impulso, perche' e' cosi' che la costruisce `damage_enemy`.
## `impulse_dir` e' la direzione dell'impulso; `chase_vec` la velocita' a regime.
func _predicted_moved(chase_vec: Vector3, impulse_dir: Vector3, impulse: float) -> float:
	var alpha := minf(1.0, DT * REAL_ACCEL)
	var wanted := chase_vec.dot(impulse_dir)
	var vel := wanted + impulse
	# Il frame d'impatto: l'ho gia' contato nella posizione `before`, quindi qui
	# si simula solo per arrivare alla velocita' da cui partono i frame misurati.
	vel = clampf(vel + (wanted - vel) * alpha, -REAL_SPEED_MAX, REAL_SPEED_MAX)
	var x := 0.0
	for i in KNOCKBACK_FRAMES:
		vel = clampf(vel + (wanted - vel) * alpha, -REAL_SPEED_MAX, REAL_SPEED_MAX)
		x += vel * DT
	return absf(x)

## La velocita' d'inseguimento reale di ogni specie, dall'orda viva. E' il numero
## che nella `FakeHorde` di -gameplay era un campo scritto a mano.
func _chase_list(horde) -> String:
	var parts: Array[String] = []
	for kind in KINDS_MUST_KNOCK + KINDS_MEASURED:
		parts.append("%.1f" % horde.speed_of_kind(kind))
	return "/".join(parts)

## La direzione di spinta: dal player verso il nemico, sul piano. E' la direzione
## del proiettile, e quindi quella che `damage_enemy` riceve come knockback.
func _away_dir(horde, player) -> Vector3:
	var d := _flat(horde.transforms[0] - player.global_position)
	return d.normalized() if d.length() > 0.001 else Vector3.FORWARD

## Sul piano XZ: la `y` qui non c'entra, l'arena e' piatta e il nemico non vola.
func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

# --- 8. Milestone 3: la disposizione dell'orda e' una funzione del seme ---------
#
# ## Il debito che questa sezione chiude
#
# `src/sim/spatial_grid.gd:32-39` dichiara che la densita' che fa traboccare un
# secchiello e' stata misurata sull'orda **isolata** (`BUCKET_SLOTS` 12 -> 32 sul
# picco di 19). Ma l'orda della **scena vera** gira con `seed = 0` e nessuna
# asserzione guardava la sua `grid_overflowed()`: il traboccamento vero poteva
# accadere e nessuno lo avrebbe saputo. Non era un test che fallisce a caso, era
# un test che non esisteva.
#
# La causa non era la casualita', era un buco di API: `horde.seed` era un campo
# pubblico documentato «0 = casuale, un numero = riproducibile», ma `_build()` lo
# leggeva **una volta sola** dentro `_ready()`, e sulla scena vera l'orda la crea
# `scenes/arena_main.tscn`: nessun codice esterno poteva scriverlo prima che la
# disposizione fosse gia' nata. Il campo sembrava la riproducibilita' e sulla scena
# vera era irraggiungibile. `horde.reseed(s)` chiude il buco.
#
# ## La semantica che questo test usa, e come l'ho letta
#
# `horde.worst_bucket()` e' dichiarato in `src/sim/horde.gd` come **il picco del
# frame (griglia) appena ricostruito**, cioe' NON un massimo storico: dentro
# `spatial_grid.gd` il contatore e' un massimo storico che si azzera solo in
# `setup()`, e `_rebuild_grid()` lo azzera a ogni ricostruzione perche' altrimenti,
# dopo un `reseed`, il numero direbbe ancora il picco della disposizione
# **precedente** invece di quella appena scritta.
#
# Quindi qui: la lettura avviene **subito dopo `reseed`**, che per contratto (punto
# 5) ricostruisce gia' la griglia, e il numero che ne esce e' il picco di **quel**
# seme e non un massimo accumulato. Se un domani la semantica tornasse storica, le
# letture di questo sweep continuerebbero a essere valide ma monotone: ogni valore
# sarebbe il massimo di tutti i precedenti. Il numero di semi traboccati e la
# somma delle posizioni, invece, resterebbero gli stessi. La differenza si vede,
# quindi non e' una scelta invisibile.
#
# ## Perche' `BUCKET_SLOTS` non e' il tetto
#
# Il tetto NON puo' essere 32: `insert()` aggiorna il contatore solo con
# `n < BUCKET_SLOTS`, quindi `worst_bucket() <= 32` e' una tautologia che non puo'
# fallire. Il segnale che il traboccamento e' avvenuto e' `grid_overflowed()`, e la
# **misura di densita'** va confrontata con un tetto **proprio, sotto 32**, derivato
# da una misura. E' quello che c'e' sotto.

## I tre membri che `src/core/contracts.gd` dichiara congelati nella sezione
## "Supersficie di milestone 3". Non sono API registrate: sono metodi pubblici
## dell'orda della scena vera, e il contratto li dichiara perche' m3 e' la prima
## onda che mette due foglie sullo stesso oggetto di simulazione.
const M3_SURFACE := ["reseed", "worst_bucket", "grid_overflowed"]

## I due semi della riproducibilita'. Due numeri lontani e non consecutivi: con
## `SEED_A` e `SEED_A + 1` un `reseed` che ignorasse il seme e producesse sempre
## la stessa disposizione passerebbe lo stesso, perche' i due semi si somigliano
## piu' di quanto credibile. `7311` non ha nessun rapporto con `4242`.
const SEED_A := 4242
const SEED_B := 7311

## Quanti semi nello sweep, e come sono scelti. `SWEEP_COUNT` semi a passo
## `SWEEP_STEP` da `SWEEP_FIRST`: 24 semi fra 1 e 231, cioe' la stessa banda che
## `tests/test_gameloop.gd` aveva gia' percorso sull'orda isolata (semi 1..240),
## ma qui sul mondo vero.
##
## Il passo serve a coprire la banda, non a fare un campione fitto: ogni coppia
## di semi consecutivi **dello sweep** viene confrontata posizione per posizione e
## il risultato e' stampato sotto (misurato 23 coppie diverse su 23), quindi non
## si sta campionando ventiquattro volte la stessa disposizione. Il passo 1
## costerebbe il doppio delle query di griglia per coprire 24 semi su metta' banda.
const SWEEP_COUNT := 24
const SWEEP_FIRST := 1
const SWEEP_STEP := 10

## Tetto dichiarato di `worst_bucket()` sulla scena vera.
##
## ## m9: il tetto e' stato RIMISURATO, non alzato (criterio n. 5)
##
## L'arena e' passata da 56 m a **92 m** di diametro con gli stessi 200 nemici:
## stesso numero, disco 2,7 volte piu' grande, quindi **densita' calata**. Un
## tetto derivato a 28 m e' un tetto dichiarato su una misura che non e' piu'
## quella di oggi, e la regola di 1.2 e' che la costante si dichiara sulla
## misura: qui sotto ci sta la misura nuova e il numero che ne deriva.
##
## ## COME E' STATO DERIVATO (misura prima del numero)
##
## Sweep degli stessi 24 semi (1, 11, ..., 231), stessa banda, `population` al
## massimo dichiarato da -orda (200), sulla **scena vera** con il raggio nuovo:
##
##     worst_bucket a R=46 (oggi):  min 3, mediana 4, max 4; traboccati 0 su 24
##     worst_bucket a R=28 (misurato con il codice di -orda di oggi, prima di
##                           cambiare il raggio): min 5, mediana 6, max 8
##
## Il confronto e' il punto: sul disco 2,7 volte piu' grande il **massimo** e'
## sceso da 8 a 4, cioe' la densita' per cella da 4 m si e' dimezzata, che e'
## esattamente quello che la sonda di 1.12 aveva gia' visto sullo spazio libero
## (85,2% -> 94,6%). Nota storica dichiarata perche' non torni': il
## "min 4, mediana 5, max 7" scritto qui sotto nel 2026-10-12 **non si riproduce
## piu'** con il codice di -orda di oggi (che al vecchio raggio dà 5/6/8): quel
## numero appartiene a una disposizione che non e' piu' quella del gioco, e
## quindi non puo' piu' fare da base a nessun tetto.
##
## Il tetto e' **8**, e si deriva con **la stessa regola dei tre passi** usata a
## 28 m, cambiato solo il numero misurato:
##
##   1. base = 4, il **massimo misurato** (su 24 semi, 22 valgono 4 e 2 valgono
##      3: il massimo coincide con la mediana, e resta il massimo perche' un
##      tetto sulla mediana cadrebbe alla meta' dei semi, cioe' non piu' che
##      rumore). Non il minimo (3): cadrebbe appena la densita' torna alla norma.
##   2. margine dichiarato = **+4 slot**, invariato. L'escursione dell'intero
##      campione e' adesso di **1** slot (3 -> 4), quindi il margine e' quattro
##      volte l'escursione: era tre volte quella di allora (3 slot su un
##      margine di 4). Il tetto non e' tarato sul caso peggiore.
##   3. coerenza col codice: `BUCKET_SLOTS` = 32, e 8 ne lascia **24 slot** di
##      margine prima del punto in cui le query cadono davvero a scansione
##      lineare. Un balzo della densita' deve quindi essere di **quattro volte**
##      perche' questo tetto cada.
##
## **Perche' scende da 11 a 8 e non resta 11**: 11 era `7 + 4`, cioe' il massimo
## di allora piu' lo stesso margine. Il massimo di oggi e' 4, e `4 + 4 = 8`.
## Tenere 11 sarebbe stato alzare il tetto per far passare una misura che e'
## **scesa**, cioe' l'esatto opposto di quello che il criterio chiede.
##
## ## PERCHE' NON `BUCKET_SLOTS - 1`
##
## `spatial_grid.gd::insert` aggiorna il contatore solo con `n < BUCKET_SLOTS`,
## quindi `worst_bucket()` **non puo' superare 32**: un tetto a 31 non puo' mai
## fallire e non starebbe misurando niente. Il segnale che il traboccamento
## e' avvenuto e' `grid_overflowed()`, ed e' un'asserzione separata qui sotto.
##
## ## I DENTI SONO STATI PROVATI, DUE VOLTE, E POI RIMOSSI
##
## Protocollo di m2-w3: una prova che non sa fallire non e' un'asserzione. Il
## blocco che forza il traboccamento **non e' in questo file**: fu rimosso dopo.
## Quello che faceva, con la sola API di massa che il piano dichiara
## (`count`/`transforms`/`colors`, `horde.gd:94-101`), era scrivere posizioni e un
## `count` piu' grande dentro una **sola cella da 4 m** e far ricostruire la griglia
## chiamando `nearest_enemy_index(...)`, che passa da `_ensure_grid()`. `count`,
## `transforms` e `colors` venivano salvati e rimessi **sempre**: `check()` non
## interrompe, quindi un'asserzione fallita a meta' avrebbe lasciato l'orda sporca
## per le sezioni successive.
##
## 1. **Tutti i 200 nemici in una cella** -> `worst_bucket` 32, `grid_overflowed()`
##    a vero. Le tre asserzioni di 8.2 hanno detto **FAIL** una per una
##    ("nessun seme deve traboccare...", "deve stare sotto il tetto dichiarato
##    11: massimo misurato 32", e il controllo di semantica che ha visto che il
##    seme 1 non riproduceva piu' 32). Uscita 1.
## 2. **12 nemici in una cella** -> `worst_bucket` 13 e `grid_overflowed()` resta
##    **falso**. E' la prova che conta per il tetto di densita': l'asserzione del
##    traboccamento era green e **quella del tetto ha detto FAIL** lo stesso.
##    Senza questo, il tetto 11 potrebbe essere portato dalla sola segnalazione di
##    traboccamento e non starebbe misurando la densita'. Uscita 1.
##
## ## I DENTI RIFATTI SU m9, PERCHE' IL TETTO E' CAMBIATO (criterio n. 6)
##
## Una costante nuova ha bisogno dei suoi denti, non eredita quelli del numero
## vecchio: il blocco qui sopra provava il tetto **11**, e contro 8 quegli stessi
## numeri non dimostrerebbero piu' niente. Quindi il 2026-10-13 il tetto e' stato
## portato a **8** e i due denti sono stati rifatti sul tetto nuovo, con numeri
## che stanno **fra** la misura e il tetto (e non al di la', che provano solo
## l'overflow e non la densita'):
##   1. **6 nemici in una cella** -> `worst_bucket` 6: sotto il tetto 8, sopra la
##      mediana 4, e `grid_overflowed()` resta falso -> l'asserzione del tetto e'
##      quella che reagisce, e reagisce a 6 e non a 32.
##   2. **9 nemici in una cella** -> `worst_bucket` 9: sopra il tetto 8, e
##      `grid_overflowed()` resta ancora falso -> e' il numero che dimostra che il
##      tetto sta guardando la densita' e non la saturazione del secchiello.
## ## 5.9 `GRID_CEILING = 8` IL 2026-10-14, E PERCHE' **RESTA** A 60 m
##
## Il raggio e' passato a **60 m** (piano 1.14-quinque) e la densita' e' scesa
## ancora: il disco e' 1,70 volte piu' grande di quello da 46 m con gli stessi
## 200 nemici. I due numeri, entrambi misurati:
##
##     disposizione iniziale, 46 m    picco 4
##     disposizione iniziale, 60 m    picco 3
##     a regime con 200 addensati, 60 m   picco 20 (su 32 slot, nessun traboccamento)
##
## Il tetto **non scende** e la ragione non e' che sia giusto cosi': e' che la
## misura su cui e' stato derivato (sweep di 24 semi a `population` = 200, che
## questa sezione stampa: min 2, mediana 3, **max 4**) non e' cambiata nella sua
## parte che conta, e `4 + 4 = 8`. Abbassarlo perche' la mediana e' scesa sarebbe
## spostare un tetto per far passare una misura che e' **scesa**: l'esatto
## opposto di quello che il criterio chiede. E il picco di 20 a regime resta
## molto sotto i 32 slot di `BUCKET_SLOTS`, quindi nessun traboccamento.
const GRID_CEILING := 8

## Quante posizioni devono cambiare fra due semi **diversi**: il criterio n. 2 di
## m3 dice "seme diverso -> diversi", e senza un numero minimo quella frase
## accetterebbe anche una disposizione fissa con due nemici spostati.
##
## ## COME E' STATO DERIVATO (misura prima del numero)
##
## Misurato con `SEED_A` = 4242 contro `SEED_B` = 7311: **200 posizioni diverse
## su 200**. La disposizione iniziale e' ad anelli e l'angolo di ogni nemico esce
## da `_rng`, quindi con un altro seme si muove **tutti**: e' il massimo possibile,
## non un caso.
##
## Il tetto e' il **90%** dei nemici vivi, cioe' 180 su 200 nel campione misurato.
## Non 100%: un numero che pretende che tutti i 200 si muovano rende l'asserzione
## fragile per un motivo che non c'entra (due nemici che si toccano e restano
## fermi insieme). Non 1 posizione: quello e' la parola "diversi" del criterio
## riscritta in codice, e non aggiunge niente.
##
## ## PERCHE' UNA FRAZIONE E NON UN NUMERO
##
## Era `180`, cioe' 200 - 20. Da m4 il numero di nemici vivi **non e' piu' una
## costante**: e' una curva che cresce per onda, ed e' di -orda. Un tetto
## assoluto qui sarebbe un numero scritto contro una curva che non e' mia, e
## fallirebbe -- o peggio, passerebbe -- per un motivo che non e' la
## riproducibilita'. La frazione e' la stessa soglia detta nella sua unita' vera:
## "quasi tutti i nemici si muovono quando il seme cambia". Con l'orda al
## massimo (che e' come questa sezione misura, vedi `_milestone_3`) la frazione
## vale esattamente il 180 di prima.
const REPRO_DIFF_FRACTION := 0.9

func _milestone_3(h, arena: Node3D) -> void:
	var horde = arena.get_node_or_null("Horde")
	if not h.check(horde != null, "m3: la scena vera non ha il nodo Horde"):
		return
	# Superficie congelata: se uno dei tre non c'e', il resto della sezione
	# misurerebbe un'altra cosa e fallirebbe con un messaggio che non dice quale
	# dei tre manca. Non e' uno stub: e' la guardia che dice il numero giusto.
	for m in M3_SURFACE:
		if not h.check(horde.has_method(m),
				"m3: l'orda della scena vera non espone \"%s()\": e' la superficie congelata in src/core/contracts.gd, sezione \"Supersficie di milestone 3\"" % m):
			return
	# `reseed` ripopola a `population` (contratto di m3, punto 3), quindi il
	# numero di nemici su cui questa sezione misura **non e' una cifra scritta
	# qui**: e' la popolazione dell'onda in corso. Il tetto di densita'
	# `GRID_CEILING` e' stato derivato con l'arena **piena**, e su un'arena mezza
	# vuota ogni densita' starebbe sotto il tetto per il motivo sbagliato -- il
	# tetto passerebbe perche' non c'e' piu' nessuno, non perche' la griglia
	# tiene. Quindi `population` viene portata al massimo **dichiarato da -orda**,
	# letto dal suo codice, salvata e rimessa a posto, e il fatto e' stampato.
	var cap := _max_enemies(horde)
	if not h.check(cap > 0,
			"m3: l'orda della scena vera non espone piu' la costante MAX_ENEMIES: la densita' non si puo' piu' confrontare con un tetto dichiarato"):
		return
	var saved_pop: int = horde.population
	horde.population = cap
	print("test_arena: m3 densita' misurata con population=%d (massimo dichiarato di -orda), ripristinata a %d"
		% [cap, saved_pop])
	_riproducibilita(h, horde, cap)
	_sweep(h, horde, cap)
	# Ripristino **sempre**: `check()` non interrompe, e una sezione che lascia
	# l'orda con una popolazione diversa da quella trovata sporca tutto quello
	# che viene dopo.
	horde.population = saved_pop
	horde.reseed(SEED_A)

## ## 8.1 Riproducibilita': stesso seme due volte IDENTICO, seme diverso DIVERSO
##
## Entrambe le asserzioni, perche' una sola e' a denti nulli: la prima da sola
## passerebbe anche con un `reseed` che riscrive sempre la stessa disposizione, la
## seconda da sola passerebbe anche con un `reseed` che mette un rumore casuale
## sopra una disposizione fissa. Insieme dicono "funzione del seme".
##
## `cap` e' la popolazione con cui la sezione misura: il contratto di m3 dice che
## `reseed` riempie fino a `population`, quindi e' il numero di vivi che ci deve
## essere dopo, non una cifra che questo test sceglie.
func _riproducibilita(h, horde, cap: int) -> void:
	horde.reseed(SEED_A)
	var a: PackedVector3Array = horde.transforms.duplicate()
	var a_colors: PackedColorArray = horde.colors.duplicate()
	h.eq(horde.count, cap,
		"m3: dopo un reseed l'orda deve essere riempita fino a population (%d), che e' il punto 3 del contratto di m3" % cap)
	h.eq(horde.transforms.size(), horde.count,
		"m3: transforms.size() deve combaciare con count dopo un reseed")
	h.eq(horde.colors.size(), horde.count,
		"m3: colors.size() deve combaciare con count dopo un reseed")

	# Stesso seme, di nuovo: il percorso e' lo stesso, quindi la disposizione
	# deve tornare **identica**, non "vicina". Il confronto e' elemento per
	# elemento, e sotto anche la somma delle coordinate: se un solo nemico
	# differisse di un epsilon, il primo confronto lo prenderebbe, e la somma
	# dice in che direzione si e' mosso.
	horde.reseed(SEED_A)
	var b: PackedVector3Array = horde.transforms.duplicate()
	h.eq(b.size(), a.size(),
		"m3: lo stesso seme due volte deve produrre lo stesso numero di nemici")
	h.check(b == a,
		"m3: stesso seme due volte -> transforms IDENTICI: %d posizioni su %d diverse"
			% [_differing(a, b), mini(a.size(), b.size())])
	h.near(_checksum(b), _checksum(a), 0.0,
		"m3: stesso seme due volte -> la somma delle posizioni deve essere la stessa")
	h.check(horde.colors == a_colors,
		"m3: stesso seme due volte -> anche i colori devono essere identici")

	# Seme diverso: la disposizione deve essere un'altra, e lo deve essere per
	# gran parte dei nemici, non per uno.
	horde.reseed(SEED_B)
	var c: PackedVector3Array = horde.transforms.duplicate()
	var moved := _differing(a, c)
	var diff_min := _diff_min(mini(a.size(), c.size()))
	h.check(moved >= diff_min,
		"m3: due semi diversi devono dare disposizioni DIVERSE: %d posizioni su %d diverse, tetto dichiarato il %.0f%% = %d"
			% [moved, mini(a.size(), c.size()), REPRO_DIFF_FRACTION * 100.0, diff_min])

	print("test_arena: m3 riproducibilita': seme %d due volte -> %d/%d posizioni diverse, somma %.6f; seme %d -> %d/%d diverse"
		% [SEED_A, _differing(a, b), a.size(), _checksum(a), SEED_B, moved, mini(a.size(), c.size())])

## ## 8.2 Lo sweep: N semi sulla scena vera, `worst_bucket()` misurato
##
## La misura che m2-w3 aveva rimandato per iscritto e che nessuno aveva fatta: il
## traboccamento vero, sull'orda vera, dentro l'arena vera. Non su un'orda isolata
## con una griglia costruita a mano.
##
## Il tetto e' `GRID_CEILING`, e sotto ne c'e' il commento che dice come e' stato
## derivato dalla misura che questo sweep stampa. Nessun numero qui e' scritto
## prima di averlo misurato: e' la lezione di piano 1.2, dove un'ipotesi sul margine
## si e' rivelata sbagliata solo dopo misurata.
##
## `cap` e' la popolazione con cui si misura: vedi `_milestone_3`. Il tetto di
## densita' e' derivato a pieno, e su un'orda piu' piccola ogni densita' ci
## starebbe sotto senza che la griglia abbia fatto niente.
func _sweep(h, horde, cap: int) -> void:
	var samples: Array[int] = []
	var raw: Array[int] = []
	var seeds: Array[int] = []
	var overflowed: Array[int] = []
	var dirty_cells: Array[int] = []
	var steps_differ := 0
	var steps_alike: Array = []
	var prev: PackedVector3Array = PackedVector3Array()
	for i in SWEEP_COUNT:
		var s: int = SWEEP_FIRST + i * SWEEP_STEP
		seeds.append(s)
		horde.reseed(s)
		# Il seme e' davvero un ingresso: due semi consecutivi dello sweep
		# producono due disposizioni diverse, o il campione non sta misurando
		# niente. Non e' una riga che si lascia supporre: sotto il numero e'
		# contato, e sotto l'asserzione lo richiede **tutto**.
		var here: PackedVector3Array = horde.transforms.duplicate()
		if i > 0:
			var d := _differing(prev, here)
			if d >= _diff_min(here.size()):
				steps_differ += 1
			else:
				steps_alike.append("%d/%d:%d" % [seeds[i - 1], s, d])
		prev = here
		# `reseed` ricostruisce gia' la griglia (punto 5 del contratto di m3),
		# quindi la lettura successiva parla della disposizione appena scritta.
		# `nearest_enemy_index` passa comunque da `_ensure_grid()`: e' l'unica
		# API pubblica che garantisce la ricostruzione, costa una query e rende
		# la misura indipendente da **quando** -orda ha deciso di farlo. (Il
		# nome sull'orda e' `nearest_enemy_index`: `nearest_enemy` e' il nome
		# dell'API **del contratto**, che -orda registra su `Game`.)
		horde.nearest_enemy_index(Vector3.ZERO, 12.0)
		h.eq(horde.count, cap,
			"m3: il seme %d deve lasciare l'orda piena fino a population (%d)" % [s, cap])
		var w: int = horde.worst_bucket()
		if horde.grid_overflowed():
			overflowed.append(s)
		if int(horde.get("grid_unknown_cells")) != 0:
			dirty_cells.append(s)
		raw.append(w)

	samples = raw.duplicate()
	samples.sort()
	var lo: int = samples[0]
	var hi: int = samples[samples.size() - 1]
	# Mediana = elemento di indice floor(n/2) della lista ordinata. Su n pari
	# e' il medio-alto, non la media dei due centrali: la media dei due centrali
	# sarebbe un numero che nessuna disposizione ha avuto, e qui si vuole
	# riportare una disposizione **misurata**, non una sintesi.
	var med: int = samples[samples.size() / 2]

	print("test_arena: m3 sweep, %d semi sulla scena vera (%d, %d, ... %d): worst_bucket = %s"
		% [SWEEP_COUNT, seeds[0], seeds[1], seeds[seeds.size() - 1], str(raw)])
	print("test_arena: m3 sweep: min %d, mediana %d, max %d; semi traboccati %d su %d; celle sconosciute %d su %d"
		% [lo, med, hi, overflowed.size(), SWEEP_COUNT, dirty_cells.size(), SWEEP_COUNT])
	print("test_arena: m3 sweep: coppie di semi consecutivi con disposizione diversa %d su %d%s"
		% [steps_differ, SWEEP_COUNT - 1, ("" if steps_alike.is_empty() else "; simili: %s" % str(steps_alike))])

	# Il campione non sta misurando sempre la stessa disposizione sotto vestiti
	# diversi. La soglia e' **tutte** le coppie: misurate 23 su 23, e sotto un
	# seme diverso tutti i nemici si muovono, quindi una coppia simile
	# sarebbe un difetto di `reseed` e non una coincidenza.
	h.check(steps_differ == SWEEP_COUNT - 1,
		"m3: ogni coppia di semi consecutivi dello sweep deve dare una disposizione diversa (almeno il %.0f%%, cioe' %d posizioni su %d): %d su %d, e le coppie simili sono %s"
			% [REPRO_DIFF_FRACTION * 100.0, _diff_min(cap), cap, steps_differ, SWEEP_COUNT - 1, str(steps_alike)])

	# Il traboccamento e' il fatto vero, e la sua segnalazione e' dedicata:
	# `worst_bucket()` non puo' superare `BUCKET_SLOTS` e non puo' dire da solo
	# che un secchiello e' traboccato.
	h.check(overflowed.is_empty(),
		"m3: nessun seme deve traboccare la griglia sulla scena vera: traboccano i semi %s (picco %d su %d slot)"
			% [str(overflowed), hi, 32])
	h.check(dirty_cells.is_empty(),
		"m3: la griglia non deve scaldare celle nuove nel ciclo di gioco: semi %s" % str(dirty_cells))
	# E il tetto di densita', derivato dalla misura sopra e non da `BUCKET_SLOTS`.
	h.check(hi <= GRID_CEILING,
		"m3: worst_bucket sulla scena vera deve stare sotto il tetto dichiarato %d: massimo misurato %d sui semi %s"
			% [GRID_CEILING, hi, str(seeds)])

	_semantica_worst_bucket(h, horde, seeds, raw)

## ## 8.3 La semantica dichiarata, verificata invece che supposta
##
## `worst_bucket()` e' dichiarato in `src/sim/horde.gd` come **il picco del frame
## (griglia) appena ricostruito**: dentro `spatial_grid.gd` il contatore e' un
## massimo storico che si azzera solo in `setup()`, e `_rebuild_grid()` lo azzera
## a ogni ricostruzione perche' altrimenti direbbe ancora il picco della
## disposizione precedente.
##
## Il modo economico per distinguere le due semantiche non e' leggerne il
## commento: e' chiedere al numero di **scendere**. Si riscrive la disposizione
## peggiore dello sweep e poi quella migliore: se il numero torna indietro sta
## parlando dell'ultima disposizione scritta; se risale, o resta fermo al massimo,
## sta accumulando da `setup()` e tutte le letture dello sweep sono una curva
## sola. E' l'unica parte di questa sezione che puo' fallire se -orda cambia
## idea sulla semantica senza dirlo, ed e' per questo che c'e'.
func _semantica_worst_bucket(h, horde, seeds: Array[int], raw: Array[int]) -> void:
	var i_hi := 0
	var i_lo := 0
	for i in raw.size():
		if raw[i] > raw[i_hi]:
			i_hi = i
		if raw[i] < raw[i_lo]:
			i_lo = i
	horde.reseed(seeds[i_hi])
	h.eq(horde.worst_bucket(), raw[i_hi],
		"m3: riscrivere la disposizione peggiore (%d) deve riprodurre il suo picco %d"
			% [seeds[i_hi], raw[i_hi]])
	horde.reseed(seeds[i_lo])
	var back: int = horde.worst_bucket()
	h.eq(back, raw[i_lo],
		"m3: riscrivere la disposizione migliore (%d) deve riprodurre il suo picco %d, non il massimo di prima"
			% [seeds[i_lo], raw[i_lo]])
	h.check(back < raw[i_hi],
		"m3: worst_bucket() e' dichiarato per-frame, non storico: dopo il seme %d deve scendere a %d dal %d del seme %d. "
		% [seeds[i_lo], back, raw[i_hi], seeds[i_hi]]
		+ "Se resta fermo al massimo, il numero sta accumulando da setup() e ogni lettura di questo test e' sbagliata")
	print("test_arena: m3 semantica worst_bucket(): dopo il seme %d (picco %d) il seme %d lo riporta a %d: e' il picco del frame ricostruito, non un massimo storico"
		% [seeds[i_hi], raw[i_hi], seeds[i_lo], back])

## Quante posizioni devono moversi fra due semi diversi, su `live` nemici vivi:
## la frazione dichiarata, arrotondata per eccesso. `maxi(1, ...)` perche' un
## tetto di zero posizioni sarebbe un'asserzione che non puo' fallire, cioe'
## esattamente la cosa che questa sezione sta cercando di evitare.
func _diff_min(live: int) -> int:
	return maxi(1, int(ceil(REPRO_DIFF_FRACTION * float(live))))

## Quante posizioni di due disposizioni sono diverse. Il confronto e' esatto
## (`!=` su `Vector3`), non una tolleranza: "identici" nel criterio n. 2 di m3
## vuol dire identici, e una tolleranza qui lascerebbe passare un `reseed` che
## sposta ogni nemico di mezzo centimetro.
func _differing(a: PackedVector3Array, b: PackedVector3Array) -> int:
	var n := mini(a.size(), b.size())
	var d := 0
	for i in n:
		if a[i] != b[i]:
			d += 1
	return d

## Una somma delle coordinate. Non serve a misurare niente: serve a dare un
## secondo modo di vedere che due disposizioni sono la stessa cosa, e che il primo
## confronto non e' passato per un caso. Con `near(..., 0.0)` la tolleranza e' zero:
## due somme identiche o non sono.
func _checksum(pts: PackedVector3Array) -> float:
	var acc := 0.0
	for i in pts.size():
		var p := pts[i]
		acc += p.x * 3.0 + p.z * 7.0 + p.y * 11.0
	return acc

# --- 9. Milestone 8: la taglia che vedi e' quella che morde ---------------------
#
# ## Il difetto, e perche' la misura e' una proporzione
#
# Prima di m8 `src/render/horde_renderer.gd` aveva **una sola taglia** per tutte e
# quattro le specie (`BASE_SCALE = 1.5`) e le specie si distinguevano **solo di
# tinta**. Quindi un runner (raggio 0.45 m) e un boss (raggio 1.90 m) erano
# identici alla vista, mentre il boss mordeva fino a 3.10 m dal centro: la taglia
# che il giocatore vedeva non era quella che lo mordeva.
#
# Il numero che il renderer deve disegnare ora e' `horde.radii[i]`, esposto da
# -orda (superficie congelata in `src/core/contracts.gd`, "Supersficie di
# milestone 8"). **Questo file non conosce `RADIUS[kind]` e non lo ricopia**: legge
# `radii` dall'orda vera e misura. E' il criterio n. 4, generalizzato a tutti i
# numeri e non solo a quelli di danno.
#
# ## Perche' l'invariante e' la PROPORZIONALITA' e non la taglia assoluta
#
#     disegnato_i / disegnato_j  ==  radii[i] / radii[j]
#
# Se l'invariante fosse sulla taglia assoluta, l'unico modo per soddisfarlo sarebbe
# disegnare i nemici **esattamente** a `RADIUS[kind]`, cioe' un runner da 45 cm, e
# l'orda diventerebbe illeggibile. Con la proporzionalita' c'e' un **fattore di
# calibrazione libero** (`SIZE_FACTOR` nel renderer): l'invariante resta vero
# cambiandolo, e il fattore si sceglie sulla misura e si dichiara col numero che
# produce.
#
# La proporzionalita' e' anche la forma piu' economica da asserire: e' equivalente
# a dire che **`disegnato_i / radii[i]` e' lo stesso numero per tutti i nemici**,
# e quindi bastano N divisioni invece di N^2 rapporti. E non e' piu' debole: con la
# taglia costante di prima lo spread dei rapporti e' da 3.33 (runner) a 0.79
# (boss), cioe' un fattore 4.2, e la tolleranza qui e' di 1e-3.

## La taglia di **prima** di m8, e la sola cosa che questo test deve ricordare di
## come era. La costante era `BASE_SCALE = 1.5` nel renderer; il modello misurato
## il 2026-10-13 (`enemy_small.glb`, AABB 0.894425 x 1.000000 x 0.850640 m)
## dava un corpo disegnato di **1.500000 m** nel suo lato maggiore.
##
## Non e' una copia del raggio di una specie: e' **il difetto che m8 corregge**,
## cioe' la base di confronto del "non regredisce". Il raggio di una specie non
## compare qui in nessuna forma, quindi questa asserzione non puo' cambiare
## risposta se `-orda` muove `RADIUS[kind]`: puo' cambiare risposta solo se il
## renderer torna a una taglia costante, che e' esattamente il difetto.
const LEGACY_BASE_SCALE := 1.5

## Tolleranza del rapporto `disegnato / radii`. Il rapporto e' un `float` a 32 bit
## che passa per una `Basis`, quindi l'errore relativo e' dell'ordine di 1e-7: una
## tolleranza di 1e-3 assoluta sul fattore (che vale ~3.4) e' quattro ordini di
## grandezza sopra quel rumore e **dieci ordini** sotto il difetto da prendere.
const RATIO_TOLERANCE := 0.001

## Tolleranza della sollevata. Stessa natura: `Transform3D` e' a 32 bit.
const LIFT_TOLERANCE := 0.002

## I nomi delle specie, **letti dalla tabella di -orda** (`KIND_NAMES` in
## `src/sim/enemy.gd`) e non scritti qui. Nessuna copia: `ENEMY_KINDS` non esiste
## in questo file, e i nomi che compaiono nei messaggi sono quelli che -orda ha
## nel suo codice al momento della misura.
##
## Il percorso e' lo stesso di `_max_enemies()`: si arriva alla tabella passingo
## per la costante `E` con cui `horde.gd` preloada `src/sim/enemy.gd`. Quindi
## questo file non sa nemmeno il nome del file che contiene le specie: e' un dato
## di -orda letto da -orda.
##
## Restituisce un array vuoto se la tabella non e' piu' li', e il chiamante lo
## dichiara invece di procedere con un tetto sbagliato.
func _kind_names(horde) -> Array:
	var scr = horde.get_script()
	if scr == null or not scr.has_method("get_script_constant_map"):
		return []
	var map: Dictionary = scr.get_script_constant_map()
	if not map.has("E"):
		return []
	var e: Object = map["E"]
	if e == null or not e.has_method("get_script_constant_map"):
		return []
	var emap: Dictionary = e.get_script_constant_map()
	if not emap.has("KIND_NAMES"):
		return []
	var names: Array = emap["KIND_NAMES"]
	return names

func _milestone_8(h, arena: Node3D) -> void:
	var horde = arena.get_node_or_null("Horde")
	var enemies = arena.get_node_or_null("Enemies")
	if not h.check(horde != null, "m8: la scena vera non ha il nodo Horde"):
		return
	if not h.check(enemies != null, "m8: la scena vera non ha il nodo Enemies"):
		return

	# ## Superficie congelata: il campo deve esistere ed essere della forma giusta
	#
	# `horde.radii` e' dichiarato in `src/core/contracts.gd`, sezione "Supersficie
	# di milestone 8", come `PackedFloat32Array`. Se non c'e' la sezione misurerebbe
	# un'altra cosa, quindi la guardia dice il numero giusto invece di lasciare che
	# un `Invalid get index` dica "qualcosa non va".
	var radii = horde.get("radii")
	if not h.check(radii is PackedFloat32Array,
			"m8: l'orda della scena vera non espone `radii` come PackedFloat32Array (misurato %s): e' la superficie congelata di src/core/contracts.gd, sezione \"Supersficie di milestone 8\", e lo scrive -orda"
				% type_string(typeof(radii))):
		return

	var mm = enemies.multimesh
	if not h.check(mm != null and mm.mesh != null, "m8: il renderer non ha costruito la MultiMesh con la sua mesh"):
		return
	var mesh_size: Vector3 = mm.mesh.get_aabb().size
	var legacy_extent: float = LEGACY_BASE_SCALE * _max3(mesh_size.x, mesh_size.y, mesh_size.z)

	# L'orologio congelato: con il tempo che scorre cambiano il bob e la rotazione,
	# e la geometria scritta nel buffer non e' piu' prevedibile. `_geometry_*`
	# misura sempre con indice 0, dove il bob e' esattamente 0 (e' `sin(0)`), cosi'
	# la misura della taglia non ha dentro il movimento.
	enemies.set_time(0.0)
	enemies.set_horde(horde)

	var cap := _max_enemies(horde)
	if not h.check(cap > 0,
			"m8: l'orda non espone piu' MAX_ENEMIES: senza la popolazione piena non si puo' osservare un campione che contenga tutte e quattro le specie"):
		return
	var saved_pop: int = horde.population
	horde.population = cap
	print("test_arena: m8 campione misurato con population=%d (massimo dichiarato di -orda), ripristinata a %d"
		% [cap, saved_pop])

	_proporzionalita(h, horde, enemies, mesh_size)
	var kind_names := _kind_names(horde)
	if not h.check(kind_names.size() > 0,
			"m8: dalla tabella delle specie di -orda non si legge KIND_NAMES: senza i nomi il criterio n. 3 non puo' essere asserito per nome"):
		horde.population = saved_pop
		horde.reseed(SEED_A)
		return
	var kinds: int = kind_names.size()

	# ## Il campione: uno **sweep di semi fissati**, non un dado
	#
	# `reseed(s)` con `s != 0` fissa il `_rng` di -orda, quindi l'orda che ne
	# nasce e' **sempre** la stessa disposizione: la lista delle specie osservate
	# qui sotto e' un fatto di questo test e non un caso di una esecuzione. I semi
	# sono **quelli dello sweep di m3** (`SWEEP_FIRST`, `SWEEP_STEP`,
	# `SWEEP_COUNT`), gia' dichiarati in questo file: nessun numero nuovo.
	#
	# Il ciclo si ferma al primo seme che mostra tutte le specie. Serve perche' il
	# boss pesa il 3% dei nemici dell'onda 1 (`Spawner.KIND_WEIGHTS`) e un singolo
	# campione da 200 potrebbe non mostrarlo: il numero dei semi usati viene
	# stampato, cosi' si vede quanto campione e' servito davvero.
	var by_kind: Dictionary = {}
	var seeds_used: Array[int] = []
	for i in SWEEP_COUNT:
		var s: int = SWEEP_FIRST + i * SWEEP_STEP
		horde.reseed(s)
		_accumula(horde, enemies, mesh_size, by_kind)
		seeds_used.append(s)
		if by_kind.size() >= kinds:
			break

	print("test_arena: m8 campione: %d semi (%s) x %d nemici vivi, %d specie distinte"
		% [seeds_used.size(), str(seeds_used), horde.count, by_kind.size()])
	_quattro_specie(h, by_kind, mesh_size, legacy_extent, kind_names)

	# Ripristino **sempre**: `check()` non interrompe, e una sezione che lascia
	# l'orda con una popolazione diversa da quella trovata sporca quello che viene
	# dopo.
	horde.population = saved_pop
	horde.reseed(SEED_A)

## ## 9.1 Il criterio n. 1: la taglia disegnata e' PROPORZIONALE a `radii[i]`
##
## L'invariante scritto e' `disegnato_i / radii[i] == costante`, che e' la stessa
## cosa di `disegnato_i / disegnato_j == radii[i] / radii[j]` senza il costo di N^2
## rapporti. Il confronto e' fra **tutti** i nemici campionati, non fra due: una
## prova su due coppie passerebbe anche con un renderer che distingue solo due
## specie.
func _proporzionalita(h, horde, enemies, mesh_size: Vector3) -> void:
	var radii: PackedFloat32Array = horde.radii
	# L'allineamento degli array paralleli e' il punto 2 del contratto di m8, e lo
	# si controlla **prima** di leggere `radii[i]`: leggere fuori dal vettore e'
	# un crash, e un crash non e' un fallimento con un messaggio.
	h.eq(radii.size(), horde.count,
		"m8: radii.size() deve combaciare con count: e' il punto 2 del contratto di m8")
	h.eq(radii.size(), horde.transforms.size(),
		"m8: radii deve essere allineato a transforms, stesso indice stesso nemico")
	h.eq(radii.size(), horde.colors.size(),
		"m8: radii deve essere allineato a colors, stesso indice stesso nemico")
	h.eq(radii.size(), horde.kinds.size(),
		"m8: radii deve essere allineato a kinds, stesso indice stesso nemico")
	if radii.size() != horde.count or horde.count == 0:
		return

	var lo := INF
	var hi := -INF
	var sample := 0
	for i in horde.count:
		var r: float = float(radii[i])
		if r <= 0.0:
			continue
		var t: Transform3D = enemies.instance_transform(horde.transforms[i], r, i)
		# Il rapporto e' l'invariante, non il confronto a occhio fra due numeri.
		var ratio: float = _scale_of(t.basis) / r
		lo = minf(lo, ratio)
		hi = maxf(hi, ratio)
		sample += 1

	h.eq(sample, horde.count,
		"m8: tutti i nemici campionati devono avere un raggio del corpo positivo")
	if sample == 0:
		return
	h.check(hi - lo <= RATIO_TOLERANCE,
		"m8: la taglia disegnata deve essere PROPORZIONALE a horde.radii: il rapporto disegnato/raggio deve essere lo stesso per tutti, e va da %.6f a %.6f su %d nemici (escursione %.6f, tolleranza %.4f)"
			% [lo, hi, sample, hi - lo, RATIO_TOLERANCE])

	# E il fattore cosi' ottenuto e' quello che il renderer dichiara: non viene
	# riletto dalla costante, viene **misurato** dal prodotto. E' il numero che m8
	# chiede di dichiarare con il numero che produce.
	var factor: float = (lo + hi) * 0.5
	print("test_arena: m8 fattore di calibrazione MISURATO: disegnato/raggio = %.4f (min %.6f, max %.6f su %d nemici, escursione %.9f)"
		% [factor, lo, hi, sample, hi - lo])
	print("test_arena: m8 mesh %s, AABB %.6f x %.6f x %.6f m"
		% [_mesh_name(enemies), mesh_size.x, mesh_size.y, mesh_size.z])

## Raccoglie, **senza asserire**, quello che ogni specie osservata mostra nel
## campione. Le asserzioni sono tutte in `_quattro_specie`: qui si sommano i numeri
## e basta, cosi' il conteggio resta quello che il difetto merita e non 200 righe
## che ripetono la stessa verta' per ogni nemico.
##
## Per ogni specie: quanti nemici, il raggio **minimo e massimo** (devono essere
## uguali, perche' `radii[i]` e' una funzione di `kinds[i]`), e la taglia disegnata
## e la sollevata del primo esemplare visto.
##
## Il **nome** non lo mette qui: `horde.kind_name(i)` prende un **indice** di
## nemico, non un indice di specie, e chiamarlo con `kind` avrebbe scritto il
## nome di un'altra specie accanto al suo raggio — un errore che si vede solo
## confrontando la tabella con `src/sim/enemy.gd`. Il nome arriva da
## `_kind_names()`, cioe' dalla tabella di -orda.
func _accumula(horde, enemies, mesh_size: Vector3, by_kind: Dictionary) -> void:
	var radii: PackedFloat32Array = horde.radii
	for i in horde.count:
		var kind: int = horde.kinds[i]
		var r: float = float(radii[i])
		var t: Transform3D = enemies.instance_transform(horde.transforms[i], r, i)
		if not by_kind.has(kind):
			by_kind[kind] = {
				"seen": 0,
				"r_lo": r,
				"r_hi": r,
				"drawn": _drawn_extent(t.basis, mesh_size),
				"height": _scale_of(t.basis) * mesh_size.y,
				"lift": _lift_of(enemies, horde.transforms[i], r),
			}
		var row: Dictionary = by_kind[kind]
		row["seen"] = int(row["seen"]) + 1
		row["r_lo"] = minf(float(row["r_lo"]), r)
		row["r_hi"] = maxf(float(row["r_hi"]), r)

## ## 9.2 Il criterio n. 3: le quattro specie sono distinguibili, per nome
##
## «La misura c'e'» non e' «la misura e' guardata»: l'invariante del criterio n. 1
## rende la distinguibilita' **automatica**, e proprio per questo va asserita per
## nome, una specie alla volta.
##
## Sono **tre** le cose da guardare, e due delle tre hanno denti propri.
##   - le specie sono **tutte** quelle che -orda dichiara, e ciascuna ha un raggio
##     unico: e' la misura indiretta di `radii[i] == RADIUS[kinds[i]]`, fatta sui
##     dati dell'orda e non sulla tabella;
##   - le taglie disegnate sono **diverse** fra loro, e nessuna e' piu' piccola
##     della taglia unica di prima (il "non regredisce");
##   - ogni specie sta **appoggiata sul pavimento**: la sollevata e' meta'
##     dell'altezza effettiva del corpo. Questo controllo e' **indipendente** dalla
##     proporzionalita' — un renderer che scala i nemici e li lascia affondare
##     rispetta la proporzione e non si vede — ed e' la via corta per i denti.
func _quattro_specie(h, by_kind: Dictionary, mesh_size: Vector3, legacy_extent: float, kind_names: Array) -> void:
	h.eq(by_kind.size(), kind_names.size(),
		"m8: il campione deve contenere tutte le specie dichiarate da -orda (%d), e ne contiene %d"
		% [kind_names.size(), by_kind.size()])

	var ordered: Array = by_kind.keys()
	ordered.sort()
	var names: Array[String] = []
	var sizes: Array[float] = []
	var rows: Array[String] = []
	for k in ordered:
		var row: Dictionary = by_kind[k]
		# Il nome viene dalla tabella di -orda, indicata dall'indice di specie.
		var nm: String = str(kind_names[k]) if k < kind_names.size() else "specie %d" % k
		names.append(nm)
		sizes.append(float(row["drawn"]))
		# `radii[i]` e' una funzione di `kinds[i]`: due nemici della stessa specie
		# hanno lo stesso raggio. Contratto di m8 punto 1, misurato sui dati.
		h.near(float(row["r_hi"]), float(row["r_lo"]), 0.0001,
			"m8: tutti i %d %s campionati devono avere lo stesso raggio del corpo: va da %.6f a %.6f"
				% [int(row["seen"]), nm, float(row["r_lo"]), float(row["r_hi"])])
		# ## Il "non regredisce"
		#
		# Il requisito non e' che la taglia resti identica, e' che **non
		# diminuisca**: nessuna specie puo' disegnare piu' piccola di quanto
		# disegnava quando tutte avevano la taglia unica `LEGACY_BASE_SCALE`. Il
		# pavimento di questa asserzione e' la base di confronto, non il raggio di
		# una specie.
		h.check(float(row["drawn"]) >= legacy_extent - 0.002,
			"m8: il %s non puo' diventare piu' piccolo di prima: disegna %.3f m di lato maggiore, e prima di m8 ogni nemico ne disegnava %.3f m"
				% [nm, float(row["drawn"]), legacy_extent])
		# I piedi sul pavimento. L'altezza disegnata e' la scala dell'istanza per
		# l'altezza della mesh: entrambe misurate, nessuna copiata.
		var half: float = float(row["height"]) * 0.5
		h.near(float(row["lift"]), half, LIFT_TOLERANCE,
			"m8: il %s deve stare appoggiato sul pavimento, non affondato: centro a %.3f m sopra il terreno contro meta' altezza %.3f m. Con la taglia unica di prima la sollevata era fissa e questo corpo ne avrebbe avuti %.2f m sotto il terreno"
				% [nm, float(row["lift"]), half, maxf(float(row["drawn"]) - LEGACY_BASE_SCALE * mesh_size.y, 0.0)])
		rows.append("%s r=%.3f m -> %.3f m (%d visti)" % [nm, float(row["r_lo"]),
			float(row["drawn"]), int(row["seen"])])

	# Quattro taglie diverse. Due specie che si distinguono di un millimetro non
	# sono distinguibili, quindi la soglia e' un centimetro e non un epsilon.
	for a in names.size():
		for b in range(a + 1, names.size()):
			h.check(absf(sizes[a] - sizes[b]) > 0.01,
				"m8: il %s (%.3f m) e il %s (%.3f m) devono essere distinguibili a occhio: due taglie a meno di un centimetro sono la stessa taglia"
					% [names[a], sizes[a], names[b], sizes[b]])

	print("test_arena: m8 le quattro specie, per nome: %s" % " | ".join(rows))

## La taglia disegnata in metri: **il lato maggiore** del corpo, perche'
## `enemy_small.glb` non e' una sfera (AABB 0.894425 x 1.000000 x 0.850640 m) e la
## misura che conta e' quella che si vede. Scala dell'istanza per lato maggiore
## della mesh.
func _drawn_extent(basis: Basis, mesh_size: Vector3) -> float:
	return _scale_of(basis) * _max3(mesh_size.x, mesh_size.y, mesh_size.z)

## La scala uniforme dell'istanza. Il `Basis` arriva gia' ruotato dal renderer
## (rotazione comune sull'asse Y) e `get_scale()` e' invariante rispetto alla
## rotazione, quindi il valore letto e' la scala e non una sua componente mista.
func _scale_of(basis: Basis) -> float:
	var s := basis.get_scale()
	return maxf(absf(s.x), maxf(absf(s.y), absf(s.z)))

## Quanto il nemico sta sopra il pavimento, cioe' meta' dell'altezza del suo corpo.
## Si misura con indice 0 perche' il bob e' `sin(0 * BOB_SPEED + 0 * 0.37)`, che
## e' esattamente zero: con un indice qualsiasi il bob entrerebbe nella misura e
## renderebbe il confronto con la meta' altezza una domanda sul pavimento.
func _lift_of(enemies, pos: Vector3, radius: float) -> float:
	var t: Transform3D = enemies.instance_transform(pos, radius, 0)
	return t.origin.y - pos.y

func _max3(a: float, b: float, c: float) -> float:
	return maxf(a, maxf(b, c))

func _mesh_name(enemies) -> String:
	var mm = enemies.multimesh
	return "MultiMesh" if mm == null else str(mm.mesh.resource_path)

# --- Interno -------------------------------------------------------------------

## Un nodo e tutto quello che ha sotto, ricorsivamente. Il tetto del criterio n.
## 3 e' su questo numero, quindi il conteggio non puo' essere quello di un altro.
func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total

## Il path dello script attaccato a un nodo, o "" se non ce n'e'. Serve a dire che
## il nodo `Horde` usa il file di -orda e non uno stub con gli stessi campi.
func _script_path(node: Node) -> String:
	if node == null:
		return ""
	var scr = node.get_script()
	if scr == null:
		return ""
	return str(scr.resource_path)

## Un campo del contratto letto per nome: `arena_radius` e `player` sono campi
## dello script di `contracts.gd`, non di `Node`, quindi l'accesso resta dinamico.
func _contract_float(game: Node, key: String) -> float:
	var value = game.get(key)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return -1.0

func _cleanup(arena: Node3D) -> void:
	if arena == null:
		return
	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()
