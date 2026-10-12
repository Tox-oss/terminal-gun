extends SceneTree
## Criterio n. 2 della milestone 2: **l'XP fa salire di livello, e non e' finta**.
## -gameplay, `tests/test_progression.gd`. Piano sez. 1.1, riga 2.
##
## Tre cose, tutte misurate sulla **scena vera** (`scenes/arena_main.tscn`, con
## l'orda vera di -orda, il giocatore vero e l'arma che spara da sola):
##
##   1. **le uccisioni sono reali e il livello dipende da loro.** Il percorso e'
##      l'unico che il gioco usa: proiettile -> `Game.damage_enemy(...)` che
##      risponde `true` (piano sez. 5.2) -> `weapon_base.on_kill()` ->
##      `player.on_enemy_killed()` -> `progression.on_kill(1)`. Nessuna scorciatoia:
##      nessuna `add_xp` a mano, nessun `progression.add_xp(...)` per far salire il
##      livello, nessun nemico creato a mano. Il livello viene confrontato con la
##      funzione **calcolata dal test** del numero di uccisioni, letta dalle
##      costanti della progressione a runtime: se l'XP arrivasse da una strada
##      diversa dal `true` di `damage_enemy`, il confronto fallirebbe anche se il
##      livello salisse lo stesso.
##   2. **la barra XP e' un numero, sempre.** `xp` in `[0, xp_to_next())` e
##      `progress()` in `[0, 1]`, controllati **in ogni frame** di ogni ciclo, e
##      poi provati con un `NAN` e un `INF` infilati a mano: la guardia non e'
##      decorativa e il criterio non e' soddisfatto da una barra che oggi e' sana.
##   3. **l'XP di un ucciso non e' perso al cambio d'onda.** Il numero che decide
##      e' l'invariante contabile tenuta **in ogni frame**:
##
##          xp_earned  ==  xp + somma delle soglie dei livelli saliti
##
##      Se un cambio d'onda azzerasse qualcosa, o se un ucciso attraversasse il
##      confine dell'onda senza portare la sua XP, questa identita' si romperebbe
##      **esattamente lì**. E al confine viene anche misurato, frame per frame,
##      che `xp_earned` cresce di `xp_per_kill` per ogni uccisione.
##
## ## Il percorso delle uccisioni e' quello vero anche dove costa di piu'
## L'onda 1 si chiude con `Run.WAVE_BASE` = 200 uccisioni: quel numero non e'
## cambiato e non e' scritto qui dentro, arriva dalla tabella di `run.gd`. Con il
## danno di codice (10.0) servirebbero circa 1400 colpi e qualche migliaio di
## passi di simulazione: il test per prima cosa **alza il danno** a un valore che
## uccide con un colpo, e lo dichiara. Non e' una scorciatoia: e' l'impalcatura del
## tempo, e la prova di "l'XP non e' finta" (sezione 1) gira con il **danno di
## codice**, intatto. Cio' che il criterio n. 2 misura e' da quanti `true` di
## `damage_enemy` passa, non da quanti punti fa un colpo.
##
## Dal primo di m4 c'e' un secondo tetto al ritmo: l'orda non e' piena al primo
## frame, si riempie a `Run.SPAWN_RATE` nemici al secondo, quindi le 200
## uccisioni dell'onda 1 non costano piu' 200 passi ma ~`200 / SPAWN_RATE`
## secondi di simulazione. Il numero di passi **misurato** e' stampato in fondo
## alla sezione 3, e il tetto `TETTO_PASSI` e' dichiarato per quello.
##
## ## La trappola del `const preload` (piano sez. 5.3)
## `scenes/arena_main.tscn` si carica con `load()` **dentro il corpo del test**,
## mai in `const`: un `const preload` risolve gli script a tempo di compilazione,
## PRIMA che l'autoload `Game` sia fra le costanti globali, e `player.gd` usa
## l'identificatore nudo `Game`. `res://src/sim/run.gd` invece e' un `RefCounted`
## che non nomina mai `Game`: li' il `const preload` e' sicuro, ed e' la strada
## che gia' usano `tests/test_orda.gd` e `tests/test_gameloop.gd` per non copiare
## la tabella delle onde. `tools/test_harness.gd` non tocca il contratto.
##
## ## Perche' qui non c'e' piu' nessun numero scritto a mano
##
## Fino a m4 questo file asseriva `count == 200` all'avvio. Poi `-orda` ha messo la
## curva per onda in `src/sim/run.gd` e l'avvio e' sceso a `Run.POP_BASE`: la
## cifra e' cambiata, il criterio no. Sostituire `200` con `25` avrebbe fatto
## passare il gate e lasciato un test da riscrivere alla prossima milestone che
## tocca la curva, che e' gia' successo una volta. Quindi l'avvio e' asserito come
## **relazione** (`_popolazione_davvio`) e il numero esce dalla misura.
##
## Stringhe a schermo solo ASCII: la console di Windows e il pipe di
## `OS.execute` sono in codepage e mangiano gli accenti.

const H = preload("res://tools/test_harness.gd")
## La tabella delle onde di -orda, letta a runtime. Nessuna copia qui dentro.
const Run = preload("res://src/sim/run.gd")

const DT := 1.0 / 60.0
const ARENA_SCENE := "res://scenes/arena_main.tscn"
## Nomi dei nodi nella scena vera. Sono stringhe di -arena: questo file non
## possiede la scena, legge quello che c'e' e dice cosa manca se manca.
const NODO_HORDE := "Horde"
const NODO_PLAYER := "Player"

## Danno con cui un colpo uccide qualunque specie dell'onda 1 (la piu' dura e' il
## boss con 900 HP). Serve **solo a comprimere il tempo**: vedi la nota lunga in
## testa al file.
const DANNO_UN_COLPO := 5000.0
## Intervallo fra i colpi per ammazzare: un colpo a ogni passo. La soglia di
## spinta e il danno di codice non vengono toccati.
const CADENZA_MASSIMA := 0.0
## Intervallo per la sezione "uccisioni con il danno vero": il danno resta quello
## di `weapon_base.gd` e cambia solo il tempo.
const CADENZA_COMPRESSA := 0.05
## Tetto di passi per ogni ciclo: un ciclo che non arriva deve fallire subito, non
## girare per sempre.
const TETTO_PASSI := 40000

var _h
var _ran := false
var _t0 := 0

func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	_h = H.new()

## Il corpo del test gira al **primo frame**, non in `_initialize()`: un nodo
## aggiunto a `root` durante `_initialize()` non ha ancora il suo `_ready`, e la
## parte importante di questo progetto (la registrazione sul contratto) sta li'.
func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	var h = _h
	var game = root.get_node_or_null("Game")
	if not h.check(game != null,
			"l'autoload Game non e' stato istanziato: nessun test delle foglie puo' partire"):
		quit(h.finish("test_progression"))
		return true

	var arena = _apri_arena(h)
	if arena != null:
		_prova(h, game, arena)
		_chiudi(arena)

	print("progression: test terminato in %d ms" % (Time.get_ticks_msec() - _t0))
	quit(h.finish("test_progression"))
	return true

# --- Il corpo ------------------------------------------------------------------

func _prova(h, game, arena) -> void:
	var horde = arena.get_node_or_null(NODO_HORDE)
	if not h.check(horde != null,
			"la scena vera deve avere il nodo \"%s\" (src/sim/horde.gd)" % NODO_HORDE):
		return
	var player = arena.get_node_or_null(NODO_PLAYER)
	if not h.check(player != null,
			"la scena vera deve avere il nodo \"%s\" (src/player/player.gd)" % NODO_PLAYER):
		return
	# Il passo di simulazione lo guida questo test, a mano. Senza questo un tick
	# di fisica fra l'avvio della scena e il primo `_process` sposterebbe i nemici
	# una volta senza che nessuno l'abbia chiesto, e il test misurerebbe un mondo
	# diverso da quello che dichiara di misurare.
	horde.set_physics_process(false)
	player.set_physics_process(false)
	player.drive_manually()

	h.check(game.get("player") == player, "Game.player e' il giocatore della scena vera")
	h.check(game.get("horde") == horde, "e Game.horde e' l'orda della scena vera")
	_popolazione_davvio(h, horde)
	h.eq(int(horde.wave), 1, "e sull'onda 1")

	var prog = _progressione(h, game, player)
	if prog == null:
		return
	var weapon = player.weapon
	if not h.check(weapon != null, "il giocatore della scena vera ha un'arma"):
		return

	var costanti := _costanti(prog)
	if not h.check(costanti.has("XP_BASE") and costanti.has("XP_STEP") and costanti.has("XP_PER_KILL"),
			"la progressione dichiara la curva (XP_BASE, XP_STEP, XP_PER_KILL)"):
		return
	var base: float = costanti["XP_BASE"]
	var passo: float = costanti["XP_STEP"]
	var per_kill: float = costanti["XP_PER_KILL"]
	h.near(float(prog.xp_per_kill), per_kill, 0.0001,
		"l'XP per uccisione del campo e' quello della costante")

	_uccisioni_reali(h, prog, horde, player, weapon, per_kill, base, passo)
	_senza_uccisioni_niente_xp(h, prog, horde, player, weapon, per_kill, base, passo)
	_barra_e_nan(h, prog, base, passo)
	_xp_al_cambio_onda(h, prog, horde, player, weapon, per_kill, base, passo)
	_descrizione_delle_offerte(h, prog, player, weapon)

# --- 0. La popolazione d'avvio: una relazione, non una cifra --------------------

## Cosa resta vero qualunque numero scelga `-orda` domani, e cosa il criterio
## chiede davvero (che l'avvio sia **coerente con la curva dichiarata**, non che
## la curva valga un numero fissato da questo test):
##
##     count      == population                il campo e' pieno al suo tetto
##     population == Run.population_of(1)      il tetto e' quello che chiede la curva
##
## Il numero **esce** dalla misura ed e' stampato: nessuna cifra scritta a mano
## nell'asserzione. Fino a m4 qui c'era `count == 200`; sostituire quella riga
## con `count == 25` avrebbe fatto passare il gate e lasciato un test da
## riscrivere alla prossima milestone che tocca la curva, che e' gia' successo.
##
## Il secondo `check` e' voluto: `population` deve essere **positivo**, altrimenti
## la prima relazione (`count == population == 0`) passerebbe su un'orda vuota.
func _popolazione_davvio(h, horde) -> void:
	var tetto: Variant = horde.get("population")
	if not h.check(typeof(tetto) == TYPE_INT,
			"l'orda dichiara il campo `population`: senza, non si sa a cosa debba essere pieno"):
		return
	h.eq(int(horde.count), int(tetto),
		"l'orda della scena vera parte piena al suo tetto di popolazione")
	h.eq(int(tetto), Run.population_of(1),
		"e il tetto e' quello che chiede la curva delle onde sull'onda 1 (Run.population_of)")
	h.check(int(tetto) > 0,
		"un'onda che parte vuota non e' un'onda: %d nemici vivi" % int(tetto))
	print("progression: avvio, onda %d, %d nemici vivi = tetto di popolazione %d, %d uccisioni per chiudere l'onda"
		% [int(horde.wave), int(horde.count), int(tetto), int(horde.wave_total())]
		+ " (Run.population_of(1) = %d, Run.POP_BASE = %d)"
		% [Run.population_of(1), Run.POP_BASE])

# --- 1. Le uccisioni sono reali e il livello dipende da loro --------------------

## Dodici uccisioni fatte **attraverso il percorso vero**, con il danno e la
## spinta di `weapon_base.gd` intatti, e tre numeri confrontati a ogni uccisione:
## il livello con la funzione calcolata dal test, `xp_earned` con
## `uccisioni * xp_per_kill`, e le uccisioni di -gameplay con quelle di -orda.
func _uccisioni_reali(h, prog, horde, player, weapon, per_kill: float,
		base: float, passo: float) -> void:
	prog.reset()
	var bersaglio := 12
	var uccisi0 := int(horde.kills)
	h.eq(int(prog.kills), 0, "partiamo da zero uccisioni")
	h.eq(int(prog.level), 1, "e dal livello 1")
	h.near(float(prog.xp), 0.0, 0.0001, "con la barra a zero")

	# Solo il tempo e' compresso: il danno resta quello di codice e i proiettili
	# volano con la velocita' di codice.
	weapon.fire_interval = CADENZA_COMPRESSA
	weapon.cooldown = 0.0

	var guard := 0
	var controllati := 0
	while int(prog.kills) < bersaglio and guard < TETTO_PASSI:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
		guard += 1
		if int(prog.kills) < bersaglio:
			continue
		controllati += 1
		var uccisi := int(prog.kills)
		h.eq(int(prog.level), _livello_atteso(uccisi, per_kill, base, passo),
			"dopo %d uccisioni il livello e' quello che danno le uccisioni" % uccisi)
		h.near(float(prog.xp_earned), per_kill * float(uccisi), 0.0001,
			"dopo %d uccisioni l'XP totale e' uccisioni per XP per uccisione" % uccisi)
		h.eq(int(prog.kills), int(horde.kills) - uccisi0,
			"dopo %d uccisioni -gameplay e -orda contano le stesse morti" % uccisi)

	h.check(int(prog.kills) >= bersaglio,
		"%d uccisioni attraverso il percorso vero in %d passi (ne sono arrivate %d)"
		% [bersaglio, guard, int(prog.kills)])
	h.check(controllati > 0, "il livello e' stato confrontato a ogni uccisione, non solo alla fine")
	h.check(int(prog.level) >= 2,
		"uccidere fa salire di livello: %d uccisioni portano al livello %d (era 1)"
		% [int(prog.kills), int(prog.level)])

	# La prova che l'XP **non e' finta**: nessuna `add_xp` e' stata chiamata a
	# mano da questo file (non c'e' una sola riga di questo test che tocchi
	# `prog.add_xp`), e l'unica strada scritta e' il `true` di `damage_enemy`.
	h.near(float(prog.xp_earned), per_kill * float(int(horde.kills) - uccisi0), 0.0001,
		"l'XP guadagnato e' esattamente quello delle %d morti contate dall'orda"
		% (int(horde.kills) - uccisi0))

	weapon.fire_interval = 0.35
	weapon.cooldown = 0.0
	print("progression: %d uccisioni vere in %d passi -> livello %d, XP %.1f in barra, %.1f guadagnati"
		% [int(prog.kills), guard, int(prog.level), float(prog.xp), float(prog.xp_earned)])

## Il contrario della stessa cosa, e senza il quale la sezione sopra non dice
## niente: **senza uccisioni l'XP non sale**. L'arma viene messa in attesa lunga,
## il mondo gira per 180 passi con tutta l'orda viva intorno, e nessun numero
## della progressione puo' muoversi. Se l'XP dipendesse da un frame, da un
## contatore o da una euristica sulla vicinanza dei nemici, qui salirebbe.
##
## ## Perche' il pool si svuota **prima** della finestra
##
## La finestra dichiara "nessuna uccisione in 180 passi", ma l'ultimo colpo della
## sezione precedente puo' essere **ancora in volo**: se arriva dentro la
## finestra uccide un nemico, e il test vede un'uccisione mentre l'arma e' in
## attesa. Non e' un difetto del codice: e' un proiettile partito **prima**, cioe'
## un'uccisione che la sezione di sopra non ha ancora contato. Con l'orda a
## `Run.POP_BASE` il bersaglio piu' vicino e' piu' lontano di quando ce n'erano a
## `MAX_ENEMIES`, quindi il tempo di volo e' piu' lungo e la corsa e' piu' probabile
## dentro quei 180 passi; col seme dell'orda casuale (`seed = 0`) e' una moneta.
## La prima esecuzione dopo m4 e' passata e la seconda e' rossa su quello.
##
## Quindi il pool si svuota con `pool.reset()` -- lo stesso metodo che
## `weapon.reset()` chiama, che riusa i 100 record e non ne libera nessuno -- e
## sotto la finestra viene **misurata** la sua silenziosita' invece di darla per
## scontata: nessun colpo partito (`weapon.shots`), nessun proiettile vivo,
## nessuna morte. Se il test fallisce li', adesso dice perche'.
func _senza_uccisioni_niente_xp(h, prog, horde, player, weapon, per_kill: float,
		base: float, passo: float) -> void:
	var pool = weapon.pool
	if not h.check(pool != null,
			"l'arma dichiara il campo `pool`: senza, la finestra non puo' essere misurata"):
		return
	pool.reset()
	h.eq(int(pool.active_count()), 0,
		"nessun proiettile in volo all'inizio della finestra")

	var prima := _stato(prog)
	var uccisi0 := int(horde.kills)
	var spari0 := int(weapon.shots)
	var intervallo0: float = weapon.fire_interval
	weapon.fire_interval = 10000.0
	weapon.cooldown = 10000.0
	for _i in 180:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
	var dopo := _stato(prog)

	h.eq(int(weapon.shots), spari0,
		"180 passi con l'arma in attesa non fanno partire nessun colpo")
	h.eq(int(pool.active_count()), 0,
		"e nessun proiettile e' vivo: la finestra e' davvero silenziosa")
	h.eq(int(dopo["kills"]), int(prima["kills"]),
		"180 passi con l'arma in attesa non uccidono nessuno")
	h.eq(int(horde.kills), uccisi0, "e l'orda non conta nessuna morte")
	h.near(float(dopo["xp_earned"]), float(prima["xp_earned"]), 0.0001,
		"e l'XP totale non cresce di un grammo")
	h.near(float(dopo["xp"]), float(prima["xp"]), 0.0001, "la barra resta ferma")
	h.eq(int(dopo["level"]), int(prima["level"]), "e il livello non si muove")
	h.check(_coerente(dopo, base, passo),
		"e l'invariante xp_earned = xp + soglie consumate resta vera a fine ciclo")

	# L'attesa lunga era di questo file: si rimette a posto quello che c'era
	# prima, non un numero nuovo, cosi' la sezione dopo non parte da una
	# regolazione che nessuno ha dichiarato.
	weapon.fire_interval = intervallo0
	weapon.cooldown = 0.0

# --- 2. La barra e' un numero, sempre, anche se qualcuno prova a rompere il tetto

## Il criterio chiede che la barra sia **sempre** in `[0, next]` e mai
## `NaN`/`INF`. "Sempre" vuol dire anche quando qualcuno le infila un numero
## non finito: `NaN <= 0.0` e' falso e `clampf(NAN, 0.0, 1.0)` restituisce
## `NaN`, quindi una guardia assente qui non si vede in nessun altro numero: la
## barra semplicemente non compare e nessuna asserzione se ne accorgerebbe.
func _barra_e_nan(h, prog, base: float, passo: float) -> void:
	prog.reset()
	# Il percorso normale prima: la barra dopo qualche uccisione e' un numero
	# dentro [0, 1].
	for _i in 6:
		prog.on_kill(1)
		var r: float = prog.progress()
		h.finite(r, "progress() dopo %d uccisioni e' un numero" % int(prog.kills))
		h.check(r >= 0.0 and r <= 1.0, "e sta in [0, 1]: %s" % r)
		h.check(float(prog.xp) >= 0.0 and float(prog.xp) < float(prog.xp_to_next()),
			"xp sta in [0, xp_to_next): %s di %s" % [prog.xp, prog.xp_to_next()])
	h.check(int(prog.level) >= 2, "l'XP del percorso normale ha fatto salire di livello")

	var xp_salvo: float = prog.xp
	var base_salvata: float = base
	var passo_salvato: float = passo

	# Un numero non finito **non e' XP**: `NaN <= 0.0` e' falso, quindi senza la
	# guardia entrerebbe, il ciclo dei livelli non partirebbe (`NaN >= soglia` e'
	# falso) e `xp` resterebbe `NaN` per sempre.
	for cattivo in [NAN, INF, -INF, -7.0]:
		var livello_prima := int(prog.level)
		h.eq(int(prog.add_xp(cattivo)), 0,
			"add_xp(%s) non sale di livello: non e' XP" % str(cattivo))
		h.near(float(prog.xp), xp_salvo, 0.0001,
			"e non muove la barra di un nanometro")
		h.near(float(prog.xp_earned), xp_salvo + float(int(prog.level) - 1) * base_salvata
			+ passo_salvato * float((int(prog.level) - 1) * (int(prog.level) - 2)) / 2.0,
			0.0001, "e non conta XP guadagnata")
		h.eq(int(prog.level), livello_prima, "il livello resta quello di prima")

	# E la guardia finale: anche se qualcuno **scrive** un numero non finito
	# direttamente nel campo, il numero che l'interfaccia legge resta in [0, 1].
	for cattivo in [NAN, INF]:
		prog.xp = cattivo
		var r: float = prog.progress()
		h.finite(r, "progress() con xp = %s restituisce un numero" % str(cattivo))
		h.check(r >= 0.0 and r <= 1.0,
			"e lo tiene in [0, 1] invece di passare il NaN alla HUD: %s" % r)
	prog.xp = xp_salvo
	h.check(_coerente(_stato(prog), base_salvata, passo_salvato),
		"rimessa a posto, l'invariante contabile torna vera")

	prog.reset()
	h.check(_barra_sana(prog), "dopo reset() la barra e' di nuovo un numero in [0, 1]")

# --- 3. L'XP di un ucciso non e' perso al cambio d'onda -------------------------

## Il pezzo che m1 non aveva e che nessun test guardava. L'onda 1 si chiude a
## `wave_total` = 200 uccisioni; il confine avviene dentro `horde.step()`, e il
## numero che decide e' l'invariante contabile **in ogni frame**:
##
##     xp_earned == xp + somma delle soglie dei livelli saliti
##
## Se il cambio d'onda azzerasse la progressione, o se un ucciso attraversasse
## il confine senza portare la sua XP, l'invariante si romperebbe esattamente li'.
## Al confine viene anche misurato, frame per frame, che `xp_earned` cresce di
## `xp_per_kill` per ogni uccisione, e che **dopo** il confine l'XP continua a
## entrare: un confine che congelasse la progressione per un frame sarebbe
## indistinguibile da uno che la congelasse per sempre.
func _xp_al_cambio_onda(h, prog, horde, player, weapon, per_kill: float,
		base: float, passo: float) -> void:
	prog.reset()
	# Le due basi sono **due numeri diversi** e vanno presi dopo il reset:
	# `progression.reset()` azzera `prog.kills` ma non tocca `horde.kills`, che e'
	# di -orda e conta le morti dalla partita. Con una base sola per i due il
	# confronto misurerebbe 12 uccisioni della sezione precedente contro 0 e
	# fallirebbe su un codice che sta bene: la prima esecuzione ha misurato
	# esattamente quello, 177 contro 189.
	var uccisi0 := int(horde.kills)
	var prog0 := int(prog.kills)
	var wave0 := int(horde.wave)
	var bersaglio_onda: int = horde.wave_total()

	# Impalcatura del tempo, dichiarata in testa al file: un colpo uccide, cosi'
	# l'unico tetto al ritmo che resta e' `Run.SPAWN_RATE` (l'orda si riempie
	# invece che essere gia' piena) e le `wave_total` uccisioni dell'onda costano
	# ~`wave_total / SPAWN_RATE` secondi di simulazione invece di `wave_total`
	# passi. Il numero di passi effettivamente speso e' `guard`, ed e' stampato
	# in fondo a questa sezione. Il danno e la spinta **del colpo** sono l'unica
	# cosa che questo file cambia, e tornano ai numeri di codice prima di uscire.
	var danno0: float = weapon.damage
	var spinta0: float = weapon.knockback
	var intervallo0: float = weapon.fire_interval
	weapon.damage = DANNO_UN_COLPO
	weapon.fire_interval = CADENZA_MASSIMA
	weapon.cooldown = 0.0

	var prima := _stato(prog)
	var attraversato := false
	var confine := {}
	var uccisi_al_confine := 0
	var frame_barra_rotta := -1
	var frame_incoerente := -1
	var guard := 0

	while guard < TETTO_PASSI:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
		guard += 1

		# Il controllo **di ogni frame**: non solo alla fine, che e' dove un
		# invariante rotta si nasconderebbe.
		if not _barra_sana(prog) and frame_barra_rotta < 0:
			frame_barra_rotta = guard
		if not _coerente(_stato(prog), base, passo) and frame_incoerente < 0:
			frame_incoerente = guard

		var dopo := _stato(prog)
		if int(horde.wave) != wave0 and not attraversato:
			attraversato = true
			confine = _stato(prog)
			uccisi_al_confine = int(dopo["kills"])
			# Il numero che decide, al confine.
			h.near(float(dopo["xp_earned"]) - float(prima["xp_earned"]),
				per_kill * float(uccisi_al_confine - int(prima["kills"])), 0.0001,
				"al cambio d'onda l'XP cresciuta e' uccisioni per XP per uccisione")
			h.check(float(dopo["xp_earned"]) >= float(prima["xp_earned"]),
				"e nessuna XP sparisce: %.1f -> %.1f"
				% [float(prima["xp_earned"]), float(dopo["xp_earned"])])
			h.check(int(dopo["level"]) >= int(prima["level"]),
				"il livello non torna indietro al cambio d'onda: %d -> %d"
				% [int(prima["level"]), int(dopo["level"])])
			h.check(_coerente(dopo, base, passo),
				"e l'invariante contabile e' vera nel frame stesso del cambio d'onda")
			h.eq(int(dopo["kills"]) - prog0, int(horde.kills) - uccisi0,
				"al confine -gameplay e -orda contano le stesse morti")
		elif int(horde.wave) != wave0 and int(dopo["kills"]) > uccisi_al_confine + 40:
			break
		prima = dopo

	h.check(attraversato,
		"l'onda %d si chiude e l'onda successiva parte (dopo %d passi, %d uccisioni)"
		% [wave0, guard, int(prog.kills)])
	h.eq(int(horde.wave), wave0 + 1, "il contatore d'onda e' salito di uno")
	h.check(int(prog.kills) >= bersaglio_onda,
		"l'onda %d si e' chiusa con %d uccisioni reali, non con una barra azzerata a mano"
		% [wave0, int(prog.kills)])
	h.eq(frame_barra_rotta, -1,
		"la barra e' stata un numero in [0, next) in tutti i %d frame del ciclo" % guard)
	h.eq(frame_incoerente, -1,
		"l'invariante xp_earned = xp + soglie consumate non si e' mai rotta in %d frame" % guard)

	if attraversato:
		# Dopo il confine l'XP continua a entrare: un confine che congelasse la
		# progressione per un frame sarebbe indistinguibile da uno che la
		# congelasse per sempre, e il test deve vedere la differenza.
		#
		# Il ciclo non si ferma a un numero fisso di uccisioni ma quando **il
		# livello sale davvero**: al livello 15 la soglia sono 92 XP, cioe' 31
		# uccisioni, e fermarsi a 15 avrebbe asserito "il livello continua a
		# salire" su un numero che non puo' salire. La prima esecuzione ha
		# fallito li' per quello, non per il codice.
		var uccisi_prima := int(prog.kills)
		var xp_prima := float(prog.xp_earned)
		var livello_prima := int(prog.level)
		var dopo2 := 0
		while int(prog.level) <= livello_prima and dopo2 < TETTO_PASSI:
			player.step(DT, Vector3.ZERO)
			horde.step(DT)
			dopo2 += 1
		var fatte := int(prog.kills) - uccisi_prima
		h.check(fatte >= 15,
			"dopo il cambio d'onda si continuano a uccidere: %d uccisioni in %d passi"
			% [fatte, dopo2])
		h.check(int(prog.level) > livello_prima,
			"e il livello sale ancora dopo il cambio d'onda: %d -> %d in %d uccisioni"
			% [livello_prima, int(prog.level), fatte])
		h.near(float(prog.xp_earned) - xp_prima, per_kill * float(fatte), 0.0001,
			"e portano esattamente la loro XP: %.1f di %.1f attesa"
			% [float(prog.xp_earned) - xp_prima, per_kill * float(fatte)])
		h.check(_coerente(_stato(prog), base, passo),
			"e l'invariante contabile resta vera anche dopo il confine")

	# La regolazione torna ai numeri di codice: un test che lascia il danno
	# sporco fa fallire in modo falso chi viene dopo.
	weapon.damage = danno0
	weapon.knockback = spinta0
	weapon.fire_interval = intervallo0
	weapon.cooldown = 0.0
	h.near(float(weapon.damage), 10.0, 0.0001, "il danno torna a quello di codice")
	h.near(float(weapon.knockback), 18.0, 0.0001,
		"e la spinta resta 18.0 m/s: non e' stata alzata per stare comodo (piano sez. 1.2)")

	print("progression: onda %d -> %d dopo %d uccisioni, livello %d, XP %.1f di %.1f, %.1f guadagnati"
		% [wave0, int(horde.wave), int(prog.kills), int(prog.level),
			float(prog.xp), float(prog.xp_to_next()), float(prog.xp_earned)])
	print("progression: l'onda %d si e' chiusa in %d passi (%.2f s) per %d uccisioni, "
		% [wave0, guard, float(guard) * DT, bersaglio_onda]
		+ "con il campo a %d vivi e Run.SPAWN_RATE = %.1f/s" % [int(horde.count), Run.SPAWN_RATE])
	if not confine.is_empty():
		print("progression: al confine dell'onda %d nessuna XP persa, %d uccisioni contate da -orda e da -gameplay"
			% [wave0, uccisi_al_confine])

# --- 4. m6: la descrizione di un'offerta e' dichiarata, non ricopiata ---------

## Il pannello di `-ui` non scrive «Danno +25%»: lo chiede a
## `offer_label(index)` e `offer_effect(index)`. Qui si prova che quei due
## metodi dicono qualcosa di leggibile e di solo ASCII (finiscono in una
## Label), e soprattutto che **leggere una carta non e' scegliere una carta**:
## il criterio n. 6 di m6 chiede esattamente questo, e il numero che decide e'
## che `pending()` e la firma dei numeri dell'arma restano quelle di prima.
##
## Si sale di livello con `on_kill(1)`, che e' la strada che il percorso vero
## chiama quando `Game.damage_enemy` ha risposto `true`: non e' un `add_xp` a
## mano, e quindi le offerte che arrivano sono quelle che l'uccisione ha fatte
## rullare.
##
## ## L'altra meta' del contratto: dopo la scelta **non resta niente**
##
## La regola e' dell'utente (2026-10-13), non dedotta dal codice: si sale di
## livello, si sceglie **uno**, gli altri due si buttano, e al livello dopo ne
## arrivano altri tre. Quindi `choose(index)` non accorcia la coda, la **svuota**:
## `pending()` va da 3 a 0 in un colpo, e non 3 -> 2 -> 1 -> 0 come scriveva il
## commento di `progression.gd` che questo criterio aveva copiato.
##
## E non e' una questione di stile: `add_xp` rulla le offerte solo se la coda e'
## vuota, quindi e' **lo svuotamento** che fa tornare il ciclo. Qui sotto e' il
## numero che lo dimostra, perche' e' il punto in cui una `choose()` che tenesse
## le due pending si romperebbe e continuerebbe a sembrare giusta fino al
## livello successivo.
func _descrizione_delle_offerte(h, prog, player, weapon) -> void:
	var firma := _firma(player, weapon)
	prog.reset()
	h.eq(str(prog.offer_label(0)), "",
		"a menu vuoto offer_label(0) risponde stringa vuota, non un errore")
	h.eq(str(prog.offer_effect(0)), "",
		"e offer_effect(0) anche: un indice che non esiste non e' un'offerta")
	h.eq(str(prog.offer_label(-1)), "",
		"un indice negativo e' fuori dalla coda come uno troppo grande")
	h.eq(int(prog.pending()), 0, "e la coda delle offerte e' ancora vuota")

	# Quante uccisioni servono a far salire **un** livello: la soglia e' quella
	# che la progressione dichiara, quindi il numero esce dalla misura e non e'
	# scritto qui dentro.
	var uccise := int(ceilf(float(prog.xp_to_next()) / float(prog.xp_per_kill)))
	for _i in uccise:
		prog.on_kill(1)
	h.eq(int(prog.pending()), 3,
		"dopo %d uccisioni il livello offre esattamente 3 potenziamenti" % uccise)

	var nomi := []
	var effetti := []
	for i in 3:
		var nome := str(prog.offer_label(i))
		var effetto := str(prog.offer_effect(i))
		nomi.append(nome)
		effetti.append(effetto)
		h.check(nome != "" and _ascii(nome),
			"l'offerta %d ha un nome leggibile: '%s'" % [i + 1, nome])
		h.check(effetto != "" and _ascii(effetto),
			"l'offerta %d ha un effetto leggibile: '%s'" % [i + 1, effetto])
		h.check(_ha_numero(effetto),
			"l'effetto '%s' contiene un numero: la carta dice quanto, non solo che cosa" % effetto)
	h.eq(_unici(nomi), 3, "le tre carte hanno tre nomi diversi")
	h.eq(_unici(effetti), 3, "e tre effetti diversi")

	# Il numero che decide del criterio n. 6: leggere le carte e' un'operazione
	# **di lettura**.
	for i in 3:
		prog.offer_label(i)
		prog.offer_effect(i)
	h.eq(int(prog.pending()), 3, "leggere le tre carte non sceglie niente: la coda e' quella")
	h.eq(_firma(player, weapon), firma,
		"e non muove nessun numero dell'arma o del giocatore")

	# ## Una scelta sola, e le altre due si buttano
	#
	# Qui `choose(0)` e' chiamato per provare che funziona, non per far passare
	# un'asserzione sulla scena vera: che sia **il gioco** a scegliere, uccidendo
	# nemici, e' il compito del pannello di `-ui`.
	var id_primo := str(prog.offers[0])
	var scelto: String = prog.choose(0)
	h.eq(scelto, id_primo,
		"choose(0) applica il primo della coda, quello che la carta 0 descriveva: '%s'" % scelto)
	h.eq(int(prog.pending()), 0,
		"e la coda si svuota in un colpo: le altre due offerte sono scartate, non accodate")
	h.check(_firma(player, weapon) != firma,
		"la scelta ha mosso almeno un numero dell'arma o del giocatore")
	h.eq(str(prog.offer_label(0)), "",
		"l'indice 0 non e' piu' un'offerta: la stringa vuota e' la risposta giusta")
	h.eq(str(prog.offer_effect(0)), "", "e il suo effetto e' vuoto come il nome")
	h.eq(str(prog.choose(0)), "",
		"una seconda scelta con la coda vuota non applica niente")

	# ## Il ciclo: al livello dopo ne arrivano altre tre
	#
	# `add_xp` chiama `roll()` solo con `gained > 0 and offers.is_empty()`: se
	# `choose()` tenesse le due pending, quella riga non scatterebbe piu' e il
	# ciclo dei livelli si fermerebbe. Il numero che decide e' questo: dalla coda
	# svuotata, l'XP che fa salire il livello successivo deve tirare tre offerte
	# nuove, tutte distinte.
	var uccise2 := int(ceilf(float(prog.xp_to_next()) / float(prog.xp_per_kill)))
	for _i in uccise2:
		prog.on_kill(1)
	h.eq(int(prog.pending()), 3,
		"dopo %d uccisioni il livello successivo offre altre 3 potenziamenti: la coda svuotata e' la condizione che rilancia il ciclo"
		% uccise2)
	h.eq(_unici(prog.offers), 3, "e sono tre potenziamenti distinti anche loro")

	# Il contratto con `-ui` vale anche al contrario: la stessa offerta descritta
	# due volte dice due volte la stessa cosa. Una carta che cambiasse testo da
	# un frame all'altro sarebbe un pannello che mente.
	prog.reset()
	prog.on_kill(uccise)
	var primo := str(prog.offer_label(0))
	var primo_effetto := str(prog.offer_effect(0))
	for _giro in 5:
		prog.offer_label(0)
		prog.offer_effect(0)
	h.eq(str(prog.offer_label(0)), primo,
		"la stessa offerta descritta sei volte dice sempre '%s'" % primo)
	h.eq(str(prog.offer_effect(0)), primo_effetto,
		"e l'effetto resta '%s': leggere non consuma niente" % primo_effetto)
	print("progression: m6 descrizione, tre carte '%s' / '%s' / '%s'"
		% [str(prog.offer_label(0)), str(prog.offer_label(1)), str(prog.offer_label(2))])
	print("progression: m6 effetti '%s' / '%s' / '%s' (una scelta sola: dopo choose la coda e' vuota)"
		% [str(prog.offer_effect(0)), str(prog.offer_effect(1)), str(prog.offer_effect(2))])

	# La sezione ha applicato potenziamenti a mano per provare `choose`: la
	# regolazione torna a com'era, letta **qui dentro** e non scritta, cosi' la
	# sezione dopo non parte da numeri sporchi.
	_ripristina(player, weapon, firma)
	prog.reset()
	h.eq(_firma(player, weapon), firma, "rimessa a posto, la firma dei numeri e' quella di prima")

# --- Le misure ------------------------------------------------------------------

## L'invariante contabile. `xp_earned` e' tutto quello che e' entrato; `xp` e' la
## parte non ancora spesa; la differenza e' la somma delle soglie dei livelli
## saliti, cioe' `BASE + STEP * (0 + 1 + ... + (livello - 2))`. Se un livello o un
## cambio d'onda perdessero un grammo di XP, questa identita' smetterebbe di
## valere, e su che frame lo smetterebbe e' esattamente la domanda del criterio.
func _coerente(st: Dictionary, base: float, passo: float) -> bool:
	var livello := int(st["level"])
	var consumato := _soglie_consumate(livello, base, passo)
	return absf(float(st["xp_earned"]) - (float(st["xp"]) + consumato)) <= 0.0001

func _soglie_consumate(livello: int, base: float, passo: float) -> float:
	var k := livello - 1
	if k <= 0:
		return 0.0
	return base * float(k) + passo * float(k * (k - 1)) / 2.0

## Il livello che danno `kills` uccisioni, calcolato **dal test** con le stesse
## costanti della progressione. Non e' una copia della curva: e' la curva
## ricalcolata, ed e' quello che distingue "l'XP sale quando si uccide" da "il
## livello sale ogni toti frame".
func _livello_atteso(kills: int, per_kill: float, base: float, passo: float) -> int:
	var earned := per_kill * float(maxi(kills, 0))
	var livello := 1
	var guard := 0
	while guard < 100000:
		var soglia: float = base + passo * float(maxi(livello - 1, 0))
		if earned < soglia:
			break
		earned -= soglia
		livello += 1
		guard += 1
	return livello

## La barra e' sana: `xp` in `[0, xp_to_next())`, `progress()` in `[0, 1]`, e
## nessuno dei due non finito.
func _barra_sana(prog) -> bool:
	var xp: float = prog.xp
	var need: float = prog.xp_to_next()
	if not is_finite(xp) or not is_finite(need):
		return false
	if xp < 0.0 or xp >= need or need <= 0.0:
		return false
	var r: float = prog.progress()
	return is_finite(r) and r >= 0.0 and r <= 1.0

func _stato(prog) -> Dictionary:
	return {
		"level": int(prog.level),
		"xp": float(prog.xp),
		"xp_earned": float(prog.xp_earned),
		"kills": int(prog.kills),
	}

## I numeri che un potenziamento tocca, come **firma**. Serve alla sezione m6:
## leggere una carta non deve cambiarli, quindi il confronto e' fatto su tutti
## e non su quello che la carta nomina.
func _firma(player, weapon) -> Dictionary:
	return {
		"danno": float(weapon.damage),
		"intervallo": float(weapon.fire_interval),
		"velocita": float(weapon.projectile_speed),
		"vita_proj": float(weapon.projectile_life),
		"spinta": float(weapon.knockback),
		"perforante": int(weapon.pierce),
		"gittata_mira": float(weapon.acquire_radius),
		"corsa": float(player.move_speed),
		"vita_max": float(player.max_hp),
		"vita": float(player.hp),
	}

## Rimette i numeri di `_firma` al posto loro. I valori vengono **da** la firma,
## non da una copia scritta qui dentro: una sezione che lascia la regolazione
## sporca fa fallire in modo falso chi viene dopo.
func _ripristina(player, weapon, firma: Dictionary) -> void:
	weapon.damage = float(firma["danno"])
	weapon.fire_interval = float(firma["intervallo"])
	weapon.projectile_speed = float(firma["velocita"])
	weapon.projectile_life = float(firma["vita_proj"])
	weapon.knockback = float(firma["spinta"])
	weapon.pierce = int(firma["perforante"])
	weapon.acquire_radius = float(firma["gittata_mira"])
	weapon.cooldown = 0.0
	player.move_speed = float(firma["corsa"])
	player.max_hp = float(firma["vita_max"])
	player.hp = float(firma["vita"])

## Solo ASCII nelle stringhe che finiscono a schermo: e' la regola del progetto
## (piano §5.1) e la console di Windows la mangia proprio dove serve leggerla.
func _ascii(s: String) -> bool:
	for i in s.length():
		if s.unicode_at(i) > 126:
			return false
	return true

## La stringa dell'effetto contiene un numero. «+25%» e «+1 nemico» passano,
## «Danno» no: un effetto che non dice quanto e' un'etichetta travestita.
func _ha_numero(s: String) -> bool:
	for i in s.length():
		if s[i] >= "0" and s[i] <= "9":
			return true
	return false

## Quanti valori diversi ci sono in una lista di stringhe.
func _unici(valori: Array) -> int:
	var visti := {}
	for v in valori:
		visti[v] = true
	return visti.size()

## Le costanti della progressione lette a runtime dallo **script vivo**, mai
## riscritte qui dentro: una copia nel test si romperebbe al primo ritocco della
## curva e fallirebbe senza che nessuno l'abbia toccata. `get_script_constant_map()`
## e' l'unico modo di arrivare a una costante di uno script senza metterla in
## `const preload` qui (vedi la trappola in testa al file).
func _costanti(prog) -> Dictionary:
	var m: Variant = prog.get_script().get_script_constant_map()
	return m as Dictionary if m is Dictionary else {}

# --- La progressione sul contratto ---------------------------------------------

## `Game.progression`, non `Game.player.progression`: e' la voce che
## `verify_m2_surface()` chiede e che senza questa registrazione valeva `null`.
## Dodici membri (`level`, `xp`, `kills`, `offers`, `progress`, `xp_to_next`,
## `pending`, `choose`, `apply`, `on_kill`, `offer_label`, `offer_effect`)
## erano irraggiungibili per tre foglie,
## e il gate restava verde lo stesso. Dieci erano quelli di m2; la m6 ne ha
## dichiarati due in piu'.
func _progressione(h, game, player):
	var prog = game.get("progression")
	if not h.check(prog != null,
			"Game.progression e' registrato: senza, dodici voci del contratto di m2 non sono raggiungibili"):
		return null
	h.check(prog == player.progression,
		"Game.progression e' lo stesso oggetto che il giocatore tiene in `progression`")
	h.eq(prog, player.progression, "identico per valore, non per copia")

	var mancanti: Array = game.call("verify_m2_surface")
	var miei: Array[String] = []
	for riga in mancanti:
		var testo := str(riga)
		if testo.begins_with("terminal-gun-gameplay"):
			miei.append(testo)
	h.check(miei.is_empty(),
		"le dodici voci di m2 dichiarate a -gameplay sono tutte raggiungibili: %s" % ", ".join(miei))

	for membro in ["level", "xp", "kills", "offers", "progress", "xp_to_next",
			"pending", "choose", "apply", "on_kill", "offer_label", "offer_effect"]:
		var v: Variant = prog.get(membro)
		h.check(v != null, "progression.%s esiste ed e' leggibile" % membro)
		if membro in ["progress", "xp_to_next", "pending", "choose", "apply", "on_kill",
				"offer_label", "offer_effect"]:
			h.check(v is Callable, "progression.%s e' un metodo, non un campo" % membro)
	return prog

# --- Scena ---------------------------------------------------------------------

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
## `free`, cosi' l'albero e' pulito **subito**.
func _chiudi(arena) -> void:
	if arena == null:
		return
	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()
