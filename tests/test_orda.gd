extends SceneTree
## Test dell'orda (terminal-gun-orda). Dimostra con numeri il criterio n. 3 della
## milestone: 200 nemici vivi senza un nodo per nemico.
##
## Verifica, in ordine:
##   1. `count == 200` al riempimento iniziale e `transforms.size() == count`;
##   2. la griglia restituisce **gli stessi indici** di una scansione lineare
##      (stessa distribuzione, stesse query, risultati identici): una griglia
##      piu' veloce ma sbagliata non e' una griglia;
##   3. `nearest_enemy_index` sull'indice atteso, e -1 quando il raggio e' vuoto;
##   4. 1000 query di prossimita' su 200 nemici in meno di 50 ms, e la griglia
##      piu' rapida della scansione lineare: misurati su 8 giri e riportati come
##      minimo e mediana, perche' una corsa sola e' rumore e fallirebbe a caso;
##   5. 600 aggiornamenti in headless: nessun SCRIPT ERROR, nessuna crescita di
##      nodi, oggetti e memoria;
##   6. `damage_enemy` uccide e il conteggio scende, per scambio-ultimo.
##
## ## LA MISURA DEL PRIMA, e perche' questo file la porta in testa
##
## Il numero di sotto e' la base di tutta la milestone 4, ed e' stato misurato
## **prima** di toccare una riga di `src/sim/`. Strumento: questo stesso file,
## con un blocco di misura temporaneo poi rimosso, sull'orda isolata con il fuoco
## al centro dell'arena (raggio 28 m) e passo fisso 1/60 s.
##
## | cosa si misura | prima di m4 | dopo m4 |
## |---|---|---|
## | nemici vivi al **primo frame** | **200** | **25** (`Run.POP_BASE`) |
## | tempo per arrivare alla popolazione piena, dall'avvio | **0.0000 s** (0 passi: era gia' pieno) | 0.0000 s (25, che e' il tetto dell'onda 1) |
## | tempo per riempire **dopo uno svuotamento totale** | **0.0167 s** (1 passo, da 0 a 200) | **3.13 s** (188 passi, da 0 a 25) |
## | primo contatto, nessun vivo entro 3 m dal bersaglio | **t = 0.02 s** | **t = 2.28 s** |
## | 25 nemici entro 6 m dal bersaglio | **t = 1.68 s** | **t = 5.52 s** |
## | a regime (t = 20 s) con 200 vivi | **104 entro 6 m** (52%) | 76 entro 6 m su 160 vivi (il campo e' ancora in rampa) |
##
## **Perche' la riporta questo file e non `run.gd`.** `run.gd` dichiara i numeri
## che sono usciti da questa misura, e dichiarare una derivazione senza la
## misura sarebbe un numero scelto a occhio: `run.gd` rimanda a qui, e qui la
## tabella e' scritta per prima, coi numeri di allora.
##
## ## Perche' il test continua a volere 200 nemici
##
## La capacita' e' un criterio di m1 e resta un criterio: questo file pilota
## **la propria** `population` (`horde.population = HORDE.MAX_ENEMIES`) e la porta
## a 200 col ritmo di `run.spawn_rate()`, quindi non dipende dalla curva delle
## onde e non smette di esistere quando la curva cambia. Il tempo che ci mette e'
## anche una misura: viene stampato, ed e' il numero che rende visibile che
## raggiungere 200 ora costa dei secondi e non un passo.
##
## Nota sul contratto: `nearest_enemy` e' `-> int` e `damage_enemy` e' `-> bool`
## (piano 5.2), quindi qui si chiama **anche** il contratto, non solo
## `horde.nearest_enemy_index(...)`: se le due strade dessero risposte diverse,
## il gioco in partita punterebbe a un nemico diverso da quello che il test
## crede di aver colpito.
##
## ## `--quit-after` in headless NON e' un misurino
##
## Resta qui perche' e' costata una notte di prove false. `--quit-after N` conta
## **frame**, non passi di fisica: sotto `--headless --script` il motore gira
## senza orologio, quindi 300 iterazioni sono state 132 passi di fisica reali --
## e quel rapporto si sposta col carico della macchina, non col codice. Ne
## segue che due esecuzioni consecutive dello stesso comando, a configurazione di
## gioco identica, danno numeri diversi: durante il bisect del leak la traccia
## e' comparsa ed e' sparita senza che nessuna riga di `src/sim/` cambiasse. Le
## prime due prove erano rumore, e il colpevole vero era un suono da 0,18 s
## ancora in riproduzione all'uscita del motore.
##
## **La regola.** Un numero preso con `--quit-after` in headless e' un numero
## che cambia col carico: se qualcuno lo usa come misurino, deve saperlo prima
## di fidarsi, e non puo' confrontarlo con una corsa precedente perche' le due
## corse non hanno girato lo stesso numero di passi. Per misurare si guida un
## passo di fisso dal test -- e' il `DT` qui sotto, 1/60 s, lo stesso di
## `tests/test_gameloop.gd` -- e si contano i passi, non le iterazioni.

const H = preload("res://tools/test_harness.gd")
const HORDE = preload("res://src/sim/horde.gd")
const RUN = preload("res://src/sim/run.gd")
const GRID = preload("res://src/sim/spatial_grid.gd")
const POOL = preload("res://src/sim/object_pool.gd")
const ENEMY = preload("res://src/sim/enemy.gd")

## Passo di simulazione: quello di `tests/test_gameloop.gd`, cosi' i due numeri
## di -orda sono confrontabili. Un passo fisso e' l'unica misura riproducibile.
const DT := 1.0 / 60.0
## Seme della disposizione con cui il benchmark di griglia viene misurato.
## Vedi `_population`: serve a tornare alla condizione ad anelli e a rendere il
## numero di oggi confrontabile con quello di m1.
const SEME_CAPACITY := 20260912

## Bersaglio dei nemici in questo test: il centro dell'arena, perche' -gameplay
## non e' registrato in questo processo.
const FOCUS := Vector3.ZERO
## Un punto in cui non c'e' e non puo' esserci nessun nemico.
const LONTANO := Vector3(900.0, 0.0, 900.0)

## Oggetto del pool: serve solo per contare, non ha comportamento.
class Thing extends RefCounted:
	var tag: int = 0

## Solo l'inserimento nell'albero. Il corpo del test gira al **primo frame**, in
## `_process`: sotto `--script` l'entrata nell'albero di un nodo aggiunto a
## `root` dalla `_initialize()` passa dalla coda di messaggi, quindi
## `horde._ready()` non e' ancora partito quando `_initialize()` finisce e il
## test leggerebbe `count == 0` su un'orda che non si e' ancora costruita.
## L'orda sotto test. Campo e non variabile di `_initialize()` perche' il corpo
## del test gira al primo frame, e a quel punto `_initialize()` e' gia' tornata.
var _horde: HORDE = null

func _initialize() -> void:
	_horde = HORDE.new()
	_horde.name = "Orda"
	# Il test vuole vedere il conteggio scendere quando un nemico muore: senza
	# questo, `_top_up()` lo riemPIREbbe entro lo stesso passo.
	_horde.auto_respawn = false
	root.add_child(_horde)

## `SceneTree._process` restituisce `true` per chiudere il ciclo: e' il `quit()`
## del test, e non viene prima perche' a questo punto l'orda e' viva.
func _process(_delta: float) -> bool:
	_run()
	return true

func _run() -> void:
	var h := H.new()
	var horde: HORDE = _horde
	if horde == null:
		h.fail("l'orda aggiunta in _initialize() non e' piu' nell'albero")
		quit(h.finish("orda"))
		return

	_population(h, horde)
	_no_node_per_enemy(h, horde)
	_registration(h, horde)
	_grid_matches_linear(h)
	_nearest(h, horde)
	_spawn_points(h, horde)
	_query_budget(h, horde)
	_object_pool(h)
	_burn_in(h, horde)
	_damage_kills(h, horde)
	_touch(h, horde)
	# Per ultima, e non per caso: `_scena_vera` carica `scenes/arena_main.tscn`,
	# che registra sul contratto l'orda e il giocatore **veri**. Farla prima
	# significherebbe che le sezioni precedenti parlassero con l'altra orda senza
	# accorgersene, quindi va in fondo e poi rimette a posto il contratto.
	_scena_vera(h, horde)

	quit(h.finish("orda"))

# --- 11. Il morso: il nemico chiama Game.damage_player (milestone 7) ----------
#
# ## La sezione che dimostra il criterio n. 1 di m7
#
# Il criterio n. 1 e' una `grep`, non un'asserzione: il chiamante di
# `damage_player` deve stare in `src/`, e un chiamante solo in `tests/`
# dimostrerebbe che la funzione **funziona** e non che **qualcuno la chiami**
# (piano sez. 1.6). Qui sotto ci sono tre prove, e nessuna e' "chiamo la
# funzione e guardo che cosa fa":
#
#   1. una `grep` vera sul disco: fra i file di `src/`, `damage_player`
#      compare solo nel contratto (che lo dichiara) e in `src/sim/horde.gd`
#      (che lo chiama);
#   2. lo **spia** di sotto riceve le chiamate ma non le fa: e' il giocatore,
#      non il nemico. Il totale che arriva allo spia viene confrontato con il
#      totale che l'orda dichiara di aver consegnato (`touch_damage_last`), e
#      i due numeri devono coincidere passo per passo;
#   3. ogni numero che arriva allo spia deve essere **uno dei quattro** della
#      tabella delle specie: nessun numero di danno scritto a mano qui dentro
#      (criterio n. 6 di m7).
#
# ## Il giocatore finto e' una spia, non un giocatore
#
# `player_position` e `damage_player` sono le due API che registra -gameplay.
# Non sono un trucco per far funzionare il test: sono il contrattino che il
# nemico si trova davvero davanti in partita, e registrarle e' l'unico modo di
# misurare senza toccare `src/player/`, che non e' di questa foglia.

## Dove sta il giocatore finto. Non e' l'origine: `_player_focus()` rifiuta un
## punto a distanza quasi nulla e ripiega sul fuoco dell'orda, quindi un
## giocatore finto all'origine misurerebbe una cosa diversa dal gioco.
const FAKE_PLAYER := Vector3(3.0, 0.0, -5.0)

## Passi di misura dell'economia del morso. 1800 passi a DT = 1/60 sono 30 s,
## dieci volte il periodo massimo di morso (boss ~2.9 s): la finestra contiene
## molti periodi e non un numero che dipende dalla fase.
const TOUCH_STEPS := 1800

## Vita massima del giocatore di riferimento, **solo per tradurre un danno al
## secondo in secondi di sopravvivenza**. Non e' un numero di gioco: nessuna
## riga di `src/` lo usa e nessuno puo' leggerlo da qui. Il valore (100.0) e'
## misurato sulla scena vera, e serve a dare un'unita' leggibile ai numeri.
const PLAYER_HP_REFERENCE := 100.0

## Bande di misura, non soglie di robustezza: i numeri che escono sono scritti
## sotto questa sezione e vengono ricontrollati a ogni lancio.
##
## La cadenza: sotto `BITE_RATE_MIN` nessuno morderebbe (e il chiamante di m7
## sarebbe sparito senza che nessuno se ne accorga), sopra `BITE_RATE_MAX` il
## tetto `TOUCH_INTERVAL` non terrebbe, perche' `1/0.40 = 2.5`.
##
## **Le tre bande sotto sono cambiate in m8, e i valori di prima sono qui
## dichiarati, non cancellati.** Il numero che le muove e' `TOUCH_REACH`, sceso
## da **1.2** a **0.45**: la derivazione e' in `src/sim/enemy.gd` e la misura
## sulla scena vera e' nella sezione 12. Accorciare la portata toglie corpi a
## portata, e i morsi arrivano meno spesso.
##
## | banda | prima (1.2) | dopo (0.45) | perche' |
## |---|---|---|---|
## | cadenza misurata | 1.07-1.57 morsi/s | **0.60-1.17** | 3-5 corpi a portata invece di 5-20 |
## | sopravvivenza massima | 16.5 s | **29.2 s** | segue la cadenza |
## | rapporto danno pieno/piccolo | 2.56 | **3.27** | l'onda piccola cala piu' della piena |
##
## Il **valore di prima non e' una regressione e non e' difeso**: e' la richiesta
## dell'utente, e il piano lo dichiara (§1.11, "cosa cambia nella difficolta'").
const BITE_RATE_MIN := 0.5
const BITE_RATE_MAX := 2.5
## Secondi che un giocatore regge **fermo al centro dell'orda** con 100 hp.
const SURVIVAL_MIN := 5.0
const SURVIVAL_MAX := 35.0
## L'orda da 200 vivi puo' fare al massimo questo multiple del danno al secondo
## dell'orda piccola. **Il primo tetto dichiarato era 2.0 ed era sbagliato**:
## la misura sul campione qui sotto dava 2.56, e la differenza non e' rumore ma
## il campione dei morsi: con 25 vivi il contatto lo fanno quasi solo brute
## (5.94 hp), con 200 vivi quasi solo boss (13.71 hp), perche' l'anello intorno
## al giocatore si riempie dei nemici piu' grossi. Era 3.0 fino a m7; con
## `TOUCH_REACH` a 0.45 la misura da **3.27** e il tetto sale a 4.0. Il tetto
## resta un tetto vero: **senza** `TOUCH_INTERVAL` lo stesso campione
## crescerebbe di ~5.7 volte (contatto 3.3 volte x morso 1.7 volte).
const DPS_RATIO_MAX := 4.0

## ## Cosa misura questa sezione, e cosa non misura
##
## Misura **la produzione dell'orda**: quanti morsi tira e quanto danno consegna a
## chi riceve. Lo spia accetta ogni morso, quindi qui il numero e' il massimo
## che l'orda puo' dare. Quello che il **giocatore** sente e' circa la meta':
## `player.gd::take_damage` scarta meta' dei morsi per `INVULN_AFTER_HIT`. Sono
## due fatti diversi, e la sezione 12 misura quello vero.

## I quattro casi misurati: semi e popolazione. I primi due sono l'onda 1 (25
## vivi) su due semi diversi, il terzo la curva a meta' strada, il quarto
## l'onda 8 (200 vivi). Primo e quarto sono i due estremi che il piano dichiara.
const TOUCH_CASES := [[4242, 25], [7311, 25], [20260912, 75], [20260912, 200]]

## Accumuli dello spia. Sono **campi** e non variabili locali di questa funzione:
## una lambda di GDScript cattura per valore, e la callback qui e' un metodo,
## quindi i campi sono l'unica forma che funziona.
var _totale_danno := 0.0
var _morsi := 0
## Quante volte e' arrivato **quello** numero di danno. Le chiavi sono i valori
## della tabella delle specie: se ne compare uno che non e' in tabella, vuol
## dire che qualcuno ha scritto un danno a mano.
var _per_morso := {}
## L'ultimo numero di danno che e' arrivato allo spia. Serve a confrontarlo, in
## ogni passo in cui un morso arriva, con `horde.touch_damage_last`: i due
## numeri vengono da due conti indipendenti e devono coincidere.
var _ultimo_danno := 0.0

## Lo spia. E' **il giocatore**, non il nemico: il chiamante di `damage_player`
## e' `src/sim/horde.gd`, e questo file non chiama `damage_player` una volta
## sola, solo la registra.
func _spia_damage_player(amount: float) -> bool:
	_totale_danno += amount
	_morsi += 1
	_ultimo_danno = amount
	_per_morso[amount] = int(_per_morso.get(amount, 0)) + 1
	return true

## La posizione del giocatore finto, letta dal contratto come in partita.
func _spia_player_position() -> Vector3:
	return FAKE_PLAYER

func _touch(h, horde: HORDE) -> void:
	_touch_table(h)
	_touch_caller(h)

	# Da qui in poi l'orda ha un giocatore davanti: questa sezione va per ultima
	# apposta, perche' le precedenti misurano un'orda senza bersaglio.
	var game := _game()
	game.register_impl("player_position", _spia_player_position)
	game.register_impl("damage_player", _spia_damage_player)
	h.check(game.has_impl("damage_player"),
		"il contratto accetta damage_player: e' l'API che -gameplay registra")

	var misure: Array = []
	for caso in TOUCH_CASES:
		misure.append(_misura_morso(h, horde, int(caso[0]), int(caso[1])))
	_touch_economia(h, misure)
	_touch_game_over(h, horde)

# --- 11a. La tabella del morso ------------------------------------------------

## Il danno e la cadenza di ogni specie devono uscire dalla tabella `MASS` e da
## nient'altro. E' il criterio n. 6 di m7 (un numero in un posto solo) reso
## verificabile: se qualcuno sostituisce la formula con una tabella di danni per
## specie, qui viene fuori che non e' piu' la stessa cosa.
func _touch_table(h) -> void:
	h.check(ENEMY.TOUCH_DAMAGE_BASE > 0.0, "il morso base e' positivo")
	h.check(ENEMY.TOUCH_PERIOD > 0.0, "il periodo base e' positivo")
	h.check(ENEMY.TOUCH_REACH > 0.0, "la portata del morso e' positiva")
	h.near(ENEMY.touch_damage_of(ENEMY.RUNNER), ENEMY.TOUCH_DAMAGE_BASE, 0.000001,
		"il runner e' la base del morso: la formula e' ancorata a lui")
	h.near(ENEMY.touch_period_of(ENEMY.RUNNER), ENEMY.TOUCH_PERIOD, 0.000001,
		"e del periodo")
	for k in ENEMY.KIND_COUNT:
		var atteso := ENEMY.TOUCH_DAMAGE_BASE * ENEMY.MASS[k] / ENEMY.MASS[ENEMY.RUNNER]
		h.near(ENEMY.touch_damage_of(k), atteso, 0.000001,
			"il morso di %s esce dalla tabella MASS, non da una tabella sua"
				% ENEMY.KIND_NAMES[k])
		var periodo := ENEMY.TOUCH_PERIOD * sqrt(ENEMY.MASS[k] / ENEMY.MASS[ENEMY.RUNNER])
		h.near(ENEMY.touch_period_of(k), periodo, 0.000001,
			"la cadenza di %s esce dalla stessa tabella" % ENEMY.KIND_NAMES[k])
		if k > 0:
			h.check(ENEMY.touch_damage_of(k) > ENEMY.touch_damage_of(k - 1),
				"piu' pesante morde piu' forte: %s (%.2f) sopra %s (%.2f)"
					% [ENEMY.KIND_NAMES[k], ENEMY.touch_damage_of(k),
						ENEMY.KIND_NAMES[k - 1], ENEMY.touch_damage_of(k - 1)])
			h.check(ENEMY.touch_period_of(k) > ENEMY.touch_period_of(k - 1),
				"piu' pesante morde piu' lento: %s (%.2f s) sopra %s (%.2f s)"
					% [ENEMY.KIND_NAMES[k], ENEMY.touch_period_of(k),
						ENEMY.KIND_NAMES[k - 1], ENEMY.touch_period_of(k - 1)])
	# nessun morso uccide da solo: il capo e' la specie piu' pesante e quindi
	# quella che morde piu' forte, ed e' il numero che tiene sotto il tetto.
	h.check(ENEMY.touch_damage_of(ENEMY.BOSS) <= PLAYER_HP_REFERENCE / 4.0,
		"il morso peggiore (%s, %.2f hp) non uccide da solo il giocatore da 100 hp"
			% [ENEMY.KIND_NAMES[ENEMY.BOSS], ENEMY.touch_damage_of(ENEMY.BOSS)])
	# e nessuna specie morde piu' di una volta al secondo: sotto il periodo base.
	for k in ENEMY.KIND_COUNT:
		h.check(ENEMY.touch_period_of(k) >= ENEMY.TOUCH_PERIOD,
			"%s non morde piu' di una volta al secondo (periodo %.2f s)"
				% [ENEMY.KIND_NAMES[k], ENEMY.touch_period_of(k)])

# --- 1. Popolazione -----------------------------------------------------------

func _population(h, horde: HORDE) -> void:
	# ## Perche' questo test continua a volere 200 e l'avvio no
	#
	# `_build()` riempie a `Run.population_of(1)` = 25 dal primo di m4, e la
	# prima cosa che questo test verifica e' proprio quello: l'avvio **non** e'
	# pieno. Poi il test pilota la propria `population` e la porta a
	# `HORDE.MAX_ENEMIES`, perche' la capacita' e' un criterio di m1 e non
	# diventa inesistente quando la curva delle onde cambia.
	h.eq(horde.wave, 1, "l'orda appena costruita e' sull'onda 1")
	h.eq(horde.population, RUN.population_of(1),
		"alla costruzione la popolazione e' quella che chiede la curva")
	h.eq(horde.population, RUN.POP_BASE, "che sull'onda 1 e' Run.POP_BASE")
	h.eq(horde.count, horde.population, "e il campo e' gia' a quel numero")
	h.check(horde.count < HORDE.MAX_ENEMIES,
		"l'avvio NON e' gia' pieno: %d vivi su %d di capienza" % [horde.count, HORDE.MAX_ENEMIES])

	# La rampa fino alla capienza, **misurata**: e' il numero che rende
	# visibile che 200 nemici ora costa dei secondi e non un passo.
	horde.auto_respawn = true
	horde.population = HORDE.MAX_ENEMIES
	var passi := 0
	while horde.count < HORDE.MAX_ENEMIES and passi < 6000:
		horde.step(DT)
		passi += 1
	h.eq(horde.count, HORDE.MAX_ENEMIES, "%d nemici vivi per il criterio di m1" % HORDE.MAX_ENEMIES)
	h.check(passi > 1,
		"la capienza NON si raggiunge in un passo: %d passi = %.2f s"
			% [passi, float(passi) * DT])
	# e nessun passo ne aggiunge piu' di uno
	var aggiunti_max := 0
	for _i in 30:
		var prima := horde.count
		horde.step(DT)
		aggiunti_max = maxi(aggiunti_max, horde.count - prima)
	h.eq(aggiunti_max, 0, "a pieno non si aggiunge niente")
	horde.auto_respawn = false

	# La rampa appena fatta ha lasciato i primi nemici **convergi sul centro**:
	# il campo che il benchmark di sotto misura sarebbe un grappolo addensato, e
	# il confronto griglia/scansione cambierebbe di numero per un motivo che non
	# ha a che fare con la griglia. `reseed()` ridisegna la disposizione a 200
	# nemici ad anelli, che e' la condizione con cui quel confronto e' stato
	# misurato in m1, e rende il numero di oggi confrontabile con quello di
	# allora. Il seme e' fisso perche' il benchmark legga un numero, non una
	# disposizione casuale.
	horde.reseed(SEME_CAPACITY)
	h.eq(horde.count, HORDE.MAX_ENEMIES, "dopo il reseed ci sono ancora %d nemici" % HORDE.MAX_ENEMIES)
	h.eq(horde.transforms.size(), horde.count, "e gli array sono allineati")
	h.eq(horde.grid_unknown_cells, 0, "il reseed non ha creato celle nuove")

	h.eq(horde.transforms.size(), horde.count,
		"transforms e' lunga quanto count: e' l'invariante che arena usa per il MultiMesh")
	h.eq(horde.colors.size(), horde.count, "un colore per nemico")
	h.eq(horde.radii.size(), horde.count,
		"m8: un raggio di corpo per nemico, allineato come transforms e colors")
	h.eq(horde.velocities.size(), horde.count, "velocita': array parallelo allineato")
	h.eq(horde.hp.size(), horde.count, "hp: array parallelo allineato")
	h.eq(horde.kinds.size(), horde.count, "specie: array parallelo allineato")
	h.eq(horde.timers.size(), horde.count, "timer: array parallelo allineato")
	h.eq(horde.bites.size(), horde.count, "morso: array parallelo allineato")
	h.eq(horde.bite_timers.size(), horde.count, "timer del morso: array parallelo allineato")

	var census := horde.census()
	var somma := 0
	for k in census:
		somma += k
	h.eq(somma, horde.count, "il censimento conta tutti i nemici")
	h.eq(census.size(), ENEMY.KIND_COUNT, "censimento: una voce per specie")

	# un giro solo, con i numeri fuori: 200 assertioni sullo stesso dato
	# costerebbero piu' di quanto dicano
	var dentro := 0
	var finiti := 0
	var vivi := 0
	var specie_ok := 0
	for i in horde.count:
		var p := horde.transforms[i]
		if Vector2(p.x, p.z).length() <= horde.arena_radius + 0.001:
			dentro += 1
		if is_finite(p.x) and is_finite(p.y) and is_finite(p.z):
			finiti += 1
		if horde.hp[i] > 0.0:
			vivi += 1
		if horde.kinds[i] >= 0 and horde.kinds[i] < ENEMY.KIND_COUNT:
			specie_ok += 1
	h.eq(dentro, horde.count, "tutti i nemici nascono dentro l'arena")
	h.eq(finiti, horde.count, "nessuna posizione spazzatura")
	h.eq(vivi, horde.count, "nessun nemico nasce morto")
	h.eq(specie_ok, horde.count, "ogni specie e' in tabella")
	h.check(census[ENEMY.RUNNER] > 0, "qualche runner")
	h.check(census[ENEMY.BOSS] < horde.count / 4,
		"il boss resta raro: %d su %d" % [census[ENEMY.BOSS], horde.count])
	print("orda: avvio a %d nemici (Run.POP_BASE), portati a %d in %d passi = %.2f s "
		% [RUN.POP_BASE, horde.count, passi, float(passi) * DT]
		+ "(Run.SPAWN_RATE = %.1f/s)" % RUN.SPAWN_RATE)
	print("orda: %d nemici su %d celle, specie %s, raggio %.1f m"
		% [horde.count, horde.occupied_cells(), str(census), horde.arena_radius])

# --- 2. Nessun nodo per nemico ------------------------------------------------

func _no_node_per_enemy(h, horde: HORDE) -> void:
	var nodi := _count_nodes(root)
	print("orda: %d nemici vivi con %d nodi in tutta la scena (criterio: sotto 120)"
		% [horde.count, nodi])
	h.check(nodi < 120,
		"node_count deve stare sotto 120 con 200 nemici vivi: sono %d" % nodi)
	h.eq(horde.count, HORDE.MAX_ENEMIES, "e i nemici sono davvero 200 mentre si conta")
	h.eq(horde.get_child_count(), 0,
		"l'orda non ha figli: nessun nodo per nemico, nemmeno per accenderlo")

# --- 3. Registrazione sul contratto ------------------------------------------

func _registration(h, horde: HORDE) -> void:
	var game := _game()
	h.check(game != null, "l'autoload Game deve esistere: horde.gd si registra su di lui")
	h.check(game.horde == horde, "Game.horde = self nel _ready")
	for api in ["nearest_enemy", "damage_enemy", "random_spawn_point"]:
		h.check(game.has_impl(api), "register_impl(%s) deve aver registrato l'API" % api)
	h.check(not game.has_impl("player_position"),
		"player_position e' di -gameplay: registrarla qui sarebbe una doppia registrazione")

# --- 4. La griglia contro la scansione lineare -------------------------------

## Distribuzione nota: un incrocio sulle celle (nomi di confine), una griglia
## regolare, un mucchio a caso. Se un nemico finisce nella cella sbagliata, o se
## un secchiello perde un indice, qui si vede.
func _grid_matches_linear(h) -> void:
	h.eq(GRID.CELL, 4.0, "il piano fissa la cella a 4 unita'")
	var pts := _distribution(400)
	var grid: GRID = GRID.new()
	grid.setup(GRID.CELL, 30.0)
	h.eq(grid.unknown_cells, 0, "il riscaldamento ha creato le celle")

	grid.begin_frame()
	for i in pts.size():
		grid.insert(i, pts[i])
	h.eq(grid.unknown_cells, 0,
		"tutti i punti della distribuzione stanno nelle celle riscaldate")

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260906
	var vuoti := 0
	var sbagliati := 0
	var discordi := 0
	var primo_motivo := ""
	var atteso := PackedInt32Array()
	var got := PackedInt32Array()
	for t in 300:
		var q := Vector3(rng.randf_range(-32.0, 32.0), 0.0, rng.randf_range(-32.0, 32.0))
		var r := rng.randf_range(0.5, 9.0)
		GRID.linear_fill_radius(atteso, q, r, pts, pts.size())
		grid.fill_radius(got, q, r, pts)
		atteso.sort()
		got.sort()
		if atteso.is_empty():
			vuoti += 1
		if not _same_indices(got, atteso):
			sbagliati += 1
			if primo_motivo == "":
				primo_motivo = "q=(%.2f, %.2f) r=%.2f: griglia %d indici, lineare %d" \
					% [q.x, q.z, r, got.size(), atteso.size()]
		var lin := GRID.linear_nearest(q, r, pts, pts.size())
		var gidx := grid.nearest_index(q, r, pts)
		if gidx != lin:
			discordi += 1
			var dl := 1e9 if lin < 0 else q.distance_squared_to(pts[lin])
			var dg := 1e9 if gidx < 0 else q.distance_squared_to(pts[gidx])
			if absf(dl - dg) > 0.000001 and primo_motivo == "":
				primo_motivo = "nearest discorda su q=(%.2f, %.2f): griglia %d (d2 %.6f), lineare %d (d2 %.6f)" \
					% [q.x, q.z, gidx, dg, lin, dl]
	h.check(sbagliati == 0,
		"300 query con raggio: la griglia deve dare gli stessi indici della scansione"
		+ ("" if primo_motivo == "" else "; prima discordanza: " + primo_motivo))
	h.check(discordi == 0,
		"300 query: il piu' vicino deve coincidere con la scansione lineare"
		+ ("" if primo_motivo == "" else "; " + primo_motivo))
	h.check(vuoti > 0, "il confronto deve contenere anche query con raggio vuoto")
	print("orda: griglia e scansione lineare coincidono su 300 query (%d con raggio vuoto)" % vuoti)

	# Fuori dal quadrato riscaldato la cella non esiste, ma la risposta deve
	# essere giusta lo stesso: e' il caso in cui una griglia "ottimizzata"
	# perde un nemico, e meglio che se ne accorga qui.
	var fuori := Vector3(500.0, 0.0, 500.0)
	grid.begin_frame()
	grid.insert(pts.size(), fuori)
	h.eq(grid.unknown_cells, 1, "una cella nuova fuori dal riscaldamento: contata")
	h.eq(grid.nearest_index(fuori + Vector3(1.0, 0.0, 0.0), 5.0, _plus_one(pts, fuori)),
		pts.size(), "un nemico fuori dal quadrato riscaldato deve essere trovato lo stesso")

## `n` punti: incrocio sulle celle, griglia regolare, mucchio a caso.
func _distribution(n: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234567
	# un incrocio: coordinate su multipli esatti della cella, e due celle vicine
	pts.append(Vector3(4.0, 0.0, 4.0))
	pts.append(Vector3(8.0, 0.0, 4.0))
	pts.append(Vector3(4.0, 0.0, 8.0))
	pts.append(Vector3(-8.0, 0.0, -8.0))
	pts.append(Vector3(0.0, 0.0, 0.0))
	# una griglia regolare, un punto per cella
	for gz in 12:
		for gx in 12:
			pts.append(Vector3(float(gx) * 2.0 - 12.0, 0.0, float(gz) * 2.0 - 12.0))
	# il mucchio a caso
	for _i in maxi(0, n - pts.size()):
		pts.append(Vector3(rng.randf_range(-26.0, 26.0), 0.0, rng.randf_range(-26.0, 26.0)))
	return pts

func _plus_one(pts: PackedVector3Array, extra: Vector3) -> PackedVector3Array:
	var out := pts.duplicate()
	out.append(extra)
	return out

func _same_indices(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true

# --- 5. nearest ---------------------------------------------------------------

func _nearest(h, horde: HORDE) -> void:
	var k := 37
	h.check(k < horde.count, "indice di prova dentro la folla")
	var q := horde.transforms[k] + Vector3(0.03, 0.0, 0.03)
	var got := horde.nearest_enemy_index(q, 1.5)
	h.eq(got, k, "nearest_enemy_index deve dare l'indice atteso")
	h.eq(got, GRID.linear_nearest(q, 1.5, horde.transforms, horde.count),
		"l'indice coincide con la scansione lineare")

	# il vicino cambia: la risposta deve seguire l'indice, non restare ferma
	h.eq(horde.nearest_enemy_index(horde.transforms[90] + Vector3(0.02, 0.0, 0.0), 1.0),
		90, "un altro nemico e' il piu' vicino")

	# raggio vuoto: -1, mai un indice a caso
	h.eq(horde.nearest_enemy_index(LONTANO, 4.0), -1, "fuori dall'arena il risultato e' -1")
	h.eq(horde.nearest_enemy_index(LONTANO, 0.001), -1,
		"un millimetro di raggio non contiene nessuno")
	h.eq(horde.nearest_enemy_index(horde.transforms[0], 0.0), -1,
		"raggio zero non e' una ricerca")
	h.eq(horde.nearest_enemy_index(Vector3.ZERO, -3.0), -1, "raggio negativo: niente")

	# stessa domanda attraverso il contratto: `as int` su un int non deve dare
	# "Invalid cast", e l'indice deve essere lo stesso (piano 5.2)
	h.eq(_game().nearest_enemy(q, 1.5), k,
		"Game.nearest_enemy (-> int) restituisce lo stesso indice")
	h.eq(_game().nearest_enemy(LONTANO, 4.0), -1,
		"Game.nearest_enemy (-> int) fuori raggio restituisce -1")

# --- 6. Punti di spawn --------------------------------------------------------

func _spawn_points(h, horde: HORDE) -> void:
	var peggiore := 0.0
	var rotte := 0
	for _i in 400:
		var p := horde.random_spawn_point()
		if p == Vector3.ZERO:
			rotte += 1
			continue
		peggiore = maxf(peggiore, Vector2(p.x, p.z).length())
		if p.distance_to(FOCUS) < 12.0 - 0.001 or Vector2(p.x, p.z).length() > horde.arena_radius + 0.001:
			rotte += 1
	h.eq(rotte, 0,
		"random_spawn_point: mai ZERO, sempre dentro l'arena e lontano dal giocatore")
	h.positive(peggiore, "i punti di spawn si spargono sull'arena")
	h.check(peggiore > horde.arena_radius * 0.5,
		"i punti di spawn arrivano fino al bordo: %d su %.1f" % [int(peggiore), horde.arena_radius])

# --- 7. Budget di 1000 query --------------------------------------------------
#
# Perche' piu' giri e non uno: una corsa sola e' rumore. Il scheduling del
# processore, la frequenza che sale e scende e la cache che si scalda spostano
# due misure consecutive del 20-30%, e un'asserzione con 180 us di margine su
# un numero che gira attorno a 9000 fallisce a caso. Qui si gira piu' volte
# prendendo il **minimo**: il minimo di N corse e' la stima piu' vicina a "quanto
# costa davvero", perche' tutto quello che c'e' dentro e' rumore che si somma solo.

## Giri misurati, oltre a quello di scaldamento.
const BENCH_ROUNDS := 8
## Query per giro: il criterio della milestone parla di 1000.
const BENCH_PER_ROUND := 1000
## Raggio delle query, metri.
const BENCH_RADIUS := 6.0

func _query_budget(h, horde: HORDE) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var queries := PackedVector3Array()
	queries.resize(BENCH_PER_ROUND)
	for i in BENCH_PER_ROUND:
		queries[i] = Vector3(rng.randf_range(-28.0, 28.0), 0.0, rng.randf_range(-28.0, 28.0))

	# Scaldamento di **entrambe** le strade: senza, la scansione lineare paga la
	# prima volta il costo di una funzione mai chiamata e il confronto esce
	# falsamente a suo favore.
	for i in BENCH_PER_ROUND:
		horde.nearest_enemy_index(queries[i], BENCH_RADIUS)
		GRID.linear_nearest(queries[i], BENCH_RADIUS, horde.transforms, horde.count)

	var griglia := PackedInt64Array()
	var lineare := PackedInt64Array()
	griglia.resize(BENCH_ROUNDS)
	lineare.resize(BENCH_ROUNDS)
	for giro in BENCH_ROUNDS:
		# ordine alternato: se la CPU e' piu' veloce alla fine di un giro, non
		# puo' favorire sempre la stessa delle due
		var inverti := giro % 2 == 1
		if inverti:
			var a := _tempo_lineare(queries, horde)
			var b := _tempo_griglia(queries, horde)
			lineare[giro] = a
			griglia[giro] = b
		else:
			var a := _tempo_griglia(queries, horde)
			var b := _tempo_lineare(queries, horde)
			griglia[giro] = a
			lineare[giro] = b

	var g_min := _minimo(griglia)
	var l_min := _minimo(lineare)
	var g_med := _mediano(griglia)
	var l_med := _mediano(lineare)
	var rapporto := float(l_min) / maxf(1.0, float(g_min))
	var rapporto_med := float(l_med) / maxf(1.0, float(g_med))

	print("orda: %d query x %d giri su %d nemici, raggio %.1f m"
		% [BENCH_PER_ROUND, BENCH_ROUNDS, horde.count, BENCH_RADIUS])
	print("orda: griglia min %d us, mediana %d us | lineare min %d us, mediana %d us"
		% [g_min, g_med, l_min, l_med])
	print("orda: la griglia e' %.2f volte piu' rapida sul minimo, %.2f sulla mediana"
		% [rapporto, rapporto_med])
	print("orda: griglia per giro %s" % str(griglia))
	print("orda: lineare per giro %s" % str(lineare))
	print("orda: secchiello piu' affollato %d su %d, traboccamenti: %s"
		% [horde.worst_bucket(), GRID.BUCKET_SLOTS, str(horde.grid_overflowed())])

	h.check(not horde.grid_overflowed(),
		"nessun secchiello traboccato durante le query: la griglia stava cadendo a scansione lineare")
	h.check(g_min < 50000,
		"%d query di prossimita' su %d nemici sotto i 50 ms: %d us (minimo di %d giri)"
			% [BENCH_PER_ROUND, horde.count, g_min, BENCH_ROUNDS])
	h.check(g_med < 50000,
		"e anche la mediana dei giri sta sotto i 50 ms: %d us" % g_med)
	h.check(rapporto > 1.0,
		"la griglia deve battere la scansione lineare: %.2f volte (minimo su minimo su %d giri)"
			% [rapporto, BENCH_ROUNDS])
	h.check(rapporto_med > 1.0,
		"e deve batterla anche sulla mediana dei giri, non solo sul caso fortunato: %.2f volte"
			% rapporto_med)

func _tempo_griglia(queries: PackedVector3Array, horde: HORDE) -> int:
	var t0 := Time.get_ticks_usec()
	for i in queries.size():
		horde.nearest_enemy_index(queries[i], BENCH_RADIUS)
	return Time.get_ticks_usec() - t0

func _tempo_lineare(queries: PackedVector3Array, horde: HORDE) -> int:
	var t0 := Time.get_ticks_usec()
	for i in queries.size():
		GRID.linear_nearest(queries[i], BENCH_RADIUS, horde.transforms, horde.count)
	return Time.get_ticks_usec() - t0

func _minimo(values: PackedInt64Array) -> int:
	var m := values[0]
	for v in values:
		if v < m:
			m = v
	return m

## Mediana: copia, ordina, prende il centro. Fuori dal ciclo di gioco (e' un
## benchmark), quindi qui l'allocazione non e' un peccato.
func _mediano(values: PackedInt64Array) -> int:
	var copie := values.duplicate()
	copie.sort()
	return copie[copie.size() / 2]

# --- 8. Pool ------------------------------------------------------------------

func _object_pool(h) -> void:
	var pool: POOL = POOL.new()
	pool.configure(func() -> Object: return Thing.new(), 32)
	h.eq(pool.created(), 32, "il riscaldamento crea gli oggetti una volta sola")
	h.eq(pool.free_count(), 32, "all'inizio sono tutti liberi")
	h.eq(pool.live(), 0, "nessuno e' in uso all'inizio")

	var presi: Array = []
	for _i in 32:
		var oggetto: Object = pool.acquire()
		h.check(oggetto != null, "acquire entro capienza restituisce un oggetto")
		presi.append(oggetto)
	h.eq(pool.live(), 32, "tutti in uso")
	h.eq(pool.created(), 32, "acquire non ha creato niente")
	h.check(pool.acquire() == null, "a capienza piena acquire da null, non crea")
	h.eq(pool.rejected(), 1, "l'acquire a vuoto e' contato")

	for oggetto in presi:
		h.check(pool.release(oggetto), "release di un oggetto del pool")
	h.eq(pool.live(), 0, "tutti rilasciati")
	h.eq(pool.free_count(), 32, "la capienza e' tornata quella di prima")

	# 100000 cicli acquire/release: created() non deve muoversi di una unita'
	for _i in 100000:
		var oggetto: Object = pool.acquire()
		pool.release(oggetto)
	h.eq(pool.created(), 32,
		"100000 cicli non devono creare un solo oggetto nuovo: created() e' %d" % pool.created())
	h.eq(pool.live(), 0, "nessuna perdita di oggetti dopo 100000 cicli")
	print("orda: pool, 100000 cicli acquire/release, oggetti creati in tutto: %d" % pool.created())

# --- 9. 600 aggiornamenti -----------------------------------------------------

func _burn_in(h, horde: HORDE) -> void:
	h.eq(horde.count, 200, "si parte da 200")
	var nodi0 := _count_nodes(root)
	var obj0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var mem0 := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var passati := 0
	var morti := 0
	var morsi := 0

	for s in 600:
		horde.step(1.0 / 60.0)
		passati += 1
		morsi += horde.touch_bites_last
		# una morte ogni 5 passi: lo scambio-ultimo viene esercitato 120 volte,
		# quindi i 600 passi non sono una passeggiata
		if s % 5 == 0 and horde.count > 40:
			horde.damage_enemy(s % 37, 9999.0, Vector3(2.0, 0.0, 0.0))
			morti += 1

	h.eq(passati, 600, "600 aggiornamenti in headless senza SCRIPT ERROR")
	h.eq(morti, 120, "una morte ogni 5 passi")
	h.eq(horde.count, 200 - morti, "il conteggio scende di uno per ogni morte")
	h.eq(horde.transforms.size(), horde.count, "transforms resta allineata a count dopo le morti")
	h.eq(horde.colors.size(), horde.count, "colors resta allineata a count dopo le morti")
	h.eq(horde.hp.size(), horde.count, "anche hp resta allineata a count")
	# m8: lo scambio-ultimo sposta **anche** il raggio. Un nemico che eredita la
	# posizione di un altro e si disegna con il raggio del morto e' esattamente
	# il difetto che `radii` doveva chiudere.
	h.eq(horde.radii.size(), horde.count,
		"m8: radii resta allineata a count dopo 120 scambi-ultimo")
	var raggi_sbagliati := 0
	for i in horde.count:
		if absf(horde.radii[i] - ENEMY.RADIUS[horde.kinds[i]]) > 0.000001:
			raggi_sbagliati += 1
	h.eq(raggi_sbagliati, 0,
		"m8: ogni radii[i] e' il RADIUS della sua specie, anche dopo lo scambio-ultimo")
	h.eq(horde.kills, morti, "il contatore delle uccisioni")

	var dentro := 0
	var vivi := 0
	for i in horde.count:
		var p := horde.transforms[i]
		if is_finite(p.x) and is_finite(p.y) and is_finite(p.z):
			dentro += 1
		if horde.hp[i] > 0.0:
			vivi += 1
	h.eq(dentro, horde.count, "nessun nemico rimasto con una posizione spazzatura")
	h.eq(vivi, horde.count, "nessun nemico sopravvisso con hp negativo")
	h.check(horde.worst_bucket() <= GRID.BUCKET_SLOTS,
		"nessun secchiello traboccato: il piu' affollato ne aveva %d su %d"
		% [horde.worst_bucket(), GRID.BUCKET_SLOTS])
	h.check(not horde.grid_overflowed(), "nessuna caduta a scansione lineare")
	h.eq(horde.grid_unknown_cells, 0,
		"nessuna cella nuova dopo 600 passi: nel ciclo di gioco non si alloca")

	var nodi1 := _count_nodes(root)
	var obj1 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var mem1 := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	h.eq(nodi1, nodi0, "600 passi non aggiungono nodi")
	# Il ramo negativo del morso: in questo processo **non c'e' un giocatore**
	# (`player_position` non e' registrata, perche' e' di -gameplay), quindi
	# nessun nemico deve mordere il centro vuoto dell'arena. E' la prova che
	# l'accensione del morso dipende da `has_impl("player_position")` e non da
	# un `if` che la birra di qualcun altro.
	h.eq(morsi, 0, "senza un giocatore registrato, in 600 passi non e' arrivato un morso")
	h.eq(horde.touch_damage_last, 0.0, "e l'orda non dichiara nessun danno")
	h.eq(horde.bites.size(), horde.count, "bites allineato a count")
	h.eq(horde.bite_timers.size(), horde.count, "bite_timers allineato a count")
	h.check(obj1 <= obj0 + 16,
		"600 passi non aggiungono oggetti: %d contro %d" % [obj1, obj0])
	h.check(mem1 - mem0 < 4 * 1024 * 1024,
		"600 passi non gonfiano la memoria: +%d KB" % ((mem1 - mem0) / 1024))
	print("orda: 600 passi e %d morti, nodi %d -> %d, oggetti %d -> %d, memoria +%d KB"
		% [morti, nodi0, nodi1, obj0, obj1, (mem1 - mem0) / 1024])

# --- 10. damage_enemy uccide --------------------------------------------------

func _damage_kills(h, horde: HORDE) -> void:
	var prima := horde.count
	h.eq(prima, 80, "si riparte dagli 80 superstiti")

	var buco := 5
	var ultimo := horde.transforms[prima - 1]
	var hp_ultimo := horde.hp[prima - 1]
	var kind_ultimo := horde.kinds[prima - 1]
	var uccisioni := horde.kills

	var ucciso: bool = _game().damage_enemy(buco, 9999.0, Vector3.ZERO)
	h.check(ucciso, "Game.damage_enemy (-> bool) restituisce true quando il nemico muore")
	h.eq(horde.count, prima - 1, "damage_enemy uccide e il conteggio scende subito")
	h.eq(horde.transforms.size(), prima - 1, "transforms accorciata con lo scambio-ultimo")
	h.eq(horde.hp.size(), prima - 1, "anche hp e' accorciata")
	h.eq(horde.radii.size(), prima - 1, "m8: anche radii e' accorciata")
	h.eq(horde.kills, uccisioni + 1, "il contatore delle uccisioni e' salito")
	h.vec_near(horde.transforms[buco], ultimo, 0.0001,
		"scambio-ultimo: nel buco deve esserci il vecchio ultimo, non uno zero")
	h.eq(horde.hp[buco], hp_ultimo, "scambio-ultimo: anche hp spostato")
	h.eq(horde.kinds[buco], kind_ultimo, "scambio-ultimo: anche la specie spostata")
	h.near(horde.radii[buco], ENEMY.RADIUS[kind_ultimo], 0.000001,
		"m8 scambio-ultimo: nel buco c'e' il raggio del vecchio ultimo")

	# fuori indice: nessun crash, nessun effetto e `false` (il contratto fa
	# `as bool` sul valore di ritorno: con `void` andrebbe in errore in partita)
	h.check(not _game().damage_enemy(prima, 10.0, Vector3.ZERO),
		"indice == count: false, nessun crash")
	h.check(not _game().damage_enemy(-1, 10.0, Vector3.ZERO),
		"indice negativo: false, nessun crash")
	h.check(not _game().damage_enemy(999999, 10.0, Vector3.ZERO),
		"indice assurdo: false, nessun crash")
	h.eq(horde.count, prima - 1, "un indice fuori range non tocca niente")

	# knockback: almeno 0.3 unita' sul nemico colpito (criterio n. 4 della
	# milestone, verificato dal lato dell'orda perche' e' qui che la spinta
	# viene applicata)
	var j := 4
	var v0 := horde.velocities[j]
	var hp0 := horde.hp[j]
	var sopravvive: bool = _game().damage_enemy(j, 1.0, Vector3(4.0, 0.0, 0.0))
	h.check(not sopravvive, "Game.damage_enemy (-> bool) su un colpo non letale da' false")
	var spinta := (horde.velocities[j] - v0).length()
	h.check(spinta >= 0.3, "knockback di almeno 0.3 unita': %.3f" % spinta)
	h.near(horde.hp[j], hp0 - 1.0, 0.0001, "un colpo toglie hp")
	h.eq(horde.count, prima - 1, "un colpo non letale non ammazza nessuno")
	h.check(horde.hit_count > 0, "i colpi vengono ricordati per sfx e flash")
	h.check(ENEMY.KIND_NAMES.has(horde.kind_name(j)), "kind_name da' un nome in tabella")
	h.eq(horde.kind_name(99999), "-", "kind_name fuori range non crasha")

	# svuotare l'orda: -1 quando non resta nessuno
	var svuotati := 0
	while horde.count > 0:
		horde.damage_enemy(0, 9999.0, Vector3.ZERO)
		svuotati += 1
		if svuotati > 100:
			break
	h.eq(horde.count, 0, "orda svuotata")
	h.eq(horde.transforms.size(), 0, "transforms vuota")
	h.eq(horde.colors.size(), 0, "colors vuota")
	h.eq(horde.radii.size(), 0, "m8: anche radii si svuota con l'orda")
	h.eq(horde.nearest_enemy_index(Vector3.ZERO, 1000.0), -1,
		"senza nemici la vicina piu' vicina da' -1")

	# ## Il riempimento automatico: NON da 0 a 200 in un passo
	#
	# Questo e' il criterio n. 4 della milestone 4, dal lato della macchina: un
	# campo svuotato torna a `population` **al ritmo di `run.spawn_rate()`**, e
	# `population` nel frattempo e' cambiata con l'onda (svuotare l'orda ha
	# chiuso l'onda 1, quindi siamo sull'onda 2).
	horde.auto_respawn = true
	horde.step(DT)
	h.eq(horde.count, 0,
		"un passo dopo lo svuotamento il campo e' ancora vuoto: nessuna raffica")
	h.eq(horde.population, RUN.population_of(horde.wave),
		"e la popolazione inseguita e' quella della curva sull'onda corrente")

	var passi_pieno := 0
	while horde.count < horde.population and passi_pieno < 6000:
		horde.step(DT)
		passi_pieno += 1
	h.eq(horde.count, horde.population, "l'orda arriva a `population`, e non oltre")
	h.check(passi_pieno > 1,
		"e ci mette piu' di un passo: %d passi = %.2f s" % [passi_pieno, float(passi_pieno) * DT])
	h.eq(horde.transforms.size(), horde.count, "allineata dopo il riempimento")
	h.eq(horde.colors.size(), horde.count, "colori allineati dopo il riempimento")
	h.eq(horde.radii.size(), horde.count,
		"m8: radii si ricompone insieme agli altri nel riempimento, non dopo")
	h.eq(horde.grid_unknown_cells, 0, "i %d spawn nuovi non hanno creato celle" % horde.count)
	h.check(horde.nearest_enemy_index(Vector3.ZERO, 100.0) >= 0,
		"dopo il riempimento si trova qualcuno")

	# e adesso la capienza, di nuovo pilotata a mano, con lo stesso ritmo
	horde.population = HORDE.MAX_ENEMIES
	var passi_capienza := 0
	while horde.count < HORDE.MAX_ENEMIES and passi_capienza < 6000:
		horde.step(DT)
		passi_capienza += 1
	h.eq(horde.count, HORDE.MAX_ENEMIES, "la capienza si raggiunge anche per riempimento")
	h.check(passi_capienza > 1, "anche da %d vivi ci mette piu' di un passo: %d passi = %.2f s"
		% [RUN.population_of(horde.wave), passi_capienza, float(passi_capienza) * DT])
	h.eq(horde.count, HORDE.MAX_ENEMIES, "e non la supera")
	print("orda: svuotata e riempita di nuovo, uccisioni in tutto %d, specie %s"
		% [horde.kills, str(horde.census())])
	print("orda: da 0 a %d in %.2f s, da %d a %d in %.2f s (Run.SPAWN_RATE = %.1f/s)"
		% [RUN.population_of(horde.wave), float(passi_pieno) * DT,
			RUN.population_of(horde.wave), HORDE.MAX_ENEMIES,
			float(passi_capienza) * DT, RUN.SPAWN_RATE])

# --- 11c. L'economia del morso, misurata -------------------------------------

## Un caso di misura: dispone `pop` nemici intorno al giocatore finto, li lascia
## arrivare, warm-up, e poi guarda per `TOUCH_STEPS` passi.
##
## L'onda viene bloccata a 1 (`run.wave` e `wave_killed`) perche' altrimenti
## l'onda avanza durante il warm-up, `_sync_population()` alza `population` e il
## caso "25 vivi" finisce a misurarne 75: una misura che non descrive quello che
## dice di descrivere e' rumore, non una misura.
func _misura_morso(h, horde: HORDE, seme: int, pop: int) -> Dictionary:
	horde.auto_respawn = true
	horde.set_focus(FAKE_PLAYER)
	horde.run.wave = 1
	horde.run.wave_killed = 0
	horde.reseed(seme)
	horde.population = pop
	while horde.count > 0:
		horde.damage_enemy(0, 9999.0, Vector3.ZERO)
	var passi_pieno := 0
	while horde.count < pop and passi_pieno < 6000:
		horde.step(DT)
		passi_pieno += 1
	h.eq(horde.count, pop, "il caso seme %d e' arrivato a %d vivi" % [seme, pop])
	# warm-up: l'orda deve **arrivare**, non essere gia' addosso al primo passo
	for _i in 1800:
		horde.step(DT)

	_totale_danno = 0.0
	_morsi = 0
	_per_morso = {}
	var fuori_tabella := 0
	var delta := TOUCH_STEPS * DT
	var in_contatto := 0
	var morse_passo_max := 0
	var gap_min := 1.0e9
	var ultimo := -1
	for s in TOUCH_STEPS:
		var prima := _morsi
		horde.step(DT)
		var caduti := _morsi - prima
		if caduti > 0:
			h.eq(caduti, 1,
				"seme %d: al massimo un morso che arriva per passo (tetto a intervallo)" % seme)
			h.eq(_ultimo_danno, horde.touch_damage_last,
				"seme %d: il danno che lo spia riceve e' quello che l'orda dichiara" % seme)
			if ultimo >= 0:
				gap_min = minf(gap_min, float(s - ultimo) * DT)
			ultimo = s
		morse_passo_max = maxi(morse_passo_max, horde.touch_bites_last)
		h.eq(horde.bites.size(), horde.count, "seme %d: bites allineato a count" % seme)
		h.eq(horde.bite_timers.size(), horde.count, "seme %d: bite_timers allineato a count" % seme)
	fuori_tabella = _valori_fuori_tabella()
	h.eq(fuori_tabella, 0,
		"seme %d: ogni numero di danno arrivato allo spia e' un numero di tabella" % seme)

	for i in horde.count:
		var p := horde.transforms[i]
		var d := Vector2(p.x, p.z).distance_to(Vector2(FAKE_PLAYER.x, FAKE_PLAYER.z))
		if d <= ENEMY.RADIUS[horde.kinds[i]] + ENEMY.TOUCH_REACH:
			in_contatto += 1

	var campi := {
		"seme": seme, "pop": pop, "vivi": horde.count, "in_contatto": in_contatto,
		"morsi": _morsi, "cadenza": float(_morsi) / delta,
		"dps": _totale_danno / delta,
		"per_morso": _totale_danno / maxf(1.0, float(_morsi)),
		"sopravvivenza": PLAYER_HP_REFERENCE / maxf(0.001, _totale_danno / delta),
		"gap_min": gap_min, "morse_passo_max": morse_passo_max,
	}
	print("orda: morso seme %d, %d vivi: %d a portata, %.2f morsi/s, %.2f hp per morso, %.2f hp/s, %.1f s da fermo"
		% [seme, horde.count, in_contatto, float(campi["cadenza"]),
			float(campi["per_morso"]), float(campi["dps"]), float(campi["sopravvivenza"])])
	print("orda: morso seme %d, morsi per specie:%s" % [seme, _riparto_morsi()])
	return campi

## Quanti numeri di danno arrivati allo spia **non** sono un numero di tabella.
## Il conto e' fatto durante il caso, non dopo: e' l'unico modo per beccare un
## numero scritto a mano che arriva una volta sola su quattrocento.
func _valori_fuori_tabella() -> int:
	var fuori := 0
	for a in _per_morso:
		var riconosciuto := false
		for k in ENEMY.KIND_COUNT:
			if absf(float(a) - ENEMY.touch_damage_of(k)) < 0.000001:
				riconosciuto = true
		if not riconosciuto:
			fuori += 1
	return fuori

## Quanti morsi per specie, in ordine di specie. Legge i numeri che sono
## **arrivati allo spia** e li riconosce confrontandoli con la tabella.
func _riparto_morsi() -> String:
	var testo := ""
	for k in ENEMY.KIND_COUNT:
		var atteso := ENEMY.touch_damage_of(k)
		var trovati := 0
		for a in _per_morso:
			if absf(float(a) - atteso) < 0.000001:
				trovati = int(_per_morso[a])
		testo += " %s(%.2f hp) x%d" % [ENEMY.KIND_NAMES[k], atteso, trovati]
	return testo

# --- 11b. Il chiamante --------------------------------------------------------

## Il criterio n. 1 di m7, che e' una `grep`, resa asserzione.
##
## Un chiamante che sta solo in `tests/` **fallisce** il criterio: significherebbe
## che la funzione funziona, non che qualcuno nel gioco la chiami. Quindi qui si
## guarda il disco e non si chiama la funzione.
##
## Il confronto e' fatto sulla **chiamata** `game.damage_player(`, col ricevente in
## minuscolo: il contratto e i commenti scrivono `Game.damage_player(x)` con la G
## maiuscola, quindi il confronto non li conta. Se un giorno la chiamata cambia
## forma, questo test lo dice col nome del file: e' il segnale che la `grep` del
## vertice va rilanciata.
func _touch_caller(h) -> void:
	var citano := PackedStringArray()
	var chiamano := PackedStringArray()
	for path in _file_gdc_in("res://src"):
		if _contiene(path, "damage_player("):
			citano.append(path)
		if _contiene(path, "game.damage_player("):
			chiamano.append(path)
	citano.sort()
	chiamano.sort()
	# I tre file che possono legittimamente contenere la parola: il contratto che
	# la dichiara, `player.gd` che registra l'implementazione, e l'orda che
	# chiama. Qualunque altro nome significa che una quarta foglia e' entrata in
	# mezzo, e allora il criterio n. 1 va riletto.
	const AMMESSI := ["res://src/core/contracts.gd", "res://src/player/player.gd",
		"res://src/sim/horde.gd"]
	for path in citano:
		h.check(AMMESSI.has(path),
			"in src/ damage_player compare solo nel contratto, in player.gd e in horde.gd: trovato %s"
				% path)
	h.check(citano.has("res://src/sim/horde.gd"),
		"src/sim/horde.gd deve contenere damage_player: trovati %s" % str(citano))
	h.eq(chiamano.size(), 1,
		"in src/ deve esserci UN solo file che chiama davvero damage_player")
	h.check(chiamano.size() == 1 and chiamano[0] == "res://src/sim/horde.gd",
		"e deve essere src/sim/horde.gd, non un test: trovati %s" % str(chiamano))

## Le asserzioni sull'economia del morso, e la stampa del numero finale.
##
## Sono **bande**, non soglie: i numeri che escono sono dichiarati nella sezione
## 11 e questa funzione li ricontrolla a ogni lancio. Una banda che si stringe
## fino a diventare un numero esatto smetterebbe di misurare la cosa che
## descrive e comincerebbe a misurare il caso fortunato.
func _touch_economia(h, misure: Array) -> void:
	for m in misure:
		var seme_i := int(m["seme"])
		var pop_i := int(m["pop"])
		h.check(float(m["cadenza"]) >= BITE_RATE_MIN,
			"seme %d (%d vivi): il nemico morde davvero, %.2f morsi/s non puo' essere sotto %.1f"
				% [seme_i, pop_i, float(m["cadenza"]), BITE_RATE_MIN])
		h.check(float(m["cadenza"]) <= BITE_RATE_MAX,
			"seme %d: la cadenza rispetta il tetto TOUCH_INTERVAL (1/%.2f = %.1f morsi/s), misurata %.2f"
				% [seme_i, HORDE.TOUCH_INTERVAL, BITE_RATE_MAX, float(m["cadenza"])])
		h.check(int(m["morsi"]) > 0,
			"seme %d: almeno un morso in %d passi" % [seme_i, TOUCH_STEPS])
		h.eq(int(m["morse_passo_max"]), 1,
			"seme %d: mai piu' di un morso che arriva nello stesso passo" % seme_i)
		h.check(float(m["gap_min"]) >= HORDE.TOUCH_INTERVAL - DT - 0.000001,
			"seme %d: due morsi consecutivi distano almeno TOUCH_INTERVAL (%.4f s misurati)"
				% [seme_i, float(m["gap_min"])])
		var sopr := float(m["sopravvivenza"])
		h.check(sopr >= SURVIVAL_MIN and sopr <= SURVIVAL_MAX,
			"seme %d (%d vivi): %.1f s da fermo al centro deve stare fra %.0f e %.0f"
				% [seme_i, pop_i, sopr, SURVIVAL_MIN, SURVIVAL_MAX])
		h.check(int(m["in_contatto"]) > 0,
			"seme %d: qualcuno e' davvero a portata di morso (%d)" % [seme_i, int(m["in_contatto"])])

	# Il confronto che chiude la curva: il danno al secondo dell'orda piena non
	# e' un multiplo di quello dell'onda piccola. E' la ragione per cui il tetto
	# e' a intervallo e non per passo.
	var piccola := 1.0e9
	var grande := 0.0
	for m in misure:
		piccola = minf(piccola, float(m["dps"]))
		grande = maxf(grande, float(m["dps"]))
	var rapporto := grande / maxf(0.001, piccola)
	h.check(rapporto <= DPS_RATIO_MAX,
		"l'orda piena fa al massimo %.1f volte il danno al secondo dell'onda piccola: misurato %.2f"			% [DPS_RATIO_MAX, rapporto])
	print("orda: morso, %.0f s per caso: %.2f-%.2f hp/s, %.2f-%.2f morsi/s, %.1f-%.1f s da fermo con 100 hp, orda piena %.2f volte l'onda piccola"
		% [float(TOUCH_STEPS) * DT, piccola, grande,
			float(misure[0]["cadenza"]), float(misure[3]["cadenza"]),
			float(misure[3]["sopravvivenza"]), float(misure[0]["sopravvivenza"]),
			rapporto])

## A `game_over` la simulazione e' ferma, quindi nessun morso: il giocatore morto
## non e' un bersaglio che continua a prendere colpi. E' la continuazione della
## regola di `step()` ("lo stato della partita si guarda PRIMA di muovere
## chiunque"), vista dal lato del morso.
func _touch_game_over(h, horde: HORDE) -> void:
	var morti := _morsi
	h.check(horde.run.enter_game_over(), "la partita entra in game_over")
	h.check(horde.is_game_over(), "e horde.is_game_over() lo dice")
	for _i in 300:
		horde.step(DT)
	h.eq(_morsi, morti, "in game_over nessun morso arriva addosso")
	h.eq(horde.touch_damage_last, 0.0, "e l'orda non dichiara nessun danno")
	horde.restart_run()
	h.check(not horde.is_game_over(), "il restart rimette la partita in corso")
	h.eq(horde.touch_damage_last, 0.0, "e azzera il danno dell'ultimo passo")
	# Punto 3 del contratto di m8: `radii` si ricompone **negli stessi punti** degli
	# altri array paralleli, e il restart e' uno di quelli.
	h.eq(horde.radii.size(), horde.count,
		"m8: radii e' allineata a count dopo restart_run")
	var raggi_dopo_restart := 0
	for i in horde.count:
		if absf(horde.radii[i] - ENEMY.RADIUS[horde.kinds[i]]) > 0.000001:
			raggi_dopo_restart += 1
	h.eq(raggi_dopo_restart, 0,
		"m8: dopo il restart ogni nemico ha il raggio della sua specie")

# --- 12. m8: la portata del morso rimisurata sulla scena vera ------------------
#
# ## Perche' una sezione nuova e non una riga cambiata in `TOUCH_REACH`
#
# Il valore di prima, **1.2**, era dichiarato «misurato» in `src/sim/enemy.gd`,
# ed era misurato **sull'orda isolata di questo file**, con uno **spia** al posto
# del giocatore. Uno spia accetta ogni morso. Il giocatore vero no:
# `player.gd::take_damage` scarta il danno durante l'invulnerabilita' dopo un
# colpo (`INVULN_AFTER_HIT = 0.7 s`). Quindi la misura di m7 era **la produzione
# dell'orda**, non **l'ingestione del giocatore**, ed e' su quella che `TOUCH_REACH`
# era stato scelto. Qui sotto la scena e' vera, il giocatore e' vero, e i numeri
# che escono sono quelli che il giocatore sente.
#
# ## Cosa misura, e in che ordine
#
# 1. **Il corpo che il giocatore vede**: mezzo ingombro orizzontale del modello
#    vero, in metri. E' l'unico numero che puo' volere la parola «contatto»:
#    due corpi si toccano quando la somma dei loro raggi e' la distanza, e se il
#    nemico e' `RADIUS[kind]` allora il margine che resta al giocatore e' **il
#    suo raggio**, non una costante messa li' per andare bene.
# 2. **Dove si ferma davvero l'orda** a 200 vivi: la scala delle portate conta i
#    corpi entro `RADIUS[kind] + r`, quindi dice esattamente quanti nemici
#    morderebbero a ogni candidato. La scala contiene **0.0** (nessun margine)
#    e il **valore di prima, 1.2**: scegliere senza aver guardato entrambi
#    sarebbe scegliere a occhio.
# 3. **L'ingestione vera**: hp persi dal giocatore vero in 30 s a regime, e poi
#    il tempo fino alla morte con 100 hp.
#
# Il passo e' **fisso** (`DT`) e lo guida questo test, non il ciclo di frame:
# un passo fisso e' l'unica misura riproducibile (vedi la nota in testa al
# file). La scena resta vera — stessi nodi, stesso orda, stesso giocatore,
# stesso renderer — ma il suo `process_mode` e' disabilitato perche' due orologi
# non si misurano.

const ARENA_SCENE := "res://scenes/arena_main.tscn"
const NODO_HORDE := "Horde"
const NODO_PLAYER := "Player"

## Le portate da contare sulla scena vera. Vedi il punto 2 sopra.
const LADDER_REACH := [0.0, 0.15, 0.30, 0.45, 0.60, 0.90, 1.20]
## Passi di riscaldamento e di finestra: 1800 passi a DT sono 30 s.
const VERA_WARMUP := 1800
const VERA_WINDOW := 1800
## Vita data al giocatore vero **mentre si misura la geometria e l'ingestione**,
## cosi' il riscaldamento non finisce a `game_over` a meta' misura. `hp` e' un
## campo pubblico sul contratto di m2 ed e' gia' pilotato allo stesso modo da
## `tests/test_gameloop.gd`; nessun'altra proprieta' del giocatore e' toccata.
const VERA_HP_ALTO := 1000000.0

## La distanza minima mai vista fra il **punto** del giocatore e il **bordo del
## corpo** di un nemico (`dist - RADIUS[kind]`), su tutta la scena vera.
var _gap_min_vera := 1.0e9
## Gli stessi scarti dei nemici entro 6 m dal giocatore, campione del contatto.
var _gap_vicini := PackedFloat32Array()

func _scena_vera(h, isolate: HORDE) -> void:
	var arena = _apri_arena(h)
	if arena == null:
		return
	# Due oroli non si misurano: la scena non gira da sola, il passo e' nostro.
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var horda: HORDE = arena.get_node_or_null(NODO_HORDE) as HORDE
	var giocatore = arena.get_node_or_null(NODO_PLAYER)
	if not h.check(horda != null and giocatore != null,
			"la scena vera deve avere i nodi %s e %s" % [NODO_HORDE, NODO_PLAYER]):
		_chiudi(arena)
		_ripristina(h, isolate)
		return

	giocatore.hp = VERA_HP_ALTO
	horda.population = HORDE.MAX_ENEMIES
	var passi_pieno := 0
	while horda.count < HORDE.MAX_ENEMIES and passi_pieno < 6000:
		_passo_vera(horda, giocatore, DT)
		passi_pieno += 1
	h.eq(horda.count, HORDE.MAX_ENEMIES,
		"scena vera: l'orda arriva a %d nemici vivi, non a 25" % HORDE.MAX_ENEMIES)
	h.eq(horda.radii.size(), horda.count,
		"scena vera: anche radii e' allineata a count con 200 vivi")
	h.eq(horda.transforms.size(), horda.count, "scena vera: transforms allineata")

	# 1. il corpo che il giocatore vede, e il criterio n. 2 di m8
	var corpo := _corpo_visivo(giocatore)
	h.positive(corpo,
		"scena vera: il giocatore ha un corpo visibile di raggio positivo")
	# L'invariante, non il numero: `TOUCH_REACH` deve **uguale** il raggio del
	# corpo che il giocatore vede. E' scritto cosi' e non "vicino a 0.45" perche'
	# se il modello del giocatore cambia il numero deve cambiare con lui, e
	# l'unita' che se ne accorge e' questo assert. Rimettere `TOUCH_REACH` al
	# valore di prima (1.2) qui deve dire FAIL: e' il dente del criterio n. 2.
	h.near(ENEMY.TOUCH_REACH, corpo, 0.0001,
		"criterio n. 2: TOUCH_REACH (%.4f) e' il raggio del corpo che il giocatore VEDE (%.4f)"
			% [ENEMY.TOUCH_REACH, corpo])
	# E la forma del criterio: per **ogni** specie, la frontiera del morso e' il
	# bordo del nemice che tocca il bordo del giocatore. Nessuna specie e'
	# esclusa, quindi il numero non vale solo per il runner.
	for k in ENEMY.KIND_COUNT:
		h.near(ENEMY.RADIUS[k] + ENEMY.TOUCH_REACH, corpo + ENEMY.RADIUS[k], 0.0001,
			"criterio n. 2: il %s morde fino a %.2f m = bordo del nemico %.2f + bordo del giocatore %.2f"
				% [ENEMY.KIND_NAMES[k], ENEMY.RADIUS[k] + ENEMY.TOUCH_REACH,
					ENEMY.RADIUS[k], corpo])
	# Il numero del raggio e' **uno solo** (criterio n. 4 di m8): quello che
	# l'orda espone dev'essere quello della tabella, non una sua copia.
	var raggi_non_di_tabella := 0
	for i in horda.count:
		if absf(horda.radii[i] - ENEMY.RADIUS[horda.kinds[i]]) > 0.000001:
			raggi_non_di_tabella += 1
	h.eq(raggi_non_di_tabella, 0,
		"criterio n. 4: horde.radii[i] e' RADIUS[kinds[i]] per tutti i %d vivi" % horda.count)

	# 2. dove si ferma l'orda: scala delle portate e scarto minimo mai visto
	_gap_min_vera = 1.0e9
	_gap_vicini = PackedFloat32Array()
	for _i in VERA_WARMUP:
		_passo_vera(horda, giocatore, DT)
		_campiona_gap(horda, giocatore.global_position)
	var contatti := _conta_contatti(horda, giocatore.global_position)
	var ordinati := _gap_vicini.duplicate()
	ordinati.sort()
	var dentro := int(contatti[float(ENEMY.TOUCH_REACH)])

	print("m8 scena vera: corpo visibile del giocatore, raggio %.4f m" % corpo)
	print("m8 scena vera: scarto minimo mai visto (giocatore - bordo del corpo) %.4f m"
		% _gap_min_vera)
	if ordinati.size() > 0:
		print("m8 scena vera: scarto dei %d nemici entro 6 m -- min %.4f, mediana %.4f, max %.4f m"
			% [ordinati.size(), ordinati[0], ordinati[ordinati.size() / 2],
				ordinati[ordinati.size() - 1]])
	for r in LADDER_REACH:
		print("m8 scena vera: portata %.2f m -> %d nemici a portata di morso su %d"
			% [float(r), int(contatti[float(r)]), horda.count])
	h.check(dentro > 0,
		"scena vera: con TOUCH_REACH = %.2f qualcuno e' davvero a portata (%d su %d)"
			% [ENEMY.TOUCH_REACH, dentro, horda.count])

	# 3. l'ingestione vera: hp persi in 30 s, e poi il tempo fino alla morte
	var hp0 := float(giocatore.hp)
	var offerti := 0
	var accettati := 0
	for _i in VERA_WINDOW:
		var prima := float(giocatore.hp)
		_passo_vera(horda, giocatore, DT)
		offerti += horda.touch_bites_last
		if float(giocatore.hp) < prima:
			accettati += 1
	var persi := hp0 - float(giocatore.hp)
	var finestra := float(VERA_WINDOW) * DT
	var cadenza := float(offerti) / finestra
	var danno_morso := persi / maxf(1.0, float(accettati))
	var dps := persi / finestra
	print("m8 scena vera: %d morsi offerti in %.0f s (%.2f/s), %d accettati dal giocatore, %.2f hp persi"
		% [offerti, finestra, cadenza, accettati, persi])
	print("m8 scena vera: %.2f hp per morso accettato, %.2f hp/s, %d morsi su %d scartati dall'invulnerabilita'"
		% [danno_morso, dps, offerti - accettati, offerti])

	giocatore.hp = PLAYER_HP_REFERENCE
	var passi_morte := 0
	while float(giocatore.hp) > 0.0 and passi_morte < 6000:
		_passo_vera(horda, giocatore, DT)
		passi_morte += 1
	var morto := float(giocatore.hp) <= 0.0
	var secondi := float(passi_morte) * DT
	print("m8 scena vera: giocatore fermo al centro, %d vivi: %s dopo %.2f s (calcolato %.2f s)"
		% [horda.count, "morto" if morto else "VIVO", secondi,
			PLAYER_HP_REFERENCE / maxf(0.0001, dps)])
	h.check(morto,
		"scena vera: il giocatore vero deve morire fermo al centro con l'orda piena")
	h.check(secondi > 0.0, "scena vera: il tempo di sopravvivenza e' positivo")

	_chiudi(arena)
	_ripristina(h, isolate)

## Un passo della scena vera, a passo fisso.
##
## Della scena si guida **l'orda sola**. Del giocatore si scalda **un solo
## timer**, `invuln`, ed e' una scelta dichiarata e non una scorciatoia:
##
##   - `invuln` e' l'unica cosa che `player.gd::step` fa che riguarda il morso.
##     Senza scalarlo il giocatore vero resta **permanentemente invulnerabile**
##     dal primo colpo in poi, e la misura dell'ingestione dava 0.00 hp persi su
##     51 morsi offerti: era la prima stesura di questa sezione, ed e' il numero
##     che ha fatto capire che il valore di prima era misurato su uno spia che
##     accettava tutto.
##   - chiamare `step()` per intero porterebbe dentro la misura una **seconda
##     macchina**: l'arma che spara da sola ucciderebbe proprio gli anelli di
##     nemici che qui si stanno contando. Sarebbe la classe di difetto di
##     piano 1.5b: un ambiente che azzera la grandezza sotto esame.
##
## `invuln` e' un campo pubblico del nodo, come `hp`: qui sotto si scrivono due
## campi pubblici di un'altra foglia e non si chiama nessun suo metodo.
func _passo_vera(horda, giocatore, delta: float) -> void:
	giocatore.invuln = maxf(0.0, float(giocatore.invuln) - delta)
	horda.step(delta)

## Il contratto torna a puntare sull'orda isolata di questo file. Senza questo la
## scena vera, appena liberata, lascerebbe il contratto con `horde` e tre API
## che non portano piu' da nessuna parte: un test che viene dopo leggerebbe un
## numero e lo chiamerebbe «l'orda».
func _ripristina(h, isolate: HORDE) -> void:
	var game := _game()
	if game == null or isolate == null:
		return
	game.horde = isolate
	game.register_impl("nearest_enemy", isolate.nearest_enemy_index)
	game.register_impl("damage_enemy", isolate.damage_enemy)
	game.register_impl("random_spawn_point", isolate.random_spawn_point)
	h.check(game.horde == isolate,
		"dopo la scena vera il contratto torna a puntare all'orda isolata")

## Distanza fra il punto del giocatore e il **bordo del corpo** del nemico `i`:
## `dist - radii[i]`. E' la grandezza che `TOUCH_REACH` e' chiamato a coprire,
## e su di lei e' costruita la scala delle portate.
func _gap(horda: HORDE, centro: Vector3, i: int) -> float:
	return Vector2(horda.transforms[i].x - centro.x,
			horda.transforms[i].z - centro.z).length() - horda.radii[i]

## Campiona gli scarti: il minimo di tutti e il campione dei nemici entro 6 m.
func _campiona_gap(horda: HORDE, centro: Vector3) -> void:
	for i in horda.count:
		var g := _gap(horda, centro, i)
		_gap_min_vera = minf(_gap_min_vera, g)
		if g <= 6.0:
			_gap_vicini.append(g)

## Quanti corpi sono entro `RADIUS + r`, per ogni r della scala. Conteggio
## geometrico e quindi esatto: non serve cambiare `TOUCH_REACH` per sapere chi
## morderebbe a un portata data, basta contare gli scarti.
func _conta_contatti(horda: HORDE, centro: Vector3) -> Dictionary:
	var out := {}
	for r in LADDER_REACH:
		out[float(r)] = 0
	for i in horda.count:
		var g := _gap(horda, centro, i)
		for r in LADDER_REACH:
			if g <= float(r):
				out[float(r)] = int(out[float(r)]) + 1
	return out

## Il raggio del corpo **visibile** del giocatore: mezzo ingombro orizzontale del
## suo modello, con la scala del nodo gia' dentro. Cio' che l'occhio chiama
## «corpo del giocatore». Non e' un numero di questa foglia: e' una lettura
## della scena vera, ed e' per questo che vale come riferimento e non come
## costante duplicata da qualche parte.
func _corpo_visivo(nodo: Node) -> float:
	var mesh: Array[MeshInstance3D] = []
	_cerca_mesh(nodo, mesh)
	var semi := 0.0
	for m in mesh:
		if m.mesh == null:
			continue
		var aabb: AABB = m.mesh.get_aabb()
		var s := m.global_transform.basis.get_scale()
		semi = maxf(semi, maxf(aabb.size.x * 0.5 * absf(s.x), aabb.size.z * 0.5 * absf(s.z)))
	return semi

func _cerca_mesh(nodo: Node, out: Array[MeshInstance3D]) -> void:
	for c in nodo.get_children():
		if c is MeshInstance3D:
			out.append(c as MeshInstance3D)
		_cerca_mesh(c, out)

## `scenes/arena_main.tscn` caricata a runtime, mai in `const`: un `const preload`
## risolve i suoi script **prima** che l'autoload `Game` sia fra le costanti
## globali di GDScript, e `player.gd` usa l'identificatore nudo `Game`
## (piano 5.3, la trappola).
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

## Libera la scena **subito**: `remove_child` e poi `free`, non `queue_free`, cosi'
## l'albero e' pulito quando la funzione torna e il conteggio dei nodi dopo e' un
## numero e non una promessa.
func _chiudi(arena) -> void:
	if arena == null:
		return
	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()


## Tutti i file `.gd` sotto `dir_path`, ricorsivamente. Serve alla `grep` della
## sezione 11b: il chiamante di `damage_player` va cercato in **tutto** `src/`,
## non nella directory che questa foglia si aspetta di scrivere.
func _file_gdc_in(dir_path: String) -> PackedStringArray:
	var trovati := PackedStringArray()
	var d := DirAccess.open(dir_path)
	if d == null:
		return trovati
	for nome in d.get_files():
		if nome.ends_with(".gd"):
			trovati.append(dir_path.path_join(nome))
	for sotto in d.get_directories():
		trovati.append_array(_file_gdc_in(dir_path.path_join(sotto)))
	return trovati

func _contiene(path: String, ago: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	return f.get_as_text().contains(ago)

## Il contratto, via nodo e non via identificatore nudo.
##
## Sotto `--script` il file principale viene compilato **prima** che l'autoload
## `Game` sia registrato fra le costanti globali di GDScript: `Game.horde` qui
## dentro non da un errore di logica, da
## `Compile Error: Identifier not found: Game`, e il test morirebbe su quello
## prima di eseguire un solo assert. Il nodo che si ottiene e' lo stesso
## identico su cui horde.gd si registra, quindi la strada aggira la
## compilazione, non il contratto (piano 5.3).
func _game() -> Node:
	return root.get_node_or_null("Game")
## Conta i nodi dell'albero a mano. `get_node_count()` dentro un `--script` vale
## 0 (il ciclo di frame non e' ancora partito), quindi un test che ci si
## appoggiasse passerebbe sempre: meglio contarli davvero.
func _count_nodes(nodo: Node) -> int:
	var totale := 1
	for c in nodo.get_children():
		totale += _count_nodes(c)
	return totale