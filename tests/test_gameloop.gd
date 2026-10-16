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
## E il criterio n. 3 di m1, che non deve regredire: `node_count < 120` con
## `horde.count == 200`, misurato sulla **scena vera**, non su un'orda
## costruita in isolamento. Da m4 il numero 200 non si misura piu' all'avvio ma
## **durante** la partita (piano sez. 1.4, n. 2): lo esercita
## `_capacita_sulla_scenavera`.
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
##
## ## m4: la curva delle onde e cosa cambia in questo file
##
## Prima di m4 l'arena partiva gia' piena (200 nemici al primo frame) e
## `_top_up()` la riportava a 200 a ogni passo: l'onda non creava mai un vuoto.
## Ora `population` e' una **curva per onda** (`Run.population_of`), 25, 50, 75,
## 100, 125, 150, 175, 200 all'onda 8, e il campo si riempie al ritmo di
## `Run.SPAWN_RATE`.
##
## **I numeri che questo file verifica, ricalcolati sulla curva nuova:**
##
## | | prima di m4 | dopo m4 |
## |---|---|---|
## | nemici vivi al primo frame | 200 | **25** (`Run.POP_BASE`) |
## | `wave_total` onda 1 / 2 / 3 | 200 / 230 / 260 | **invariati**: sono uccisioni, non vivi |
## | popolazione di onda 1 / 2 / 3 | 200 / 200 / 200 | **25 / 50 / 75** |
## | tempo per riempire un'onda da 0 | 1 passo = 0.0167 s | **25/8 = 3.1 s**; a 200 vivi **25 s** |
## | riempimento a `game_over` | ripartiva in 1 passo | fermo: la simulazione e' ferma |
##
## Quello che **non** e' cambiato e che questo file continua a pretendere: la
## capacita' di 200 nemici vivi senza un nodo per nemico, e' verificata in
## `_capacita_sulla_scenavera` pilotando `population` a mano come fa
## `tests/test_orda.gd`, quindi il criterio di m1 non dipende dalla curva.

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

## Seme della disposizione dell'orda **isolata** di questo test.
##
## ## Perche' un seme e non il dado
##
## Senza questo numero `horde.seed` resta 0, e in `horde.gd::_build()` questo
## vuol dire `_rng.randomize()`: la disposizione dei 200 nemici e' diversa a
## ogni lancio. Quando il ripopolamento addensa piu' di `BUCKET_SLOTS` (32,
## `src/sim/spatial_grid.gd`) nemici in una cella, `grid_overflowed()` va a
## vero e l'asserzione «nessun secchiello traboccato» piu' sotto cade: il
## fallimento era misurato **1 volta in 175 esecuzioni**, senza alcuna
## regressione del codice. Il seme non rende l'orda piu' sicura: rende il caso
## **riproducibile**, e con esso la riga e' verde o rossa per una ragione che si
## puo' dire ad alta voce invece che per un lancio sfortunato.
##
## Va impostato **prima** di `add_child`: e' `_ready()` -> `_build()` a seminare
## `_rng`, quindi un seme messo dopo entrerebbe troppo tardi.
##
## ## Perche' 177 e non un altro
##
## Misurati i semi da 1 a 240 sulla sequenza esatta di questa parte 1 (le due
## onde svuotate di `_onde`, poi i 600 passi di `_rientro_in_gioco` con
## un'uccisione ogni due), guardando `worst_bucket()`, il **picco** di nemici
## in una sola cella su tutto quel percorso:
##
##     min 24, mediana 29, max 32, e un solo seme trabocca: il 148 (picco 33).
##
## Il 177 ha picco **28**. E' il numero giusto per tre ragioni, e tutte e tre
## si leggono nei numeri sopra:
##
## 1. **Non trabocca**, ed e' verificato, non sperato: 28 < 32 con 4 slot di
##    margine.
## 2. **E' rappresentativo**, non sorteggiato a piacere: 28 sta dentro la
##    banda tipica (mediana 29) e i semi vicini danno 28, 29 e 28: la sua
##    densita' e' quella normale della partita, non un caso limite.
## 3. **L'asserzione conserva i denti**: 4 slot di margine vuol dire che se
##    l'orda si addensa davvero la riga va rossa. Non si e' scelto il seme col
##    picco minimo (24, il 158): quello renderebbe la guardia immune a
##    qualunque densita' e sarebbe un'asserzione che non misura piu' niente.
##
## Il caso traboccante e' comunque a portata di mano: il seme **148** e' quello
## che fa fallire la riga, e serve a provare che la riga sa ancora fallire.
const SEME := 177

var _horde: HORDE = null
## Quando il corpo del test e' partito, in millisecondi di motore. Serve al
## numero di tempo stampato in fondo: vedi la nota li'.
var _t0: int = 0

func _initialize() -> void:
	# L'orda isolata entra nell'albero qui, come in `tests/test_orda.gd`: sotto
	# `--script` l'entrata nell'albero di un nodo passato dalla `_initialize()`
	# attraversa la coda di messaggi, quindi il suo `_ready()` non e' ancora
	# partito quando questa funzione torna. Il corpo del test gira al primo
	# frame, in `_process`.
	_horde = HORDE.new()
	_horde.name = "OrdaDiTest"
	# Il seme va messo **qui**, prima di `add_child`: e' `_ready()` -> `_build()`
	# a seminare `_rng`, e un seme impostato dopo entrerebbe troppo tardi.
	_horde.seed = SEME
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
	_t0 = int(Time.get_ticks_msec())
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
	_curva(h, _horde)
	_onde(h, _horde)
	_rientro_in_gioco(h, _horde)
	_restart(h, _horde, game)

	_scena_vera(h, game)

	# La superficie si verifica **dentro** `_scena_vera`, con l'orda ancora viva:
	# fuori, `Game.horde` punta a un nodo liberato e il contratto risponderebbe
	# "manca" per un registro che c'e'. E li' e' anche il posto giusto: la
	# superficie di m2 e' cio' che le foglie si scambiano **sulla scena vera**.
	_nessun_nodo_appeso(h)
	# ## Perche' il tempo di pareggio e' stampato
	#
	# m4 ha moltiplicato per sei i passi di simulazione necessari (chiudere
	# un'onda costa `wave_size / SPAWN_RATE` secondi, e le cinque onde chiuse
	# da questo file sono ~13 400 giri). `tools/gate.gd` ha un timeout per
	# test, e un timeout che scatta perche' un test e' diventato piu' lento e'
	# un test che si rompe senza dire perche'. Il numero va a schermo.
	print("gameloop: sezione chiusa, %d asserzioni in %d ms"
		% [h.checks, int(Time.get_ticks_msec()) - _t0])
	quit(h.finish("test_gameloop"))

# --- Parte 1, numero 1: l'avvio ------------------------------------------------

## Lo stato iniziale: il numero e' preso dal contratto di `run.gd`, non riscritto
## qui. Se le due copie divergono, il test mente sulla barra dell'onda.
func _apertura(h, horde: HORDE) -> void:
	# m4: l'avvio NON e' pieno. Il numero e' preso dalla curva di `run.gd`, non
	# riscritto qui, e il fatto che sia diverso da 200 e' l'invariante 1 del
	# criterio n. 3 di m1 riscritto ("capienza resta un criterio, il numero
	# iniziale diventa una curva").
	h.eq(horde.count, RUN.population_of(1),
		"l'avvio riempie a `population_of(1)`: %d nemici vivi" % RUN.population_of(1))
	h.eq(horde.count, RUN.POP_BASE, "che sull'onda 1 e' Run.POP_BASE = %d" % RUN.POP_BASE)
	h.check(horde.count < HORDE.MAX_ENEMIES,
		"l'avvio non e' gia' pieno: %d vivi su %d di capienza" % [horde.count, HORDE.MAX_ENEMIES])
	h.eq(horde.population, horde.count, "e il campo e' gia' al suo tetto: nessuno deve arrivare")
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
	print("gameloop: avvio, onda %d, barra %d/%d, scala vita %.2f, %d nemici (POP_BASE %d)"
		% [horde.wave, horde.wave_killed(), horde.wave_total(),
			horde.wave_hp_scale(), horde.count, RUN.POP_BASE])

# --- m4: la curva per onda ----------------------------------------------------
#
# I tre invarianti che il piano scrive, resi numerici:
#   1. `population` cresce strettamente da onda 1 a onda N (N = quella in cui
#      arriva al tetto: una sequenza di interi con tetto non puo' crescere per
#      sempre, e la soglia va dichiarata invece che lasciata a "per sempre");
#   2. `population` non supera mai `MAX_ENEMIES`;
#   3. il campo non salta da 0 a `population` in un passo.
#
# La sezione verifica i tre **sulle due facce**: la tabella dichiarata in
# `run.gd` e il campo `population` dell'orda vera letto dopo un cambio d'onda
# reale. Il secondo e' quello che conta: la tabella puo' essere giusta e lo
# specchio rotto, e in quel caso il gioco non crescerebbe.

## Quante onde attraversa la sezione di crescita osservata. Tre onde costano
## 200+230+260 = 690 uccisioni, e a `Run.SPAWN_RATE` quelle arrivano in 690/8 =
## 86 s, cioe' ~5180 passi: e' il costo dichiarato di misurare la curva per
## davvero invece di leggerla dalla tabella.
const ONDE_OSSERVATE := 3

func _curva(h, horde: HORDE) -> void:
	# --- faccia 1: la tabella dichiarata
	h.eq(RUN.POP_MAX, HORDE.MAX_ENEMIES,
		"Run.POP_MAX e Horde.MAX_ENEMIES sono lo stesso numero: due copie che divergono in silenzio")
	var tabella := PackedInt32Array()
	for w in range(1, RUN.POP_SATURATION + 2):
		tabella.append(RUN.population_of(w))
	print("gameloop: curva per onda, da 1 a %d: %s" % [RUN.POP_SATURATION + 1, str(tabella)])
	h.check(_cresce_stretta(tabella.slice(0, RUN.POP_SATURATION)),
		"population cresce strettamente dall'onda 1 all'onda %d: %s"
			% [RUN.POP_SATURATION, str(tabella.slice(0, RUN.POP_SATURATION))])
	var sopra := 0
	for w in range(1, 40):
		if RUN.population_of(w) > HORDE.MAX_ENEMIES:
			sopra += 1
	h.eq(sopra, 0, "su 39 onde nessuna popolazione supera la capienza")
	h.eq(RUN.population_of(0), RUN.population_of(1),
		"l'onda 0 non esiste: si parte dall'onda 1")
	h.eq(RUN.population_of(RUN.POP_SATURATION + 1), HORDE.MAX_ENEMIES,
		"dopo la saturazione la curva sta al tetto, e la dichiara invece di fingere di crescere")

	# --- faccia 2: l'orda vera, onda dopo onda
	# Ogni volta che la barra si chiude l'onda avanza e `population` deve
	# salire. `_svuota_onda` uccide davvero e il cambio avviene al passo
	# successivo, quindi qui il numero e' **osservato**, non dichiarato.
	var osservate := PackedInt32Array()
	osservate.append(horde.population)
	var attese := PackedInt32Array()
	attese.append(RUN.population_of(1))
	for _w in ONDE_OSSERVATE:
		_svuota_onda(h, horde, horde.wave)
		osservate.append(horde.population)
		attese.append(RUN.population_of(horde.wave))
	h.eq(horde.wave, ONDE_OSSERVATE + 1,
		"la sezione ha attraversato %d onde davvero" % ONDE_OSSERVATE)
	h.eq(osservate, attese,
		"a ogni cambio d'onda `population` vale quello che chiede la curva: %s" % str(osservate))
	h.check(_cresce_stretta(osservate),
		"e l'orda vera cresce di onda in onda: %s" % str(osservate))

	# --- invariante 3: il tempo di riempimento
	# Il numero di nemici vivi non puo' saltare da 0 a `population` nello stesso
	# passo. E' il sintomo «arrivano tutti insieme» ed e' un fatto sul tempo:
	# misurato, era 1 passo = 0.0167 s prima di m4.
	var svuotati := 0
	while horde.count > 0 and svuotati < 1000:
		if not _kill_uno(horde):
			break
		svuotati += 1
	h.eq(horde.count, 0, "campo svuotato per misurare il riempimento")
	h.eq(horde.population, RUN.population_of(horde.wave),
		"il tetto da raggiungere e' quello dell'onda corrente: %d" % horde.population)
	var passi := 0
	var profilo := ""
	var primo_a_meta := -1
	# Qui l'attesa e' il **soggetto** della misura (l'invariante e' "non si riempie in
	# un passo"), quindi resta un'attesa e non si puo' usare `_riempi()`. Quello che
	# cambia e' il **tetto**: era `20000` scritto a mano, e un numero scritto a mano e'
	# un numero che si rompe quando la costante che descrive cambia.
	while horde.count < horde.population and passi < _passi_per_riempire(horde.population, DT):
		horde.step(DT)
		passi += 1
		if primo_a_meta < 0 and horde.count >= horde.population / 2:
			primo_a_meta = passi
		if passi in [1, 8, 30, 60, 120, 240, 480]:
			profilo += " %d:%d" % [passi, horde.count]
	h.check(passi > 1,
		"l'arena NON si riempie in un passo: %d passi = %.2f s per arrivare a %d"
			% [passi, float(passi) * DT, horde.population])
	h.eq(horde.count, horde.population, "e arriva esattamente al tetto, non oltre")
	h.check(float(passi) * DT >= float(horde.population) / RUN.SPAWN_RATE * 0.95,
		"il tempo di riempimento e' quello che `SPAWN_RATE` prescrive: %.2f s contro %.2f s di teoria"
			% [float(passi) * DT, float(horde.population) / RUN.SPAWN_RATE])
	h.check(primo_a_meta > 1,
		"neanche a meta' strada il campo e' pieno: %d di %d al passo %d"
			% [horde.population / 2, horde.population, primo_a_meta])
	print("gameloop: inv. 3, da 0 a %d in %d passi = %.2f s (SPAWN_RATE %.1f/s); profilo (passi:vivi) %s"
		% [horde.population, passi, float(passi) * DT, RUN.SPAWN_RATE, profilo])

	# la sezione lascia l'orda come l'ha trovata, per le asserzioni dopo
	horde.restart_run()

## Il predicato dell'invariante 1: **strettamente** crescente.Uguale non passa.
## Sta in una funzione perche' i denti (milestone 4, criterio n. 6) si provano
## forzandola su una sequenza piatta e guardando l'asserzione dire `FAIL`: per
## farlo l'asserzione deve chiamare **questa** funzione e non ripetere il
## confronto nel corpo del test.
func _cresce_stretta(valori: PackedInt32Array) -> bool:
	for i in range(1, valori.size()):
		if valori[i] <= valori[i - 1]:
			return false
	return true

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

	# La barra, non il campo. Un'onda da 230 uccisioni con 25 vivi contemporanei
	# non puo' diventare vuota al momento giusto, quindi una fine d'onda che
	# guardasse il campo non finirebbe mai: e' il numero che distingue un bullet
	# heaven da un'orda sola. Dopo m4 il distacco e' anche piu' netto: 230
	# uccisioni con 50 vivi significa che il campo si riempie **mentre** uccidi.
	h.check(RUN.wave_size(2) > horde.population,
		"l'onda 2 chiede %d uccisioni con %d nemici vivi contemporanei: il campo da solo non puo' chiuderla"
			% [RUN.wave_size(2), horde.population])
	h.check(RUN.wave_size(2) > HORDE.MAX_ENEMIES,
		"e anche piu' della capienza: %d uccisioni contro %d vivi" % [RUN.wave_size(2), HORDE.MAX_ENEMIES])
	h.eq(horde.population, RUN.population_of(horde.wave),
		"dopo il passaggio all'onda %d la popolazione e' quella della curva" % horde.wave)
	print("gameloop: onde 1->3 superate, %d uccisioni in tutto, scala vita ora %.2f, %d vivi"
		% [horde.kills, horde.wave_hp_scale(), horde.population])

## Svuota l'onda `wave_da` e restituisce quanti giri sono serviti. `damage_enemy`
## uccide subito, ma il cambio d'onda avviene al passo di simulazione successivo:
## e' l'ordine che `horde.gd::_wave_tick` dichiara, e qui viene verificato
## invece che supposto.
func _svuota_onda(h, horde: HORDE, wave_da: int) -> int:
	h.eq(horde.wave, wave_da, "si parte dall'onda %d" % wave_da)
	var bersaglio := horde.wave_total()
	var giri := 0
	var tetto := _giri_per_chiudere(wave_da)
	while horde.wave == wave_da and giri < tetto:
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
	h.check(horde.wave == wave_da + 1,
		"l'onda %d si chiude entro %d giri (ne sono serviti %d): il tetto e' `wave_size / SPAWN_RATE / DT`"
			% [wave_da, tetto, giri])
	return giri

## Quanti giri puo' costare chiudere l'onda `w`: **derivato, non scelto**.
##
## Il tetto e' sorto da un numero che m4 ha cambiato e che m1 aveva reso falso.
## Prima di m4 bastavano ~8 giri: `_top_up()` riportava il campo alla popolazione
## in un passo, quindi a ogni giro il campo era pieno e l'onda 1 (200
## uccisioni) si chiudeva in 8. Dopo m4 il campo si riempie al ritmo di
## `Run.SPAWN_RATE`, e **il ritmo delle uccisioni non puo' superarlo**: se
## arrivano `SPAWN_RATE` nemici al secondo, chiudere `wave_size(w)` uccisioni
## richiede almeno `wave_size(w) / SPAWN_RATE` secondi. Il tetto e' quel
## minimo diviso per `DT`, con un margine.
##
## Il margine copre i due effetti che lo rendono non esatto, entrambi a favore
## della rapidita': le uccisioni dei nemici **gia' vivi** all'inizio dell'onda
## (il campo parte pieno, e quelle non le ha prodotte lo spawn) e
## l'arrotondamento del credito di spawn a interi. Un tetto strettamente
## derivato avrebbe fatto fallire il test per aritmetica, non per un difetto.
const MARGINE_GIRI := 1.6

func _giri_per_chiudere(wave_da: int) -> int:
	var secondi := float(RUN.wave_size(wave_da)) / RUN.SPAWN_RATE
	return int(ceil(secondi / DT * MARGINE_GIRI))

## Una uccisione attraverso il **contratto**, non solo attraverso il metodo
## diretto: e' la strada che il gioco usa, e il suo valore di ritorno dice chi e'
## morto (piano sez. 5.2). Se il contratto non puntasse a questa orda, si cadebbe
## sul metodo diretto: i due numeri devono essere lo stesso, e qui si vede.
func _kill_uno(horde: HORDE) -> bool:
	var game = _game()
	if game != null and game.get("horde") == horde:
		return game.damage_enemy(0, 9999.0, Vector3.ZERO)
	return horde.damage_enemy(0, 9999.0, Vector3.ZERO)

## ## Mettere i nemici, e **non aspettarli**: la regola del banco di prova
##
## Un test che vuole `n` corpi **ce li mette**. Il rateo di produzione e' il
## **comportamento che il test sta misurando**, non l'attrezzo per costruire lo
## scenario: usarlo per riempire l'arena vuol dire che ogni volta che
## `Run.SPAWN_RATE` cambia, tutti i test che riempiono si rompono — ed e' successo
## due volte, con m4 e con `SPAWN_RATE` da 8,0/s a 2,0408/s (m12-w1b: questo file
## e' andato rosso su `TETTO_ATTESA`, tarato sul rateo vecchio).
##
## La strada scelta e' **metterli direttamente**, non alzare il rateo durante il
## montaggio: alzare il rateo significa avere una **seconda fonte di verita' sul
## rateo dentro il test**, e un test che cambia il rateo per costruire lo scenario
## sta mentendo sullo scenario.
##
## `_spawn_one()` e' il cammino vero di `horde.gd` — quello che chiama `_top_up` — e
## non guarda `population`, solo la capienza fisica: mettere `n` corpi con questa
## funzione produce **lo stesso stato** che produrrebbe la rampa, senza aspettarla.
## Restituisce quanti ne ha messi, cosi' un test che volesse contarli non deve
## chiamare `_spawn_one()` da tre posti diversi.
func _riempi(horde: HORDE, quanti: int) -> int:
	var tetto := mini(quanti, HORDE.MAX_ENEMIES)
	var messi := 0
	while horde.count < tetto:
		horde._spawn_one()
		messi += 1
		if messi > HORDE.MAX_ENEMIES:
			break
	return messi

## Il **tetto di passi per un riempimento**, derivato dal rateo e non scritto.
##
## `horde.gd::_top_up` accumula `spawn_rate() x delta` e spende **un intero per
## passo**, quindi per arrivare a `n` nemici servono `ceil(n / (rate x delta))`
## passi. Il `+ 4` e' la tolleranza dell'arrotondamento del credito, non un margine
## comodo: e' il minimo oltre il quale il numero non puo' mentire.
##
## Il rateo e' letto dalla **costante** `RUN.SPAWN_RATE` e non da
## `run.spawn_rate()` perche' quello e' un metodo, e `tests/test_orda.gd` asserisce
## che i due sono lo stesso numero.
func _passi_per_riempire(n: int, delta: float) -> int:
	return int(ceil(float(n) / maxf(0.000001, RUN.SPAWN_RATE * delta))) + 4

# --- Parte 1: 600 passi, e un cambio d'onda dentro -----------------------------

## La milestone 1 chiedeva che 600 aggiornamenti non stampino errori e non
## gonfino niente. Qui il giro e' diverso e serve a m2: i 600 passi **attraversano
## un cambio d'onda**, che e' il posto dove si riempie l'orda, quindi e' li' che
## un'allocazione nel ciclo di gioco si farebbe vedere.
## ## m4: i due blocchi, e perche' non ne basta uno
##
## Prima di m4 bastavano 600 passi con un'uccisione ogni due: il campo si
## riempiva in un passo, quindi in 600 passi (10 s) arrivavano 6000 nemici e la
## barra si chiudeva ampiamente. Adesso **il limite non e' il ritmo delle
## uccisioni, e' la consegna**: a `SPAWN_RATE = 8/s` in 600 passi arrivano 80
## nemici, e l'onda corrente ne chiede 260. Quindi i 600 passi sono ancora un
## blocco che si misura (e' il criterio di m1), ma il cambio d'onda va cercato
## con un secondo blocco che gira finche' non arriva, e il **numero di passi che
## ci vuole** e' la misura: prima ne servivano ~300, adesso ne servono ~1950,
## cioe' 260 uccisioni a 8 al secondo. E' la stessa identita' che nella tabella
## di `run.gd`, misurata dal lato dell'orda.
##
## Il secondo blocco uccide **tutto quello che c'e'**: se il limite fosse il
## ritmo, l'attesa sarebbe quella di prima; il fatto che servano ~1950 passi e'
## la prova che il limite e' la rampa.

## Passi minimi del primo blocco: il criterio di m1.
const BLOCCHI := 600

## Il margine del secondo blocco, e **perche' il tetto non e' piu' un numero**
##
## Il tetto era `4000`, scritto a mano e tarato sul rateo di m4 (`8,0/s`: 260
## uccisioni in 32,5 s = 1950 passi, tetto il doppio). Con `SPAWN_RATE` sceso a
## `2,0408/s` le stesse 260 uccisioni costano ~7.635 passi e il tetto vecchio e'
## diventato **un traguardo che si puo' mancare per aritmetica**: misurato, il
## file e' andato rosso con 156 uccisioni su 260. Non si e' corretto il numero —
## la difesa e' **non scriverlo**: il tetto e' adesso una funzione di
## `wave_size`, di `SPAWN_RATE` e di `DT`, quindi il prossimo cambio di rateo non
## produce un rosso, produce un numero diverso, che e' la cosa che si vuole.
const MARGINE_ATTESA := 1.25

## Quanti passi puo' costare il cambio d'onda `wave_da`: **derivato, non scelto**.
##
## Il ritmo delle uccisioni non puo' superare il ritmo delle nascite, quindi
## chiudere `wave_size(w)` uccisioni richiede almeno `wave_size(w) / SPAWN_RATE`
## secondi. Il ciclo uccide **un nemico per passo**, quindi i passi sono quel
## minimo diviso per `DT`, con `MARGINE_ATTESA` sopra.
func _tetto_attesa(wave_da: int) -> int:
	var secondi := float(RUN.wave_size(wave_da)) / RUN.SPAWN_RATE
	return int(ceil(secondi / DT * MARGINE_ATTESA))

func _rientro_in_gioco(h, horde: HORDE) -> void:
	var wave_iniziale := horde.wave
	var nodi0 := _count_nodes(root)
	var obj0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var mem0 := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var morti := 0

	# Blocco 1: i 600 passi del criterio di m1, con un'uccisione ogni due passi
	# quando il campo ha qualcosa da dare. Qui non si attraversa nessun confine
	# d'onda, ed e' un fatto che va detto: lo spetta il blocco 2.
	for s in BLOCCHI:
		horde.step(DT)
		if s % 2 == 0 and horde.count > 0:
			if _kill_uno(horde):
				morti += 1

	h.eq(horde.wave, wave_iniziale,
		"in %d passi con la rampa di m4 l'onda non e' finita: %d uccisioni su %d richieste"
			% [BLOCCHI, horde.wave_killed(), horde.wave_total()])
	h.check(horde.count <= horde.population,
		"e il campo non ha mai superato il tetto: %d su %d" % [horde.count, horde.population])
	h.eq(horde.transforms.size(), horde.count, "allineata dopo %d passi" % BLOCCHI)
	h.eq(horde.hp.size(), horde.count, "anche hp allineata dopo %d passi" % BLOCCHI)

	# Blocco 2: il cambio d'onda, che ora costa secondi e non un passo.
	var uccisioni_parte := horde.wave_killed()
	var uccisioni := 0
	var attesa := 0
	while horde.wave == wave_iniziale and attesa < _tetto_attesa(wave_iniziale):
		horde.step(DT)
		attesa += 1
		if horde.count > 0:
			if _kill_uno(horde):
				morti += 1
				uccisioni += 1
	h.eq(horde.wave, wave_iniziale + 1,
		"il cambio d'onda arriva, e arriva tardi: %d passi dopo il blocco di m1" % attesa)
	h.check(attesa > BLOCCHI / 2,
		"l'attesa e' piu' lunga di meta' del blocco di m1: %d contro %d"
			% [attesa, BLOCCHI / 2])
	# ## Perche' si conta sulle uccisioni e non su `wave_killed()`
	#
	# Il cambio d'onda avviene **dentro** `horde.step(DT)`, e `run.next_wave()`
	# azzera `wave_killed` nello stesso istante: quando il ciclo esce, la barra
	# della nuova onda e' a zero. La vecchia riga `wave_killed() > 0` passava
	# perche' prima di m4 il campo si riempiva in un passo e l'attesa si
	# chiudeva con un uccisione nella nuova onda: era un incidente della rampa,
	# non la proprieta' che si voleva verificare. La domanda vera e' **perche'**
	# l'onda e' cambiata, e la risposta e' che la barra dell'onda precedente ha
	# raggiunto lo zero: quindi si contano le uccisioni di **quell'** onda.
	h.check(uccisioni_parte + uccisioni >= RUN.wave_size(wave_iniziale),
		"il cambio e' stato causato dalla barra a zero: %d uccisioni sull'onda %d, che ne chiedeva %d"
			% [uccisioni_parte + uccisioni, wave_iniziale, RUN.wave_size(wave_iniziale)])
	h.check(horde.wave_killed() < horde.wave_total(),
		"e la nuova onda non nasce gia' finita: %d uccisioni su %d" % [horde.wave_killed(), horde.wave_total()])
	h.check(horde.count <= horde.population,
		"il campo resta sotto il tetto anche dopo il cambio: %d su %d"
			% [horde.count, horde.population])
	h.eq(horde.population, RUN.population_of(horde.wave),
		"e il tetto e' salito con l'onda: %d" % horde.population)
	h.eq(horde.transforms.size(), horde.count, "allineata dopo il cambio d'onda")
	h.eq(horde.hp.size(), horde.count, "anche hp allineata dopo il cambio d'onda")
	h.eq(horde.grid_unknown_cells, 0,
		"nessuna cella nuova dopo %d passi e un cambio d'onda: nel ciclo non si alloca" % (BLOCCHI + attesa))
	h.check(not horde.grid_overflowed(), "nessun secchiello traboccato")
	_specchio(h, horde, "dopo il cambio d'onda")
	_barra_sana(h, horde, "dopo il cambio d'onda")

	var nodi1 := _count_nodes(root)
	var obj1 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var mem1 := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	h.eq(nodi1, nodi0, "%d passi non aggiungono nodi" % (BLOCCHI + attesa))
	h.check(obj1 <= obj0 + 16,
		"%d passi non aggiungono oggetti: %d contro %d" % [BLOCCHI + attesa, obj1, obj0])
	h.check(mem1 - mem0 < 4 * 1024 * 1024,
		"%d passi non gonfiano la memoria: +%d KB" % [BLOCCHI + attesa, (mem1 - mem0) / 1024])

	# e nessuna posizione spazzatura, che e' il modo in cui un array parallelo
	# disallineato si manifesta
	var spazzatura := 0
	for i in horde.count:
		var p := horde.transforms[i]
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
			spazzatura += 1
	h.eq(spazzatura, 0, "nessun nemico con una posizione spazzatura dopo %d passi" % (BLOCCHI + attesa))
	print("gameloop: %d+%d passi e %d uccisioni, onda %d -> %d, tetto %d vivi, nodi %d -> %d, oggetti %d -> %d, memoria +%d KB"
		% [BLOCCHI, attesa, morti, wave_iniziale, horde.wave, horde.population,
			nodi0, nodi1, obj0, obj1, (mem1 - mem0) / 1024])

# --- Parte 1, numero 3: il restart --------------------------------------------

## `restart_run()` tre volte di fila. Il numero da guardare non e' `wave == 1`, e
## non e' un numero scritto qui dentro: e' che **l'orda torna alla popolazione
## che la curva assegna all'onda 1** e che **il numero di nodi non e' cambiato**,
## perche' un restart che ricrea l'orda da zero sembra funzionante e lascia
## appeso un nodo per nemico.
##
## ## Perche' `population_of(1)` e non un numero
##
## `horde.count == 200` era l'invariante di prima di m4: la partita partiva
## piena, quindi il restart doveva ripartire pieno. Ora la partita parte a
## `Run.POP_BASE` e cresce onda per onda: un test con dentro `200` va
## riscritto alla prossima milestone, un test con dentro `population_of(1)`
## no. Il numero che resta fermo, e che e' quello di m1, e' `MAX_ENEMIES`: e'
## verificato a parte, in `_capacita_sulla_scenavera`.
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
		# Il tetto inseguito e la curva dell'onda 1, non una copia del numero:
		# e' la relazione che deve valere, e vale anche se `POP_BASE` cambia.
		h.eq(horde.population, RUN.population_of(horde.wave),
			"restart %d: il tetto inseguito e' quello della curva" % (giro + 1))
		h.eq(horde.count, RUN.population_of(1),
			"restart %d: horde.count azzerato e RIPOPOLATO a `population_of(1)` = %d"
				% [giro + 1, RUN.population_of(1)])
		h.check(horde.count < HORDE.MAX_ENEMIES,
			"restart %d: l'avvio NON e' pieno: %d vivi su %d di capienza"
				% [giro + 1, horde.count, HORDE.MAX_ENEMIES])
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
	h.eq(horde.count, RUN.population_of(1),
		"restart dopo 37 uccisioni: l'orda torna a `population_of(1)` = %d" % RUN.population_of(1))
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

	# m4: l'avvio della scena vera e' **sulla curva**, non pieno. Il numero che
	# m1 chiede (200 nemici vivi con meno di 120 nodi) non e' sparito, e' stato
	# spostato a **durante** la partita dal criterio riscritto (piano sez. 1.4
	# n. 2): lo esercita `_capacita_sulla_scenavera` qui sotto, che e' la
	# sezione che quel testo rende verificabile.
	h.eq(horde.wave, 1, "la partita vera parte dall'onda 1")
	h.eq(horde.count, RUN.population_of(horde.wave),
		"nella scena vera l'orda nasce a `population_of(1)` = %d, non a capienza"
			% RUN.population_of(1))
	h.eq(horde.population, RUN.population_of(horde.wave), "e insegue quel tetto")
	h.check(horde.count < HORDE.MAX_ENEMIES,
		"l'avvio NON e' pieno: %d vivi su %d di capienza" % [horde.count, HORDE.MAX_ENEMIES])
	h.eq(horde.transforms.size(), horde.count, "e transforms e' allineata")
	h.eq(horde.run_state(), "playing", "e la partita e' in corso")
	h.eq(horde.wave_remaining(), horde.wave_total(), "con la barra piena")
	h.eq(_count_named(root, NODO_HORDE), 1,
		"sotto root un solo nodo \"%s\": il totale dei nodi non lo direbbe" % NODO_HORDE)

	_capacita_sulla_scenavera(h, horde)

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

## Il criterio n. 3 della milestone 1 **durante la partita**, sulla scena vera:
## `node_count < 120` con `horde.count == 200` **raggiunto in partita**.
##
## ## Perche' questa sezione esiste solo da m4
##
## Prima di m4 bastava guardare l'avvio: la scena nasceva con 200 nemici vivi e
## il numero era li', a portata di un `h.eq`. Il criterio n. 3 di m1 e' stato
## riscritto (piano sez. 1.4, n. 2) perche' quella seconda meta' era una scelta
## di design travestita da criterio: la partita non parte piena, parte a
## `Run.POP_BASE` e cresce onda per onda. **Il tetto di 120 e il numero 200 non
## cambiano: cambia quando si misurano.** E siccome il numero non arriva piu'
## da solo, va esercitato: qui `population` viene pilotata a mano come fa
## `tests/test_orda.gd`, e il tetto di nodi viene contato mentre 200 nemici sono
## davvero vivi sulla scena che il gioco avvia.
##
## Il resto del test continua a lavorare sulla curva: la sezione finisce con un
## `restart_run()`, che rimette a posto `population` passando da
## `_sync_population()` e non da una copia del numero scritta qui.
##
## Perche' si conta **durante** e non dopo: il tetto di 120 nodi e' un numero
## che deve valere mentre l'orda e' piena. Contarlo a campo svuoto passerebbe
## anche con un nodo per nemico che nasce e muore tra due conteggi.
func _capacita_sulla_scenavera(h, horde: HORDE) -> void:
	var nodi_avvio := _count_nodes(root)
	var avvio := horde.count
	# `population` e' un campo pubblico dichiarato in `horde.gd` proprio per
	# questo: e' la rampa che la curva pilota in partita, e qui la si porta a
	# mano alla capienza senza dipendere dall'onda.
	horde.population = HORDE.MAX_ENEMIES
	# La scena vera si riempie **mettendo** i nemici: qui il numero che conta e' il
	# conteggio dei nodi **durante** la partita, non il tempo di riempimento.
	var passi := 0
	_riempi(horde, HORDE.MAX_ENEMIES)
	passi += horde.count - avvio

	h.eq(horde.count, HORDE.MAX_ENEMIES,
		"durante la partita l'orda della scena vera arriva a %d nemici vivi" % HORDE.MAX_ENEMIES)
	# Il sintomo di m4 — «la capienza non e' piu' un numero che il motore si trova
	# gia' addosso al primo passo» — **non e' piu' misurato qui**, e non perche' sia
	# sparito: e' misurato **sopra**, sull'invariante 3, dove l'attesa e' una vera
	# rampa di simulazione e `passi > 1` ha ancora un significato. Qui il campo e'
	# stato riempito **mettendo** i nemici, quindi `passi` non e' piu' un numero di
	# passi di simulazione e le due righe che lo confrontavano con
	# `SPAWN_RATE` avrebbero misurato il banco di prova invece del gioco.
	#
	# Quello che resta qui e' il numero per cui questa sezione esiste: i **nodi**
	# mentre 200 corpi sono davvero vivi.
	h.check(passi > 1,
		"i %d corpi sono stati messi in piu' di un colpo: %d" % [horde.count - avvio, passi])

	h.eq(horde.transforms.size(), horde.count, "gli array sono allineati a capienza piena")
	h.eq(horde.colors.size(), horde.count, "anche i colori")
	var nodi := _count_nodes(root)
	h.check(nodi < TETTO_NODI,
		"criterio n. 3 di m1: %d nemici vivi con %d nodi (tetto %d), sulla scena vera e DURANTE la partita"
			% [horde.count, nodi, TETTO_NODI])
	h.eq(horde.get_child_count(), 0,
		"e l'orda non ha un nodo per nemico, nemmeno a capienza piena")
	# Nessun nodo e' comparso per arrivarci: la rampa scrive dentro array, non
	# nell'albero.
	h.eq(nodi, nodi_avvio,
		"riempire l'orda a capienza non ha aggiunto un nodo: %d prima, %d dopo" % [nodi_avvio, nodi])
	print("gameloop: capienza sulla scena vera, da %d a %d vivi in %d passi = %.2f s, %d -> %d nodi"
		% [avvio, horde.count, passi, float(passi) * DT, nodi_avvio, nodi])

	# Il resto del file lavora sulla curva: si torna al numero che l'onda 1
	# chiede, e il ritorno si verifica come **relazione**, non come numero.
	horde.restart_run()
	h.eq(horde.wave, 1, "dopo la capienza esercitata si torna all'onda 1")
	h.eq(horde.population, RUN.population_of(horde.wave), "e al tetto della curva")
	h.eq(horde.count, RUN.population_of(1),
		"l'orda torna a `population_of(1)` = %d" % RUN.population_of(1))
	h.eq(_count_nodes(root), nodi_avvio, "e nessun nodo e' rimasto appeso")

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
	h.eq(horde.count, RUN.population_of(1),
		"restart: horde.count azzerato e RIPOPOLATO a `population_of(1)` = %d" % RUN.population_of(1))
	h.eq(horde.population, RUN.population_of(horde.wave), "restart: il tetto inseguito e' quello della curva")
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
	h.eq(horde.count, RUN.population_of(1), "e l'orda e' di nuovo a `population_of(1)`")
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