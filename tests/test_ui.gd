extends SceneTree
## Test dell'HUD di terminal-gun. -ui, milestone 2.
##
## Verifica i tre numeri che m2 chiede all'interfaccia (piano sez. 1.1, criteri
## n. 2 e n. 4, e la consegna di questa foglia):
##
##   1. **barra XP in [0, next] sempre**: mai `NaN`, mai `INF`, mai una larghezza
##      negativa, nemmeno con `next` a zero e nemmeno con un `INF` o un `NaN`
##      che entra dalla porta;
##   2. **contatore d'onda a 1 all'avvio**, che sale quando l'onda avanza e che
##      **torna a 1 dopo il restart**;
##   3. **game over a 0 HP**, e che sparisce al restart;
##   4. **nessun nodo duplicato** fra due restart: l'HUD ha un numero di nodi
##      fisso e lo conserva.
##
## ## Perche' due parti e non una
##
## La prima parte istanzia `scenes/hud.tscn` da solo: e' la parte che non puo'
## fallire per un file di un'altra foglia, e verifica la logica dell'HUD su
## numeri arbitrari, cosa che nella scena vera non si puo' fare (l'XP la mette
## solo `-gameplay`).
##
## La seconda parte carica `scenes/arena_main.tscn` per intero e verifica che
## l'HUD, **nella partita vera**, legga i numeri che le altre foglie espongono
## davvero: e' la verifica che un HUD con la logica giusta ma scollegata dal
## gioco non passerebbe.
##
## ## I due punti di accoppiamento, dichiarati
##
## L'HUD legge due campi che non sono suoi: `Game.player.progression.xp` (di
## `-gameplay`) e `Game.horde.wave` (di `-orda`). Qui sono verificati sul
## contratto vero, e per `wave` la verifica e' condizionata al campo che
## `-orda` deve dichiarare: se il campo non c'e' ancora, il test **stampa la
## nota** e controlla il valore di riserva, invece di far fallire un'onda che sta
## costruendo l'altra foglia in parallelo. Il rumore e' voluto: un contatore
## d'onda fermo a 1 senza che nessuno lo noti e' il difetto che questa verifica
## deve rendere visibile.
##
## ## La trappola del `const preload` (piano sez. 5.3)
##
## `scenes/arena_main.tscn` si carica con `load()` **dentro il corpo del test**,
## mai in `const`: un `const preload` risolve gli script a tempo di compilazione,
## PRIMA che l'autoload `Game` sia fra le costanti globali, e `player.gd` usa
## l'identificatore nudo `Game`. Solo `tools/test_harness.gd` e' in `const`, e non
## tocca il contratto.
##
## Stringhe a schermo solo ASCII: la console di Windows e il pipe di
## `OS.execute` sono in codepage e un accento diventa spazzatura proprio nel
## messaggio che serve a capire un fallimento.

const H = preload("res://tools/test_harness.gd")

const HUD_SCENE := "res://scenes/hud.tscn"
const ARENA_SCENE := "res://scenes/arena_main.tscn"

## La soglia di `xp_next` usata nella parte a HUD solo: la stessa forma di
## quella di `progression.gd`, cosi' l'arbitriario che si prova e' un numero
## plausibile e non un valore assurdo che nessun test deve poter produrre.
const XP_SPAN := 8.0

## `INF` e `NaN` entrano dalla porta di `set_progression`: e' il caso che
## `clampf` **non** copre, perche' ogni confronto con `NaN` e' falso e il clamp
## restituisce `NaN` invece di 0. Se l'HUD non li ferma lui, il test passa e
## l'HUD e' invisibile.
const NOT_FINITE := [INF, -INF, NAN]

## Nodo dell'HUD che il test cerca nella scena. Il nome e' in `scenes/hud.tscn`
## e in `scenes/arena_main.tscn`: se un giorno cambiasse, fallirebbe qui e non in
## silenzio.
const HUD_NODE := "Hud"

var _h: H = null
var _ran: bool = false


func _initialize() -> void:
	_h = H.new()

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
		quit(h.finish("test_ui"))
		return

	_hud_alone(h)
	# Senza tipo: `_open_arena` restituisce un Variant (il risultato di
	# `instantiate()`), e `:=` su un Variant non compila. Con `:` dichiarato
	# `:=` sbaglierebbe lo stesso tipo per una riga che non ha.
	var arena = _open_arena(h, game)
	if arena == null:
		quit(h.finish("test_ui"))
		return

	# Tre avvii della scena vera: il primo e due restart. Il confronto fra i tre
	# e' il controllo sui nodi duplicati, e il confronto fra il primo e gli altri
	# due e' il controllo che il restart ripulisce davvero (schermata di game over
	# inclusa).
	var first := _scene_round(h, game, arena, 1)
	_close(arena)

	var second := _scene_round(h, game, _open_arena(h, game), 2)
	_close(second.get("arena"))

	var third := _scene_round(h, game, _open_arena(h, game), 3)
	_close(third.get("arena"))

	print("test_ui: nodi dell'HUD per avvio: %d / %d / %d"
		% [int(first["hud_nodes"]), int(second["hud_nodes"]), int(third["hud_nodes"])])
	print("test_ui: un solo nodo \"%s\" sotto root in ogni avvio: %d / %d / %d"
		% [HUD_NODE, int(first["huds"]), int(second["huds"]), int(third["huds"])])

	quit(h.finish("test_ui"))

# --- Parte 1: l'HUD da solo ---------------------------------------------------

## L'HUD da solo, con numeri arbitrari. Nella scena vera l'XP la mette solo
## `-gameplay` e l'onda solo `-orda`: qui si puo' provare la barra con `next` a
## zero, con `next` negativo e con numeri non finiti, che sono i tre casi in cui
## una divisione produce un HUD che non si vede.
func _hud_alone(h) -> void:
	var hud = _instantiate(HUD_SCENE)
	if not h.check(hud != null, "manca %s" % HUD_SCENE):
		return
	root.add_child(hud)

	var nodes_when_new := _count_nodes(hud)

	# L'avvio: onda 1, barra vuota, nessuna schermata.
	h.eq(hud.wave_number(), 1, "all'avvio il contatore d'onda deve essere 1")
	h.check(hud.wave_text().contains("1"),
		"la scritta del contatore d'onda deve dire 1: \"%s\"" % hud.wave_text())
	h.near(hud.xp_ratio(), 0.0, 0.0001, "all'avvio la barra dell'XP e' vuota")
	h.finite(hud.xp_ratio(), "all'avvio la barra dell'XP e' un numero")
	h.check(not hud.game_over_visible(), "all'avvio la schermata di game over non si vede")
	h.check(not hud.is_game_over(), "all'avvio la partita non e' finita")

	_xp_bar(h, hud)
	_wave_counter(h, hud)
	_game_over_screen(h, hud)

	h.eq(_count_nodes(hud), nodes_when_new,
		"l'HUD non puo' cambiare numero di nodi mentre la partita va avanti: un nodo nato a meta' partita e' il difetto che il restart moltiplica")

	root.remove_child(hud)
	hud.free()

## La barra dell'XP: [0, next] sempre, e il valore disegnato dentro quel
## denominatore.
func _xp_bar(h, hud) -> void:
	var xp_values := [0.0, 0.5, 1.0, XP_SPAN - 0.001, XP_SPAN, XP_SPAN * 3.0, -7.0, 1.0e9]
	for raw in xp_values:
		hud.set_progression(raw, XP_SPAN)
		_assert_bar_sane(h, hud, "xp %s con next %s" % [raw, XP_SPAN])

	# Il caso del criterio n. 2: `next` non positivo non si divide.
	for raw in [0.0, -1.0, -1.0e9]:
		hud.set_progression(4.0, raw)
		_assert_bar_sane(h, hud, "xp 4.0 con next %s" % raw)
		h.near(hud.xp_ratio(), 0.0, 0.0001,
			"con next %s la barra non puo' dire niente, quindi dice zero" % raw)

	# E numeri non finiti dalla porta: `clampf(NAN, 0, 1)` restituisce `NaN`.
	for raw in NOT_FINITE:
		hud.set_progression(raw, XP_SPAN)
		_assert_bar_sane(h, hud, "xp %s con next %s" % [raw, XP_SPAN])
		hud.set_progression(4.0, raw)
		_assert_bar_sane(h, hud, "xp 4.0 con next %s" % raw)

	# Un valore noto, per non verificare solo che il numero sia "qualcosa".
	hud.set_progression(XP_SPAN * 0.5, XP_SPAN)
	h.near(hud.xp_ratio(), 0.5, 0.0001, "meta' della barra con meta' della soglia")
	h.near(hud.xp_bar_value(), XP_SPAN * 0.5, 0.0001,
		"la barra disegnata deve essere meta' della soglia, non meta' qualcosa")
	h.check(hud.xp_text().contains("4"),
		"il testo della barra deve dire quanta XP manca: \"%s\"" % hud.xp_text())

## Il contatore d'onda sale, e non scende mai sotto 1.
func _wave_counter(h, hud) -> void:
	hud.set_wave(4)
	h.eq(hud.wave_number(), 4, "il contatore d'onda deve salire quando l'onda avanza")
	h.check(hud.wave_text().contains("4"),
		"la scritta deve seguire il contatore: \"%s\"" % hud.wave_text())
	hud.set_wave(1)
	h.eq(hud.wave_number(), 1, "il contatore d'onda torna a 1")
	# Un'onda 0 o negativa non e' uno stato del gioco: mostrarla vuol dire far
	# leggere "nessuna onda" dove l'HUD non lo sa.
	hud.set_wave(0)
	h.eq(hud.wave_number(), 1, "l'onda non puo' essere 0")
	hud.set_wave(-5)
	h.eq(hud.wave_number(), 1, "l'onda non puo' essere negativa")

	# La barra dell'onda segue il numero di `-orda`, quindi quando l'onda e'
	# finita la barra e' vuota e il contatore e' salito: e' la coppia che rende
	# leggibile il criterio n. 4.
	for raw in [1.0, 0.5, 0.0, -0.2, 1.4]:
		hud.set_wave_progress(raw)
		_assert_wave_bar_sane(h, hud, "barra d'onda a %s" % raw)
		h.near(hud.wave_ratio(), clampf(float(raw), 0.0, 1.0), 0.001,
			"la barra d'onda a %s deve essere clampata in [0, 1]" % raw)
	for raw in NOT_FINITE:
		hud.set_wave_progress(raw)
		_assert_wave_bar_sane(h, hud, "barra d'onda a %s" % raw)

## La schermata di game over: compare, e sparisce. Comparire e basta non basta:
## una schermata che non si ritira e' un HUD che mente per il resto della partita.
func _game_over_screen(h, hud) -> void:
	hud.set_state(100.0, 100.0, 0, "-", 0, 1)
	hud.set_game_over(true)
	h.check(hud.game_over_visible(), "con set_game_over(true) la schermata deve vedersi")
	hud.set_game_over(false)
	h.check(not hud.game_over_visible(), "con set_game_over(false) la schermata deve sparire")

	# E dalla vita, che l'HUD conosce gia': e' il percorso vero della partita,
	# dove nessuno chiama `set_game_over` perche' nessuno se n'e' ricordato.
	hud.set_state(0.0, 100.0, 0, "-", 0, 1)
	h.check(hud.game_over_visible(), "a 0 HP la schermata di game over deve comparire")
	hud.set_state(35.0, 100.0, 0, "-", 0, 1)
	h.check(not hud.game_over_visible(),
		"tornando in vita la schermata deve sparire: se resta, l'HUD mente per tutta la partita")

## La barra e' sanata: finita, dentro [0, 1], e il valore **disegnato** dentro il
## denominatore del nodo. Il controllo e' sul nodo e non sul ricalcolo perche' il
## difetto di cui si parla e' proprio una barra con larghezza negativa: si vede
## solo sul `ProgressBar`.
func _assert_bar_sane(h, hud, what: String) -> void:
	var ratio: float = hud.xp_ratio()
	h.finite(ratio, "%s: il rapporto XP deve essere un numero finito" % what)
	h.check(ratio >= 0.0 and ratio <= 1.0,
		"%s: il rapporto XP deve stare in [0, 1], e' %s" % [what, ratio])
	# `hud` e' un Variant, quindi `:=` qui dentro non ha un tipo da indovinare: i
	# due numeri sono `float` per la firma e il tipo lo dichiaro.
	var value: float = hud.xp_bar_value()
	var span: float = hud.xp_bar_max()
	h.finite(value, "%s: la barra disegnata deve essere un numero finito" % what)
	h.check(value >= 0.0, "%s: la barra disegnata non puo' essere negativa, e' %s" % [what, value])
	h.check(span > 0.0, "%s: il denominatore della barra non puo' essere zero, altrimenti non si vede" % what)
	h.check(value <= span + 0.0001,
		"%s: la barra disegnata (%s) non puo' superare il suo denominatore (%s)" % [what, value, span])

## La barra dell'onda ha la stessa forma di guardia: finita, dentro [0, 1], e il
## valore disegnato dentro il suo massimo, che e' 1.
func _assert_wave_bar_sane(h, hud, what: String) -> void:
	var ratio: float = hud.wave_ratio()
	h.finite(ratio, "%s: il rapporto d'onda deve essere un numero finito" % what)
	h.check(ratio >= 0.0 and ratio <= 1.0,
		"%s: il rapporto d'onda deve stare in [0, 1], e' %s" % [what, ratio])
	var value: float = hud.wave_bar_value()
	h.finite(value, "%s: la barra d'onda disegnata deve essere un numero finito" % what)
	h.check(value >= 0.0 and value <= 1.0,
		"%s: la barra d'onda disegnata deve stare fra 0 e 1, e' %s" % [what, value])

# --- Parte 2: l'HUD nella partita vera ----------------------------------------

## `scenes/arena_main.tscn` caricata a runtime, non in `const` (vedi la trappola
## in testa al file).
func _open_arena(h, game: Node):
	if not h.check(ResourceLoader.exists(ARENA_SCENE), "manca %s" % ARENA_SCENE):
		return null
	var res = load(ARENA_SCENE)
	if not h.check(res is PackedScene, "%s non e' una PackedScene" % ARENA_SCENE):
		return null
	var arena = (res as PackedScene).instantiate()
	if not h.check(arena is Node3D, "%s non istanzia un Node3D" % ARENA_SCENE):
		if arena != null:
			arena.free()
		return null
	root.add_child(arena)
	return arena as Node3D

## Un avvio della partita vera, verificato come si verifica un boot.
##
## Restituisce un dizionario con i due numeri da confrontare fra gli avvii: i
## nodi dell'HUD e quanti nodi `%Hud` ci sono sotto `root`. Il secondo e' il
## contatore che nessuno dei due test di m1 guarderebbe: se il restart creasse
## un secondo HUD **senza liberare il primo**, il primo sarebbe gia' sparito dalla
## scena e nessun test di numero di nemici lo noterebbe.
func _scene_round(h, game: Node, arena, round_no: int) -> Dictionary:
	if not h.check(arena != null, "avvio %d: la scena non e' stata caricata" % round_no):
		return {"arena": null, "hud_nodes": -1, "huds": -1}
	var hud = arena.get_node_or_null(HUD_NODE)
	if not h.check(hud != null, "avvio %d: la scena deve avere il nodo \"%s\"" % [round_no, HUD_NODE]):
		return {"arena": arena, "hud_nodes": -1, "huds": -1}

	var huds := _count_named(root, HUD_NODE)
	h.eq(huds, 1, "avvio %d: sotto root deve esserci un solo nodo \"%s\": se il restart ne lascia due, nessuno dei test di m1 lo vede" % [round_no, HUD_NODE])

	# L'HUD alimentato dalla scena vera, non a mano: si esegue il `_process` di
	# arena, che e' il chiamante di `set_state` nella partita.
	arena.call("_process", 0.0)
	h.check(hud.enemy_text().contains("200"),
		"avvio %d: la HUD alimentata dalla scena deve mostrare i 200 nemici: \"%s\"" % [round_no, hud.enemy_text()])
	h.eq(hud.wave_number(), 1, "avvio %d: il contatore d'onda parte da 1" % round_no)
	h.check(not hud.game_over_visible(), "avvio %d: nessuna schermata di game over all'avvio" % round_no)

	_xp_from_contract(h, game, hud, round_no)
	_wave_from_contract(h, game, hud, round_no)
	_death_from_contract(h, arena, hud, round_no)

	return {"arena": arena, "hud_nodes": _count_nodes(hud), "huds": huds}

## L'XP che l'HUD espone e' quello che `-gameplay` espone. E' l'unico modo che
## l'HUD abbia di prendere i numeri che non sono suoi: se il campo si chiama
## diversamente da come lo leggo, qui il confronto fallisce invece di lasciare
## una barra a zero che nessuno guarda.
func _xp_from_contract(h, game: Node, hud, round_no: int) -> void:
	var progression = _progression(game)
	if not h.check(progression != null,
			"avvio %d: Game.player non espone \"progression\": l'HUD non ha nulla da leggere" % round_no):
		return

	var raw_xp = progression.get("xp")
	if not h.check(typeof(raw_xp) == TYPE_FLOAT or typeof(raw_xp) == TYPE_INT,
			"avvio %d: Game.player.progression non espone \"xp\": il nome su cui l'HUD fa affidamento non esiste piu'" % round_no):
		return

	# Un valore che non e' quello di partenza, cosi' il confronto non puo'
	# passare perche' due zeri somigliano. Scrivere il campo di -gameplay non e'
	# un suo file: e' il dato pubblico che l'HUD dichiara di leggere.
	progression.set("xp", 3.0)
	hud.refresh()

	# L'atteso e' ricalcolato qui con la formula che l'HUD dichiara, non letto
	# dall'HUD: se lo prendessi dall'HUD starei confrontando l'HUD con se stesso.
	# Parentesi esplicite: `or` e `and` in GDScript non hanno la precedenza che
	# hanno in C, e senza parentesi questa riga finisce per accettare metà dei
	# valori che doveva rifiutare.
	var need := 0.0
	if progression.has_method("xp_to_next"):
		var raw_need = progression.call("xp_to_next")
		if typeof(raw_need) == TYPE_FLOAT or typeof(raw_need) == TYPE_INT:
			need = float(raw_need)
	var span := maxf(need, 0.0001)
	var expected := 0.0 if need <= 0.0 else clampf(3.0 / need, 0.0, 1.0)
	h.near(hud.xp_ratio(), expected, 0.001,
		"avvio %d: la barra deve mostrare l'XP di -gameplay, non un numero proprio" % round_no)
	# Il valore disegnato e' l'XP clampato dentro la soglia: se l'XP supera la
	# soglia la barra si ferma al massimo, e anche quello e' il comportamento
	# giusto da verificare.
	h.near(hud.xp_bar_value(), minf(3.0, span), 0.01,
		"avvio %d: la barra disegnata deve essere l'XP di -gameplay, fermato alla soglia" % round_no)
	_assert_bar_sane(h, hud, "avvio %d, XP presa dal contratto" % round_no)
	_assert_wave_bar_sane(h, hud, "avvio %d, barra d'onda" % round_no)

	progression.set("xp", 0.0)
	hud.refresh()
	h.near(hud.xp_ratio(), 0.0, 0.001, "avvio %d: a zero uccisioni la barra e' vuota" % round_no)

## Il numero d'onda letto dall'orda. La verifica del nome del campo e' di
## `-orda`: se il campo non c'e' ancora, il test lo dice e controlla il valore di
## riserva invece di far fallire l'onda. Non e' una verifica piu' debole: e' la
## stessa verifica rimandata al momento in cui `-orda` dichiara il campo, e
## `hud.gd::_refresh_wave` avvisa con un `push_warning` ogni volta che il campo
## manca, quindi il caso non e' silenzioso in nessuna delle due direzioni.
func _wave_from_contract(h, game: Node, hud, round_no: int) -> void:
	var horde = game.get("horde")
	if not h.check(horde is Object, "avvio %d: Game.horde non e' un oggetto" % round_no):
		return
	var raw = (horde as Object).get("wave")
	if not (typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT):
		print("test_ui: nota, avvio %d: Game.horde non espone ancora \"wave\" (campo di -orda). "
			% round_no
			+ "L'HUD tiene il valore di riserva 1 e avvisa con un push_warning: il nome del campo e' in hud.gd::_refresh_wave.")
		h.eq(hud.wave_number(), 1,
			"avvio %d: senza un campo wave nell'orda l'HUD deve tenere il valore di riserva 1" % round_no)
		return

	# Scrittura e rilettura: se il campo di -orda non e' scrivibile il confronto
	# seguente non avrebbe niente da confrontare, e va detto che il test non ha
	# potuto provarlo invece di far passare una verifica non eseguita.
	(horde as Object).set("wave", 3)
	if not h.check((horde as Object).get("wave") == 3,
			"avvio %d: non si puo' far avanzare l'onda di -orda scrivendo \"wave\": il campo e' di sola lettura e questo test non puo' verificare che l'HUD lo segua" % round_no):
		return
	hud.refresh()
	h.eq(hud.wave_number(), 3,
		"avvio %d: quando l'orda passa a wave 3 il contatore dell'HUD deve dire 3" % round_no)
	h.check(hud.wave_text().contains("3"),
		"avvio %d: la scritta del contatore deve dire 3: \"%s\"" % [round_no, hud.wave_text()])
	(horde as Object).set("wave", 1)
	hud.refresh()
	h.eq(hud.wave_number(), 1, "avvio %d: il contatore torna a 1" % round_no)

	# La barra dell'onda segue il numero di `-orda` e non una formula ricostruita
	# qui dentro: se l'HUD calcolasse "quanto manca" per conto suo, le due barre
	# divergerebbero e nessuno dei due test di m1 lo vedrebbe.
	if (horde as Object).has_method("wave_bar_ratio"):
		var expected: float = horde.call("wave_bar_ratio")
		h.finite(expected, "avvio %d: wave_bar_ratio() di -orda deve essere un numero" % round_no)
		h.near(hud.wave_ratio(), expected, 0.001,
			"avvio %d: la barra dell'HUD deve essere il numero di -orda, non uno ricalcolato" % round_no)
		h.near(hud.wave_bar_value(), expected, 0.001,
			"avvio %d: la barra d'onda disegnata deve essere il numero di -orda" % round_no)
	else:
		print("test_ui: nota, avvio %d: Game.horde non espone ancora \"wave_bar_ratio()\": "
			% round_no
			+ "la barra dell'onda resta al valore di riserva e non e' disegnata. Il nome e' in hud.gd::_refresh_wave_progress.")

## La morte: a 0 HP la schermata compare, e `arena` e' il chiamante che porta
## quel numero all'HUD. Il percorso e' quello vero, non `set_game_over(true)`
## scritto a mano: la schermata deve comparire perche' il giocatore e' morto,
## non perche' qualcuno si e' ricordato di dirlo.
func _death_from_contract(h, arena, hud, round_no: int) -> void:
	var player = arena.get_node_or_null("Player")
	if not h.check(player is Object, "avvio %d: la scena deve avere il nodo Player" % round_no):
		return
	player.set("hp", 0.0)
	arena.call("_process", 0.0)
	h.check(hud.game_over_visible(),
		"avvio %d: il player a 0 HP deve mostrare la schermata di game over" % round_no)
	h.check(hud.health_ratio() <= 0.001,
		"avvio %d: a 0 HP anche la barra della vita deve essere vuota" % round_no)

	# E il ritorno: il restart rimette il giocatore in piedi, quindi la
	# schermata non deve essere un'insegna appesa per sempre.
	player.set("hp", 100.0)
	arena.call("_process", 0.0)
	h.check(not hud.game_over_visible(),
		"avvio %d: tornato in vita il giocatore, la schermata di game over deve sparire" % round_no)

# --- Interno -------------------------------------------------------------------

func _progression(game: Node):
	var player = game.get("player")
	if not (player is Object):
		return null
	var progression = (player as Object).get("progression")
	if not (progression is Object):
		return null
	return progression as Object

## Un nodo e tutto quello che ha sotto, ricorsivamente.
func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total

## Quanti nodi chiamati `wanted` ci sono sotto `node`, ricorsivamente. Serve a
## contare gli HUD duplicati, che sono **fuori** dalla scena: un nodo lasciato
## appeso sotto `root` non e' raggiungibile da `arena.get_node("Hud")`, quindi il
## confronto con la scena non lo troverebbe mai.
func _count_named(node: Node, wanted: String) -> int:
	var total := 1 if node.name == wanted else 0
	for child in node.get_children():
		total += _count_named(child, wanted)
	return total

func _instantiate(path: String):
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if not (res is PackedScene):
		return null
	return (res as PackedScene).instantiate()

## Libera la scena **senza lasciare appeso nessun nodo**: `remove_child` e poi
## `free`, non `queue_free`. Il contratto continua a puntare all'orda e al
## giocatore liberati fino a che i nuovi non si registrano, e proprio li' che
## `hud.gd::refresh()` deve sopravvivere senza chiamare un metodo su un'istanza
## liberata: e' la ragione per cui il terzo avvio e' il piu' severo.
func _close(arena) -> void:
	if arena == null:
		return
	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()
