extends SceneTree
## Test del ciclo di partita: onda, game over, restart. terminal-gun-orda, m2.
##
## Criterio n. 4 della milestone 2 (piano sez. 1.1), nella parte che e' di -orda:
##
##   1. uccisi i nemici dell'onda corrente e la **barra wave a 0** -> l'onda
##      successiva parte con il contatore++;
##   2. giocatore a 0 HP -> stato `game_over`;
##   3. `restart_run()` -> onda 1, `horde.count` azzerato e **ripopolato**, nessun
##      nodo duplicato.
##
## E il criterio n. 3 di m1, che non deve regredire: `horde.count == 200` con
## `node_count < 120`, misurato sulla **scena vera**, non su un'orda costruita in
## isolamento.
##
## ## Le due parti, e perche' due
##
## **Parte 1, orda isolata** (`src/sim/horde.gd` costruita da questo test): la
## scala delle onde e il restart, con numeri che il test sceglie. Niente
## giocatore e niente scena: e' l'unica parte che puo' contare 230 uccisioni
## senza che l'arma del giocatore ne faccia qualcuna per conto suo.
##
## **Parte 2, scena vera** (`scenes/arena_main.tscn`): il `game_over`. La morte
## la vede solo chi ha un giocatore sotto il naso, e l'unico giocatore del
## progetto e' quello di -gameplay: qui lo si raggiunge **per contratto**
## (`Game.player`), non con `get_node("../..")` e non chiamando `player.gd`.
##
## ## La meta' del restart che NON e' mia, dichiarata
##
## `restart_run()` azzera e ripopola l'orda e la partita, e **non tocca il
## giocatore**: rimetterlo in piedi (vite, potenziamenti, arma) e' la meta' di
## -gameplay, e il suo test. Questo file verifica **la meta' di -orda** e dice
## ad alta voce, con un numero, cosa succede se la meta' di -gameplay non
## arrives: il passo di simulazione successivo rilegge `hp == 0` e la partita si
## rimette in `game_over`. Non e' un difetto: e' la divisione del lavoro
## dichiarata, resa misurabile invece che promessa.
##
## ## La trappola del `const preload` (piano sez. 5.3)
##
## `scenes/arena_main.tscn` si carica con `load()` **dentro il corpo del test**,
## mai in `const`: un `const preload` risolve gli script a tempo di compilazione,
## PRIMA che l'autoload `Game` sia fra le costanti globali, e `player.gd` usa
## l'identificatore nudo `Game`. Solo `src/sim/` e `tools/test_harness.gd` sono
## in `const`, e nessuno dei due tocca il contratto.
##
## Stringhe a schermo solo ASCII: la console di Windows e il pipe di
## `OS.execute` sono in codepage e mangiano gli accenti.

const H = preload("res://tools/test_harness.gd")
const HORDE = preload("res://src/sim/horde.gd")
const RUN = preload("res://src/sim/run.gd")
const E = preload("res://src/sim/enemy.gd")
const GRID = preload("res://src/sim/spatial_grid.gd")

const ARENA_SCENE := "res://scenes/arena_main.tscn"
## Passo di simulazione: quello di `tests/test_orda.gd`, cosi' i due numeri di
## -orda sono confrontabili. Un passo fisso e' l'unica misura riproducibile.
const DT := 1.0 / 60.0
## Nome del nodo dell'orda nella scena vera (`scenes/arena_main.tscn`). Serve al
## controllo sui nodi duplicati: un secondo nodo con questo nome non si vedrebbe
## contando i nodi, perche' un totale puo' restare uguale.
const NODO_HORDE := "Horde"
## Tetto del criterio n. 3 della milestone 1, con 200 nemici vivi.
const TETTO_NODI := 120

var _horde: HORDE = null

func _initialize() -> void:
	# L'orda isolata entra nell'albero qui, come in `tests/test_orda.gd`: sotto
	# `--script` l'entrata nell'albero di un nodo passato dalla `_initialize()`
	# attraversa la coda di messaggi, quindi il suo `_ready()` non e' ancora
	# partito quando questa funzione torna. Il corpo del test gira al primo
	# frame, in `_process`.
	_horde = HORDE.new()
	_horde.name = "OrdaDiTest"
	# Il passo di simulazione lo guida il test, a mano. Senza questo, un tick di
	# fisica fra `_initialize()` e `_process()` sposterebbe i nemici una volta
	# senza che nessuno l'abbia chiesto, e il test misurerebbe un mondo diverso
	# da quello che dichiara di misurare.
	_horde.set_physics_process(false)
	root.add_child(_horde)

func _process(_delta: float) -> bool:
	_run()
	return true

func _run() -> void:
	var h := H.new()
	# Senza tipo dichiarato: il contratto e' un nodo che dichiara metodi che
	# `Node` non ha, quindi su una variabile tipizzata la chiamata non
	# compilerebbe. Qui si naviga per `get()` e per nome, che e' anche la strada
	# che fanno le foglie sotto `--script`.
	var game = _game()
	if not h.check(game != null,
			"l'autoload Game non e' stato istanziato: nessun test puo' girare"):
		quit(h.finish("test_gameloop"))
		return

	_apertura(h, _horde)
	_onde(h, _horde)
	_rientro_in_gioco(h, _horde)
	_restart(h, _horde, game)

	_scena_vera(h, game)

	# La superficie si verifica **dentro** `_scena_vera`, con l'orda ancora viva:
	# fuori, `Game.horde` punta a un nodo liberato e il contratto risponderebbe
	# "manca" per un registro che c'e'. E li' e' anche il posto giusto: la
	# superficie di m2 e' cio' che le foglie si scambiano **sulla scena vera**.
	_nessun_nodo_appeso(h)
	quit(h.finish("test_gameloop"))

# --- Parte 1, numero 1: l'avvio ------------------------------------------------

## Lo stato iniziale: il numero e' preso dal contratto di `run.gd`, non riscritto
## qui. Se le due copie divergono, il test mente sulla barra dell'onda.
func _apertura(h, horde: HORDE) -> void:
	h.eq(horde.count, 200, "200 nemici vivi al primo frame")
	h.eq(horde.transforms.size(), horde.count,
		"transforms e' lunga quanto count: e' l'invariante che arena usa per il MultiMesh")
	h.eq(horde.colors.size(), horde.count, "un colore per nemico")

	h.eq(horde.wave, 1, "si parte dall'onda 1")
	h.eq(horde.run_state(), "playing", "la partita e' in corso")
	h.check(not horde.is_game_over(), "nessun game over all'avvio")

	h.eq(horde.wave_total(), RUN.WAVE_BASE,
		"la barra dell'onda 1 si chiude con le uccisioni che si vedono al primo frame")
	h.eq(horde.wave_total(), RUN.wave_size(1),
		"e quel numero e' la tabella di run.gd, non una copia nel test")
	h.eq(horde.wave_killed(), 0, "nessuna uccisione all'avvio")
	h.eq(horde.wave_remaining(), horde.wave_total(), "la barra parte piena")
	h.near(horde.wave_bar_ratio(), 1.0, 0.0001, "la barra d'onda parte da 1")
	h.near(horde.wave_hp_scale(), 1.0, 0.0001,
		"sull'onda 1 il moltiplicatore di vita e' 1.0 esatto: le tabelle di m1 non cambiano")
	h.near(horde.wave_hp_scale(), RUN.hp_scale_of(1), 0.0001,
		"e il moltiplicatore viene dalla scala di run.gd")

	_specchio(h, horde, "all'avvio")
	_orda_sana(h, horde, "all'avvio")
	print("gameloop: avvio, onda %d, barra %d/%d, scala vita %.2f, %d nemici"
		% [horde.wave, horde.wave_killed(), horde.wave_total(),
			horde.wave_hp_scale(), horde.count])

# --- Parte 1, numero 1: il cambio d'onda --------------------------------------

## Uccidere tutta l'onda e guardare il contatore salire di uno, tre volte: dalla
## 1 alla 2, dalla 2 alla 3, e di nuovo dentro il ciclo di gioco.
func _onde(h, horde: HORDE) -> void:
	for wave_da in [1, 2]:
		var giri := _svuota_onda(h, horde, wave_da)
		h.eq(horde.wave, wave_da + 1,
			"uccisa l'onda %d con la barra a 0: parte l'onda successiva con il contatore++" % wave_da)
		h.eq(horde.wave_total(), RUN.wave_size(wave_da + 1),
			"l'onda %d si chiude con %d uccisioni" % [wave_da + 1, RUN.wave_size(wave_da + 1)])
		h.eq(horde.wave_killed(), 0, "la barra riparte da zero nella nuova onda")
		h.eq(horde.wave_remaining(), horde.wave_total(), "la barra e' di nuovo piena")
		h.near(horde.wave_bar_ratio(), 1.0, 0.0001, "e il rapporto torna a 1")
		h.near(horde.wave_hp_scale(), RUN.hp_scale_of(wave_da + 1), 0.0001,
			"la scala delle vite cresce con l'onda")
		h.eq(horde.run_state(), "playing", "cambiare onda non e' finire la partita")
		_specchio(h, horde, "dopo il passaggio all'onda %d" % (wave_da + 1))
		_orda_sana(h, horde, "sull'onda %d" % (wave_da + 1))
		_barra_sana(h, horde, "sull'onda %d" % (wave_da + 1))

	# La barra, non il campo. Un'onda da 230 uccisioni con 200 vivi non può
	# diventare vuota al momento giusto, quindi una fine d'onda che guardasse il
	# campo non finirebbe mai: e' il numero che distingue un bullet heaven da
	# un'orda sola.
	h.check(RUN.wave_size(2) > HORDE.MAX_ENEMIES,
		"l'onda 2 chiede %d uccisioni con %d nemici vivi: il campo da solo non puo' chiuderla"
			% [RUN.wave_size(2), HORDE.MAX_ENEMIES])
	print("gameloop: onde 1->3 superate, %d uccisioni in tutto, scala vita ora %.2f"
		% [horde.kills, horde.wave_hp_scale()])

## Svuota l'onda `wave_da` e restituisce quanti passi di riempimento sono
## serviti. `damage_enemy` uccide subito, ma il cambio d'onda avviene al passo
## di simulazione successivo: e' l'ordine che `horde.gd::_wave_tick` dichiara, e
## qui viene verificato invece che supposto.
func _svuota_onda(h, horde: HORDE, wave_da: int) -> int:
	h.eq(horde.wave, wave_da, "si parte dall'onda %d" % wave_da)
	var bersaglio := horde.wave_total()
	var giri := 0
	while horde.wave == wave_da and giri < 40:
		giri += 1
		# Il contratto, non solo il metodo diretto: e' la strada che il gioco usa.
		_kill_uno(horde)
		while horde.count > 0:
			if not _kill_uno(horde):
				break
		if horde.wave_killed() >= bersaglio:
			h.eq(horde.wave_remaining(), 0,
				"bersaglio raggiunto con %d uccisioni: la barra e' a 0" % horde.wave_killed())
			h.near(horde.wave_bar_ratio(), 0.0, 0.0001, "e il rapporto della barra e' a 0")
			h.eq(horde.wave, wave_da,
				"le uccisioni da sole non cambiano onda: il cambio avviene al passo")
		_barra_sana(h, horde, "durante l'onda %d" % wave_da)
		horde.step(DT)
	return giri

## Una uccisione attraverso il **contratto**, non solo attraverso il metodo
## diretto: e' la strada che il gioco usa, e il suo valore di ritorno dice chi e'
## morto (piano sez. 5.2). Se il contratto non puntasse a questa orda, si cadebbe
## sul metodo diretto: i due numeri devono essere lo stesso, e qui si vede.
func _kill_uno(horde: HORDE) -> bool:
	var game = _game()
	if game != null and game.get("horde") == horde:
		return game.damage_enemy(0, 9999.0, Vector3.ZERO)
	return horde.damage_enemy(0, 9999.0, Vector3.ZERO)

# --- Parte 1: 600 passi, e un cambio d'onda dentro -----------------------------

## La milestone 1 chiedeva che 600 aggiornamenti non stampino errori e non
## gonfino niente. Qui il giro e' diverso e serve a m2: i 600 passi **attraversano
## un cambio d'onda**, che e' il posto dove si riempie l'orda, quindi e' li' che
## un'allocazione nel ciclo di gioco si farebbe vedere.
func _rientro_in_gioco(h, horde: HORDE) -> void:
	var wave_iniziale := horde.wave
	var nodi0 := _count_nodes(root)
	var obj0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var mem0 := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var morti := 0

	for s in 600:
		horde.step(DT)
		# un'uccisione ogni due passi: la barra dell'onda corrente (230) si
		# chiude a meta' del cammino, quindi un cambio d'onda avviene dentro il
		# ciclo e non ai bordi
		if s % 2 == 0 and horde.count > 0:
			if _kill_uno(horde):
				morti += 1

	h.eq(horde.wave, wave_iniziale + 1,
		"un'uccisione ogni due passi per 600 passi attraversa esattamente un confine d'onda")
	h.check(horde.wave_killed() > 0, "l'onda corrente non e' finita")
	h.eq(horde.count, HORDE.MAX_ENEMIES, "l'orda torna piena dopo il riempimento")
	h.eq(horde.transforms.size(), horde.count, "allineata dopo 600 passi")
	h.eq(horde.hp.size(), horde.count, "anche hp allineata dopo 600 passi")
	h.eq(horde.grid_unknown_cells, 0,
		"nessuna cella nuova dopo 600 passi e un cambio d'onda: nel ciclo non si alloca")
	h.check(not horde.grid_overflowed(), "nessun secchiello traboccato")
	_specchio(h, horde, "dopo 600 passi")
	_barra_sana(h, horde, "dopo 600 passi")

	var nodi1 := _count_nodes(root)
	var obj1 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var mem1 := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	h.eq(nodi1, nodi0, "600 passi non aggiungono nodi")
	h.check(obj1 <= obj0 + 16,
		"600 passi non aggiungono oggetti: %d contro %d" % [obj1, obj0])
	h.check(mem1 - mem0 < 4 * 1024 * 1024,
		"600 passi non gonfiano la memoria: +%d KB" % ((mem1 - mem0) / 1024))

	# e nessuna posizione spazzatura, che e' il modo in cui un array parallelo
	# disallineato si manifesta
	var spazzatura := 0
	for i in horde.count:
		var p := horde.transforms[i]
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
			spazzatura += 1
	h.eq(spazzatura, 0, "nessun nemico con una posizione spazzatura dopo 600 passi")
	print("gameloop: 600 passi e %d uccisioni, onda %d -> %d, nodi %d -> %d, oggetti %d -> %d, memoria +%d KB"
		% [morti, wave_iniziale, horde.wave, nodi0, nodi1, obj0, obj1, (mem1 - mem0) / 1024])

# --- Parte 1, numero 3: il restart --------------------------------------------

## `restart_run()` tre volte di fila. Il numero da guardare non e' `wave == 1`:
## e' che **l'orda e' di nuovo piena** e che **il numero di nodi non e' cambiato**,
## perche' un restart che ricrea l'orda da zero sembra funzionante e lascia
## appeso un nodo per nemico.
func _restart(h, horde: HORDE, game) -> void:
	var nodi0 := _count_nodes(root)
	var hordi0 := _count_named(root, NODO_HORDE)
	# L'oggetto partita non deve essere ricreato: `run` e' creato una volta sola
	# in `_build()` e un restart che lo sostituisce cambierebbe l'identita' di
	# tutto quello che lo guarda.
	var run_prima = horde.run

	for giro in 3:
		horde.restart_run()
		h.eq(horde.wave, 1, "restart %d: si torna all'onda 1" % (giro + 1))
		h.eq(horde.run_state(), "playing", "restart %d: la partita riparte" % (giro + 1))
		h.check(not horde.is_game_over(), "restart %d: niente game over" % (giro + 1))
		h.eq(horde.wave_total(), RUN.WAVE_BASE, "restart %d: la barra riparte piena" % (giro + 1))
		h.eq(horde.wave_killed(), 0, "restart %d: nessuna uccisione contata" % (giro + 1))
		h.eq(horde.wave_remaining(), RUN.WAVE_BASE, "restart %d: restano tutti da ammazzare" % (giro + 1))
		h.near(horde.wave_bar_ratio(), 1.0, 0.0001, "restart %d: rapporto della barra a 1" % (giro + 1))
		h.near(horde.wave_hp_scale(), 1.0, 0.0001,
			"restart %d: la scala delle vite torna a 1.0, le tabelle di m1 sono quelle di prima" % (giro + 1))
		h.eq(horde.kills, 0, "restart %d: il contatore delle uccisioni riparte" % (giro + 1))
		h.eq(horde.count, HORDE.MAX_ENEMIES,
			"restart %d: horde.count azzerato e RIPOPOLATO" % (giro + 1))
		h.eq(horde.transforms.size(), horde.count, "restart %d: transforms allineata" % (giro + 1))
		h.eq(horde.colors.size(), horde.count, "restart %d: colors allineata" % (giro + 1))
		_specchio(h, horde, "restart %d" % (giro + 1))
		_orda_sana(h, horde, "restart %d" % (giro + 1))
		h.eq(_count_nodes(root), nodi0,
			"restart %d: nessun nodo creato. Un restart che ricreasse l'orda lascerebbe appeso un nodo per nemico" % (giro + 1))
		h.eq(horde.get_child_count(), 0, "restart %d: l'orda non ha figli" % (giro + 1))

	h.check(horde.run == run_prima,
		"restart_run() non ricrea l'oggetto partita: chi lo tiene per nome continua a vedere lo stesso")
	h.eq(game.get("horde"), horde,
		"restart_run() non cambia l'istanza registrata sul contratto")

	# Un restart su un'orda svuotata a meta' e' lo stesso caso: e' il percorso
	# vero dal game over, dove il campo e' spesso mezzo vuoto.
	for _i in 37:
		_kill_uno(horde)
	horde.restart_run()
	h.eq(horde.count, HORDE.MAX_ENEMIES, "restart dopo 37 uccisioni: l'orda e' di nuovo piena")
	h.eq(horde.wave, 1, "restart dopo 37 uccisioni: onda 1")
	h.eq(_count_nodes(root), nodi0, "restart dopo 37 uccisioni: nessun nodo in piu'")
	print("gameloop: 4 restart, %d nodi prima e dopo, un nodo \"%s\" sotto root"
		% [nodi0, NODO_HORDE])

# --- Parte 2: la scena vera ----------------------------------------------------

## Il `game_over` e la sua fine, sulla scena che il gioco avvia davvero.
func _scena_vera(h, game) -> void:
	var arena = _apri_arena(h)
	if arena == null:
		return
	var horde := arena.get_node_or_null(NODO_HORDE) as HORDE
	if not h.check(horde != null, "la scena deve avere il nodo \"%s\"" % NODO_HORDE):
		_chiudi(arena)
		return
	# L'orda della scena e' quella registrata sul contratto: e' la stessa
	# istanza su cui il giocatore spara e su cui l'interfaccia legge i numeri.
	h.check(game.get("horde") == horde, "Game.horde e' l'orda della scena vera")
	var player = game.get("player")
	if not h.check(player is Node,
			"Game.player non e' un nodo: il game_over e' la meta' che non si puo' verificare"):
		_chiudi(arena)
		return

	# Il criterio n. 3 della milestone 1, rimesurato: se m2 aggiungesse un nodo
	# per nemico, e' qui che lo si vede.
	h.eq(horde.count, HORDE.MAX_ENEMIES, "nella scena vera ci sono %d nemici vivi" % HORDE.MAX_ENEMIES)
	h.eq(horde.transforms.size(), horde.count, "e transforms e' allineata")
	var nodi := _count_nodes(root)
	h.check(nodi < TETTO_NODI,
		"criterio n. 3 di m1 non regredisce: %d nemici vivi con %d nodi (tetto %d)"
			% [horde.count, nodi, TETTO_NODI])
	h.eq(horde.wave, 1, "la partita vera parte dall'onda 1")
	h.eq(horde.run_state(), "playing", "e la partita e' in corso")
	h.eq(horde.wave_remaining(), horde.wave_total(), "con la barra piena")
	h.eq(_count_named(root, NODO_HORDE), 1,
		"sotto root un solo nodo \"%s\": il totale dei nodi non lo direbbe" % NODO_HORDE)

	_game_over(h, horde, player)
	_riavvio(h, horde, player, game)

	# La superficie di m2 qui, **prima** di `_chiudi`: `verify_m2_surface()`
	# legge `Game.horde`, e dopo la chiusura quel campo punta a un nodo liberato.
	# Fuori, il contratto direbbe "manca" per un registro che c'e' gia': un test
	# che misura il registro invece del contratto, che e' quello che si vuole
	# sapere.
	_superficie(h, game, horde)

	_chiudi(arena)
	h.eq(_count_named(root, NODO_HORDE), 0,
		"la scena chiusa non lascia l'orda appesa sotto root: un nodo liberato a meto resta raggiungibile")

## Giocatore a 0 vite -> la partita e' finita, e la simulazione si ferma.
func _game_over(h, horde: HORDE, player) -> void:
	var wave_prima := horde.wave
	var ferma := horde.transforms.duplicate()
	# Il percorso vero: la vita arriva a zero e la simulazione se ne accorge al
	# passo successivo leggendo il contratto. Non si chiama `enter_game_over()`:
	# quello e' il pulsante, non la morte.
	player.set("hp", 0.0)
	h.eq(horde.run_state(), "playing",
		"scrivere hp a 0 non cambia lo stato da solo: lo cambia il passo di simulazione")
	horde.step(DT)
	h.eq(horde.run_state(), "game_over",
		"a 0 HP lo stato passa a game_over: e' la fine della partita (criterio n. 4)")
	h.check(horde.is_game_over(), "is_game_over() dice la stessa cosa")
	h.eq(horde.wave, wave_prima, "il game_over non cambia il numero d'onda")

	# La parte che distingue "la partita e' finita" da "la partita continua ma
	# non si vede piu' niente": a `game_over` nessuno si muove piu'.
	for _i in 5:
		horde.step(DT)
	h.eq(horde.transforms, ferma, "cinque passi a partita finita: nessun nemico si e' mosso")
	h.eq(horde.count, ferma.size(), "e nessuno e' nato o morto")
	h.check(horde.is_game_over(), "resta game_over: da solo non si torna indietro")

## Il restart della scena vera: la meta' di -orda, e la dichiarazione esplicita
## di quella che non e' sua.
func _riavvio(h, horde: HORDE, player, game) -> void:
	var nodi0 := _count_nodes(root)
	horde.restart_run()

	h.eq(horde.wave, 1, "restart: si torna all'onda 1")
	h.eq(horde.run_state(), "playing", "restart: la partita riparte")
	h.check(not horde.is_game_over(), "restart: niente game_over")
	h.eq(horde.wave_remaining(), horde.wave_total(), "restart: la barra e' piena")
	h.near(horde.wave_bar_ratio(), 1.0, 0.0001, "restart: rapporto della barra a 1")
	h.eq(horde.count, HORDE.MAX_ENEMIES, "restart: horde.count azzerato e RIPOPOLATO")
	h.eq(horde.transforms.size(), horde.count, "restart: transforms allineata di nuovo")
	h.eq(horde.wave_killed(), 0, "restart: nessuna uccisione contata")
	h.eq(_count_nodes(root), nodi0,
		"restart: nessun nodo duplicato. Il numero di nodi non puo' cambiare invece di dover essere controllato")
	h.eq(_count_named(root, NODO_HORDE), 1, "restart: un solo nodo orda sotto root")
	h.check(game.get("horde") == horde, "restart: l'istanza registrata non e' cambiata")

	# ## LA META' DI -GAMEPLAY, DICHIARATA CON UN NUMERO
	#
	# `restart_run()` non tocca il giocatore: e' scritto nella sua documentazione
	# ed e' verificato qui, non supposto. Il giocatore e' di -gameplay e il suo
	# restart (vite, potenziamenti, arma) e' un altro file: questo test non lo
	# chiama e non lo simula.
	var hp_ora: float = player.get("hp")
	if hp_ora <= 0.0:
		print("gameloop: META' DI -GAMEPLAY: restart_run() non ha rimesso in piedi il giocatore (hp %s)." % hp_ora)
		print("gameloop:   al passo di simulazione successivo l'orda rilegge hp == 0 e la partita torna in game_over.")
		horde.step(DT)
		h.check(horde.is_game_over(),
			"con le vite ancora a zero la partita si rimette in game_over: e' la meta' di -gameplay, non un difetto di restart_run()")
	else:
		print("gameloop: nota: dopo restart_run() il giocatore risulta gia' in piedi (hp %s): "
			% hp_ora + "il contratto di restart_run() cambia, e questo test lo sta ancora verificando sul numero di 0 HP")

	# Rimettere le vite **senza** restart non deve riportare la partita in corso.
	# Non e' un caso difettoso e' il contratto di `run.gd`: `enter_game_over()` e'
	# a senso unico ("l'unica strada che riporta a PLAYING e' restart()"), perche'
	# un nemico che si risana da solo e' un nemico tornato vivo senza essere
	# stato ucciso. Riprendere a giocare e' una **decisione**, e la decisione e'
	# il restart, non un hp che sale per un motivo che nessuno ha chiesto.
	#
	# La prima versione di questo test affermava il contrario ("rimesso in piedi
	# il giocatore, la partita non e' piu' in game_over") ed era **sbagliata**:
	# pretendeva che `step()` sapesse distinguere "vite ripristinate dal restart"
	# da "vite risanate durante la partita", e non puo' distinguerlo perche' la
	# sola informazione che ha e' un numero.
	player.set("hp", 50.0)
	horde.step(DT)
	h.check(horde.is_game_over(),
		"vite rimesse senza restart la partita resta finita: il game_over e' a senso unico")
	h.eq(horde.run_state(), "game_over", "e lo stato non e' tornato in corso da solo")

	# Il restart vero: -gameplay rimette in piedi il giocatore e **poi** chiama
	# `restart_run()`. E' l'ordine con cui il pulsante di restart lavora, ed e'
	# quello che qui viene verificato numericamente.
	horde.restart_run()
	horde.step(DT)
	h.check(not horde.is_game_over(),
		"restart con il giocatore in piedi: la partita riprende")
	h.eq(horde.run_state(), "playing", "e lo stato e' tornato in corso")
	h.eq(horde.wave, 1, "sull'onda 1")
	h.eq(horde.count, HORDE.MAX_ENEMIES, "e l'orda e' di nuovo piena")
	h.eq(_count_nodes(root), nodi0, "e nessun nodo e' comparso nel frattempo")
	var quieta := horde.transforms.duplicate()
	horde.step(DT)
	h.check(horde.transforms != quieta,
		"e i nemici si muovono di nuovo: il mondo non era fermo per sempre")

# --- Parte 3: la superficie di m2 dichiarata nel contratto ---------------------

## `M2_SURFACE` elenca i membri che le tre foglie di m2 si scambiano, con
## proprietario. Le voci di **-orda** sono un criterio mio e falliscono qui se
## mancano; quelle delle altre due foglie sono una nota: sono il loro deliverable
## e fallire qui sarebbe far fallire il mio test per un file che non e' mio.
func _superficie(h, game, horde: HORDE) -> void:
	h.check(not horde.has_method("wave"),
		"\"wave\" resta un CAMPO e non diventa wave(): src/ui/hud.gd lo legge per nome e un metodo lo farebbe tacere")

	var mancanti: Array = game.call("verify_m2_surface")
	var miei: Array[String] = []
	var altrui: Array[String] = []
	for row in mancanti:
		var testo := str(row)
		if testo.begins_with("terminal-gun-orda"):
			miei.append(testo)
		else:
			altrui.append(testo)
	h.check(miei.is_empty(),
		"la superficie di m2 dichiara nove membri di -orda e tutti e nove ci sono: %s" % ", ".join(miei))
	if not altrui.is_empty():
		print("gameloop: nota, voci di m2 non ancora a posto (non sono scope di -orda): %s" % ", ".join(altrui))

	for nome in ["wave_total", "wave_remaining", "wave_killed", "wave_bar_ratio",
			"wave_hp_scale", "run_state", "is_game_over", "restart_run"]:
		h.check(horde.has_method(nome),
			"l'orda espone %s(): e' il nome con cui le altre due foglie lo chiamano" % nome)

# --- Interno ------------------------------------------------------------------

## Il campo `wave` e' uno **specchio** di `run.wave`. Uno specchio allineato in
## tre punti si puo' controllare a occhio, uno allineato "quando capita" no: e'
## il numero che il contatore d'onda dell'interfaccia mostra.
func _specchio(h, horde: HORDE, dove: String) -> void:
	var run = horde.run
	h.eq(horde.wave, int(run.wave),
		"%s: il campo wave deve combaciare con run.wave (l'HUD legge il campo)" % dove)

## La barra e' un numero: finito e dentro [0, 1]. Il difetto che questa guardia
## copre e' una barra a NaN, che non si vede e non viene segnalata da nient'altro.
func _barra_sana(h, horde: HORDE, dove: String) -> void:
	var r: float = horde.wave_bar_ratio()
	h.finite(r, "%s: wave_bar_ratio() deve essere un numero" % dove)
	h.check(r >= 0.0 and r <= 1.0, "%s: wave_bar_ratio() deve stare in [0, 1], e' %s" % [dove, r])
	h.check(horde.wave_remaining() >= 0, "%s: la barra non puo' essere negativa" % dove)
	h.eq(horde.wave_remaining(), maxi(0, horde.wave_total() - horde.wave_killed()),
		"%s: la barra e' wave_total - wave_killed" % dove)

## Gli array paralleli allineati a `count`, nessun nemico spazzatura, nessuno
## fuori dal mondo, e la vita di ciascuno pari alla tabella della specie per la
## scala dell'onda corrente.
func _orda_sana(h, horde: HORDE, dove: String) -> void:
	h.eq(horde.transforms.size(), horde.count, "%s: transforms allineata a count" % dove)
	h.eq(horde.colors.size(), horde.count, "%s: colors allineata a count" % dove)
	h.eq(horde.hp.size(), horde.count, "%s: hp allineata a count" % dove)
	h.eq(horde.kinds.size(), horde.count, "%s: kinds allineata a count" % dove)
	h.eq(horde.velocities.size(), horde.count, "%s: velocities allineata a count" % dove)
	var scala := horde.wave_hp_scale()
	var spazzatura := 0
	var fuori := 0
	var morti := 0
	var vita_sbagliata := 0
	for i in horde.count:
		var p := horde.transforms[i]
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
			spazzatura += 1
		elif Vector2(p.x, p.z).length() > horde.arena_radius * 1.5:
			fuori += 1
		var tabella := E.hp_of(horde.kinds[i])
		if horde.hp[i] <= 0.0:
			morti += 1
		elif absf(horde.hp[i] - tabella * scala) > maxf(0.01, tabella * 0.001):
			vita_sbagliata += 1
	h.eq(spazzatura, 0, "%s: nessuna posizione spazzatura" % dove)
	h.eq(fuori, 0, "%s: nessun nemico uscito dal mondo" % dove)
	h.eq(morti, 0, "%s: nessun nemico vivo con vita esaurita" % dove)
	h.eq(vita_sbagliata, 0,
		"%s: la vita di ogni nemico e' la tabella della specie per la scala %.2f dell'onda" % [dove, scala])

## `scenes/arena_main.tscn` caricata a runtime, non in `const` (vedi la trappola
## in testa al file).
func _apri_arena(h):
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

## Libera la scena senza lasciare appeso nessun nodo: `remove_child` e poi
## `free`, non `queue_free`, cosi' l'albero e' pulito **subito** e il conteggio dei
## nodi dopo e' un numero e non una promessa.
func _chiudi(arena) -> void:
	if arena == null:
		return
	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()

## Dopo tutta la partita vera l'albero deve contenere solo l'orda isolata di
## questo test: una scena lasciata viva o un nodo liberato a meta' mostrerebbero
## un numero di nodi sbagliato per tutti i test che vengono dopo.
func _nessun_nodo_appeso(h) -> void:
	h.eq(_count_named(root, NODO_HORDE), 0, "dopo la scena vera non resta nessuna orda sotto root")
	h.check(_horde != null and _horde.is_inside_tree(),
		"l'orda isolata del test e' ancora viva: e' l'unica che questo test si porta dietro")

## Il contratto, via nodo e non via identificatore nudo: sotto `--script` il
## file principale viene compilato **prima** che l'autoload `Game` sia fra le
## costanti globali di GDScript, e `Game.horde` qui dentro non da un errore di
## logica, da `Compile Error: Identifier not found: Game`. Il nodo che si ottiene
## e' lo stesso identico singleton su cui horde.gd si registra (piano 5.3).
func _game() -> Node:
	return root.get_node_or_null("Game")

## I nodi dell'albero contati davvero: `get_node_count()` dentro un `--script`
## vale 0, perche' il ciclo di frame non e' ancora partito, e un test che ci si
## appoggiasse passerebbe sempre.
func _count_nodes(nodo: Node) -> int:
	var totale := 1
	for c in nodo.get_children():
		totale += _count_nodes(c)
	return totale

## Quanti nodi chiamati `wanted` ci sono sotto `nodo`, ricorsivamente. Serve a
## contare i duplicati, che un totale non vede: due orde e un'orda morta fanno
## lo stesso numero di nodi.
func _count_named(nodo: Node, wanted: String) -> int:
	var totale := 1 if nodo.name == wanted else 0
	for c in nodo.get_children():
		totale += _count_named(c, wanted)
	return totale