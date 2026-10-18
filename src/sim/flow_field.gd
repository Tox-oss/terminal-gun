extends RefCounted
## Il **campo di percorrenza** dell'orda (milestone 10): la cosa che fa aggirare
## al nemico quello che fino a m9 era un muro.
##
## I numeri che non sono di questo file vivono in `src/sim/obstacles.gd`, che e'
## il produttore unico della geometria (§3.11): da li' viene `SKIN_EPS`, il
## margine con cui `push_out` tiene il nemico **oltre** il bordo invece che
## sul bordo. E' una dipendenza dichiarata, non una copia.

## Il produttore dei numeri di m10. Nessun `preload` circolare: quel file non
## preloada niente.
const OBST = preload("res://src/sim/obstacles.gd")
## La tabella delle specie, per il raggio del nemico piu' grosso. `enemy.gd` non
## preloada niente, quindi nemmeno questo preload puo' diventare un riferimento
## circolare (`spawner.gd` fa lo stesso).
const E = preload("res://src/sim/enemy.gd")

## Il raggio minimo perché **tutti** i varchi restino larghi quanto una cella,
## derivato dalla forma del layout e non scritto.
##
## ## La formula, e perché i fattori sono quelli
##
## Ogni disco che il campo rasterizza è gonfiato di `RADIUS[BOSS] + SKIN`: quando due
## cerchi gonfiati si toccano la rastrelliera è un muro. Fra due cerchi **si
## sottraeggono due inflazioni, una per lato**; contro il **centro** e contro il
## **muro** se ne sottrae **una**, perché il centro non è un ostacolo e il muro è la
## maschera `fuori` — celle fuori arena, che la BFS non attraversa ma che **non
## sono gonfiate**. Poi ogni varco libero deve contenere **una cella** (`CELL`), o
## non è un varco per questa griglia.
##
## Con `k` anelli, `f` le frazioni, `D = RADIUS[BOSS] + SKIN` e `c = CELL`:
##
##     centro     R x (f1 - 0,065)                >=  D + c
##     fra anelli R x ((f[k] - f[k-1]) - 2 x 0,065) >=  2D + c
##     muro       R x (1 - f[k])                  >=  D + c
##     percorso   R x (1 - 2k x 0,065)            >=  2k D + (k+1) c
##
## L'ultima e' la somma degli altri: percorso del centro al muro si attraversano `2k`
## inflazioni e `k + 1` celle libere. **È la riga che ha bocciato i tre anelli**:
## con `k = 3` dà `R x 0,61 >= 21,50` cioè **`R >= 35,246 m`** mentre ne avevamo
## `35,00`. Non « stretto »: fuori di `0,25 m`. Con i due anelli di oggi dà `20,27 m`,
## e il massimo delle quattro righe è `22,41 m`, che è il numero che va guardato.
##
## ## Perche' la cella e' un **parametro** e non una costante letta
##
## `CELL` è dichiarata **più in basso** in questo file di questa funzione, e non si
## apposta a quell'ordine. La cella è la dimensione della griglia: questa funzione
## risponde «quanto deve essere il raggio **per questa cella**», e il chiamante la
## conosce già perché l'altra metà di questa sezione la stampa accanto ai varchi.
static func arena_radius_min(cell: float) -> float:
	var k := OBST.RING_RADII.size()
	if k <= 0:
		return 0.0
	var d := E.RADIUS[E.BOSS] + SKIN
	var peggiore := 0.0
	var lato := d + cell
	var f1 := float(OBST.RING_RADII[0]) - OBST.RADIUS_FRACTION
	if f1 > 0.0:
		peggiore = maxf(peggiore, lato / f1)
	var fn := 1.0 - float(OBST.RING_RADII[k - 1])
	if fn > 0.0:
		peggiore = maxf(peggiore, lato / fn)
	for i in range(1, k):
		var salto := float(OBST.RING_RADII[i]) - float(OBST.RING_RADII[i - 1]) \
			- 2.0 * OBST.RADIUS_FRACTION
		if salto > 0.0:
			peggiore = maxf(peggiore, (2.0 * d + cell) / salto)
	var libero := 1.0 - 2.0 * float(k) * OBST.RADIUS_FRACTION
	if libero > 0.0:
		peggiore = maxf(peggiore, (2.0 * float(k) * d + float(k + 1) * cell) / libero)
	return peggiore

## L'inflazione di un disco: quanto la rastrelliera si sposta dal centro del disco.
## È il numero da cui escono tutti i varchi, e va detto una volta sola perché
## «una inflazione o due» è la domanda che ha fatto sbagliare la prima stima.
static func inflate_for(arena_radius: float) -> float:
	return OBST.radius_for(arena_radius) + E.RADIUS[E.BOSS] + SKIN

## **Varco 1: dal centro al primo anello.** Una inflazione e una cella.
## È il disco libero in cui il giocatore sta e in cui i nemici devono poter stare:
## sotto `CELL` il centro è una stanza troppo stretta perché la BFS ci metta una
## sorgente comoda e il campo comincia a inseguire da fuori.
static func gap_centro(arena_radius: float) -> float:
	if OBST.RING_RADII.is_empty():
		return 0.0
	return float(OBST.RING_RADII[0]) * arena_radius - inflate_for(arena_radius)

## **Varco 2: fra due anelli consecutivi.** **Due** inflazioni — una per lato — più
## una cella. È il numero che a `R = 35,0 m` con i numeri di prima valeva `0,05 m`
## sotto tre anelli, e che produceva i 424 passi fermi: sotto `CELL` la rastrelliera
## è chiusa e il campo ha **due** sorgenti invece di una.
static func gap_anelli(arena_radius: float) -> float:
	if OBST.RING_RADII.size() < 2:
		return 0.0
	var peggiore := 1.0e9
	for i in range(1, OBST.RING_RADII.size()):
		var salto := (float(OBST.RING_RADII[i]) - float(OBST.RING_RADII[i - 1])) * arena_radius
		peggiore = minf(peggiore, salto - 2.0 * inflate_for(arena_radius))
	return peggiore

## **Varco 3: dall'ultimo anello al muro.** Una inflazione e una cella, **non due**:
## il muro è la maschera `fuori`, che la BFS già scarta e che `build()` non gonfia.
## Sottraerne due sarebbe la trappola inversa — aprire il varco interno e chiudere
## quello esterno — ed è il numero che ha fatto scrivere `0,685` invece di `0,814`
## come tetto per la frazione esterna. Il varco così calcolato è più generoso di
## quanto serva e **la verifica resta quella**: `>= CELL`.
static func gap_muro(arena_radius: float) -> float:
	if OBST.RING_RADII.is_empty():
		return 0.0
	var ultimo := float(OBST.RING_RADII[OBST.RING_RADII.size() - 1]) * arena_radius
	return arena_radius - ultimo - inflate_for(arena_radius)

## **Varco 4: fra due dischi dello stesso anello, cioè l'apertura di un anello.**
##
## Non e' fra i tre che il piano elenca, e senza questo quarto numero il criterio
## passa con un layout i cui anelli sono **anelli chiusi**: un anello rasterizzato
## chiuso non è un ostacolo che si aggira, è un muro che isola l'interno dall'esterno,
## e il sintomo è lo stesso del varco fra anelli. Quindi la misura esiste.
##
## Il caso peggiore e' con il **jitter al massimo** (`ANGLE_JITTER`), cioe' due dischi
## consecutivi il cui passo angolare si e' ridotto del 10%: e' la ragione per cui il
## numero e' `sin(passo x (1 - jitter))` e non `sin(passo)`. Il criterio di m10 e la
## dichiarazione di questa testa dicono entrambe che il jitter e' limitato proprio
## per non toccare la garanzia, e questa e' la funzione che quella promessa verifica.
##
## ## Quale dei cinque varchi **cede per primo**, e di quanto
##
## Ogni varco cala di `delta` per ogni metro di crescita di `RADIUS[BOSS]`, e i due
## circolari calano di **`2 x delta`** perché l'inflazione è da due lati. Quindi il
## primo a cedere non è quello che sembra più stretto in assoluto (`gap_muro`, che a
## `R = 35` è il più piccolo dei cinque con `3,175 m`), ma quello che ha **meno
## margine in celle** e ne ha **due** inflazioni da pagare. Misurato sui numeri di
## oggi:
##
## | varco | oggi | quante celle | cede a un boss di |
## |---|---|---|---|
## | circolare anello 1 | 2,390 m | 1,20 | **+0,195 m** |
## | circolare anello 2 | 2,732 m | 1,37 | +0,366 m |
## | contro il muro | 3,175 m | 1,59 | +1,175 m |
## | fra anelli | 5,650 m | 2,83 | +1,825 m |
## | centro | 8,075 m | 4,04 | +3,038 m |
##
## Cioè: **`RADIUS[BOSS]` può crescere di `0,41 m` — un terzo della sua taglia —
## prima che il varco contro il muro si accorga di qualcosa, e già a `0,195 m` il
## primo anello si chiude.** Il numero che va scritto qui, perché nessuno lo scopra
## spostando una costante di `enemy.gd` e ritrovandolo in un crash tre settimane dopo.
static func gap_circolare(i: int, arena_radius: float) -> float:
	if i < 0 or i >= OBST.RING_COUNTS.size() or i >= OBST.RING_RADII.size():
		return 0.0
	var n: int = maxi(int(OBST.RING_COUNTS[i]), 1)
	var r := float(OBST.RING_RADII[i]) * arena_radius
	var passo := PI / float(n)
	var peggiore := sin(passo * maxf(0.0, 1.0 - OBST.ANGLE_JITTER))
	return 2.0 * r * peggiore - 2.0 * inflate_for(arena_radius)

## Il **minimo** dei varchi del layout a un raggio dato: il numero che il criterio
## confronta con `CELL`. `minimo` su tutti i varchi **e su tutti gli anelli**, e non
## una media: un layout con un varco buono e uno chiuso e' un layout chiuso.
static func gap_minimo(arena_radius: float) -> float:
	var peggiore := gap_centro(arena_radius)
	peggiore = minf(peggiore, gap_anelli(arena_radius))
	peggiore = minf(peggiore, gap_muro(arena_radius))
	for i in OBST.RING_COUNTS.size():
		peggiore = minf(peggiore, gap_circolare(i, arena_radius))
	return peggiore
##
## ## L'algoritmo, e perche' questo e non un altro
##
## Il bersaglio e' **uno solo** (il giocatore) e gli ostacoli sono **statici**
## (contratto di m10, punto 1). Quindi il campo si calcola una volta e si legge
## in O(1) per nemico: e' la ragione per cui questo progetto puo' permettersi
## 200 nemici che aggirano, e nessun'altra forma di inseguimento dava il
## permesso di farlo.
##
## La forma scelta e' un **campo di flusso su griglia uniforme**:
##
##   1. gli ostacoli vengono rasterizzati in una griglia di celle gonfiate del
##      raggio del **nemico piu' grosso** piu' un margine (`inflate`);
##   2. dal bersaglio si fa una **BFS** (`rebuild`): il costo di ogni cella e' il
##      numero di celle di cammino minimo dal bersaglio;
##   3. da quel costo si ricava un **versante** per cella (differenze finite
##      centrali) e si interpola bilinearmente alle quattro celle intorno al
##      nemico: la direzione e' continua, non uno degli otto passi del reticolo.
##
## Perche' BFS e non Dijkstra: i costi sono tutti uguali (una cella = un passo),
## quindi la BFS **visita ogni cella una volta sola** e il costo per ricostruire
## il campo e' lineare nel numero di celle, senza coda di priorita' e senza
## allocazioni. Lo scotto e' che la distanza e' quella del metrica di Chebyshev e
## non quella ottale: si perde qualche decimo di metro sul percorso e si guadagna
## un campo che si ricostruisce in poco tempo. E' uno scambio **voluto** e
## dichiarato: il campo e' un *consiglio*, e la verita' non e' il campo ma il
## test esatto di distanza (`push_out`), che e' quello che rende vero il
## criterio n. 2.
##
## ## Perche' il campo e' un consiglio e il vincolo e' esatto
##
## Una griglia a 2 m non sa dire se un nemico di 0,45 m e' dentro un disco di
## 3 m: puo' sbagliare di mezzo metro in ogni direzione. Se l'invariante
## "nessun nemico dentro un ostacolo" fosse affidato al campo, sarebbe un
## invariante sbagliato. Percio' i due compiti sono separati e non si mescolano:
##
##   - il **campo** dice da che parte guardare. Costa una griglia e si aggiorna
##     quando il bersaglio si e' mosso abbastanza;
##   - `push_out` dice **la verita'**: un test di distanza esatto disco-corpo,
##     che risolve l'invariante al centesimo di millimetro e cancella anche la
##     componente di velocita' che entra nell'ostacolo (cosi' il nemico
##     **scivola** lungo il bordo invece di entrare e fermarsi).
##
## Il cancello che rende `push_out` economico e' la griglia: un nemico la cui
## cella non e' bloccata e' per costruzione lontano da ogni ostacolo piu' di
## `inflate`, e li' il test esatto non serve. Nella misura di regime solo una
## trentina di nemici su duecenti aprono davvero il ciclo sugli ostacoli.
##
## ## Perche' il campo non si ricostruisce ogni passo
##
## Il giocatore corre a 7 m/s e con la spinta a 22. Ricalcolare il campo a ogni
## passo costerebbe una camminata su ~3000 celle per frame; non si fa. Si
## ricostruisce **quando il bersaglio si e' mosso piu' di `GOAL_MOVE` dal
## punto da cui e' stato costruito**: quando il giocatore sta fermo — cioe'
## esattamente quando il gioco si vorrebbe vincere stando fermi dietro un muro —
## il costo e' **zero**, e in corsa si ricostruisce ogni 0,86 s. La strada breve
## del nemico (`clear_line`) copre comunque il caso normale, quindi un campo
## vecchio di mezzo secondo non fa niente di strano: quando la linea diretta
## e' libera il nemico non lo guarda ne'.

## Lato della cella, in unita' di mondo. Dichiarato come la cella della griglia
## dei vicini (`spatial_grid.gd::CELL = 4.0`) ma **non uguale**: quella elenca
## chi c'e', questa dice da che parte andare, e il costo di due domande diverse
## non si paga con la stessa risoluzione.
const CELL := 2.0
## Margine oltre il corpo dell'enemy, in metri. Non e' decorativo: e' il
## cuscinetto che tiene il nemico **scivolando** lungo il bordo invece di
## entrare e fermarsi, e il raggio che decide se una cella e' libera e' questo
## piu' il corpo del boss.
const SKIN := 0.35
## Meta' diagonale della cella: il raggio con cui la rasterizzazione e' gonfiata
## perche' una cellata non bloccata garantisca che **nessun punto** della cella
## sia dentro l'ostacolo, nemmeno un angolo.
const HALF_DIAG := 0.7072
## Di quanto la griglia del campo supera il raggio dell'arena. I nemici possono
## essere spinti oltre il bordo dal knockback e devono restare guidati anche li':
## la griglia arriva a `arena_radius + EDGE_MARGIN`, e un punto che cade **fuori
## dalla griglia** e' trattato come ostacolato, cosi' il nemico segue il campo
## invece di andare dritto contro il vuoto.
##
## ## Perche' il campo NON attraversa il margello (misura, non ipotesi)
##
## La griglia arriva a `arena_radius + EDGE_MARGIN`, ma il campo percorre **solo
## il disco dell'arena**: le celle del margello ci sono, si possono interrogare,
## e non si attraversano. E' la maschera `fuori`, un byte per cella.
##
## Senza quella distinzione la BFS trovava che la strada piu' breve per aggirare
## un disco dell'anello esterno passa **fuori dal muro**, in una fascia di dieci
## metri dove nessun nemico puo' stare (`enemy.gd::EDGE_PUSH` lo tiene dentro a
## `arena_radius - RADIUS`). Il difetto che ne veniva e' il peggiore possibile per
## il criterio n. 4, e non si vedeva: il nemico che sta nel **corridoio fra il
## disco e il muro** ha davanti una cella bloccata (il disco gonfiato) e una
## cella libera che e' **piu' vicina al bersaglio** della sua, quindi il versante
## gli dice di uscire. Lui esce, e il `EDGE_PUSH` gli toglie esattamente quel
## moto indietro: `|v|` sotto `0.30 m/s` per **tutti i 1800 passi** della
## finestra, con `|v|` a zero e la posizione che non si muove di un millimetro.
## Nessun nemico dentro un ostacolo (criterio n. 2 verde), nessun errore, nessun
## crash: un nemico fermo in un angolo, che e' letteralmente il difetto per cui
## il criterio n. 4 esiste.
##
## Quindi il campo conosce l'arena, non solo i dischi. La maschera si calcola
## **una volta sola** in `build()`: la BFS non attraversa quelle celle e
## `_versante` le lascia a direzione zero **senza** contarle fra le irraggiungibili,
## perche' un punto fuori dall'arena non e' un posto dove il campo non sa niente:
## e' fuori dai giochi.
const EDGE_MARGIN := 8.0
## Quanto deve spostarsi il bersaglio perche' il campo venga ricostruito, in
## metri. Vedi la sezione in testa: il prezzo e' un campo vecchio di poco, e il
## vantaggio e' che da fermo il campo non costa niente.
const GOAL_MOVE := 6.0
## Quanto "vale" una cella bloccata nel calcolo del versante. Non un muro: se il
## versante vedesse `INF` davanti a un ostacolo, il nemico verrebbe respinto
## come da un muro e quello e' esattamente il difetto da evitare. Con 6 celle il
## versante punta **attorno** al disco.
const BLOCK_PENALTY := 6.0
## Quanto pesa il campo rispetto alla linea diretta quando la linea diretta non
## e' libera. Il campo comanda, ma la trazione diretta resta: senza, un nemico
## sul lato sbagliato di un ostacolo ci gira attorno per sempre.
const FIELD_WEIGHT := 1.0
const DIRECT_WEIGHT := 0.35
## Costo di una cella irraggiungibile.
const INF := 1.0e9
## Passo del cammino che verifica la linea diretta: meta' cella, cosi' nessun
## disco puo' restare in mezzo senza essere campionato.
const WALK := CELL * 0.5
## Gli otto vicini, nell'ordine in cui la BFS li visita. Costante e non
## calcolata a ogni passo: nel ciclo di gioco una lista che nasce e muore e'
## un'allocazione.
const NEIGHBOURS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

# --- La griglia (dati, non nodi) ------------------------------------------------
#
# Nessun nodo: il campo e' un oggetto che l'orda tiene in un campo e che muore
# con lei. `node_count` non si muove di una unita' (criterio n. 7).

## Gli ostacoli, nella forma del contratto (`y` = raggio). Copia: non e' l'array
## di un'altra foglia.
var obstacles: PackedVector3Array = PackedVector3Array()
## Raggio con cui un disco blocca una cella: raggio massimo degli ostacoli piu'
## corpo del boss piu' margine piu' meta' diagonale della cella.
var inflate: float = 0.0
var cells_x: int = 0
var cells_z: int = 0
var origin_x: float = 0.0
var origin_z: float = 0.0
var span: float = 0.0
## 1 = la cella tocca un ostacolo gonfiato.
var blocked: PackedByteArray = PackedByteArray()
## 1 = il centro della cella e' **fuori dal disco dell'arena**: il campo non la
## attraversa e non la conta fra le irraggiungibili. Vedi `EDGE_MARGIN`, che
## dichiara perche' la griglia arriva oltre il muro e il campo no.
var fuori: PackedByteArray = PackedByteArray()
## Raggio dentro cui il campo percorre: il disco dell'arena.
var arena_r: float = 0.0
## Cella di cammino minimo dal bersaglio. `INF` = mai raggiunta.
var cost: PackedFloat32Array = PackedFloat32Array()
## Versante per celle, in due componenti invece di un `Vector3`: sono 3000
## numeri e il ciclo di gioco li legge uno alla volta, e un terzo di memoria
## sprecata in componenti sempre nulle non e' un dettaglio su 200 nemici a 60 Hz.
var dir_x: PackedFloat32Array = PackedFloat32Array()
var dir_z: PackedFloat32Array = PackedFloat32Array()
## Coda della BFS: una sola voce per cella, quindi mai piu' di `cells`.
var queue: PackedInt32Array = PackedInt32Array()
## Il bersaglio da cui l'ultimo campo e' stato costruito.
var goal: Vector3 = Vector3.ZERO
var built: bool = false
## Celle libere che il campo non ha raggiunto. Deve restare **0**: una cella non
## raggiunta e' un posto dove il campo non sa dire niente, e il nemico che ci
## finisce e' un nemico che si ferma (criterio n. 4).
var unreachable: int = 0
## Quante volte il campo e' stato ricostruito. Telemetria per il test: senza
## questo numero, "il campo non costa niente da fermo" e' una frase.
var rebuilds: int = 0

## Costruisce la griglia dagli ostacoli. Gira **una volta sola**, all'avvio
## dell'orda: e' l'unica operazione che alloca, insieme alle quattro matrici.
## `body_radius` e' il raggio del nemico piu' grosso, letto dalla tabella delle
## specie dal chiamante e non scritto qui (criterio n. 6: un numero in un posto
## solo).
func build(obs: PackedVector3Array, arena_radius: float, body_radius: float) -> void:
	obstacles = obs
	inflate = 0.0
	for ob in obstacles:
		inflate = maxf(inflate, ob.y)
	inflate += maxf(0.0, body_radius) + SKIN + CELL * HALF_DIAG
	# La griglia copre il disco piu' un margello: i nemici possono essere spinti
	# fuori dal bordo dal knockback e devono restare guidati anche li'. Se un
	# punto cade fuori dalla griglia, la linea diretta si considera **bloccata**
	# e il nemico segue il campo: degradazione che allontana dal muro, mai
	# viceversa. Ma il campo **percorre** solo il disco: vedi `EDGE_MARGIN`.
	arena_r = maxf(6.0, arena_radius)
	span = arena_r + EDGE_MARGIN
	origin_x = -span
	origin_z = -span
	cells_x = int(ceil(span * 2.0 / CELL)) + 1
	cells_z = cells_x
	var n := cells_x * cells_z
	blocked.resize(n)
	fuori.resize(n)
	cost.resize(n)
	dir_x.resize(n)
	dir_z.resize(n)
	queue.resize(n)
	var rr_arena := arena_r * arena_r
	for gz in cells_z:
		var dz := origin_z + (float(gz) + 0.5) * CELL
		var base := gz * cells_x
		for gx in cells_x:
			var dx := origin_x + (float(gx) + 0.5) * CELL
			var i := base + gx
			blocked[i] = 0
			fuori[i] = 1 if dx * dx + dz * dz > rr_arena else 0
	for ob in obstacles:
		_raster(ob.x, ob.z, ob.y + maxf(0.0, body_radius) + SKIN)
	built = false
	rebuilds = 0
	unreachable = 0

func _raster(cx: float, cz: float, r: float) -> void:
	var x0 := maxi(0, int(floor((cx - r - origin_x) / CELL)))
	var x1 := mini(cells_x - 1, int(ceil((cx + r - origin_x) / CELL)))
	var z0 := maxi(0, int(floor((cz - r - origin_z) / CELL)))
	var z1 := mini(cells_z - 1, int(ceil((cz + r - origin_z) / CELL)))
	var rr := r * r
	for gz in range(z0, z1 + 1):
		var dz := origin_z + (float(gz) + 0.5) * CELL - cz
		var base := gz * cells_x
		for gx in range(x0, x1 + 1):
			var dx := origin_x + (float(gx) + 0.5) * CELL - cx
			if dx * dx + dz * dz <= rr:
				blocked[base + gx] = 1

func _cx_of(pos: Vector3) -> int:
	return int(floor((pos.x - origin_x) / CELL))

func _cz_of(pos: Vector3) -> int:
	return int(floor((pos.z - origin_z) / CELL))

## Costo di una cella, con le trappole fuori e dentro. Un vicino bloccato o
## fuori griglia non vale `INF`: vale `c + BLOCK_PENALTY`, altrimenti il versante
## davanti a un ostacolo sarebbe un muro e il nemico ci andrebbe contro.
## ## Lo stesso vale per una cella **fuori dal muro dell'arena**, ed e' la riga
## ## che chiude l'incastrato dell'anello esterno
## ##
## La BFS gia' tratta `fuori` come impassabile (`rebuild` scarta `fuori[n] != 0`),
## ma il versante no: `_sample` restituiva `cost[i]`, che per una cella fuori dal
## muro e' `INF` = 1e9. Una sola vicina a `INF` sottrae un milione alla
## differenza finita centrale e il versante smette di guardare il bersaglio:
## punta dalla cella fuori muro verso l'interno, cioe' **dritto contro il disco**.
## Misurato (`tests/test_orda.gd`, sezione 13c): un boss fermo **1800 passi di
## fila** nel corridoio fra l'anello esterno e il muro, `|p| = 43.75 m` su
## un'arena di 46, `|v| = 0.0003 m/s`, col campo che gli puntava addosso al disco
## (`disco = 0.001 m`) e `push_out` che glielo toglieva indietro a ogni passo. Non
## era rumore di folla: era il versante che diceva il contrario della BFS.
##
## Il verso giusto e' che **fuori dal muro costa quanto un ostacolo**: la BFS non
## lo attraversa, quindi il gradiente non deve nemmeno guardarlo come se fosse la
## strada piu' economica. Una condizione sola, e le due meta' del campo dicono
## la stessa cosa.
func _sample(c: float, cx: int, cz: int) -> float:
	if cx < 0 or cz < 0 or cx >= cells_x or cz >= cells_z:
		return c + BLOCK_PENALTY
	var i := cz * cells_x + cx
	if blocked[i] != 0 or fuori[i] != 0:
		return c + BLOCK_PENALTY
	return cost[i]

## Il campo va rifatto? No se il bersaglio non si e' mosso: e' il caso del
## giocatore fermo, che e' il caso in cui il campo **non deve costare niente**.
func needs_rebuild(target: Vector3) -> bool:
	if not built:
		return true
	var dx := target.x - goal.x
	var dz := target.z - goal.z
	return dx * dx + dz * dz > GOAL_MOVE * GOAL_MOVE

## Ricostruisce il campo dal bersaglio. Costa una passeggiata su tutte le celle
## e **zero allocazioni**: e' la promessa che rende `needs_rebuild` utile.
func rebuild(target: Vector3) -> void:
	goal = target
	for i in cost.size():
		cost[i] = INF
	var start := _nearest_free(target)
	if start >= 0:
		cost[start] = 0.0
		queue[0] = start
		var head := 0
		var tail := 1
		while head < tail:
			var c: int = queue[head]
			head += 1
			var cx := c % cells_x
			var cz := c / cells_x
			var passo := cost[c] + 1.0
			for k in NEIGHBOURS.size():
				# `nb` con tipo esplicito: `NEIGHBOURS[k]` e' un `Variant` preso da
				# una costante, e `cx + <Variant>` non ha tipo da cui inferire
				var nb: Vector2i = NEIGHBOURS[k]
				var nx := cx + nb.x
				var nz := cz + nb.y
				if nx < 0 or nz < 0 or nx >= cells_x or nz >= cells_z:
					continue
				var n := nz * cells_x + nx
				# `fuori` come `blocked`: una cella oltre il muro dell'arena
				# non e' una strada che il nemico puo' percorrere. Vedi la
				# dichiarazione di `EDGE_MARGIN`, che porta la misura.
				if blocked[n] != 0 or fuori[n] != 0 or cost[n] <= passo:
					continue
				cost[n] = passo
				queue[tail] = n
				tail += 1
	_versante()
	built = true
	rebuilds += 1

## La cella libera piu' vicina al bersaglio. Serve perche' il giocatore puo'
## accostarsi a un ostacolo: se la sua cella e' bloccata la BFS non avrebbe da
## dove partire, e un campo senza sorgente non e' un campo, e' un vicolo.
func _nearest_free(target: Vector3) -> int:
	var cx := _cx_of(target)
	var cz := _cz_of(target)
	if _free(cx, cz):
		return cz * cells_x + cx
	for r in range(1, 9):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dz) != r:
					continue
				var nx := cx + dx
				var nz := cz + dz
				if _free(nx, nz):
					return nz * cells_x + nx
	return -1

## Libera **per il campo**, che e' una domanda piu' stretta di "non bloccata":
## anche una cella oltre il muro dell'arena e' libera di ostacoli e non e' una
## strada che il nemico puo' percorrere. Senza il `fuori` qui, `_nearest_free`
## poteva scegliere come sorgente della BFS una cella nella fascia fuori muro:
## il campo ripartiva allora da un posto che il nemico non raggiunge mai, e il
## versante che ne usciva puntava fuori dal muro. E' lo stesso difetto che la
## maschera risolve nella BFS (punto 2 di `EDGE_MARGIN`), applicato alla sorgente.
func _free(cx: int, cz: int) -> bool:
	if cx < 0 or cz < 0 or cx >= cells_x or cz >= cells_z:
		return false
	var i := cz * cells_x + cx
	return blocked[i] == 0 and fuori[i] == 0

## Il versante per cella: differenze finite centrali del costo. Il gradiente
## punta **verso il costo che scende**, cioe' verso il bersaglio, e davanti a un
## ostacolo sale: per questo il nemico ci gira attorno invece di andarci dentro.
func _versante() -> void:
	unreachable = 0
	for cz in cells_z:
		for cx in cells_x:
			var i := cz * cells_x + cx
			# ## Una cella bloccata non e' una cella irraggiungibile: e' un disco
			# ## Il numero che interessa al criterio n. 4 e' **quante celle LIBERE
			# ## il campo non ha raggiunto**, e una cella bloccata non e' mai
			# ## raggiunta per costruzione: la BFS non ci entra (`blocked[n] != 0`
			# ## la scarta). Contarle insieme dava `unreachable == blocked_cells()`
			# ## e il messaggio diceva che il campo era rotto su tutta la
			# ## superficie dei dischi: un rosso costruito sul codice, non sulla
			# ## misura, cioe' la classe di difetto di §1.6.
			if blocked[i] != 0:
				dir_x[i] = 0.0
				dir_z[i] = 0.0
				continue
			# ## Una cella fuori dal muro non e' ne' bloccata ne' irraggiungibile
			# ## La BFS non la attraversa (`fuori[n] != 0` la scarta), quindi `cost`
			# ## li resta `INF` e il ramo sotto le avrebbe contate fra le
			# ## irraggiungibili: `unreachable` e' diventata 1361 su 3025 e il
			# ## messaggio accusava il campo su tutta la fascia di dieci metri
			# ## oltre il muro, che al nemico non serve e su cui non cammina mai.
			# ## Direzione zero e nessun conteggio: un punto fuori dall'arena non
			# ## e' un posto dove il campo non sa niente, e' fuori dai giochi.
			if fuori[i] != 0:
				dir_x[i] = 0.0
				dir_z[i] = 0.0
				continue
			var c := cost[i]
			if c >= INF:
				dir_x[i] = 0.0
				dir_z[i] = 0.0
				unreachable += 1
				continue
			var gx := _sample(c, cx - 1, cz) - _sample(c, cx + 1, cz)
			var gz := _sample(c, cx, cz - 1) - _sample(c, cx, cz + 1)
			var l2 := gx * gx + gz * gz
			if l2 > 0.000001:
				var s := 1.0 / sqrt(l2)
				dir_x[i] = gx * s
				dir_z[i] = gz * s
			else:
				dir_x[i] = 0.0
				dir_z[i] = 0.0

## Direzione del campo in un punto: miscela bilineare delle quattro celle che
## lo circondano. O(1), e senza la miscela la direzione cambierebbe a scatti alle
## frontiere di cella e l'orda si muoverebbe a scatti con lei.
func direction_at(pos: Vector3) -> Vector3:
	if not built or cells_x == 0:
		return Vector3.ZERO
	var fx := (pos.x - origin_x) / CELL - 0.5
	var fz := (pos.z - origin_z) / CELL - 0.5
	var x0 := int(floor(fx))
	var z0 := int(floor(fz))
	var tx := fx - float(x0)
	var tz := fz - float(z0)
	var ax := 0.0
	var az := 0.0
	ax += _dir_x(x0, z0) * (1.0 - tx) * (1.0 - tz)
	az += _dir_z(x0, z0) * (1.0 - tx) * (1.0 - tz)
	ax += _dir_x(x0 + 1, z0) * tx * (1.0 - tz)
	az += _dir_z(x0 + 1, z0) * tx * (1.0 - tz)
	ax += _dir_x(x0, z0 + 1) * (1.0 - tx) * tz
	az += _dir_z(x0, z0 + 1) * (1.0 - tx) * tz
	ax += _dir_x(x0 + 1, z0 + 1) * tx * tz
	az += _dir_z(x0 + 1, z0 + 1) * tx * tz
	if ax * ax + az * az <= 0.000001:
		return Vector3.ZERO
	var n := sqrt(ax * ax + az * az)
	return Vector3(ax / n, 0.0, az / n)

func _dir_x(cx: int, cz: int) -> float:
	if cx < 0 or cz < 0 or cx >= cells_x or cz >= cells_z:
		return 0.0
	return dir_x[cz * cells_x + cx]

func _dir_z(cx: int, cz: int) -> float:
	if cx < 0 or cz < 0 or cx >= cells_x or cz >= cells_z:
		return 0.0
	return dir_z[cz * cells_x + cx]

## La strada breve: il segmento `a -> b` tocca un ostacolo gonfiato?
##
## Se non lo tocca il nemico va dritto, che e' il comportamento di prima di m10:
## l'evitamento non deve cambiare niente quando non c'e' niente da evitare, e i
## numeri di m7/m8/m9 restano quelli che erano.
func clear_line(a: Vector3, b: Vector3) -> bool:
	if obstacles.is_empty():
		return true
	var dist := Vector2(b.x - a.x, b.z - a.z).length()
	if dist < 0.001:
		return true
	var passi := int(ceil(dist / WALK))
	for k in range(1, passi + 1):
		if _toccata(a, b, float(k) / float(passi)):
			return false
	return true

func _toccata(a: Vector3, b: Vector3, t: float) -> bool:
	var x := a.x + (b.x - a.x) * t
	var z := a.z + (b.z - a.z) * t
	var cx := int(floor((x - origin_x) / CELL))
	var cz := int(floor((z - origin_z) / CELL))
	# fuori griglia si risponde "bloccato": un punto fuori dal campo e' oltre il
	# margello, e la scelta che non lascia mai il nemico davanti a un muro
	# quando non ha piu' informazioni e' quella di non farlo andare dritto
	if cx < 0 or cz < 0 or cx >= cells_x or cz >= cells_z:
		return true
	return blocked[cz * cells_x + cx] != 0

## La direzione di inseguimento di un nemico. Tre strade, in quest'ordine:
## dritto se si puo', campo se la linea e' interrotta, e la tangente della
## superficie dell'ostacolo se il campo non sa niente (cella irraggiungibile o
## versante piatto): la tangente e' l'unica direzione che aggira **senza**
## dipendere dal campo, ed e' la rete che rende impossibile l'incastrato.
func steer(pos: Vector3, target: Vector3) -> Vector3:
	var dx := target.x - pos.x
	var dz := target.z - pos.z
	var dist := sqrt(dx * dx + dz * dz)
	if dist < 0.001:
		return Vector3.ZERO
	var d := Vector3(dx / dist, 0.0, dz / dist)
	if clear_line(pos, target):
		return d
	var f := direction_at(pos)
	if f.length_squared() > 0.000001:
		var s := f * FIELD_WEIGHT + d * DIRECT_WEIGHT
		if s.length_squared() > 0.000001:
			return s.normalized()
	var n := _normale(pos)
	if n.length_squared() > 0.000001:
		# la tangente, con il verso scelto dal lato su cui sta' il bersaglio
		var t := Vector3(-n.z, 0.0, n.x)
		return t if t.dot(d) >= 0.0 else -t
	return d

## Quanto spingere un nemico **fuori** dagli ostacoli che lo contengono, in
## metri: `ZERO` se e' gia' libero. E' il punto dove l'invariante del criterio
## n. 2 e' deciso, ed e' un test di distanza esatto: nessuna griglia, nessuna
## approssimazione, il corpo del nemico e' il raggio che si passa qui dentro.
##
## Con i numeri di oggi e' una spinta quasi sempre nulla, e il ramo costoso si
## apre solo per i nemici la cui cella e' bloccata (vedi la sezione in testa).
func push_out(pos: Vector3, body_radius: float) -> Vector3:
	if obstacles.is_empty():
		return Vector3.ZERO
	var cx := int(floor((pos.x - origin_x) / CELL))
	var cz := int(floor((pos.z - origin_z) / CELL))
	if cx < 0 or cz < 0 or cx >= cells_x or cz >= cells_z:
		return Vector3.ZERO
	if blocked[cz * cells_x + cx] == 0:
		return Vector3.ZERO
	var spinta := Vector3.ZERO
	for giro in 2:
		var mosso := false
		for k in obstacles.size():
			var ob := obstacles[k]
			var ex := pos.x + spinta.x - ob.x
			var ez := pos.z + spinta.z - ob.z
			# `SKIN_EPS` dentro il raggio di riferimento, non fuori dal confronto:
			# la spinta porta il nemico **oltre** il bordo di `SKIN_EPS`, cosi'
			# la posizione finale, che e' una somma, resta fuori anche dopo
			# l'errore di arrotondamento. La costante e' di `obstacles.gd`,
			# dichiarazione e misura in testa a quel file.
			var rr := ob.y + maxf(0.0, body_radius) + OBST.SKIN_EPS
			var d2 := ex * ex + ez * ez
			if d2 >= rr * rr:
				continue
			mosso = true
			var d := sqrt(d2)
			if d < 0.0001:
				# esattamente al centro: non c'e' un verso, se ne sceglie uno
				spinta.x += rr
			else:
				spinta.x += ex / d * (rr - d)
				spinta.z += ez / d * (rr - d)
		if not mosso:
			break
	return spinta

## Versore che esce dal disco piu' vicino, o `ZERO` se il punto e' libero.
func _normale(pos: Vector3) -> Vector3:
	var peggiore := 0.0
	var n := Vector3.ZERO
	for k in obstacles.size():
		var ob := obstacles[k]
		var ex := pos.x - ob.x
		var ez := pos.z - ob.z
		var d2 := ex * ex + ez * ez
		if d2 < ob.y * ob.y and d2 > peggiore:
			peggiore = d2
			n = Vector3(ex, 0.0, ez)
	if n.length_squared() <= 0.000001:
		return Vector3.ZERO
	return n.normalized()

## Un punto e' dentro un ostacolo, con dentro anche il corpo del nemico? Il
## criterio n. 2 e' scritto su questa domanda e su nient'altro.
func contains(pos: Vector3, body_radius: float) -> bool:
	for k in obstacles.size():
		var ob := obstacles[k]
		var ex := pos.x - ob.x
		var ez := pos.z - ob.z
		var rr := ob.y + maxf(0.0, body_radius)
		if ex * ex + ez * ez < rr * rr:
			return true
	return false

## Celle bloccate e celle libere: due numeri che il test riconsidera a ogni lancio.
func blocked_cells() -> int:
	var n := 0
	for i in blocked.size():
		if blocked[i] != 0:
			n += 1
	return n