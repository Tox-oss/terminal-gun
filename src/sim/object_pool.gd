extends RefCounted
## Pool di oggetti riusabili: nasce per i proiettili e gli effetti di -gameplay e
## per gli eventi di -orda, e vale per qualunque cosa che nel ciclo di gioco si
## crea e si butta ogni frame.
##
## Il contratto e' una parola sola: **`created()` smette di crescere**. Il pool
## crea i suoi oggetti nel riscaldamento, una volta sola; dopo, `acquire()` e
## `release()` non chiamano mai la fabbrica. E' la differenza fra un bullet
## heaven che gira e uno che si frammenta dopo due minuti.
##
##     var pool = ObjectPool.new()
##     pool.configure(func(): return Proiettile.new(), 100)   # fuori dal ciclo
##     ...
##     var p = pool.acquire()      # dentro il ciclo: niente allocazioni
##     pool.release(p)
##
## ## Come sono tenuti gli slot
##
## `_items[slot]` **non si svuota mai**: l'oggetto vive li' per tutta la vita del
## pool, e a dire se che uno slot e' libero e' `_busy[slot]`. Il motivo e' che
## `release()` deve trovare lo slot di un oggetto ricevuto dal chiamante: se
## `acquire()` azzerasse `_items[slot]`, la ricerca non troverebbe piu' niente e
## ogni release diventerebbe una perdita silenziosa. Con la bandierina la ricerca
## funziona e il doppio release si riconosce.
##
## La pila degli slot liberi e' un `PackedInt32Array` di capienza fissa con un
## indice in cima (`_free_top`), non un array che cresce e si restringe: un
## `append`/`resize` per ogni acquire\/release sarebbe una riallocazione per
## frame, cioe' esattamente cio' che questo file esiste per evitare.

## Fabbrica degli oggetti. Chiamata solo nel riscaldamento.
var _factory: Callable = Callable()
## Capienza massima: oltre, `acquire()` da `null` invece di creare.
var capacity: int = 0

var _items: Array = []                             # slot -> oggetto, sempre pieno
var _busy: PackedInt32Array = PackedInt32Array()  # slot -> 1 se in uso
var _free_slots: PackedInt32Array = PackedInt32Array()
var _free_top: int = 0
var _live: int = 0
var _created: int = 0
var _rejected: int = 0       ## acquire() a vuoto: il difetto che il pool nasconde

## Riscaldamento: crea `cap` oggetti con la fabbrica e li rimette tutti liberi.
## Va chiamata una volta sola, fuori dal ciclo di gioco.
func configure(factory: Callable, cap: int) -> void:
	_factory = factory
	capacity = maxi(0, cap)
	_items.clear()
	_items.resize(capacity)
	_busy.resize(capacity)
	_free_slots.resize(capacity)
	_free_top = 0
	_live = 0
	_created = 0
	_rejected = 0
	for slot in capacity:
		if not _factory.is_valid():
			push_error("ObjectPool.configure: fabbrica non valida, il pool non puo' creare nulla")
			return
		var item: Variant = _factory.call()
		if item == null:
			push_error("ObjectPool.configure: la fabbrica ha restituito null allo slot %d" % slot)
			return
		_items[slot] = item
		_busy[slot] = 0
		_free_slots[_free_top] = slot
		_free_top += 1
		_created += 1

## Un oggetto libero, o `null` se il pool e' esaurito. **Non** crea niente: se il
## chiamante deve poter crescere, deve chiamare `grow()` e rendersene conto.
func acquire() -> Object:
	if _free_top <= 0:
		_rejected += 1
		return null
	_free_top -= 1
	var slot: int = _free_slots[_free_top]
	_busy[slot] = 1
	_live += 1
	return _items[slot]

## Restituisce un oggetto al pool. Se l'oggetto non e' del pool si rifiuta (e si
## avvisa): accettarlo silenziosamente nasconderebbe una perdita. Rifiuta anche il
## doppio release, per lo stesso motivo: un oggetto gia' libero che torna dentro
## fa vivere due proiettili con lo stesso slot.
func release(item: Object) -> bool:
	if item == null:
		return false
	var slot := -1
	for s in _items.size():
		if _items[s] == item:
			slot = s
			break
	if slot < 0:
		_rejected += 1
		push_error("ObjectPool.release: l'oggetto non e' di questo pool")
		return false
	if _busy[slot] == 0:
		_rejected += 1
		return false
	_busy[slot] = 0
	_free_slots[_free_top] = slot
	_free_top += 1
	_live -= 1
	return true

## Restituisce tutto quello che e' fuori, in un colpo solo.
func release_all(items: Array) -> void:
	for item in items:
		release(item)

## Allarga il pool di `extra` slot, chiamando la fabbrica. Fuori dal ciclo.
func grow(extra: int) -> void:
	if extra <= 0 or not _factory.is_valid():
		return
	# Si ricostruisce lo stato invece di spostare indici: e' una operazione da
	# fuori ciclo, e cosi' non si puo' dimenticare di aggiornare una tabella.
	var tutti: Array = []
	for s in _items.size():
		if _busy[s] == 0:
			tutti.append(_items[s])
	for _slot in extra:
		if not _factory.is_valid():
			break
		var item: Variant = _factory.call()
		if item == null:
			break
		tutti.append(item)
		_created += 1
	_items.clear()
	_items.resize(tutti.size())
	_busy.resize(tutti.size())
	_free_slots.resize(tutti.size())
	_free_top = 0
	capacity = _items.size()
	for s in capacity:
		_items[s] = tutti[s]
		_busy[s] = 0
		_free_slots[_free_top] = s
		_free_top += 1
	_live = 0

func live() -> int:
	return _live

func free_count() -> int:
	return _free_top

## Totale oggetti mai creati. E' il numero da guardare: se cresce dentro il ciclo
## di gioco, il pool sta allocando e il gioco si sta frammentando.
func created() -> int:
	return _created

## Quante volte `acquire()` ha trovato il pool vuoto.
func rejected() -> int:
	return _rejected

func is_full() -> bool:
	return _free_top <= 0