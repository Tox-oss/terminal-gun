extends Node3D
## L'orda: 200 nemici vivi **senza un nodo per nemico**.
##
## Un nemico e' un record in `transforms` (dove sta) piu' quattro array paralleli
## (velocita', hp, specie, timer), non un `Node3D`. Il criterio della milestone e'
## `node_count < 120` con `horde.count == 200`: un nodo per nemico, da solo,
## farebbe fallire il criterio.
##
## ## L'API "massa" non passa da funzioni
##
## Disegnare 200 nemici non e' una query, e' un `MultiMeshInstance3D` che legge
## tre campi. Per questo sono campi pubblici e non metodi:
##
##     horde.count        # quanti nemici vivi
##     horde.transforms   # PackedVector3Array, posizione mondo di ciascuno
##     horde.colors       # PackedColorArray, tinta per specie
##
## `transforms.size() == colors.size() == count`, sempre: l'invariante e' quello
## che permette all'arena di non controllare nulla.
##
## ## La partita non e' fra i tre campi
##
## Onda, barra e `game_over` stanno in `src/sim/run.gd`, un oggetto che questa
## foglia tiene in un campo. Si leggono cosi':
##
##     horde.wave               # campo: numero dell'onda (lo legge anche l'HUD)
##     horde.wave_total()       # uccisioni che chiudono l'onda
##     horde.wave_remaining()   # la barra wave, in interi
##     horde.wave_bar_ratio()   # la stessa barra, da 0 a 1
##     horde.run_state()        # "playing" oppure "game_over"
##     horde.is_game_over()     # la stessa domanda in booleano
##     horde.restart_run()      # nuova partita: onda 1, orda ripopolata
##
## `wave` e' un campo e gli altri sono metodi perche' non sono la stessa cosa:
## `wave` e' un numero che un'altra foglia legge gia' per nome
## (`src/ui/hud.gd`), gli altri sono numeri **derivati** — la barra e'
## `wave_total - wave_killed`, e se fossero campi pubblici qualcuno potrebbe
## leggerne due in due momenti diversi e vedere una combinazione che non e' mai
## vera. I tre campi di sopra sono dati grezzi e il lettore ne fa quello che
## vuole; questi no.
##
## `population` resta il significato che aveva in m1: quanti nemici vivi
## **contemporaneamente**. Quanti ne vanno ammazzati in tutto lo dice la barra,
## e sono due numeri diversi (vedi `src/sim/run.gd`).
##
## ## m4: `population` non e' piu' una costante
##
## Prima di m4 questo campo valeva `MAX_ENEMIES` e `_build()` riempiva a quel
## numero: 200 nemici vivi al primo frame, e `_top_up()` li riportava a 200 a
## ogni passo. Nessun colpo svuotava l'arena. La **curva per onda** sta in
## `src/sim/run.gd` (`Run.population_of`), con la misura da cui e' uscita scritta
## li'; qui dentro ci sono solo il meccanismo e il credito di spawn.
##
## ## Le tre API del contratto (registrate in `_ready`)
##
##     Game.horde = self
##     Game.register_impl("nearest_enemy", self.nearest_enemy_index)
##     Game.register_impl("damage_enemy", self.damage_enemy)
##     Game.register_impl("random_spawn_point", self.random_spawn_point)
##
## Forma lunga (`register_impl` con la Callable), non `Game.nearest_enemy = ...`:
## GDScript rifiuta l'assegnazione a un nome che e' gia' un `func` e l'errore
## interromperebbe il `_ready()` (piano 5.1).
##
## `player_position` NON e' registrata qui: e' di -gameplay, e registrarne due
## impl per lo stesso nome e' una doppia registrazione.
##
## ## Perche' qui il contratto si prende con `get_node_or_null` e non con `Game.`
##
## Questo file viene compilato anche dai processi di test lanciati con
## `--script`, e in quel contesto l'autoload `Game` non e' ancora fra le
## costanti globali di GDScript: l'identificatore nudo `Game` non risolve e la
## compilazione si ferma con `Compile Error: Identifier not found: Game`,
## **prima** che una riga di questo file venga eseguita. Il nodo che si ottiene
## e' lo stesso identico singleton: si aggira la compilazione, non il
## contratto. Vedi `_contract()` e piano 5.3.

const E = preload("res://src/sim/enemy.gd")
const Grid = preload("res://src/sim/spatial_grid.gd")
const Spawner = preload("res://src/sim/spawner.gd")
const Run = preload("res://src/sim/run.gd")

## Capienza massima: decisa qui, una volta sola, e mai piu' cambiata.
const MAX_ENEMIES := 200
## Quanti colpi recenti si ricordano per sfx e flash, in un anello di capienza fissa.
const HITS_KEPT := 64
## Raggio entro cui due nemici si spingono, e quanti vicini si controllano per
## ciascuno. Il tetto e' quello che tiene il costo costante.
const SEPARATION_RADIUS := 1.6
const SEPARATION_CHECKS := 6
const SEPARATION_FORCE := 11.0
## Dalla zona dei colpi dello sparo, un nemico non deve arrivare addosso.
const MIN_SPAWN_GAP := 12.0
## Popolazione viva **contemporaneamente** dell'onda corrente. **Non e' una
## costante**: e' uno specchio di `Run.population_of(run.wave)`, tenuto allineato
## da `_sync_population()` negli stessi punti in cui cambia `wave` (vedi il
## commento di quel metodo). Il valore di partenza non e' 200 ma
## `Run.POP_BASE` = 25: la curva e la sua misura sono in `src/sim/run.gd`.
var population: int = 0
## Se falsa, l'orda non si riempie da sola: serve al test per vedere il
## conteggio scendere davvero.
var auto_respawn: bool = true
## Seed della disposizione. 0 = casuale a ogni avvio; un numero = riproducibile.
var seed: int = 0

# --- API massa (piano 5) -------------------------------------------------------

## Nemici vivi. Vale sempre `transforms.size() == colors.size() == count`.
var count: int = 0
## Posizione mondo di ogni nemico vivo. Cio' che arena legge per il MultiMesh.
var transforms: PackedVector3Array = PackedVector3Array()
## Tinta per nemico (per specie).
var colors: PackedColorArray = PackedColorArray()

# --- Dati per nemico: array paralleli, tutti lunghi `count` --------------------

var velocities: PackedVector3Array = PackedVector3Array()
var hp: PackedFloat32Array = PackedFloat32Array()
var kinds: PackedInt32Array = PackedInt32Array()
## Secondi di pausa dopo un colpo. Colpisce solo l'animazione, non la fisica.
var timers: PackedFloat32Array = PackedFloat32Array()

# --- Telemetria ---------------------------------------------------------------

## Nemici ammazzati dall'inizio della partita.
var kills: int = 0
## Raggio utile dell'arena, ripreso dal contratto a ogni passo.
var arena_radius: float = 28.0
## Ultimi colpi ricevuti, in un anello di capienza fissa: `hit_count` quanti
## sono validi. Serve a sfx/flash senza toccare gli array e senza allocare.
var hit_count: int = 0
var hit_positions: PackedVector3Array = PackedVector3Array()
var hit_kinds: PackedInt32Array = PackedInt32Array()
## Numero di celle mai viste dalla griglia: dopo il riscaldamento deve restare 0.
var grid_unknown_cells: int = 0

# --- La partita ---------------------------------------------------------------
#
# Senza tipo dichiarato, come `_grid`: l'oggetto lo crea `_build()`, e in GDScript
# `:=` su una variabile senza tipo non compila. Si indica il tipo dove si legge.
# `run` non e' nullo dopo `_build()`, che e' l'unico posto in cui si costruisce.

## Stato della partita e scala delle onde. Oggetto, non nodo: un restart non
## crea e non libera niente nell'albero.
var run = null

## Pesi delle specie dell'onda corrente. Ricalcolati **solo** al cambio d'onda e
## in `_build()`: ogni spawn legge questo array e non ne costruisce uno, quindi lo
## spawn non alloca nel ciclo di gioco.
var _weights: PackedFloat32Array = PackedFloat32Array()

# --- Interno ------------------------------------------------------------------

var _grid = null
var _grid_extent: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Bersaglio dei nemici. Se -gameplay ha registrato `player_position` e' la sua
## posizione, altrimenti il centro dell'arena.
var _focus: Vector3 = Vector3.ZERO
var _sep_buf: PackedInt32Array = PackedInt32Array()
## Credito di spawn accumulato, in nemici. `_top_up()` lo riempie di
## `run.spawn_rate() * delta` e ne spende solo interi: e' il posto dove vive il
## "non tutti insieme" di m4. Il tetto a 1 (in `_top_up`) vuol dire che un passo
## lento non accumula un raffica e la scarica tutta al passo dopo.
var _budget: float = 0.0
var _built: bool = false
var _registered: bool = false
var _grid_dirty: bool = true
var _contract_node: Node = null
## Il giocatore, tenuto dal dato `Game.player`. Si rivede solo se non e' piu'
## valido: nel ciclo di gioco non si fa una ricerca per nome ogni frame.
var _player_cache: Node = null

func _ready() -> void:
	_build()
	_register()

## Il contratto, come nodo. Vedi la nota in testa al file: `Game.` non compila
## sotto `--script`, `get_node_or_null("Game")` si'. Va risolto una volta sola:
## nel ciclo di gioco una ricerca per nome a ogni frame sarebbe sprecata.
func _contract() -> Node:
	if _contract_node == null and is_inside_tree():
		_contract_node = get_tree().root.get_node_or_null("Game")
	return _contract_node

## Raggio utile dell'arena, letto dal contratto. Se il contratto non c'e' ancora
## si tiene il valore gia' in campo: meglio un raggio che uno zero.
func _contract_radius() -> float:
	var game := _contract()
	if game != null:
		var r: float = game.arena_radius
		return maxf(r, 6.0)
	return maxf(arena_radius, 6.0)

func _physics_process(delta: float) -> void:
	step(delta)

# --- Costruzione --------------------------------------------------------------

func _build() -> void:
	if _built:
		return
	_built = true
	arena_radius = _contract_radius()
	if seed != 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	# La griglia si riscalda su un quadrato piu' largo dell'arena: i nemici non
	# escono mai, ma il knockback puo' spingerli oltre il raggio utile.
	# `_sync_grid()` fa `setup()` solo quando l'estensione cambia davvero:
	# `setup()` ricrea tutti i secchielli, quindi rifarlo ogni frame sarebbe
	# esattamente l'allocazione nel ciclo di gioco che questo file evita.
	_grid = Grid.new()
	_sync_grid()
	_sep_buf.resize(SEPARATION_CHECKS)
	hit_positions.resize(HITS_KEPT)
	hit_kinds.resize(HITS_KEPT)

	# La partita esiste **prima** di qualunque spawn: `_apply_spawn` legge da
	# `run` il moltiplicatore di vita dell'onda, quindi costruirlo dopo sarebbe
	# un ordine in cui la prima generazione di nemici nasce con regole diverse
	# dalla seconda.
	run = Run.new()
	_sync_wave()
	_sync_weights()
	# La curva decide quanti nemici ci sono **al primo frame**: 25, non 200. Il
	# numero e la misura da cui e' uscito stanno in `src/sim/run.gd`.
	_sync_population()
	_budget = 0.0
	# Disposizione iniziale **a `population`**, non a `MAX_ENEMIES`.
	_populate(population)
	_rebuild_grid()

func _register() -> void:
	if _registered:
		return
	var game := _contract()
	if game == null:
		push_error("Horde: l'autoload Game non c'e': nessuna API registrata sul contratto")
		return
	_registered = true
	# Dato (piano 5.1): assegnazione diretta del campo.
	game.horde = self
	# Metodi (piano 5.1): forma lunga, perche' GDScript rifiuta l'assegnazione
	# a un nome che e' gia' un `func` del contratto.
	game.register_impl("nearest_enemy", self.nearest_enemy_index)
	game.register_impl("damage_enemy", self.damage_enemy)
	game.register_impl("random_spawn_point", self.random_spawn_point)

func _resize_arrays(n: int) -> void:
	transforms.resize(n)
	colors.resize(n)
	velocities.resize(n)
	hp.resize(n)
	kinds.resize(n)
	timers.resize(n)

## Mette `n` nemici nell'orda, disposti ad anelli come all'avvio, **senza creare
## nessun nodo**: si riscrivono array che hanno gia' la capienza.
##
## E' la stessa operazione del primo frame e quella del restart, ed e' voluto
## che sia una sola: due versioni della stessa disposizione sarebbero due numeri
## che possono divergere, e il primo frame e il restart devono essere la stessa
## cosa vista due volte.
func _populate(n: int) -> void:
	var target := clampi(n, 0, MAX_ENEMIES)
	count = target
	_resize_arrays(count)
	for i in count:
		_apply_spawn(i, Spawner.layout_point(arena_radius, i, count, _rng), _pick_kind())
	_grid_dirty = true

## I pesi delle specie dell'onda in corso.
func _sync_weights() -> void:
	_weights = Spawner.wave_weights(1 if run == null else run.wave)

## Una specie per lo spawn di adesso: un peso solo, non uno studio di insieme.
func _pick_kind() -> int:
	if _weights.is_empty():
		return Spawner.pick_kind(_rng)
	return Spawner.pick_kind_with(_rng, _weights)

## La vita di un nemico appena nato: la tabella della specie per il
## moltiplicatore dell'onda. Sull'onda 1 il moltiplicatore e' 1.0 esatto, quindi
## i numeri di `src/sim/enemy.gd` sono quelli di sempre e il criterio n. 4 della
## milestone 1 resta tarato su di loro.
func _hp_scale() -> float:
	return 1.0 if run == null else run.hp_scale()

func _apply_spawn(i: int, pos: Vector3, kind: int) -> void:
	transforms[i] = pos
	velocities[i] = Vector3.ZERO
	kinds[i] = kind
	hp[i] = E.hp_of(kind) * _hp_scale()
	timers[i] = 0.0
	colors[i] = E.color_of(kind)

# --- Simulazione --------------------------------------------------------------

## Un passo. Chiamato da `_physics_process`; il test lo chiama direttamente
## per non dipendere dal ciclo di frame.
##
## Nel corpo di questa funzione non c'e' `new()`, `instantiate()` o `queue_free()`:
## si scrive dentro array gia' di capienza e dentro la griglia gia' riscaldata.
## ## Lo stato della partita si guarda PRIMA di muovere chiunque
##
## Non e' solo un ordine: a `game_over` la simulazione e' ferma, quindi un passo
## non sposta nessuno e non riempie nessuno. E' la differenza fra "la partita e'
## finita" e "la partita continua ma non si vede piu' niente", che e' la
## confusione peggiore che un gioco possa fare a chi ci sta giocando.
func step(delta: float) -> void:
	if not _built or delta <= 0.0:
		return
	arena_radius = _contract_radius()
	# Se l'arena e' cambiata, la griglia va riscaldata di nuovo, altrimenti le
	# celle nuove costerebbero un'allocazione per frame.
	_sync_grid()

	_poll_run()
	if run != null and run.is_game_over():
		return

	_rebuild_grid()
	hit_count = 0
	var focus := _player_focus()
	for i in count:
		E.step(i, delta, focus, _separation(i), transforms, velocities, timers,
			kinds, arena_radius)
	_sweep_dead()
	_wave_tick(delta)

## Fine dell'onda e riempimento, in un passo solo.
func _wave_tick(delta: float) -> void:
	# La barra a zero e' l'unica condizione che chiude un'onda. Non si guarda
	# anche che il campo sia vuoto: col riempimento continuo un'onda da 230
	# uccisioni con 200 vivi non ha mai il campo vuoto al momento giusto, e
	# l'onda non finirebbe mai.
	if run != null and run.wave_cleared():
		run.next_wave()
		# I pesi delle specie cambiano con l'onda. Adesso, e non dentro
		# `next_wave`: le specie sono di questa foglia, `run.gd` non sa cosa sia
		# un runner.
		_sync_wave()
		_sync_weights()
		# E con l'onda cambia anche **quanti** ne devono essere vivi: la curva
		# di `run.gd`. Rialineata qui e non dentro `next_wave()` per lo stesso
		# motivo dei pesi, e non in `_top_up()` perche' li' il numero deve
		# arrivare gia' giusto: uno specchio allineato in due posti e' una
		# combinazione che non e' mai vera.
		_sync_population()
	_top_up(delta)

## Rende il campo pubblico `wave` uguale a quello di `run`. Chiamata dagli
## **tre** punti in cui l'onda cambia, e da nessun altro: uno specchio
## allineato in tre punti si puo' controllare a occhio, uno allineato "quando
## capita" no.
func _sync_wave() -> void:
	if run != null:
		wave = run.wave

## Rende il campo pubblico `population` uguale a quello che `run` chiede per
## l'onda corrente. Chiamata dagli stessi **tre** punti di `_sync_wave()`
## (`_build()`, cambio d'onda, restart) e da nessun altro.
##
## Non e' una copia per comodita': e' l'unico posto in cui la curva di
## `src/sim/run.gd` entra nell'orda. `_top_up()` legge **solo** il campo, quindi
## un test che pilota `population` a mano (il test di capacita') ottiene un'orda
## di 200 senza dipendere dalla curva, ed e' esattamente il motivo per cui i due
## numeri sono separati.
func _sync_population() -> void:
	if run != null:
		population = clampi(run.population_of(run.wave), 0, MAX_ENEMIES)

## Rimette a posto i nemici rimasti senza vita. `damage_enemy` li toglie subito,
## quindi di norma non trova niente: e' la rete di sicurezza, non il caso normale.
func _sweep_dead() -> void:
	var i := 0
	while i < count:
		if hp[i] <= 0.0:
			_kill(i)
			continue
		i += 1

## Riporta l'orda verso `population`, ma **al ritmo di `run.spawn_rate()`**.
##
## ## Perche' non "finche' `count < population`" come prima
##
## La versione di m1 e di m3 era un `while` che riempiva tutto in un passo:
## misurato, da 0 a 200 in **0.0167 s**, cioe' un passo. E' il sintomo «arrivano
## tutti insieme addosso», ed e' un fatto sul **tempo**, non sul conteggio: una
## curva per onda che si riempisse comunque in un frame avrebbe risolto il
## numero e lasciato il sintomo.
##
## Quindi qui il numero di spawn per passo e' il **credito** meno uno, e il
## credito cresce di `spawn_rate() * delta`. Intero per intero: con 8/s e un
## passo a 1/60 lo spawn arriva ogni 7.5 passi, mai piu' di uno per passo.
##
## Il credito non puo' accumularsi oltre **1**: un passo lento (o un `delta`
## enorme) non deve poter scaricare una raffica tutta insieme al passo dopo,
## altrimenti il tetto esisterebbe solo nella media e il sintomo tornerebbe
## proprio nei momenti in cui il gioco e' andato a scatti.
func _top_up(delta: float) -> void:
	if not auto_respawn or count >= population:
		return
	if delta <= 0.0:
		return
	_budget += (SPAWN_RATE_FALLBACK if run == null else run.spawn_rate()) * delta
	var n := int(_budget)
	if n <= 0:
		return
	# mai piu' di quanti ne servono, e mai piu' della capienza fisica
	n = mini(n, population - count)
	n = mini(n, MAX_ENEMIES - count)
	_budget = minf(_budget - float(n), 1.0)
	for _i in n:
		_spawn_one()

## Usato solo se `run` non c'e' ancora, cioe' mai: sta qui perche' `population`
## si puo' pilotare a mano anche su un'orda senza partita.
const SPAWN_RATE_FALLBACK := 8.0

func _spawn_one() -> void:
	if count >= MAX_ENEMIES:
		return
	var kind := Spawner.pick_kind(_rng)
	var pos := Spawner.spawn_point(arena_radius, _player_focus(), _rng, MIN_SPAWN_GAP)
	count += 1
	_resize_arrays(count)
	_apply_spawn(count - 1, pos, kind)
	_grid_dirty = true

## Uccisione per **scambio con l'ultimo**: `transforms[i] = transforms[last]` e
## `resize(count - 1)`. Non si cancella dal vettore: spostare 200 elementi per
## ogni nemico ammazzato costerebbe piu' della query che l'ha ucciso.
func _kill(i: int) -> void:
	var last := count - 1
	if i != last:
		transforms[i] = transforms[last]
		colors[i] = colors[last]
		velocities[i] = velocities[last]
		kinds[i] = kinds[last]
		hp[i] = hp[last]
		timers[i] = timers[last]
	count = last
	_resize_arrays(count)
	kills += 1
	# Ogni morte e' un passo in avanti sulla barra dell'onda. Si conta qui e non
	# in `damage_enemy`: `_kill` e' l'unico posto in cui un nemico sparisce davvero,
	# e cosi' la barra non dipende da **come** e' morto.
	if run != null:
		run.register_kill()
	_grid_dirty = true

# --- La partita e le onde ------------------------------------------------------
#
# Superficie che l'interfaccia e i test usano. Tre campi pubblici (`count`,
# `transforms`, `colors`) restano dati grezzi perche' sono la massa da disegnare;
# qui sotto sono numeri **derivati**, quindi metodi: se fossero campi, una barra
# letta a metà fra due aggiornamenti mostrerebbe una combinazione che non è mai
# vera.

## La partita e' in corso.
const RUN_PLAYING := "playing"
## La partita e' finita: il giocatore non ha piu' vite.
const RUN_GAME_OVER := "game_over"

## Numero dell'onda. **Campo**, e non metodo, perche' un altro file lo legge gia'
## per nome: `src/ui/hud.gd`::_refresh_wave fa `Game.horde.get("wave")` e si
## aspetta un intero, con un valore di riserva e un `push_warning` se non lo
## trova. Un metodo `wave()` avrebbe fatto dire all'HUD che il campo non esiste,
## e il contatore delle onde sarebbe rimasto fermo a 1 senza che nessuno lo
## notasse.
##
## E' uno **specchio** di `run.wave`, tenuto allineato da `_sync_wave()`: un solo
## punto in cui cambia, chiamato da `_build()`, dal cambio d'onda e dal restart.
## `tests/test_gameloop.gd` confronta il campo con `run.wave` in ogni stato
## raggiungibile, quindi uno specchio rotto diventa un test rosso e non un
## contatore fermo.
var wave: int = 1

## Numero dell'onda corrente. 1 all'avvio e dopo un restart.
func wave_total() -> int:
	return 0 if run == null else run.wave_total

## Quante uccisioni restano all'onda corrente: **la barra wave**. A zero l'onda
## è finita. Non scende mai sotto zero: quando le uccisioni sorpassano il
## bersaglio, l'onda è già finita e non "da un meno".
func wave_remaining() -> int:
	return 0 if run == null else run.wave_remaining()

## Quante uccisioni sono cadute nell'onda corrente.
func wave_killed() -> int:
	return 0 if run == null else run.wave_killed

## La barra wave come rapporto da 0 a 1, per l'interfaccia: 1.0 all'inizio
## dell'onda, 0.0 quando è finita. Sono gli stessi due numeri di
## `wave_remaining()`, quindi l'HUD non può mostrare una barra diversa da quella
## che la simulazione conta.
func wave_bar_ratio() -> float:
	return 0.0 if run == null else run.bar_ratio()

## `Run.PLAYING` o `Run.GAME_OVER`. Le due stringhe sono anche qui, perche' un
## metodo che restituisce una costante di un altro file e' una costante che si
## rompe da sola quando l'altro file la cambia: meglio due righe che una
## dipendenza per un nome.
func run_state() -> String:
	return RUN_PLAYING if run == null else run.state

## La partita è finita: il giocatore non ha più vite. Da solo non si torna
## indietro, l'unica strada è `restart_run()`.
func is_game_over() -> bool:
	return run != null and run.is_game_over()

## La vita relativa dei nemici di questa onda: 1.0 sull'onda 1, e cresce con le
## onde. Le tabelle di `src/sim/enemy.gd` non si toccano mai, quindi il criterio
## n. 4 della milestone 1 resta tarato su quei numeri: è la scala delle onde a
## essere nuova, non la fisica.
func wave_hp_scale() -> float:
	return 1.0 if run == null else run.hp_scale()

## Ricomincia la partita: **onda 1**, barra piena, niente `game_over`, e l'orda
## di nuovo piena **di `population`**, che sull'onda 1 e' `Run.POP_BASE` = 25 e
## non `MAX_ENEMIES`. Prima di m4 il restart ripartiva da 200 nemici vivi; era
## la stessa scelta di design sbagliata dell'avvio, ripetuta al secondo posto.
##
## Nessun nodo viene creato e nessuno viene liberato: si riscrivono gli array che
## già esistono. Il criterio n. 4 chiede che un restart non lasci nodi
## duplicati, e con questa forma il numero di nodi non *può* cambiare invece di
## dover essere controllato.
##
## Il giocatore **non** è toccato: è di -gameplay, e rimetterlo in piedi (vite,
## potenziamenti, arma) è la sua metà del restart. Chi chiama questo metodo deve
## rimettere in piedi anche il giocatore: se le vite restano a zero, il passo di
## simulazione successivo rilegge `game_over` e la partita si ferma di nuovo,
## che è la cosa giusta da fare ma non è un restart riuscito.
func restart_run() -> void:
	if not _built:
		return
	run.restart()
	kills = 0
	hit_count = 0
	_sync_wave()
	_sync_weights()
	_sync_population()
	_budget = 0.0
	_populate(population)

## Ridispone l'orda su un altro seme: il **semplice** e' la disposizione, non
## la partita. Chiamata dal contratto di m3 (`contracts.gd`, "Supersficie di
## milestone 3"), che ne dichiara la semantica in cinque punti; qui la si
## implementa senza aggiungere nomi nuovi.
##
## Serve perche' `seed` e' un campo pubblico ma lo leggeva **una volta sola**,
## dentro `_build()`, che gira nel `_ready()`: sulla scena vera l'orda la crea
## `arena_main.tscn`, quindi nessun codice esterno poteva scriverlo prima, e il
## campo sembrava la riproducibilita' mentre era irraggiungibile (`seed = 0`
## sempre, `_rng.randomize()` sempre).
##
## ## I cinque punti, e come sono resi qui
##
## 1. scrive il campo pubblico `seed` con `s` — una riga sotto.
## 2. `s == 0` **mantiene il significato dichiarato del campo**: `randomize()`,
##    cioe' casuale, e non "seme zero" (che Godot tratterebbe come seme fisso).
## 3. con `s != 0` fissa `_rng` sul seme e ripopola **a `population`** con lo
##    **stesso percorso del primo frame**: la funzione chiamata e' `_populate`,
##    la stessa che chiama `_build()`, non un mestiere separato. Due versioni
##    della stessa disposizione sarebbero due numeri che possono divergere, ed e'
##    la lezione gia' scritta in `_populate`.
## 4. **non tocca** `run`, `wave`, `kills` ne `population`: si leggono, non si
##    scrivono. E' un'operazione di disposizione, non di stato di partita;
##    `restart_run()` resta l'unica cosa che rimette a posto la partita. In
##    particolare `_sync_wave()` e `_sync_weights()` **non** vengono chiamate:
##    l'onda non e' cambiata, quindi pesi e scala della vita sono gia' quelli
##    giusti e risincronizzarli sarebbe scrivere lo stato di partita.
## 5. ricostruisce la griglia, cosi' `worst_bucket()` e `grid_overflowed()`
##    parlano della disposizione **appena scritta** e non di quella precedente.
##
## Sia con `s == 0` sia con `s != 0` la disposizione viene riscritta: il nome e'
## "ridisporre su un altro seme", e lasciare il campo com'e' a `s == 0` lascerebbe
## al chiamante una disposizione vecchia travestita da casuale. La differenza fra
## i due rami e' **solo** come `_rng` viene seminato.
##
## Nessun nodo viene creato e nessuno viene liberato, e nessuna allocazione
## nuova: `_populate` riscrive array che hanno gia' la capienza e `_rebuild_grid`
## riusa la griglia gia' riscaldata. Se `_built` e' falso e' un no-op, come
## `restart_run()`: l'orda non e' nata, quindi non c'e' niente da disporre.
func reseed(s: int) -> void:
	if not _built:
		return
	seed = s
	if s != 0:
		_rng.seed = s
	else:
		_rng.randomize()
	_populate(population)
	_rebuild_grid()

# --- Griglia ------------------------------------------------------------------

## Riscalda la griglia solo quando l'estensione cambia. `setup()` ricrea tutti i
## secchielli: chiamarlo ogni frame sarebbe l'allocazione nel ciclo di gioco che
## questo file evita, quindi la soglia e' volutamente grossolana.
func _sync_grid() -> void:
	var extent := arena_radius * 1.5
	if absf(extent - _grid_extent) < 0.5:
		return
	_grid_extent = extent
	_grid.setup(Grid.CELL, extent)
	_grid_dirty = true

func _rebuild_grid() -> void:
	_grid.begin_frame()
	# `worst_bucket` e' un **massimo storico** dentro `spatial_grid.gd`: si azzera
	# in `setup()` e non in `begin_frame()`, quindi dopo questo punto direbbe ancora
	# il picco della disposizione **precedente**. Il contratto di m3 pretende il
	# contrario: dopo `reseed` il numero deve parlare della disposizione appena
	# scritta (punto 5). Lo si azzera qui, dall'unico posto che ricostruisce la
	# griglia: il campo e' pubblico e non serve toccare `spatial_grid.gd`. Dopo il
	# ciclo di `insert` sotto, vale "picco del frame appena ricostruito".
	_grid.worst_bucket = 0
	for i in count:
		_grid.insert(i, transforms[i])
	grid_unknown_cells = _grid.unknown_cells
	_grid_dirty = false

## Una morte o uno spawn rendono la griglia vecchia. La query la sistema da
## sola invece di ricostruirla 30 volte per frame solo perche' un nemico e'
## morto.
func _ensure_grid() -> void:
	if _grid_dirty:
		_rebuild_grid()

func _separation(i: int) -> Vector3:
	if count < 2:
		return Vector3.ZERO
	var p := transforms[i]
	# `found` con tipo esplicito: `_grid` e' una variabile senza tipo (perche' la
	# griglia si crea in `_build()`), e `:=` su un chiamata che non ha tipo
	# dichiarato non compila.
	var found: int = _grid.collect_into(_sep_buf, p, SEPARATION_RADIUS, transforms,
		SEPARATION_CHECKS)
	var acc := Vector3.ZERO
	for k in found:
		var j: int = _sep_buf[k]
		if j == i:
			continue
		var away := p - transforms[j]
		var l2 := away.length_squared()
		if l2 > 0.0001 and l2 < SEPARATION_RADIUS * SEPARATION_RADIUS:
			acc += away / l2
	if acc.length_squared() <= 0.000001:
		return Vector3.ZERO
	return acc.normalized() * (SEPARATION_FORCE / E.mass_of(kinds[i]))

# --- API del contratto --------------------------------------------------------

## Indice del nemico vivo piu' vicino a `from` entro `radius`, oppure -1.
##
## Restituisce un **indice**, non un nodo: un nemico non e' un nodo (regola 1).
## L'indice e' esattamente quello che `damage_enemy(index, ...)` si aspetta, e il
## contratto fa `as int` su questo valore: si puo' chiamare
## `Game.nearest_enemy(pos, 12.0)` senza errori di cast (piano 5.2).
func nearest_enemy_index(from: Vector3, radius: float) -> int:
	if not _built or count == 0 or radius <= 0.0:
		return -1
	_ensure_grid()
	return _grid.nearest_index(from, radius, transforms)

## Applica `amount` di danno al nemico `index` e gli impartisce `knockback`.
## Se il nemico muore, viene tolto **subito**: dopo questa chiamata `count` e'
## gia' giusto, senza aspettare il frame dopo. Restituisce `true` se e' morto:
## e' l'unico modo per -gameplay di sapere **chi** e' morto senza aggiungere un
## segnale (piano 5.2).
##
## `knockback` e' un **impulso in m/s, gia' scalato dal chiamante**: qui non si
## normalizza e non si somma alla posizione, si somma alla velocita'.
func damage_enemy(index: int, amount: float, knockback: Vector3) -> bool:
	if not _built or index < 0 or index >= count:
		return false
	hp[index] -= amount
	if knockback.length_squared() > 0.000001:
		velocities[index] += knockback * (1.0 - E.knockback_resist_of(kinds[index]))
		timers[index] = 0.12
	_record_hit(transforms[index], kinds[index])
	if hp[index] <= 0.0:
		_kill(index)
		return true
	return false

## Punto di arrivo casuale dentro l'arena. Non puo' restituire `Vector3.ZERO`:
## il contratto usa ZERO come segnale di "non implementato".
func random_spawn_point() -> Vector3:
	if not _built:
		return Vector3(0.0, 0.0, _contract_radius() * 0.5)
	return Spawner.spawn_point(arena_radius, _player_focus(), _rng, MIN_SPAWN_GAP)

# --- Lettura per arena e ui ---------------------------------------------------

## Nome della specie, per un HUD o un log.
func kind_name(index: int) -> String:
	if index < 0 or index >= count:
		return "-"
	return E.KIND_NAMES[E.clamp_kind(kinds[index])]

## Velocita' massima di un tipo di nemico, per il render che deve animarli.
func speed_of_kind(kind: int) -> float:
	return E.speed_of(kind)

## Popolazione viva per specie.
func census() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(E.KIND_COUNT)
	for i in count:
		out[E.clamp_kind(kinds[i])] += 1
	return out

## Celle occupate dalla griglia, per diagnostica.
func occupied_cells() -> int:
	if _grid == null:
		return 0
	return _grid.occupied_cells()

## Qualche secchiello e' traboccato e le query stanno cadendo a scansione
## lineare? Non deve succedere, e il test lo controlla.
func grid_overflowed() -> bool:
	return _grid != null and _grid.overflowed

## Il nemico piu' occupato in una cella, **nel frame (griglia) appena
## ricostruito**: il picco delle celle dell'ultima disposizione scritta nella
## griglia, non un massimo storico.
##
## ## Perche' questo numero e' per-frame e non storico (scelta dichiarata)
##
## Dentro `spatial_grid.gd` il contatore e' un **massimo storico**: si azzera in
## `setup()` e non in `begin_frame()`. Lasciandolo com'e', dopo un `reseed`
## continuerebbe a dire il picco della disposizione **precedente**, e il
## chiamante misurerebbe una griglia vera che pero' non risponde alla domanda
## che ha fatto. Il contratto di m3 (punto 5) pretende esattamente il contrario:
## dopo `reseed` il numero parla della disposizione appena scritta.
##
## Percio' `_rebuild_grid()` azzera il campo pubblico del contatore a ogni
## ricostruzione: **non** serve modificare `spatial_grid.gd`. Il numero che
## esce da qui e' quindi il picco **dell'ultimo frame ricostruito**, ed e' quello
## che un test che asserisce deve sapere che sta usando.
##
## Nota per chi asserisce: non e' un massimo "da sempre". Un test che volesse il
## picco di tutta una sequenza deve ricordare il massimo osservato frame per
## frame, perche' questo numero torna giu' a ogni ricostruzione.
##
## ## Il numero e' limitato a `BUCKET_SLOTS`: non usarlo come guardia
##
## `spatial_grid.gd::insert` aggiorna il contatore solo con `n < BUCKET_SLOTS`,
## quindi questo valore **non puo' superare 32**: `worst_bucket() <= BUCKET_SLOTS`
## e' una tautologia che non puo' fallire, e un test che ci mette sopra una soglia
## cosi' non sta misurando niente. Il segnale che il traboccamento e' avvenuto e'
## `grid_overflowed()`. Per una **misura di densita'** questo numero va confrontato
## con un tetto **proprio, sotto 32** (e quel tetto va derivato da una misura, non
## scelto a piacere), che e' esattamente il tetto dichiarato che m3 chiede.
func worst_bucket() -> int:
	return 0 if _grid == null else _grid.worst_bucket

# --- Interno ------------------------------------------------------------------

func _record_hit(pos: Vector3, kind: int) -> void:
	var slot := hit_count % HITS_KEPT
	hit_positions[slot] = pos
	hit_kinds[slot] = kind
	hit_count = mini(hit_count + 1, HITS_KEPT)

## Lo stato della partita si aggiorna leggendo le vite del giocatore, e il
## giocatore si raggiunge per il **contratto**: `Game.player` è un dato pubblico
## che -gameplay registra, non un nodo che questa simulazione va a cercare
## nell'albero con `get_node("../..")`. È la strada che usa già
## `src/render/arena.gd` per la barra delle vite, e vale per la stessa ragione:
## una foglia che si cerca fra le altre foglie è una dipendenza circolare.
##
## Un campo assente, o di un tipo diverso, vale "non lo so": niente errore e
## niente `push_warning` ogni frame. Se un domani il giocatore smettesse di
## esporre `hp`, il test che azzera le vite e poi chiede `is_game_over()` lo
## direbbe subito — il che è meglio di un `game_over` che scatta da solo per un
## motivo sbagliato.
func _poll_run() -> void:
	if run == null:
		return
	var hp := _player_hp()
	if hp >= 0.0 and hp <= 0.0:
		run.enter_game_over()

## Le vite del giocatore, o -1.0 se il contratto non ha ancora un giocatore con
## quel campo. -1.0 e non 0.0 perché "non lo so" e "è morto" sono due fatti
## diversi e metterli nello stesso numero fa finire la partita a chi non lo sa.
func _player_hp() -> float:
	var game := _contract()
	if game == null:
		return -1.0
	if _player_cache == null or not is_instance_valid(_player_cache):
		_player_cache = null
		var found = game.get("player")
		if not (found is Node):
			return -1.0
		_player_cache = found
	var v: Variant = _player_cache.get("hp")
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return -1.0

## Il bersaglio dei nemici. Se -gameplay ha registrato `player_position` si usa
## quella, altrimenti il centro dell'arena: nessuna dipendenza circolare, e
## nessun `push_warning` se il contratto non e' ancora popolato.
func _player_focus() -> Vector3:
	var game := _contract()
	if game != null and game.has_impl("player_position"):
		var p: Vector3 = game.player_position()
		if p.length_squared() > 0.000001:
			return p
	return _focus

## Se arena ha il giocatore ma non ha registrato `player_position`, puo' dirlo
## qui. Non e' un `get_node("../..")`: e' un dato, non una dipendenza.
func set_focus(pos: Vector3) -> void:
	_focus = pos