extends RefCounted
## Griglia spaziale uniforme per le query di prossimita' dell'orda.
##
## `Dictionary[Vector2i] -> PackedInt32Array`: la cella e' la chiave, il valore
## e' il secchiello degli indici nemico che ci sono dentro.
##
## ## Perche' il contatore vive dentro il secchiello
##
## Il secchiello e' un `PackedInt32Array` di capienza **fissa** (`BUCKET_SIZE`),
## con l'indice 0 che tiene quanti indici sono validi. Il motivo e' `resize(0)` +
## `append`, che sembrano la via naturale ma NON vanno bene nel ciclo di gioco:
## `PackedInt32Array.resize(0)` mette a `null` il puntatore interno, e la
## `append` successiva riallocca il buffer. Con 200 nemici e ~150 celle sarebbero
## centinaia di rialloc per frame. Scrivendo a indice fisso non rialloca mai.
##
## Overflow: oltre `BUCKET_SLOTS` nemici nella stessa cella il secchiello segnala
## `overflowed`, conta il nemico in `dropped` e le query **cadono a scansione
## lineare**: lente ma corrette. Non si perde un nemico, che e' l'unica cosa
## che conta.
##
## Scrivere `cells[key][n] = i` su un `PackedInt32Array` tenuto in un `Dictionary`
## funziona ed e' in place: GDScript prende un riferimento all'elemento del
## contenitore, non una copia. E' la forma usata qui per **tutte** le scritture,
## perche' su un `PackedInt32Array` la scrittura e' copy-on-write e la
## combinazione sbagliata (una copia in una variabile locale) silenziosamente
## non scriverebbe niente. Verificato su 4.7.2: la forma indicizzata scrive.

## Lato della cella, in unita' di mondo. Il piano lo fissa a 4.
const CELL := 4.0

## Indici per cella, oltre al contatore.
##
## ## 32, e **resta 32**: l'esperimento di m4 e' finito e la risposta e' "no"
##
## La domanda era: *esiste un valore piu' stretto che non perda nessun
## nemico?* La risposta e' **no**, e il valore corrente resta quello giusto.
## Non per inerzia: sotto ci sono i due numeri che lo decidono, entrambi
## misurati, e `tests/test_orda.gd` li rimisura a ogni esecuzione.
##
## **Il caso che obbliga la costante e' l'orda isolata che converge**, non la
## scena vera. I due numeri che il piano mette uno contro l'altro misurano due
## cose diverse:
##
##   - **scena vera** (`tests/test_arena.gd`, sweep di 24 semi sul nodo della
##     scena): `worst_bucket` min 4, mediana 5, **max 7**, zero semi
##     traboccati, tetto dichiarato `GRID_CEILING = 11`;
##   - **orda isolata** (`tests/test_gameloop.gd`, sweep dei semi da 1 a 240
##     sulla sequenza di 600 passi con un'uccisione ogni due): **picco** di
##     nemici in una sola cella min **24**, mediana **29**, **max 32**, e il
##     seme 177 che quel test usa ha picco **28**.
##
## La scena vera non e' il caso che obbliga, e il conto si fa: sull'orda
## isolata **tutti e 240 i semi** hanno un picco sopra 11, quindi un valore
## tarato sulla scena vera (16, per esempio) farebbe traboccare **tutti** e
## 240 i semi, e con il traboccamento **ogni** query torna a scansione
## lineare proprio nel caso in cui la griglia serve, cioe' quando la densita'
## e' alta. Il fallback tornerebbe a essere la camminata di 200 confronti che
## la griglia doveva sostituire. Un valore uguale al picco del seme del test
## (28) non trabocca, ma non ha margine: e' la costante tarata sul caso che
## si vuole evitare, e non `BUCKET_SLOTS - 1` peggio. Scendere di uno sotto il
## picco (27) fa traboccare il seme del test.
##
## **Il margine che resta, detto per intero.** Sul seme 177 che il gate usa ci
## sono 4 slot di margine (28 su 32). Nel campione dei 240 semi il picco
## massimo e' **32**: la costante lo contiene esattamente, con zero margine, e
## il seme **148** ha picco **33**, quindi su quel seme un nemico viene
## rifiutato. Non e' un nemico perso: `insert()` lo rifiuta, `grid_overflowed()`
## va a vero e le query cadono a scansione lineare **per quel frame**, che e'
## il fallback corretto per costruzione e verificato in `tests/test_orda.gd`.
## Chi volesse chiudere anche quello sale a 34 e paga 8 KiB in piu' una volta
## sola all'avvio: e' una decisione sul gioco, non una misura, e m4 non la
## prende da solo.
##
## ## Costo, **misurato** e non dedotto (m4)
##
## Il numero di celle non si deduce da un commento: viene da
## `ceil(extent / CELL) + margin_cells` con `extent = arena_radius * 1.5` che
## passa `_sync_grid()`. Con `arena_radius = 28` sono `ceil(42 / 4) = 11` celle
## per lato piu' 3 di margine, cioe' 29 per lato: **841 celle**, lette dalla
## griglia di produzione con `occupied_cells()` e ristampate da
## `tests/test_orda.gd` a ogni esecuzione. Ogni secchiello e' un
## `PackedInt32Array` di `BUCKET_SIZE = 33` interi da 4 byte:
## **841 * 33 * 4 = 111012 byte** di carico utile, **108.4 KiB**, presi **prima**
## del primo frame e mai piu'.
##
## Il numero che questo commento dichiarava prima ("841 celle da 25 slot sono
## ~84 KB") era un resto di una configurazione passata (25 slot =
## `BUCKET_SLOTS` 24) e non tornava piu' da quando la costante era 12: le
## stesse 841 celle a 33 interi sono 108.4 KiB, non 84. Il totale e' quello
## qui sopra e la formula e' nel test, cosi' il commento non puo' invecchiare
## un secondo numero.
##
## Il costo nel ciclo di gioco resta **zero** comunque sia il valore:
## `nearest_index`, `collect_into` e `fill_radius` iterano `bucket[HEAD]`, cioe'
## gli indici **validi**, mai la capienza. Il secchiello grande costa solo
## `BUCKET_SIZE * 4` byte per cella riscaldata, e il riscaldamento sta in
## `setup()`, che gira una volta sola all'avvio.
const BUCKET_SLOTS := 32
## `bucket[0]` = quanti indici validi.
const HEAD := 0
## Il primo slot di dato.
const FIRST := 1
## Capienza del secchiello.
const BUCKET_SIZE := FIRST + BUCKET_SLOTS

## Lato della cella in uso.
var cell: float = CELL
## Celle incontrate per la prima volta DOPO il riscaldamento. Se resta 0, il
## ciclo di gioco non ha allocato niente: e' l'indicatore di perdite.
var unknown_cells: int = 0
## Il piu' grande numero di nemici visti in una cella in un frame.
var worst_bucket: int = 0
## Qualcuno ha superato BUCKET_SLOTS in una cella: le query cadranno a scansione
## lineare finche' il flag resta acceso.
var overflowed: bool = false
## **Quanti** nemici `insert()` ha rifiutato, non un flag: `overflowed` risponde
## a "qualcuno ha superato BUCKET_SLOTS", questo a "quanto". La differenza non
## e' di rumore: fra `dropped == 1` e `dropped == 199` c'e' la differenza fra una
## griglia che funziona e una griglia che **non vede piu' niente**, ed e' il
## numero con cui `BUCKET_SLOTS` e' stato misurato (m4).
##
## Si azzera in `begin_frame()`, **non** in `insert()` e non in `setup()`-per-
## frame: `insert()` non conosce l'inizio di un frame, quindi azzerarlo li'
## farebbe valere `0` per sempre.
##
## ## La sua portata non e' un invariante
##
## `dropped`, `overflowed` e `worst_bucket` descrivono lo **stesso** intervallo,
## cioe' l'ultima ricostruzione, ma non per costruzione: `begin_frame()` azzera
## i primi due, mentre `worst_bucket` lo azzera a mano il chiamante che
## ricostruisce la griglia (`horde.gd::_rebuild_grid`). Coincidono perche' in
## produzione `begin_frame()` ha **un solo chiamante**. Aggiungerne uno nel
## ciclo di gioco farebbe dire a due numeri "questo frame" e al terzo
## "l'ultima ricostruzione", e nessuno dei tre fallirebbe rumorosamente.
var dropped: int = 0

var _cells: Dictionary = {}

## Riscaldamento. Si fa UNA volta sola, prima del ciclo di gioco: crea un
## secchiello vuoto per ogni cella del quadrato `-extent-margin .. +extent+margin`
## (in celle). Serve a non allocare la prima volta che un nemico entra in una
## cella; non serve alla correttezza, che e' garantita comunque perche' `insert`
## crea la cella se manca.
func setup(p_cell: float, extent: float, margin_cells: int = 3) -> void:
	cell = maxf(0.5, p_cell)
	_cells.clear()
	unknown_cells = 0
	overflowed = false
	dropped = 0
	worst_bucket = 0
	var n := ceili(extent / cell) + margin_cells
	for cz in range(-n, n + 1):
		for cx in range(-n, n + 1):
			var bucket := PackedInt32Array()
			bucket.resize(BUCKET_SIZE)
			_cells[Vector2i(cx, cz)] = bucket

func cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / cell), floori(pos.z / cell))

func occupied_cells() -> int:
	return _cells.size()

## Ricostruisce tutto da capo. Va chiamata una volta per frame, e solo quella:
## sono 200 scritture, non 200 query.
func begin_frame() -> void:
	for key in _cells:
		_cells[key][HEAD] = 0
	overflowed = false
	dropped = 0

## Mette `index` nella cella di `pos`. Nessuna allocazione se la cella esiste.
##
## `bucket` **senza tipo dichiarato**, e non `PackedInt32Array`: `Dictionary.get`
## su una chiave assente restituisce `null`, e assegnare `null` a una variabile
## tipizzata lancia "Trying to assign value of type 'Nil'" e **interrompe la
## funzione**: la cella non verrebbe creata e `unknown_cells` non salirebbe.
## Il tipo si recupera con `as` solo nei rami caldi, dove la cella esiste.
func insert(index: int, pos: Vector3) -> void:
	var key := Vector2i(floori(pos.x / cell), floori(pos.z / cell))
	var bucket = _cells.get(key)
	if bucket == null:
		bucket = PackedInt32Array()
		bucket.resize(BUCKET_SIZE)
		_cells[key] = bucket
		unknown_cells += 1
	var n: int = bucket[HEAD]
	if n < BUCKET_SLOTS:
		_cells[key][FIRST + n] = index
		_cells[key][HEAD] = n + 1
		if n + 1 > worst_bucket:
			worst_bucket = n + 1
	else:
		overflowed = true
		dropped += 1

## Indice del nemico piu' vicino a `from` entro `radius`, o -1.
##
## E' la hot path della partita: non alloca niente e non chiama niente. E'
## scritta senza una sola funzione ausiliaria perche' in GDScript una chiamata
## costa piu' del corpo della funzione: con 25 celle da guardare, 25 chiamate
## avrebbero mangiato meta' del tempo della query.
##
## ## Perche' non le 25 celle di sempre
##
## Con `radius` 6 e cella 4 il quadrato da guardare e' 5x5 = 25 celle, e 25
## ricerche nel dizionario costano piu' dei 200 confronti di una scansione
## lineare: la griglia risultava **piu' lenta** del metodo che doveva
## sostituire. Due tagli, in quest'ordine:
##
## 1. **la cella che contiene il punto, e basta**. Quasi sempre c'e' un nemico
##    li' vicino, e la sua distanza dice subito quanto grande debba essere la
##    ricerca: se il vicino e' a 2 unita', una cella due passi piu' in la' dista
##    almeno `2 * cell` e non la si puo' guardare. Il secondo giro copre quindi
##    3x3 celle, non 5x5.
## 2. **il taglio per cella**: prima di aprire una cella se ne calcola la
##    distanza minima dal punto (la cella occupa `[lo, lo + cell]` su un asse, e
##    un punto dentro ha distanza 0) e se e' gia' maggiore di `best_d` quella
##    cella non puo' contenere il nemico piu' vicino, quindi si salta anche la
##    ricerca nel dizionario.
##
## Il confronto e' `>` e non `>=`: a parita' di distanza il comportamento deve
## restare quello di prima, che accetta l'ultimo indice a parita' (`d <= best_d`).
func nearest_index(from: Vector3, radius: float, positions: PackedVector3Array) -> int:
	if overflowed:
		return linear_nearest(from, radius, positions, positions.size())
	var best := -1
	var best_d := radius * radius
	var c := cell_of(from)
	var span := ceili(radius / cell)
	var last := positions.size()
	var fx := from.x
	var fy := from.y
	var fz := from.z
	var cx := c.x
	var cz := c.y
	# secondo giro: il quadrato ridotto a quello che `best_d` rende necessario
	var narrow := 0
	for phase in 2:
		if phase == 1 and narrow <= 0:
			break
		var sp: int = 0 if phase == 0 else narrow
		for dz in range(-sp, sp + 1):
			var loz := float(cz + dz) * cell
			# distanza minima dal punto all'intervallo [loz, loz + cell]
			var gz := loz - fz
			var gz_alt := fz - loz - cell
			if gz_alt > gz:
				gz = gz_alt
			if gz < 0.0:
				gz = 0.0
			var gz2 := gz * gz
			if gz2 > best_d:
				continue
			for dx in range(-sp, sp + 1):
				var lox := float(cx + dx) * cell
				var gx := lox - fx
				var gx_alt := fx - lox - cell
				if gx_alt > gx:
					gx = gx_alt
				if gx < 0.0:
					gx = 0.0
				if gx * gx + gz2 > best_d:
					continue
				# senza tipo dichiarato: una cella fuori dal riscaldamento vale
				# `null` e un'assegnazione tipizzata la tratterebbe come un
				# errore fatale, interrompendo la funzione
				var bucket = _cells.get(Vector2i(cx + dx, cz + dz))
				if bucket == null:
					continue
				var n: int = bucket[HEAD]
				for k in n:
					var i: int = bucket[FIRST + k]
					if i >= last:
						continue
					var p := positions[i]
					var ex := p.x - fx
					var ey := p.y - fy
					var ez := p.z - fz
					var d := ex * ex + ey * ey + ez * ez
					if d <= best_d:
						best_d = d
						best = i
		if phase == 0:
			# una cella `k` passi piu' in la' dista dal punto almeno
			# `(k - 1) * cell`, quindi oltre `narrow` non c'e' niente che possa
			# battere `best_d`. Se nella cella del punto non c'era nessuno,
			# `best_d` e' ancora il raggio e il secondo giro copre tutto.
			narrow = span if best < 0 else ceili(sqrt(best_d) / cell)
	return best

## Distanza minima fra un punto e una cella su **un solo asse**: la cella che
## parte da `lo` occupa `[lo, lo + cell]`, e un punto dentro l'intervallo ha
## distanza 0. Nessuna formula del tipo "quanto sono lontano dalla cella
## vicina": quella e' asimmetrica, la cella a sinistra si allontana dal bordo
## sinistro e quella a destra dal bordo destro, ed e' sbagliata una volta su due.
## Serve a `collect_into`; `nearest_index` la tiene inlined perche' la chiama 25
## volte per query e in GDScript la chiamata costa piu' del corpo.
static func _axis_gap(q: float, lo: float, cell: float) -> float:
	return maxf(0.0, maxf(lo - q, q - lo - cell))

## Scrive in `out` fino a `limit` indici entro `radius` e restituisce quanti.
## `out` deve essere gia' della capienza giusta: e' la via senza allocazioni,
## pensata per il ciclo di gioco (separazione dei nemici).
func collect_into(out: PackedInt32Array, from: Vector3, radius: float,
		positions: PackedVector3Array, limit: int) -> int:
	var written := 0
	var reach := radius * radius
	if overflowed:
		for i in positions.size():
			if written >= limit:
				break
			if from.distance_squared_to(positions[i]) <= reach:
				out[written] = i
				written += 1
		return written
	var c := cell_of(from)
	var span := ceili(radius / cell)
	for dz in range(-span, span + 1):
		var loz := float(c.y + dz) * cell
		var gz2 := _axis_gap(from.z, loz, cell)
		gz2 *= gz2
		if gz2 > reach:
			continue
		for dx in range(-span, span + 1):
			# stesso taglio di `nearest_index`: una cella che non tocca il disco
			# di raggio `radius` non ha niente dentro
			var lox := float(c.x + dx) * cell
			var gx := _axis_gap(from.x, lox, cell)
			if gx * gx + gz2 > reach:
				continue
			var bucket = _cells.get(Vector2i(c.x + dx, c.y + dz))
			if bucket == null:
				continue
			var n: int = bucket[HEAD]
			for k in n:
				var i: int = bucket[FIRST + k]
				if i >= positions.size():
					continue
				if from.distance_squared_to(positions[i]) <= reach:
					out[written] = i
					written += 1
					if written >= limit:
						return written
	return written

## Come `collect_into`, ma crescendola con `append`: comoda per i test e per il
## debug, **non** per il ciclo di gioco (append rialloca).
func fill_radius(out: PackedInt32Array, from: Vector3, radius: float,
		positions: PackedVector3Array) -> int:
	out.resize(0)
	var reach := radius * radius
	var candidates: Array[PackedInt32Array] = []
	if overflowed:
		for i in positions.size():
			if from.distance_squared_to(positions[i]) <= reach:
				out.append(i)
		return out.size()
	var c := cell_of(from)
	var span := ceili(radius / cell)
	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var bucket = _cells.get(Vector2i(c.x + dx, c.y + dz))
			if bucket != null:
				candidates.append(bucket as PackedInt32Array)
	for bucket in candidates:
		var n: int = bucket[HEAD]
		for k in n:
			var i: int = bucket[FIRST + k]
			if i >= positions.size():
				continue
			if from.distance_squared_to(positions[i]) <= reach:
				out.append(i)
	return out.size()

## Il riferimento: scansione lineare su tutti gli indici. Serve al test per
## dimostrare che la griglia restituisce **gli stessi** indici, non indici
## diversi e piu' veloci. Usata anche come fallback quando un secchiello trabocca.
static func linear_nearest(from: Vector3, radius: float, positions: PackedVector3Array,
		count: int) -> int:
	var best := -1
	var best_d := radius * radius
	var n := mini(count, positions.size())
	for i in n:
		var d := from.distance_squared_to(positions[i])
		if d <= best_d:
			best_d = d
			best = i
	return best

static func linear_fill_radius(out: PackedInt32Array, from: Vector3, radius: float,
		positions: PackedVector3Array, count: int) -> int:
	out.resize(0)
	var reach := radius * radius
	var n := mini(count, positions.size())
	for i in n:
		if from.distance_squared_to(positions[i]) <= reach:
			out.append(i)
	return out.size()