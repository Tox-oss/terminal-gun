extends SceneTree
## Test dell'HUD di terminal-gun. -ui, milestone 2.
##
## Verifica i tre numeri che m2 chiede all'interfaccia, i numeri duplicati fra
## un avvio e un restart, e il punto in cui l'HUD deve **leggere** invece di
## sapere (piano sez. 1.1, criteri n. 2 e n. 4, e la consegna di questa foglia):
##
##   1. **barra XP in [0, next] sempre**: mai `NaN`, mai `INF`, mai una larghezza
##      negativa, nemmeno con `next` a zero e nemmeno con un `INF` o un `NaN`
##      che entra dalla porta;
##   2. **contatore d'onda a 1 all'avvio**, che sale quando l'onda avanza e che
##      **torna a 1 dopo il restart**;
##   3. **game over a 0 HP**, e che sparisce al restart;
##   4. **nessun nodo duplicato** fra due restart: l'HUD ha un numero di nodi
##      fisso e lo conserva;
##   5. **il numero di nemici viene dall'orda, non da un letterale**: l'HUD
##      mostra il `count` che l'orda ha **adesso**, e lo segue quando l'orda
##      cambia. La popolazione d'avvio e' un numero di `-orda`
##      (`Run.population_of(1)`, in `src/sim/run.gd`) e non un dato di questa
##      foglia: qui dentro non c'e' nessun `25` e nessun `200`, perche' un
##      letterale diventa falso alla prima milestone che tocca la curva e,
##      intanto, fa passare un HUD con un numero scritto dentro;
##   6. **il numero che arriva all'HUD e' anche il numero che si vede**: le
##      verifiche sui campi (`xp_ratio()`, `wave_ratio()`) non bastano, perche'
##      un HUD puo' ricevere 0.995 e scrivere 1.0 sul `ProgressBar`. Ogni barra
##      viene quindi confrontata anche sul **valore disegnato**, letto dal nodo.
##      Il caso che ha reso la verifica necessaria e' `Range.step`, che vale
##      0.01 per default e **arrotonda a scatti** quello che gli viene scritto:
##      su un'onda da 200 uccisioni (`Run.population_of` e' di -orda) una
##      uccisione vale 0.005, meta' scatto, e la barra dell'onda restava ferma
##      per meta' onda. Il fix e' `step = 0.0` su tutte e tre le barre, e
##      qui si verifica su tutte e tre perche' una decisione dichiarata solo in
##      un commento decade senza rumore.
##
## ## m7: la meta' di questa foglia, e che cosa **non** e' sua
##
## Il criterio n. 4 di m7 e' «la HUD mostra la salute vera». Il cablaggio
## esisteva gia' dal primo giorno: `src/render/arena.gd` legge `Game.player.hp` e
## `Game.player.max_hp` e chiama `set_state(...)` ogni frame (arena.gd:83, 87, 91).
## La barra era **piatta** perche' nessun codice di gioco scriveva `hp`, non
## perche' mancasse un filo: quindi la meta' di `-ui` qui dentro e' **un test**,
## non un intervento.
##
## Percio' la parte nuova di questo file non scrive `hp` e non chiama
## `damage_player` a mano per poi dichiarare che la barra e' scesa: **legge la vita
## vera dal giocatore e confronta** quello che l'HUD ne ha fatto, quattro volte
## per avvio — vita iniziale, dopo un colpo, dopo una cura, a zero — e in ogni
## caso confronta tre cose: la barra **disegnata**, il rapporto **ricalcolato qui**,
## e i **numeri dentro la scritta**. Il testo non e' di questa foglia (la metafora
## e' dell'utente, RAM disponibile), quindi il confronto non e' sulla stringa: e'
## sui numeri che ci sono dentro, cosi' "HP 67 / 100" e "RAM 67% di 100" sono lo
## stesso HUD e un HUD con un numero stampato dentro non passa lo stesso.
##
## Il danno e la cura arrivano dai **metodi veri del giocatore**
## (`take_damage()`, `heal()`), che sono la porta che `Game.damage_player()`
## chiama e che -orda chiama dal ciclo di gioco: qui il test non scrive il campo
## `hp` a mano nemmeno per fare scena, perche' un test che scrive il numero che
## poi confronta sta verificando se stesso.
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
## Il terzo numero che questa parte controlla, il **conteggio dei nemici**, non
## arriva da `refresh()` ma dal canale di m1: `src/render/arena.gd::_process`
## chiama `set_state(...)` con `Game.horde.count`. Quindi anche qui il confronto
## e' sul contratto vero, e sullo stesso campo che il chiamante legge: il numero
## che l'HUD mostra e' quello che `-orda` ha adesso, mai una copia messa qui.
##
## ## Perche' esiste `_tick` e non un `arena.call("_process")` solo
##
## I due canali muoiono in due modi diversi. Un'uccisione cambia `horde.count`
## **e** `run.wave_killed`, quindi muove l'etichetta dei nemici (canale di m1,
## `set_state`) e la barra d'onda (canale di m2, `refresh`) **nello stesso
## istante**. Rilanciando un `_process` solo, si legge meta' della partita e si
## conclude che l'HUD segue l'orda quando invece segue solo una delle due.
## `_tick` chiama entrambi, ed e' l'unico posto che lo fa.
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

## Un numero che **non** sta sulla griglia di arrotondamento del default di
## `Range` (`step = 0.01`): 3.3333 non e' un multiplo di 0.01.
##
## Serve a provare che le barre disegnano il numero che l'HUD ha ricevuto e non
## quello che il nodo ha arrotondato. Con lo step di default questa verifica
## fallisce (3.33 contro 3.3333), ed e' esattamente il difetto che ha reso muta
## la barra dell'onda: il dato giusto che non si vede. Non usare qui un valore
## multiplo di 0.01, altrimenti la verifica passa senza aver mai provato niente.
const OFF_GRID := 3.3333

var _h: H = null
var _ran: bool = false
## `-ui`, m6. Il pannello delle carte **mette in pausa l'albero**, e una parte di
## questo test ha bisogno di guardare il giocatore mentre l'albero e' fermo:
## serve aspettare che passino dei frame *di fisica*, e in un test sotto
## `--script` non c'e' nessun frame da aspettare senza chiederlo.
##
## Quindi `_process` non finisce mai il test da solo: finisce solo quando `_run()`
## arriva in fondo e chiama `quit()`. `_wait_physics` sospende `_run()` con un
## `await` e il ciclo continua a girare intanto, quindi mettere in pausa
## l'albero **non ferma il test**: `SceneTree._process` e' il ciclo del
## `MainLoop`, non un nodo, e la pausa dei nodi non lo tocca (e' esattamente la
## ragione per cui il pannello puo' essere `PROCESS_MODE_ALWAYS` e il test no).
var _done: bool = false


func _initialize() -> void:
	_h = H.new()


func _process(_delta: float) -> bool:
	if _ran:
		return _done
	_ran = true
	_run()
	return _done


## Aspetta che passino `n` frame **di fisica**, non di processo.
##
## La distinzione non e' pignolerie: il criterio n. 2 chiede che "il giocatore
## non si muove", e il giocatore si muove in `_physics_process`. Aspettare frame
## di processo in un test headless -- dove il ciclo gira piu' veloce del
## realtime -- puo' voler dire che nel mezzo non e' passato **nessun** passo di
## fisica, e "non si e' mosso" passerebbe senza aver provato niente.
##
## Il contatore e' un tetto, non un'attesa infinita: se i frame di fisica non
## avanzassero, il test si bloccherebbe e il gate lo ucciderebbe fra 120 s
## dicendo "timeout", che e' un fatto diverso da "l'attesa non serve". Qui si
## esce prima e si dice il numero misurato.
const PHYSICS_WAIT_CAP := 20000

func _wait_physics(n: int) -> int:
	var start := Engine.get_physics_frames()
	var seen := 0
	while Engine.get_physics_frames() < start + n and seen < PHYSICS_WAIT_CAP:
		seen += 1
		await physics_frame
	return Engine.get_physics_frames() - start


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
	print("test_ui: popolazione d'avvio letta da horde.count e mostrata dalla HUD: %d / %d / %d"
		% [int(first["boot_pop"]), int(second["boot_pop"]), int(third["boot_pop"])])

	await _upgrade_flow(h, game)

	_done = true
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
	_health_bar(h, hud)
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

	# ## La stessa verifica sulla barra dell'XP, fuori dalla griglia del nodo
	#
	# `Range.step` vale 0.01 per default e arrotonda a scatti quello che gli viene
	# scritto, quindi questa barra si salva solo per scala: con `max_value = 8` uno
	# scatto e' un quarantesimo di barra, invisibile. Il difetto e' che si salva
	# **per caso**, non perche' il nodo non arrotondi: `hud.gd` mette `step = 0.0`
	# su tutte e tre le barre perche' qui il numero non e' di questa foglia e non
	# e' niente di suo da ri-arrotondare. Il valore scelto e' fuori dalla griglia
	# del default di proposito: 3.3333 non e' un multiplo di 0.01, e con lo step
	# di default questa verifica fallirebbe invece di passare senza aver
	# provato niente.
	hud.set_progression(OFF_GRID, XP_SPAN)
	h.near(hud.xp_bar_value(), OFF_GRID, 0.0001,
		"la barra dell'XP deve disegnare il numero che le e' stato dato, anche se non sta sulla griglia di arrotondamento del nodo: se il nodo arrotonda, la barra mente e il difetto si vede solo a occhio")

## La barra della vita: stessa regola delle altre due, e per la stessa ragione.
##
## `hud.gd` dichiara `step = 0.0` su tutte e tre le ProgressBar. Sulla barra della
## vita il difetto non si vede, perche' il suo `max_value` e' 100 e uno scatto da
## 0.01 ci sta dentro un decimo di pixel: si salva per **scala**, non perche' il
## nodo smetta di arrotondare. Percio' qui la verifica serve a **bloccare la
## decisione**: se qualcuno rimette il default di `Range` solo su questa barra,
## la difetta non romperebbe niente oggi e romperebbe tutto alla prima
## milestone che cambia la scala, che e' esattamente com'e' andata con la barra
## dell'onda.
func _health_bar(h, hud) -> void:
	hud.set_state(OFF_GRID * 20.0, 100.0, 0, "-", 0, 1)
	h.near(hud.health_bar_max(), 100.0, 0.0001, "il massimo della barra della vita e' quello dato")
	h.near(hud.health_bar_value(), OFF_GRID * 20.0, 0.0001,
		"la barra della vita deve disegnare i HP che le sono stati dati, non un numero arrotondato a scatti dal nodo: con il default di Range non si accorgerebbe nessuno, e la barra mentirebbe dal primo danno frazionario")

	# I due estremi, che sono i numeri che si vedono davvero in partita.
	hud.set_state(100.0, 100.0, 0, "-", 0, 1)
	h.near(hud.health_bar_value(), 100.0, 0.0001, "a piena vita la barra della vita e' piena")
	hud.set_state(1.0, 100.0, 0, "-", 0, 1)
	h.near(hud.health_bar_value(), 1.0, 0.0001, "a un HP la barra della vita e' quasi vuota, non vuota")

	# ## Il numero **sotto** la barra: il criterio n. 4 di m7
	#
	# Qui i numeri li mette `set_state`, quindi non c'e' niente da leggere dal
	# contratto: la parte dove vengono dal giocatore vero e' `_health_from_contract`.
	# Quello che si verifica qui e' che la Label e la barra **dicano lo stesso
	# numero**, e che l'arrotondamento sia quello dichiarato in `hud.gd` (`roundi`,
	# l'unico arrotondamento di questa foglia, e sta nella Label e non nella barra).
	#
	# I tre numeri sono scelti per distinguere `roundi` da `floor` e da `ceil`, che
	# e' la differenza fra "arrotondato" e "troncato": 66.5 arrotondato fa 67,
	# troncato 66. Con un numero intero la verifica passerebbe senza aver mai
	# provato niente. Il terzo elemento di ogni trio e' quello che **si deve
	# leggere**, scritto qui perche' un numero atteso che si ricava da se stesso
	# non e' un numero atteso: e' la regola dichiarata, non il suo risultato.
	#
	# A `_health_text_numbers` passa il numero **grezzo**: e' lei che arrotonda con
	# `roundi`, la stessa regola dichiarata in `hud.gd`. Passarle il numero gia'
	# arrotondato farebbe passare la verifica anche con un'HUD che tronca.
	for caso in [[66.5, 100.0, 67], [0.4, 100.0, 0], [99.6, 100.0, 100]]:
		hud.set_state(caso[0], caso[1], 0, "-", 0, 1)
		h.eq(int(roundi(caso[0])), int(caso[2]),
			"la regola dichiarata in hud.gd e' roundi: %.1f si deve leggere %d, non %d"
				% [caso[0], int(caso[2]), int(roundi(caso[0]))])
		_health_text_numbers(h, hud, float(caso[0]), float(caso[1]),
			"vita %s su %s" % [caso[0], caso[1]])

	# E con una vita massima che **non e' 100**: il denominatore della barra non
	# e' un numero di questa foglia (il potenziamento "vita massima" lo alza), e
	# qui dentro non deve esserci nessun `100` scritto come se lo fosse.
	hud.set_state(30.0, 120.0, 0, "-", 0, 1)
	h.near(hud.health_bar_max(), 120.0, 0.0001,
		"il massimo della barra dev'essere la vita massima che le e' stata data: se qui dentro ci fosse un 100, la barra mentirebbe dal primo potenziamento")
	h.near(hud.health_bar_value(), 30.0, 0.0001,
		"la barra della vita deve disegnare i 30 HP su 120 che le sono stati dati")
	_health_text_numbers(h, hud, 30.0, 120.0, "30 su 120")

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

	# ## Il rapporto che il nodo riesce davvero a disegnare
	#
	# `wave_ratio()` legge un **campo**, e un campo puo' dire 0.995 mentre il
	# `ProgressBar` ne disegna 1.0: e' il caso peggiore di tutti, perche' il
	# numero e' arrivato giusto e non si vede, quindi un HUD che si ispeziona
	# sembra a posto mentre a schermo mente. `Range.step` (che in Godot vale
	# 0.01 per default) arrotonda a scatti quello che gli viene scritto, e su
	# un'onda da 200 uccisioni una uccisione vale 0.005, cioe' meta' scatto: la
	# barra non si muove affatto.
	#
	# Qui il rapporto e' scelto **fuori** dalla griglia di arrotondamento
	# (0.995 non e' un multiplo di 0.01), altrimenti la verifica passerebbe
	# senza aver mai provato niente.
	hud.set_wave_progress(0.995)
	h.near(hud.wave_ratio(), 0.995, 0.0001,
		"la barra d'onda deve dire il rapporto che le e' stato dato")
	h.near(hud.wave_bar_value(), 0.995, 0.0001,
		"la barra d'onda deve poter disegnare un rapporto che non sta sulla griglia del nodo: se il nodo arrotonda, il numero arriva e non viene mostrato")

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
## Restituisce un dizionario con i tre numeri da confrontare fra gli avvii: i
## nodi dell'HUD, quanti nodi `%Hud` ci sono sotto `root`, e la popolazione
## d'avvio **letta dall'orda** (non un letterale: e' il numero che l'HUD ha
## mostrato, e serve alla stampa di `_run` per riportare un fatto misurato
## invece di una copia di uno scritto qui). Il secondo e' il contatore che
## nessuno dei due test di m1 guarderebbe: se il restart creasse un secondo HUD
## **senza liberare il primo**, il primo sarebbe gia' sparito dalla scena e
## nessun test di numero di nemici lo noterebbe.
func _scene_round(h, game: Node, arena, round_no: int) -> Dictionary:
	if not h.check(arena != null, "avvio %d: la scena non e' stata caricata" % round_no):
		return {"arena": null, "hud_nodes": -1, "huds": -1, "boot_pop": -1}
	var hud = arena.get_node_or_null(HUD_NODE)
	if not h.check(hud != null, "avvio %d: la scena deve avere il nodo \"%s\"" % [round_no, HUD_NODE]):
		return {"arena": arena, "hud_nodes": -1, "huds": -1, "boot_pop": -1}

	var huds := _count_named(root, HUD_NODE)
	h.eq(huds, 1, "avvio %d: sotto root deve esserci un solo nodo \"%s\": se il restart ne lascia due, nessuno dei test di m1 lo vede" % [round_no, HUD_NODE])

	# L'HUD alimentato dalla scena vera, non a mano: si rilanciano i due
	# `_process` della partita, che sono i due canali di ingresso dell'HUD
	# (`set_state` da arena, `refresh` dall'HUD stesso). Vedi `_tick`.
	_tick(arena, hud)
	var boot_pop := _enemies_from_contract(h, game, arena, hud, round_no)
	h.eq(hud.wave_number(), 1, "avvio %d: il contatore d'onda parte da 1" % round_no)
	h.check(not hud.game_over_visible(), "avvio %d: nessuna schermata di game over all'avvio" % round_no)

	_xp_from_contract(h, game, hud, round_no)
	_wave_from_contract(h, game, hud, round_no)
	# m7: la vita vera letta dal giocatore, prima di morire. Va qui e non dentro
	# `_death_from_contract` perche' quella finisce a 0 HP e a 0 HP non c'e' piu'
	# niente da misurare sulla barra.
	_health_from_contract(h, game, arena, hud, round_no)
	_death_from_contract(h, arena, hud, round_no)

	return {"arena": arena, "hud_nodes": _count_nodes(hud), "huds": huds, "boot_pop": boot_pop}

## Il numero di nemici che l'HUD mostra e' quello che l'orda ha **adesso**, e il
## numero lo prende l'orda, non questo file.
##
## Qui dentro non c'e' nessun letterale, ed e' il punto. La popolazione d'avvio e'
## di `-orda` (`Run.population_of(1)`, in `src/sim/run.gd`) ed e' gia' cambiata
## una volta, dalla milestone 1 a m4: un `200` scritto in questa riga non
## sarebbe un test sbagliato, sarebbe un test che aspetta di essere riscritto
## alla prossima milestone che tocca la curva, e intanto fa passare un HUD con un
## numero stampato dentro. Leggendo `horde.count` al momento del confronto, il
## test dice una cosa di piu': che l'HUD **legge**.
##
## Restituisce il numero letto, o -1 se non e' stato possibile leggerlo: serve
## alla stampa di `_run`, che riporta la popolazione d'avvio **misurata** invece
## di ripeterne una copia.
func _enemies_from_contract(h, game, arena, hud, round_no: int) -> int:
	# Il contratto e' la strada che usano gia' i due chiamanti veri di questo
	# numero: `src/render/arena.gd::_enemies()` per il valore che arriva a
	# `set_state`, e `hud.gd` per gli altri. Se `Game.horde` non c'e', l'HUD non
	# ha nulla da leggere. `is_instance_valid` perche' dopo un restart il
	# contratto puo' puntare ancora all'orda liberata: chiamare un metodo su
	# un'istanza liberata e' un errore a ogni frame.
	var horde = game.get("horde")
	if not h.check(horde is Object and is_instance_valid(horde),
			"avvio %d: il contratto deve esporre un \"horde\" valido: l'HUD non ha nulla da leggere" % round_no):
		return -1
	# E deve essere l'orda **di questa scena**: dopo un restart il contratto
	# punta alla nuova, ma se un giorno non puntasse piu' a nessuna il confronto
	# sarebbe fra due partite diverse e passerebbe lo stesso.
	if not h.check(horde is Node and arena.is_ancestor_of(horde),
			"avvio %d: l'orda del contratto non e' un nodo di questa scena: il confronto sarebbe con un'altra partita" % round_no):
		return -1

	var raw = (horde as Object).get("count")
	if not h.check(typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT,
			"avvio %d: l'orda non espone \"count\": il nome su cui l'HUD fa affidamento non esiste piu'" % round_no):
		return -1
	var alive: int = int(raw)
	h.check(alive > 0,
		"avvio %d: all'avvio l'orda deve avere nemici vivi, ne ha %d" % [round_no, alive])

	var shown := _shown_enemies(hud)
	if not h.check(shown >= 0,
			"avvio %d: la scritta dei nemici deve finire con un numero: \"%s\"" % [round_no, hud.enemy_text()]):
		return alive
	h.eq(shown, alive,
		"avvio %d: la HUD alimentata dalla scena deve mostrare i %d nemici che l'orda ha adesso" % [round_no, alive])

	_hud_follows_the_horde(h, arena, horde, hud, round_no)
	return alive

## L'HUD **segue** il conteggio, non lo ha stampato una volta sola.
##
## Il confronto di sopra dice che i due numeri sono uguali, non che il primo
## venga dal secondo: un HUD con un numero dentro passerebbe anche quello, e
## passerebbe proprio nel giorno in cui `-orda` cambia la curva. Quindi qui si
## ammazza un nemico per davvero, con l'API pubblica di `-orda`
## (`damage_enemy`, che toglie il nemico e riallinea gli array: scrivere su
## `count` a mano romperebbe l'invariante `transforms.size() == count` che
## `horde.gd` dichiara) e poi si rilegge **tutto** quello che l'HUD mostra.
##
## ## Perche' `_tick` e non un `call("_process")` solo
##
## L'HUD ha **due** canali di ingresso e muoiono in due modi diversi:
## `src/render/arena.gd::_process` chiama `set_state(...)` (vite, punteggio,
## livello, nemici, arma), mentre `src/ui/hud.gd::_process` chiama `refresh()`,
## che legge il contratto (XP, numero d'onda, barra d'onda, stato della partita).
## Rilanciare solo il primo lascia il secondo fermo al valore di prima:
## un'uccisione cambia `horde.count` **e** `run.wave_killed`, quindi muove
## l'etichetta dei nemici e la barra dell'onda insieme, e un test che ne
## rilesse uno solo misurerebbe meta' della partita. `_tick` chiama
## entrambi, in quest'ordine, ed e' l'unico posto dove lo fa.
##
## ## Cosa NON tocca questa funzione
##
## La morte di un nemico non tocca nessuna delle altre verifiche: il passo di
## simulazione che chiuderebbe l'onda e cambierebbe il numero d'onda sta in
## `horde.step()`, e qui non gira. Percio' `horde.wave` resta quello che era e
## il contatore d'onda non sale: quello lo verifica `_wave_from_contract`.
func _hud_follows_the_horde(h, arena, horde, hud, round_no: int) -> void:
	if not h.check(horde.has_method("damage_enemy"),
			"avvio %d: l'orda non espone \"damage_enemy\": questo test non puo' provare che l'HUD segua il conteggio" % round_no):
		return
	var prima: int = int(horde.get("count"))
	if not h.check(prima > 0, "avvio %d: non c'e' nessun nemico da ammazzare" % round_no):
		return
	var ucciso: bool = horde.call("damage_enemy", 0, 1000000.0, Vector3.ZERO)
	if not h.check(ucciso, "avvio %d: damage_enemy sul primo nemico avrebbe dovuto ucciderlo" % round_no):
		return

	_tick(arena, hud)

	# Canale di m1: l'etichetta dei nemici, che arriva con `set_state`.
	var adesso: int = int(horde.get("count"))
	h.eq(adesso, prima - 1,
		"avvio %d: un nemico ammazzato deve abbassare il conteggio dell'orda" % round_no)
	h.eq(_shown_enemies(hud), adesso,
		"avvio %d: la HUD deve seguire il conteggio dell'orda, non un numero scritto dentro" % round_no)

	# Canale di m2: la barra dell'onda, che arriva con `refresh()`. La stessa
	# uccisione la muove, perche' `horde.gd::_kill` chiama `run.register_kill()`:
	# verificare solo l'etichetta e passarebbe con una barra d'onda ferma a 1.0
	# per tutta l'onda, che e' il difetto che questa funzione cerca.
	if not horde.has_method("wave_bar_ratio"):
		print("test_ui: nota, avvio %d: l'orda non espone \"wave_bar_ratio()\": non posso verificare che la barra dell'onda segua l'uccisione" % round_no)
		return
	var atteso: float = horde.call("wave_bar_ratio")
	h.finite(atteso, "avvio %d: wave_bar_ratio() dopo l'uccisione deve essere un numero" % round_no)
	h.near(hud.wave_ratio(), atteso, 0.001,
		"avvio %d: dopo un'uccisione la barra d'onda dell'HUD deve essere il numero di -orda" % round_no)
	h.near(hud.wave_bar_value(), atteso, 0.001,
		"avvio %d: dopo un'uccisione la barra d'onda **disegnata** deve essere il numero di -orda, non quello di prima" % round_no)
	# E il contatore non deve essere salito: l'uccisione non e' un cambio d'onda.
	h.eq(hud.wave_number(), int(horde.get("wave")),
		"avvio %d: un'uccisione non cambia l'onda: il contatore deve dire ancora quello dell'orda" % round_no)

## I due `_process` della partita vera, in quest'ordine.
##
## Non e' un vezzo: sono i due canali dichiarati in testa al file, e un test che
## ne rilancia uno solo legge meta' dei numeri dell'HUD. `delta` a zero e' la
## scelta giusta perche' nessuno dei due deve muovere qualcosa: qui si vuole
## il ridisegno, non un passo di simulazione.
func _tick(arena, hud) -> void:
	arena.call("_process", 0.0)
	hud.call("_process", 0.0)

## L'intero **scritto** nella Label dei nemici, o -1 se non c'e'.
##
## Si prende l'ultima parola e la si prova come intero invece di usare
## `contains()`: `contains("25")` accetterebbe anche una Label che dice
## "ENEMIES 250", e un numero sbagliato che *sembra* quello giusto e'
## esattamente il difetto che questa verifica cerca.
func _shown_enemies(hud) -> int:
	var text: String = hud.enemy_text()
	var cut: int = text.rfind(" ")
	if cut < 0:
		return -1
	var tail: String = text.substr(cut + 1).strip_edges()
	if not tail.is_valid_int():
		return -1
	return int(tail)

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
			"avvio %d: la barra d'onda disegnata deve essere il numero di -orda: se il nodo arrotonda quello che gli viene scritto, il numero arriva e non viene disegnato" % round_no)
	else:
		print("test_ui: nota, avvio %d: Game.horde non espone ancora \"wave_bar_ratio()\": "
			% round_no
			+ "la barra dell'onda resta al valore di riserva e non e' disegnata. Il nome e' in hud.gd::_refresh_wave_progress.")

## --- Parte 2-bis: la vita vera (m7) --------------------------------------------
#
# ## Che cosa e' la meta' di `-ui` in m7, e perche' qui non si tocca `src/render`
#
# Il cablaggio della salute **esiste gia'** e non e' stato scritto in m7:
# `src/render/arena.gd::_health()` legge `Game.player.hp` (riga 87),
# `_health_max()` legge `Game.player.max_hp` (riga 91) e `_process` chiama
# `hud.set_state(...)` **ogni frame** (riga 83). La barra era piatta perche' `hp`
# non scendeva mai, non perche' mancasse un filo. Quindi la meta' di questa foglia
# qui dentro e' **una verifica**, e `src/render/**` non e' da toccare: e' di
# `-arena`, che in m7 non lavora.
#
# ## Perche' qui il numero non e' scritto a mano
#
# Il test scrive `xp` e `wave` sugli oggetti altrui perche' sono i numeri che il
# pannello e il contatore devono seguire, e li confronta subito dopo. La vita e'
# diversa: **non basta** scrivere `player.hp = 63.0` e guardare che la barra scenda,
# perche' quello verificherebbe che `hud.gd` sappia leggere un numero che il test
# gli ha appena dato, e non che lo **segua**: una barra ferma a 100 passerebbe lo
# stesso. Quindi qui il campo `hp` **non viene mai scritto**: si usano
# `take_damage()` e `heal()`, che sono i metodi di `-gameplay`
# attraverso cui il gioco ferisce e cura il giocatore, e il numero che la barra
# deve mostrare e' **riletto dal giocatore** a ogni passo.
#
# ## Perche' l'invulnerabilita' viene azzerata a mano
#
# `take_damage()` rifiuta il colpo mentre il giocatore e' invulnerabile, e dopo
# ogni colpo mette un temporizzatore (`invuln`) che dura qualche decimo di secondo.
# Senza azzerarlo, il secondo colpo del test non entra e la verifica non avrebbe
# niente da confrontare. Azzerare `invuln` **non e' una scorciatoia che invalida la
# prova**: e' mettere il giocatore nelle condizioni in cui un colpo entra, che e'
# esattamente la condizione che il gioco deve soddisfare quando un nemico tocca il
# giocatore. Il numero che viene dopo il colpo e' comunque quello che **il
# giocatore** calcola, non quello che il test aveva in mente.

## Quanta vita perde il giocatore a ogni colpo, in frazione della vita massima.
## Una frazione e non un numero assoluto perche' `max_hp` non e' fisso: il
## potenziamento "vita massima" lo alza, e un test che colpisse per 10 su una vita
## massima di 20 non misurerebbe niente. Il numero che conta e' la barra, non i
## punti vita persi.
const HIT_FRACTION := 0.25

## L'HUD mostra la vita vera, letta dal giocatore, almeno in un colpo.
##
## Il numero non e' scritto qui: si rilegge `player.hp` e `player.max_hp` a ogni
## passo, e si confronta con quello che l'HUD espone. L'atteso e' **ricalcolato
## qui** con la formula che l'HUD dichiara, non letto dall'HUD: se lo prendessi
## dall'HUD starei confrontando l'HUD con se stesso, che e' il difetto di m4
## riscritto.
func _health_from_contract(h, game: Node, arena, hud, round_no: int) -> void:
	var player = _contract_player(game)
	if not h.check(player != null and arena.is_ancestor_of(player),
			"avvio %d: il contratto deve esporre un \"player\" che e' un nodo di questa scena: senza, l'HUD non ha nulla da leggere" % round_no):
		return

	# ## L'avvio: la barra e' quella che il giocatore ha
	#
	# Un giocatore appena nato e' a piena vita, quindi questo confronto da solo
	# passerebbe anche con una barra fissa a 100: e' per questo che il pezzo
	# interessante e' quello dopo, col colpo.
	_tick(arena, hud)
	var hp0: float = _player_number(player, "hp")
	var max0: float = _player_number(player, "max_hp")
	if not h.check(max0 > 0.0, "avvio %d: la vita massima del giocatore dev'essere positiva, e' %s" % [round_no, max0]):
		return
	h.near(hud.health_ratio(), clampf(hp0 / max0, 0.0, 1.0), 0.0001,
		"avvio %d: a piena vita la barra dev'essere piena" % round_no)

	# ## Il colpo: `hp` scende, e la barra **insieme**
	#
	# Il numero perso e' una frazione della vita massima **vera**, quindi non e' un
	# letterale di gioco e resta giusto anche se `max_hp` cambia. Il danno entra
	# dalla porta che il gioco usa davvero: `take_damage()`, che e' anche quello
	# che `Game.damage_player()` chiama secondo il contratto di m7.
	if not h.check((player as Object).has_method("take_damage"),
			"avvio %d: il giocatore non espone \"take_damage\": la meta' di -gameplay in m7 e' renderlo chiamabile dal gioco, e questo test non puo' verificare che la barra segua un colpo" % round_no):
		return
	if not h.check((player as Object).has_method("heal"),
			"avvio %d: il giocatore non espone \"heal\": senza una cura questo test puo' vedere solo la discesa e non il ritorno, e un HUD che non risale passerebbe lo stesso" % round_no):
		return

	var amount := max0 * HIT_FRACTION
	_clear_invuln(player)
	var entrato: bool = (player as Object).call("take_damage", amount)
	if not h.check(entrato,
			"avvio %d: il colpo di %.2f vite doveva entrare: nessun codice di gioco lo chiama, ma qui non e' il test a chiamare la porta, e' take_damage() stessa" % [round_no, amount]):
		return
	var hp1: float = _player_number(player, "hp")
	h.check(hp1 < hp0,
		"avvio %d: dopo il colpo la vita doveva scendere, era %.2f ed e' %.2f" % [round_no, hp0, hp1])
	h.near(hp1, maxf(hp0 - amount, 0.0), 0.0001,
		"avvio %d: dopo il colpo la vita dev'essere hp - danno, non un numero a caso" % round_no)

	_tick(arena, hud)
	h.near(hud.health_ratio(), clampf(hp1 / max0, 0.0, 1.0), 0.0001,
		"avvio %d: la barra della vita deve scendere **insieme a hp**: il giocatore ha %.2f su %.2f e la barra dice %.4f"
			% [round_no, hp1, max0, hud.health_ratio()])
	# Il valore **disegnato**, non il ricalcolato: e' la lezione di m4, cioe' il
	# numero che arriva giusto e il nodo lo arrotonda lo stesso. Sulla barra della
	# vita il difetto si salva per scala (max 100, scatto 0.01), quindi oggi questa
	# verifica non romperebbe niente: e tenuta lo stesso, perche' e' la decisione
	# `step = 0.0` a dover restare scritta da qualche parte.
	h.near(hud.health_bar_value(), hp1, 0.0001,
		"avvio %d: la barra della vita **disegnata** deve essere la vita vera, %.2f" % [round_no, hp1])
	# E il numero sotto la barra, che e' quello che si legge: il criterio n. 4 di
	# m7 dice che la metafora e' RAM disponibile e che il testo **non** si decide
	# qui, quindi il confronto e' sui numeri dentro la scritta e non sulla stringa.
	_health_text_numbers(h, hud, hp1, max0, "dopo il colpo")

	# ## La cura: la barra sale **insieme** a hp
	#
	# Senza questo, una HUD che sapesse solo scendere passerebbe lo stesso. Il
	# numero e' meta' di quello appena tolto, quindi nessuna delle due meta' e' un
	# letterale scritto qui dentro.
	var curato: float = (player as Object).call("heal", amount)
	if not h.check(curato > 0.0,
			"avvio %d: la cura di %.2f vite doveva entrare su un giocatore vivo" % [round_no, amount]):
		return
	var hp2: float = _player_number(player, "hp")
	h.near(hp2, minf(hp1 + amount, max0), 0.0001,
		"avvio %d: dopo la cura la vita dev'essere hp + cura, fermata a max_hp" % round_no)
	_tick(arena, hud)
	h.near(hud.health_ratio(), clampf(hp2 / max0, 0.0, 1.0), 0.0001,
		"avvio %d: la barra della vita deve salire **insieme a hp**: il giocatore ha %.2f su %.2f e la barra dice %.4f"
			% [round_no, hp2, max0, hud.health_ratio()])
	_health_text_numbers(h, hud, hp2, max0, "dopo la cura")

	# ## I numeri stampati, uno per volta
	#
	# Qui sotto non si confronta niente: si **stampa** quello che e' successo, per
	#che il rapporto dell'onda abbia i numeri misurati e non una copia di quelli
	# scritti qui. Il confronto e' quello di `_health_text_numbers`, fatto a ogni
	# passo: se la scritta mostrasse ancora il numero di prima mentre `hp` e'
	# cambiato, la verifica sul testo l'avrebbe preso gia' alla riga sopra.
	print("test_ui: m7, avvio %d: vita vera %.2f -> %.2f -> %.2f su %.2f, barra disegnata %.2f, scritta \"%s\""
		% [round_no, hp0, hp1, hp2, max0, hud.health_bar_value(), hud.health_text()])

## Il giocatore che il contratto espone, o `null` se non c'e'.
##
## Il contratto e' la strada che `src/render/arena.gd` usa gia' per leggere
## `hp` e `max_hp`, quindi e' la stessa che l'HUD vede. Il controllo che il
## giocatore sia **un nodo di questa scena** e' quello che distingue "il giocatore
## vero" da "un giocatore di un'altra partita": senza, un confronto passerebbe
## anche misurando la barra contro un'altra scena.
func _contract_player(game: Node):
	var player = game.get("player")
	if not (player is Node) or not is_instance_valid(player):
		return null
	return player as Node

## Un numero del giocatore letto dal contratto, o `0.0` se il campo non esiste.
##
## Come `src/render/arena.gd::_num()`: se il nome non c'e' piu' vale il valore di
## riserva, e il confronto su quel numero fallisce con un messaggio che nomina il
## campo invece di far saltare il test. Perche' non `0.0` come segnale di errore e
## `0.0` come vita? Perche' alla vita si guarda `max_hp > 0` prima, e il controllo
## e' li' piuttosto che nascosto in un valore di riserva.
func _player_number(player: Object, key: String) -> float:
	if player == null or not is_instance_valid(player):
		return 0.0
	var raw = (player as Object).get(key)
	if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
		return float(raw)
	return 0.0

## Il numero sotto la barra della vita: intero **arrotondato**, perche' e' quello
## che si vede. `roundi` e' la stessa regola dichiarata in `hud.gd`: l'HUD non
## tronca e non arrotonda in eccesso, e qui la stessa regola viene ricalcolata per
## confrontarla, invece di rileggere il valore dall'HUD che si sta verificando.
func _health_text_numbers(h, hud, hp: float, max_hp: float, what: String) -> void:
	var numeri := _numbers_in(hud.health_text())
	if not h.check(numeri.size() >= 2,
			"%s: sotto la barra dev'essere \"<vita> / <vita massima>\", ma la scritta e' \"%s\""
				% [what, hud.health_text()]):
		return
	h.near(numeri[0], float(roundi(hp)), 0.0,
		"%s: il numero sotto la barra dev'essere la vita vera (arrotondata cosi' come la Label la arrotonda), non un numero proprio" % what)
	h.near(numeri[1], float(roundi(max_hp)), 0.0,
		"%s: il secondo numero sotto la barra dev'essere la vita massima vera, %.2f" % [what, max_hp])

## Azzera il temporizzatore d'invulnerabilita' del giocatore, se c'e'.
##
## `take_damage()` mette `invuln` dopo ogni colpo e rifiuta il successivo finche'
## non scade, quindi senza questa riga il secondo colpo non entra e non c'e' niente
## da confrontare. Il campo e' pubblico e questa e' una delle due scritture che
## questo test fa su un oggetto di un'altra foglia (l'altra e' `progression.xp`),
## ed e' dichiarata per la stessa ragione: non si puo' pilotare il giocatore senza
## toccarlo, e non si puo' dichiarare che la barra segue `hp` senza mettere `hp`
## nella condizione di cambiare.
func _clear_invuln(player: Object) -> void:
	if player == null or not is_instance_valid(player):
		return
	# Il campo e' pubblico e questa e' una delle due scritture che questo test fa
	# su un oggetto di un'altra foglia (l'altra e' `progression.xp`): non si puo'
	# pilotare il giocatore senza toccarlo. Il chiamante ha gia' verificato che
	# `take_damage` esista, quindi qui non si ricontrolla: se il campo `invuln`
	# non ci fosse, `set()` su un nome assente su un oggetto e' un no-op e
	# l'asserzione successiva ("il colpo doveva entrare") lo direbbe.
	(player as Object).set("invuln", 0.0)

## La morte: a 0 HP la schermata compare, e `arena` e' il chiamante che porta
## quel numero all'HUD. Il percorso e' quello vero, non `set_game_over(true)`
## scritto a mano: la schermata deve comparire perche' il giocatore e' morto,
## non perche' qualcuno si e' ricordato di dirlo.
func _death_from_contract(h, arena, hud, round_no: int) -> void:
	var player = arena.get_node_or_null("Player")
	if not h.check(player is Object, "avvio %d: la scena deve avere il nodo Player" % round_no):
		return
	# Il colpo che uccide passa dalla porta del giocatore, non dalla scrittura
	# del campo: `take_damage()` e' la via che `Game.damage_player()` chiama
	# secondo il contratto di m7, e quindi la stessa che il nemico usa in gioco.
	# Un valore maggiore della vita massima porta `hp` a zero per il clamp del
	# giocatore, non per una soglia scritta qui.
	if h.check((player as Object).has_method("take_damage"),
			"avvio %d: il giocatore non espone \"take_damage\"" % round_no):
		_clear_invuln(player)
		(player as Object).call("take_damage", _player_number(player, "max_hp"))
	else:
		# Ripiego dichiarato: il campo `hp` resta pubblico, quindi questa riga
		# funziona anche se `take_damage` sparisce. Non e' il percorso di m7, ed e'
		# per questo che il ramo di sopra e' quello che il test prova.
		player.set("hp", 0.0)
	_tick(arena, hud)
	h.check(hud.game_over_visible(),
		"avvio %d: il player a 0 HP deve mostrare la schermata di game over" % round_no)
	h.check(hud.health_ratio() <= 0.001,
		"avvio %d: a 0 HP anche la barra della vita deve essere vuota" % round_no)

	# E il ritorno: il restart rimette il giocatore in piedi, quindi la
	# schermata non deve essere un'insegna appesa per sempre. Il numero non e'
	# scritto qui: si rimette in piedi il giocatore e si rilegge la vita che si e'
	# dato da solo, cosi' la verifica non ha un secondo numero di mano.
	if h.check((player as Object).has_method("restart_run"),
			"avvio %d: il giocatore non espone \"restart_run\"" % round_no):
		(player as Object).call("restart_run")
	else:
		player.set("hp", _player_number(player, "max_hp"))
	_tick(arena, hud)
	h.check(_player_number(player, "hp") > 0.0,
		"avvio %d: dopo il restart il giocatore dev'essere in piedi: hp e' %.2f" % [round_no, _player_number(player, "hp")])
	h.check(not hud.game_over_visible(),
		"avvio %d: tornato in vita il giocatore, la schermata di game over deve sparire" % round_no)

# --- Parte 3: il pannello delle scelte (m6) -------------------------------------
#
# `choose()` non era chiamato da nessuna parte del gioco (piano sez. 1.6, primo
# difetto della sezione): uccidi, sali di livello, senti un suono, e non
# succede niente. Fino a m5 i test chiamavano `choose(0)` e misuravano che
# `choose` funzionasse; il criterio n. 1 di m6 chiede l'opposto, e questa parte
# e' scritta per non poterlo passare per sbaglio:
#
#   - nessuna riga di questa parte chiama `choose()`, `apply()` o
#     `_on_card_pressed`. Il livello sale **uccidendo**, con l'API pubblica di
#     `-orda`, e la scelta la fa **premedendo il bottone**, con un evento di
#     mouse. Il percorso e' quattro passi, e quattro sono pezzi di codice di
#     gioco: `Button.pressed` -> `hud._on_card_pressed` -> `progression.choose`
#     -> `progression.apply`.
#   - se il pannello non chiamasse `choose()`, qui `pending()` resterebbe a 3 e
#     il danno non cambierebbe: il test va rosso da solo.

## Danno con cui il test ammazza un nemico. Volutamente enorme: il nemico deve
## morire al primo colpo, e la sua vita e' di `-orda` (`enemy.gd`), quindi qui non
## c'e' nessuna soglia da indovinare e nessun numero di gioco.
const KILL_DAMAGE := 1000000000.0

## Quanti frame di fisica si aspettano per vedere se il giocatore si muove. Tre
## bastano: `MOVE_SPEED` e' 7 m/s e la decelerazione e' 40 m/s^2, quindi anche
## con una spinta piccola il primo passo lo muove di qualche centesimo.
const MOVE_FRAMES := 3

## La spinta data al giocatore per misurare se si muove. Il test non ha
## tastiera e il giocatore non si muove da solo, quindi "non si e' mosso" senza
## una spinta passerebbe **sempre**, anche col gioco che corre: e un controllo
## che passa sempre non e' un controllo. Il numero e' arbitrario e serve solo a
## essere non nullo.
const PLAYER_PUSH := 6.0

## Quanta distanza conta come "si e' mosso". Sotto questa soglia il confronto
## sarebbe fra due numeri che differiscono per il rumore dei float.
const MOVE_EPS := 0.01

## Soglia con cui un numero della carta combacia con una variazione misurata.
## Un punto percentuale: abbastanza stretto da notare che "25%" non e' "30%",
## abbastanza largo da non litigare con l'ultimo bit di un `*= 1.25` ripetuto.
const CARD_NUM_TOL := 0.011

func _upgrade_flow(h, game: Node) -> void:
	var arena = _open_arena(h, game)
	if arena == null:
		return
	var hud = arena.get_node_or_null(HUD_NODE)
	var player = arena.get_node_or_null("Player")
	var horde = game.get("horde")
	var prog = _progression(game)
	if not h.check(hud != null and player != null,
			"avvio m6: la scena deve avere i nodi \"%s\" e \"Player\"" % HUD_NODE):
		_close(arena)
		return
	if not h.check(horde is Object and is_instance_valid(horde),
			"avvio m6: il contratto non espone un'orda valida: nessun livello puo' salire"):
		_close(arena)
		return
	if not h.check(prog != null,
			"avvio m6: nessuna progressione nel contratto: l'HUD non ha nulla da leggere"):
		_close(arena)
		return
	var weapon = player.get("weapon")
	if not h.check(weapon != null, "avvio m6: il giocatore non ha un'arma: nessun potenziamento puo' cambiare"):
		_close(arena)
		return

	# ## Perche' la finestra viene ridimensionata, e con quali numeri
	#
	# Sotto `--script` la `Window` radice nasce a 64x64, la dimensione di default
	# del motore: nessuna scena principale viene aperta, quindi nessuno legge
	# `display/window/size/viewport_width` da `project.godot`. La GUI pero'
	# **rifiuta** un evento di mouse fuori dal rettangolo della viewport, quindi
	# un clic sul centro di una carta non arriverebbe a nessun bottone e il
	# pannello sembrerebbe non cliccabile quando e' solo fuori dallo schermo.
	# I due numeri vengono da `project.godot`, non scritti qui: sono la misura
	# della finestra che l'HUD e' disegnato per (`scenes/hud.tscn` ha offset
	# assoluti su 1280x720), e rileggere il valore invece di copiarlo e' la
	# differenza fra una verifica che gira e una che aspetta che qualcuno cambi
	# la risoluzione.
	var vp_w := int(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
	var vp_h := int(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	root.size = Vector2i(vp_w, vp_h)
	h.eq(root.size, Vector2i(vp_w, vp_h),
		"la finestra radice deve avere la dimensione che dichiara project.godot: sotto --script nasce a 64x64 e la GUI scarta ogni clic fuori da quella")

	# --- zero: il pannello non c'e', e il gioco non e' fermo ------------------
	h.eq(_pending(prog), 0, "all'avvio non ci sono scelte da prendere")
	h.check(not hud.upgrade_panel_visible(),
		"all'avvio il pannello delle carte non si vede")
	h.eq(hud.upgrade_cards_shown(), 0,
		"all'avvio nessuna carta e' visibile: un pannello nato aperto mostra scelte che non esistono")
	h.check(not paused,
		"all'avvio il gioco non deve essere in pausa: e' il pannello a metterla in pausa, e solo quando e' aperto")

	_process_mode_declared(h, hud)

	var nodes_boot := _count_nodes(root)
	_node_budget(h, nodes_boot, "all'avvio")

	# --- uno: uccidendo sale di livello da solo -------------------------------
	#
	# Il livello sale perche' il test ha ucciso dei nemici, non perche' abbia
	# scritto un campo. Le due meta' della catena sono le due righe dentro
	# `_kill_until`: `damage_enemy` e' l'API pubblica di `-orda` e toglie il
	# nemico davvero, `weapon.on_kill()` e' la riga che `weapon_base` chiama
	# quando un suo proiettile torna indietro e che finisce in
	# `progression.on_kill(1)`. Nessuna delle due tocca `offers`: se il pannello
	# non ci fosse, qui sotto il livello salirebbe e non succederebbe comunque
	# niente.
	var kills := _kill_until(h, prog, horde, weapon, 2)
	print("test_ui: m6, uccisioni fino al primo livello: %d" % kills)
	h.eq(_level_of(prog), 2,
		"uccidendo %d nemici il livello deve essere salito da solo a 2, senza che nessuno tocchi la progressione" % kills)
	h.eq(_pending(prog), 3,
		"un livello appena salito deve offrire 3 scelte: pending() e' di -gameplay, qui non c'e' nessun 3 scritto")

	# Il pannello si apre nel frame in cui l'HUD rilegge il contratto: e' lo
	# stesso canale che gia' porta XP e numero d'onda, non un secondo canale.
	_tick(arena, hud)

	h.check(hud.upgrade_panel_visible(),
		"salendo di livello il pannello delle carte si deve aprire da solo: nessuno, nel gioco, apre niente")
	h.check(paused,
		"col pannello aperto l'albero deve essere in pausa: senza, il giocatore corre mentre si sceglie e la scelta non e' una scelta")
	h.eq(hud.upgrade_cards_shown(), _pending(prog),
		"il pannello deve mostrare esattamente le offerte disponibili")
	h.eq(_count_nodes(root), nodes_boot,
		"aprire il pannello non puo' creare un nodo: le carte sono nella scena dal primo frame, e un nodo nato a meta' partita e' quello che un restart moltiplica")
	_node_budget(h, _count_nodes(root), "col pannello aperto")

	var ids := _offer_ids(prog)
	print("test_ui: m6, id offerti dal livello %d: %s" % [_level_of(prog), str(ids)])
	# --- due: col pannello aperto il giocatore non si muove -------------------
	await _stays_put(h, player, "col pannello delle carte aperto")

	# --- tre: una scelta sola, e le altre due si buttano ---------------------
	#
	# ## La regola, e di chi e'
	#
	# «me li fa scegliere tutti e 3, non solo 1»: la regola nuova e' **una sola
	# scelta e le altre due buttate**, e l'ha decisa **l'utente** (2026-10-13),
	# non il codice. `choose(index)` **svuota** `offers`, quindi `pending()` va
	# da 3 a 0 con **una** pressione e non 3 -> 2 -> 1 -> 0.
	#
	# Per questo qui si preme **una** carta e non tre: un test che ne preme tre
	# sarebbe scritto sul contratto che l'utente ha cambiato, e direbbe rosso o
	# verde sul significato sbagliato. Il pannello **non si tocca**: chiama
	# `choose()` una volta sola e fa esattamente quello che faceva, e cambia solo
	# la semantica di `choose()`, che e' di `-gameplay`.
	#
	# ## Perche' si preme la carta 1 e non la 0
	#
	# Nessuna in particolare: e' la seconda delle tre, cosi' la verifica non
	# passerebbe nemmeno con un pannello che applicasse sempre la prima. La
	# regola vecchia aveva un motivo per l'indice 1 (gli indici si spostavano a
	# ogni scelta); quella non c'e' piu', e questo commento non la riporta indietro
	# per abitudine.
	var offerte := _offer_ids(prog)
	h.eq(offerte.size(), _pending(prog),
		"la lista delle offerte e pending() devono dire la stessa cosa: sono la stessa coda letta in due modi")
	if not h.check(_pending(prog) > 0, "prima della scelta deve esserci almeno un'offerta da prendere"):
		_close(arena)
		return
	var idx: int = 1
	if not h.check(idx < offerte.size(),
			"la carta %d non esiste fra le %d offerte" % [idx, offerte.size()]):
		_close(arena)
		return

	# La carta che il pannello **mostra** adesso, letta dalle Label.
	var shown_title: String = hud.upgrade_card_title(idx)
	var shown_effect: String = hud.upgrade_card_effect(idx)
	if prog.has_method("offer_label"):
		h.eq(shown_title, _offer_label(prog, idx),
			"la carta %d deve mostrare il nome che -gameplay da' per l'indice %d di adesso" % [idx, idx])

	var snap_before := _snapshot(player)
	# ## Il percorso della scelta passa dai clic, e questo e' il fatto
	#
	# L'esperimento «clic o nessun clic» e' stato fatto e il suo risultato sta
	# qui perche' resta: **col clic la scelta c'e', col segnale del bottone non
	# c'e'**. Quindi il percorso che il gioco usa e' `Button.pressed` ->
	# `_on_card_pressed` -> `choose()` -> `apply()`, e i due fatti che lo rendono
	# possibile sono due, non uno: sotto `--script` la finestra radice nasce a
	# 64x64 e la GUI scarta i clic fuori da quel rettangolo (per questo qui
	# sopra la finestra viene ridimensionata), e `BaseButton.action_mode` vale
	# `BUTTON_RELEASE` quindi un bottone emette `pressed` quando il tasto si
	# alza e serve premuto **e** rilasciato. Sono fatti che valgono per
	# qualunque GUI di questo progetto, e il secondo e' il motivo per cui qui
	# sotto ci sono due eventi e non uno.
	var how := _press_card(hud, prog, idx)
	h.eq(how, "clic",
		"la scelta deve arrivare da un clic del mouse: il percorso e' Button.pressed -> _on_card_pressed -> choose() -> apply(), e nessuno dei quattro passi puo' essere questo test")
	var snap_after := _snapshot(player)

	# ## Le tre cose che la regola nuova chiede di dire
	#
	# 1. `pending()` e' 3 prima e **0** dopo **una** pressione: non 2.
	h.eq(_pending(prog), 0,
		"una sola scelta deve svuotare la coda delle offerte: pending() va da 3 a 0, non scende di uno a uno")
	# E la coda svuotata e' anche la **condizione** che fa rullare il livello
	# dopo (`add_xp` rulla solo se `offers.is_empty()`): se le altre due restassero
	# in lista, il giocatore salirebbe e non gli verrebbe piu' niente da scegliere.
	h.eq(_offer_ids(prog), [],
		"le altre due offerte devono essere buttate e non lasciate in lista: con la coda piena il livello successivo non rulla niente")
	# 2. **Uno solo** dei tre potenziamenti e' stato applicato: un numero reale e'
	# cambiato, e gli altri due no. E' `_card_number_matches`, che da quando la
	# regola e' questa confronta **tutti** i numeri cambiati e non basta che
	# uno combaci (vedi la sua nota).
	_card_number_matches(h, str(offerte[idx]), shown_effect, snap_before, snap_after)

	h.check(not hud.upgrade_panel_visible(),
		"esaurita la scelta il pannello deve sparire da solo: nessuno, nel gioco, deve ricordarsi di chiuderlo")
	h.eq(hud.upgrade_cards_shown(), 0, "esaurita la scelta nessuna carta deve restare visibile")
	h.check(not paused,
		"esaurita la scelta l'albero deve tornare a girare: una pausa che resta e' una partita che non riprende")
	h.eq(_count_nodes(root), nodes_boot,
		"chiudere il pannello non puo' liberare un nodo: le carte erano gia' nella scena dal primo frame")
	await _does_move(h, player, "a pannello chiuso")

	# --- quattro: al livello dopo ne arrivano altre tre, distinte -------------
	#
	# 3. La terza cosa che la regola nuova chiede di dire: uccidendo ancora,
	# senza toccare niente, la coda si riempie **di nuovo** e di offerte
	# diverse. Se il pannello tenesse le carte che ha appena buttato, qui
	# mostrerebbe nomi e numeri che non corrispondono a nessuna offerta viva.
	var kills2 := _kill_until(h, prog, horde, weapon, 3)
	h.eq(_level_of(prog), 3,
		"uccidendo altri %d nemici il livello deve essere salito a 3 da solo" % kills2)
	h.eq(_pending(prog), 3,
		"il livello successivo deve offrire di nuovo 3 scelte: e' la coda svuotata dalla scelta precedente a far rullare")
	var ids_dopo := _offer_ids(prog)
	print("test_ui: m6, id offerti dal livello %d: %s" % [_level_of(prog), str(ids_dopo)])
	h.eq(ids_dopo.size(), 3, "al livello 3 devono esserci tre offerte nuove")
	# ## «altre tre, distinte»: cosa si puo' affermare, e cosa no
	#
	# **Non** si puo' affermare che nessuna delle tre sia una delle tre di prima:
	# il sorts e' di `-gameplay` (`rng_seed + level * 977 + kills`) e un id puo'
	# ricomparire fra due livelli. Misurato qui: al livello 2 escono
	# `vitality, move_speed, knockback` e al livello 3 `projectile_speed,
	# vitality, fire_rate`: `vitality` e' in tutte e due le liste. Un test che
	# chiedesse la disgiunzione dei due insiemi sarebbe un test che pretende da
	# `-gameplay` una cosa che `-gameplay` non ha dichiarato, e che domani
	# cambierebbe il seme farebbe fallire senza che nessun difetto sia nato.
	#
	# Quello che e' invece proprio di questa foglia, e che qui si verifica:
	# le tre carte mostrate sono le tre offerte **di adesso**. Il confronto e'
	# con `offer_label(i)` letto dal contratto vivo, quindi un pannello che
	# tenesse i testi di prima lo prenderebbe qui.
	var visti := {}
	for id in ids_dopo:
		h.check(not visti.has(id),
			"al livello 3 l'offerta \"%s\" e' stata tirata due volte nello stesso livello: le tre carte devono essere tre potenziamenti diversi" % id)
		visti[id] = true
	# E il sorts non e' ricominciato da capo: un pannello che mostrasse le stesse
	# tre carte di prima sarebbe fermo, e qui nessuno si e' fermato.
	h.check(ids_dopo != offerte,
		"al livello 3 il pannello mostra esattamente le stesse tre carte del livello 2: i sorts non si e' rilanciato")
	print("test_ui: m6, id scartati al livello 2: %s" % str(offerte))

	_tick(arena, hud)
	h.check(hud.upgrade_panel_visible(), "al livello successivo il pannello deve riaprirsi da solo")
	h.eq(hud.upgrade_cards_shown(), 3, "il pannello riaperto deve mostrare tutte e tre le offerte nuove")
	if prog.has_method("offer_label"):
		for i in ids_dopo.size():
			h.eq(hud.upgrade_card_title(i), _offer_label(prog, i),
				"la carta %d del livello successivo deve mostrare il nome dell'offerta nuova che occupa quella posizione" % i)

	# --- cinque: il restart ---------------------------------------------------
	var before_restart := _count_nodes(root)
	player.call("restart_run")
	_tick(arena, hud)
	h.eq(_pending(prog), 0, "dopo il restart non deve restare nessuna scelta pendente")
	h.check(not hud.upgrade_panel_visible(),
		"dopo il restart il pannello delle carte non deve riaprire con le scelte del livello prima")
	h.check(not paused, "dopo il restart il gioco non deve restare in pausa")
	h.eq(_count_nodes(root), before_restart,
		"il restart non puo' far crescere il numero di nodi: il pannello non crea e non libera nulla")
	_node_budget(h, _count_nodes(root), "dopo il restart")

	# E il pannello torna a funzionare dopo il restart: uno che funziona solo al
	# primo livello e' un pannello che una partita lunga non usa mai.
	_kill_until(h, prog, horde, weapon, 2)
	_tick(arena, hud)
	h.check(hud.upgrade_panel_visible(),
		"dopo il restart il pannello deve aprirsi di nuovo al livello successivo")
	h.check(paused, "dopo il restart il pannello deve di nuovo fermare il gioco")
	h.eq(_pending(prog), 3, "dopo il restart il livello deve offrire di nuovo 3 scelte")
	h.eq(_press_card(hud, prog, 0), "clic",
		"dopo il restart il pannello deve accettare di nuovo il clic del mouse")
	h.eq(_pending(prog), 0,
		"dopo il restart una sola scelta deve esaurire il livello come la prima volta: pending() va a 0, non a 2")

	# ## Si esce con il pannello **aperto**
	#
	# Con la regola nuova una scelta chiude il pannello, quindi per arrivare
	# all'uscita con l'albero fermo si sale di un altro livello e **non** si
	# sceglie niente. Il pannello aperto e' lo stato da cui l'HUD esce, ed e'
	# l'unico in cui la pausa e' ancora di qualcuno.
	_kill_until(h, prog, horde, weapon, 4)
	_tick(arena, hud)
	h.check(hud.upgrade_panel_visible(),
		"precondizione: senza scegliere niente il pannello resta aperto")
	h.check(paused, "precondizione: il pannello aperto tiene l'albero in pausa")

	# ## La pausa restituita all'uscita
	#
	# Il pannello e' aperto e ci resta: si chiude la scena **cosi' com'e'**, e
	# l'HUD che esce dall'albero deve restituire la pausa che aveva preso.
	# `get_tree().paused` e' globale: un HUD che sparisce mentre l'albero e' fermo
	# lo lascia fermo per sempre, senza piu' nessuno che possa toglierla. In un
	# test che esce subito dopo si vede come `2 ObjectDB instances were leaked`:
	# il motore chiude l'albero in pausa e non scarica la coda dei messaggi.
	_close(arena)
	h.check(not paused,
		"un HUD che esce dall'albero deve restituire la pausa che aveva preso: se no l'albero resta fermo per sempre e nessuno puo' rimetterlo in moto")

## Uccide nemici finche' la progressione non arriva a `target`, e dice quante
## uccisioni sono servite.
##
## Il livello sale perche' il test ha **ucciso**, non perche' abbia scritto un
## campo: `damage_enemy` e' l'API pubblica di `-orda` e toglie il nemico
## davvero, `weapon.on_kill()` e' la riga che `weapon_base` chiama quando un suo
## proiettile torna indietro e che finisce in `progression.on_kill(1)`. Nessuna
## delle due tocca `offers`: se il pannello non ci fosse il livello salirebbe lo
## stesso e non succederebbe niente.
##
## Il tetto su `guard` e' un tetto, non un'attesa: senza nemici (`count == 0`) o
## con un `damage_enemy` che non uccide, il ciclo deve uscire e dire che non ha
## potuto arrivare al livello invece di girare per sempre.
func _kill_until(h, prog, horde, weapon, target: int) -> int:
	var kills := 0
	var guard := 0
	while _level_of(prog) < target and guard < 400:
		guard += 1
		if int((horde as Object).get("count")) <= 0:
			break
		var died: bool = (horde as Object).call("damage_enemy", 0, KILL_DAMAGE, Vector3.ZERO)
		if not h.check(died, "verso il livello %d: il nemico %d doveva morire al primo colpo" % [target, guard]):
			break
		kills += 1
		weapon.call("on_kill")
	return kills

## Il `process_mode` **dichiarato** su radice, pannello e pulsanti.
##
## Letto **prima** che l'albero vada in pausa, e per un motivo che e' il difetto
## stesso: mentre l'albero e' fermo il motore riscrive temporaneamente il
## process mode dei nodi che non possono elaborare, quindi leggere li'
## misurerebbe `DISABLED` e non quello che c'e' nella scena. E non basta il
## primo livello: `PROCESS_MODE_INHERIT` risale al padre, quindi dichiarare la
## radice e lasciare i pulsanti a `INHERIT` funziona finche' nessuno sposta un
## nodo -- ed e' esattamente il difetto che non si vede.
func _process_mode_declared(h, hud) -> void:
	h.eq(hud.upgrade_process_mode_at("."), Node.PROCESS_MODE_ALWAYS,
		"la radice dell'HUD deve essere PROCESS_MODE_ALWAYS: con l'albero in pausa deve continuare a leggere il contratto, se no il pannello si apre e resta muto")
	h.eq(hud.upgrade_process_mode_at("Root/Upgrade"), Node.PROCESS_MODE_ALWAYS,
		"il pannello delle carte deve essere PROCESS_MODE_ALWAYS: un pannello che non riceve input non si puo' cliccare")
	var n := 0
	while hud.upgrade_card_path(n) != "":
		h.eq(hud.upgrade_process_mode_at(hud.upgrade_card_path(n)), Node.PROCESS_MODE_ALWAYS,
			"la carta %d deve essere PROCESS_MODE_ALWAYS, non PROCESS_MODE_INHERIT: il pulsante e' quello che riceve il clic" % n)
		n += 1
	h.check(n > 0, "il pannello delle carte deve avere almeno un pulsante da premere")

## Il tetto di nodi: il criterio n. 3 di m1 chiede `node_count < 120` e il
## confronto vero e' "non cresce", perche' un tetto che non si tocca puo' essere
## un tetto che nessuno guarda.
func _node_budget(h, nodes: int, when: String) -> void:
	h.check(nodes < 120,
		"%s: la scena vera conta %d nodi e il tetto di m1 e' 120: il pannello delle carte non puo' farlo salire" % [when, nodes])
	# La stampa e' il numero **misurato**, non quello che il piano scrive.
	print("test_ui: m6, nodi sotto root %s: %d" % [when, nodes])

## Con il pannello aperto il giocatore non si muove. Misurato, non dedotto.
func _stays_put(h, player, what: String) -> void:
	var prima: Vector3 = player.global_position
	# Una spinta: il test non ha tastiera e il giocatore non si muove da solo,
	# quindi senza questa riga "non si e' mosso" direbbe niente.
	player.velocity = Vector3(PLAYER_PUSH, 0.0, 0.0)
	var aspettati := await _wait_physics(MOVE_FRAMES)
	h.check(aspettati >= MOVE_FRAMES,
		"%s: i frame di fisica non sono avanzati (%d su %d): l'attesa non ha potuto provare niente" % [what, aspettati, MOVE_FRAMES])
	var dopo: Vector3 = player.global_position
	h.check(prima.distance_to(dopo) <= 0.0001,
		"%s: il giocatore si e' spostato di %.4f metri mentre l'albero era in pausa" % [what, prima.distance_to(dopo)])

## Il controllo di `_stays_put`: la stessa attesa, ma senza pausa, deve muovere.
func _does_move(h, player, what: String) -> void:
	var prima: Vector3 = player.global_position
	player.velocity = Vector3(PLAYER_PUSH, 0.0, 0.0)
	var aspettati := await _wait_physics(MOVE_FRAMES)
	var dopo: Vector3 = player.global_position
	h.check(aspettati >= MOVE_FRAMES,
		"%s: i frame di fisica non sono avanzati (%d su %d)" % [what, aspettati, MOVE_FRAMES])
	h.check(prima.distance_to(dopo) > MOVE_EPS,
		"%s: il giocatore doveva muoversi e non si e' mosso di %.4f metri: l'attesa di _stays_put non avrebbe provato niente" % [what, prima.distance_to(dopo)])

## Preme davvero il pulsante della carta `index`, e dice **come**.
##
## Il percorso e' un evento di mouse, non una chiamata: il criterio n. 1 vieta che
## sia il test a scegliere, e chiamare `hud._on_card_pressed(0)` da qui sarebbe
## esattamente la stessa cosa che chiama `choose(0)`. Con l'evento il percorso
## e' `Button.pressed` -> `_on_card_pressed` -> `choose()` -> `apply()`: quattro
## passi, quattro pezzi di codice di gioco.
##
## Se l'evento di mouse non arriva, il ripiego e' il segnale `pressed`, che e'
## comunque il segnale che il bottone emette quando lo si preme, e il test
## **dichiara quale delle due strade ha preso**. Un test che cambia strada in
## silenzio e' un test che un giorno smette di provare la strada vera.
func _press_card(hud, prog, index: int) -> String:
	var path: String = hud.upgrade_card_path(index)
	var card := hud.get_node_or_null(path) as Button
	if card == null:
		hud.fail("la carta %d non esiste: \"%s\"" % [index, path])
		return "nessuna carta"
	if not card.is_visible_in_tree():
		hud.fail("la carta %d non e' visibile: non si puo' premere un bottone che non si vede" % index)
		return "nascosta"

	var prima := _pending(prog)
	var centro: Vector2 = card.get_global_rect().get_center()
	# Premuto **e rilasciato**: `BaseButton.action_mode` vale
	# `ACTION_MODE_BUTTON_RELEASE` di default, quindi un bottone emette
	# `pressed` quando il tasto si alza, non quando si abbassa. Un solo evento di
	# pressione arriverebbe al bottone e non produrrebbe nessuna scelta: sembrerebbe
	# che il pannello non sia cliccabile, e invece non e' stato finito il clic.
	#
	# E `flush_buffered_events()` dopo ognuno: `Input.use_accumulated_input` vale
	# `true` di default, quindi `parse_input_event` **accoda** l'evento e lo
	# consegna alla GUI al frame dopo. Senza la flush l'evento arriverebbe
	# davvero, ma un frame dopo, e qui si confronterebbe `pending()` subito:
	# un verde che aspetta il frame giusto senza che nessuno lo sappia e' un
	# verde che aspetta per sempre.
	Input.parse_input_event(_mouse_button(MOUSE_BUTTON_LEFT, true, centro))
	Input.flush_buffered_events()
	Input.parse_input_event(_mouse_button(MOUSE_BUTTON_LEFT, false, centro))
	Input.flush_buffered_events()
	# ## Il successo e' «`pending()` e' cambiato», non «e' sceso di uno»
	#
	# La regola e' dell'utente (2026-10-13): `choose()` svuota la coda, quindi
	# dopo una scelta `pending()` va a zero e non a due. La domanda che questa
	# funzione fa al contratto resta la stessa prima e dopo il cambio di regola,
	# ed e' la piu' piccola che si possa fare: la coda delle offerte e' cambiata
	# oppure no.
	if _pending(prog) != prima:
		return "clic"

	card.pressed.emit()
	if _pending(prog) != prima:
		return "segnale"
	return "non e' successo niente"

## Un evento di mouse a un punto dello schermo. Le coordinate sono sia locali
## sia globali perche' la GUI le cerca con le une e con le altre a seconda del
## percorso che fa l'evento nella viewport.
func _mouse_button(button: int, down: bool, at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = down
	ev.position = at
	ev.global_position = at
	return ev

## Criterio n. 4: il numero scritto sulla carta contro quello che `apply()` ha
## fatto davvero, misurato campando **tutti** i numeri che lo script del
## giocatore e quello dell'arma espongono.
##
## La lista dei campi non e' scritta qui: si legge `get_property_list()` con il
## filtro `PROPERTY_USAGE_SCRIPT_VARIABLE`, quindi se `-gameplay` aggiunge un
## campo a `apply()` questa verifica lo vede senza che nessuno la aggiorni.
##
## ## Perche' **tutti** i numeri cambiati, e non uno
##
## Con la regola vecchia bastava che **uno** dei numeri cambiati combaciasse con
## quello scritto sulla carta: se ne applicavano tre, ne cambiavano tre, e la
## verifica passava guardando uno solo dei tre. Oggi la regola e' **una scelta e
## le altre due buttate**, quindi il numero giusto da confrontare e' l'unico
## insieme di numeri che la carta premuta spiega: se uno dei due potenziamenti
## scartati avesse toccato il suo campo, quel numero non sarebbe spiegato da
## quello sulla carta e qui va rosso. Un confronto che ne tollera uno su tre non
## distingue "una scelta" da "tre scelte", che e' esattamente la domanda.
##
## Il caso che resta spiegato da una carta sola e sono due campi e' `vitality`,
## che alza `max_hp` e cura della stessa quantita`: e` voluto, perche' la carta
## dice "+20" e i due numeri cambiano di 20.
func _card_number_matches(h, id: String, shown: String, prima: Dictionary, dopo: Dictionary) -> void:
	var cambiamenti: Array[String] = []
	for k in prima.keys():
		if not dopo.has(k):
			continue
		var a: float = prima[k]
		var b: float = dopo[k]
		if absf(b - a) > 0.000001:
			cambiamenti.append("%s da %s a %s" % [k, a, b])
	if not h.check(cambiamenti.size() > 0,
			"applicata la carta \"%s\", nessun numero di arma o giocatore e' cambiato: apply() non ha fatto niente" % id):
		return
	var numeri := _numbers_in(shown)
	if not h.check(numeri.size() > 0,
			"la carta \"%s\" mostra \"%s\": non c'e' nessun numero da confrontare con quello che apply() fa davvero (misurato: %s)"
			% [id, shown, ", ".join(cambiamenti)]):
		return
	for k in prima.keys():
		if not dopo.has(k):
			continue
		var a: float = prima[k]
		var b: float = dopo[k]
		if absf(b - a) <= 0.000001:
			continue
		var rapporto := INF
		if absf(a) > 0.000001:
			rapporto = b / a
		var spiegato := false
		for n in numeri:
			if _cambia_di(n, a, b, rapporto):
				spiegato = true
				break
		if not h.check(spiegato,
				"la carta \"%s\" (%s) spiega il suo potenziamento ma qualcos'altro e' cambiato: \"%s\". Se gli altri due potenziamenti scartati fossero stati applicati, i loro campi comparirebbero qui e non sarebbero spiegati da questa carta"
				% [id, shown, ", ".join(cambiamenti)]):
			return

## Un numero scritto sulla carta spiega una variazione misurata?
##
## Quattro forme, perche' la carta non e' obbligata a parlare in percento: un
## "+25%", un "-15%" (la cadenza sale e l'intervallo scende: la stessa cosa detta
## al contrario), un "1.25" (il moltiplicatore), e un "+20" (una vita massima,
## che e' additiva e non ha rapporto).
func _cambia_di(n: float, prima: float, dopo: float, rapporto: float) -> bool:
	if absf(n - (dopo - prima)) <= 0.05:
		return true
	if not is_finite(rapporto):
		return false
	if absf(n / 100.0 - (rapporto - 1.0)) <= CARD_NUM_TOL:
		return true
	if absf(n / 100.0 - (1.0 - rapporto)) <= CARD_NUM_TOL:
		return true
	if absf(n - rapporto) <= CARD_NUM_TOL:
		return true
	if absf(n / 100.0 - rapporto) <= CARD_NUM_TOL:
		return true
	return false

## I numeri dentro un testo. Accetta il punto e la virgola decimali e un segno
## iniziale, e salta tutto quello che non e' un numero: cosi' va bene sia
## "Danno +25%" sia "x1.25" sia "20 HP in piu'".
func _numbers_in(text: String) -> Array[float]:
	var trovati: Array[float] = []
	var i := 0
	var n := text.length()
	while i < n:
		var c := text[i]
		if c == "-" or c == "+" or (c >= "0" and c <= "9"):
			var j := i
			if text[j] == "-" or text[j] == "+":
				j += 1
			var visto_numero := false
			var visto_separatore := false
			while j < n:
				var d := text[j]
				if d >= "0" and d <= "9":
					visto_numero = true
					j += 1
				elif (d == "." or d == ",") and visto_numero and not visto_separatore:
					visto_separatore = true
					j += 1
				else:
					break
			if visto_numero:
				var pezzo := text.substr(i, j - i)
				if pezzo.begins_with("+"):
					pezzo = pezzo.substr(1)
				if not pezzo.is_empty() and pezzo.is_valid_float():
					trovati.append(pezzo.to_float())
			i = maxi(j, i + 1)
			continue
		i += 1
	return trovati

## I numeri che lo script di un oggetto espone, con un prefisso per non
## confondere un campo del giocatore con uno dell'arma.
func _numeric_props(obj: Object, prefix: String) -> Dictionary:
	var out := {}
	if obj == null:
		return out
	for p in (obj as Object).get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var nome := str(p["name"])
		var v = (obj as Object).get(nome)
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			out[prefix + nome] = float(v)
	return out

## Un'istantanea di **tutti** i numeri del giocatore e dell'arma.
func _snapshot(player: Object) -> Dictionary:
	var out := {}
	out.merge(_numeric_props(player, "p:"), true)
	out.merge(_numeric_props(player.get("weapon"), "w:"), true)
	return out

## Quante scelte non ancora prese, lette dal contratto. `-1` se non si puo' sapere.
func _pending(prog) -> int:
	if prog == null or not (prog as Object).has_method("pending"):
		return -1
	var raw = (prog as Object).call("pending")
	if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
		return -1
	return maxi(int(raw), 0)

## Gli id offerti adesso, copiati: la copia serve perche' `offers` e' la lista
## viva e questa funzione non deve scriverci dentro.
func _offer_ids(prog) -> Array:
	if prog == null:
		return []
	var raw = (prog as Object).get("offers")
	if not (raw is Array):
		return []
	return (raw as Array).duplicate()

## Il nome che `-gameplay` da' per quell'indice, letto dalla sua API.
func _offer_label(prog, index: int) -> String:
	if prog == null or not (prog as Object).has_method("offer_label"):
		return ""
	return str((prog as Object).call("offer_label", index))

func _level_of(prog) -> int:
	if prog == null:
		return 0
	return int((prog as Object).get("level"))

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
