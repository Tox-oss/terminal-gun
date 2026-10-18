extends Camera3D
## La camera dell'arena: fissa in alto e indietro **orizzontalmente**, e segue il
## giocatore **anche in verticale** dal m12.
##
## Non registra niente sul contratto. Il bersaglio arriva da `Game.player_position()`
## (registrato da -gameplay) e, se quel metodo non c'e' ancora, dalla posizione di
## `Game.player`: un dato del contratto, non un `get_node("../..")`.
##
## -gameplay legge la base della camera dal viewport per orientare i tasti
## rispetto a quello che si vede: quindi la camera e' di arena e la camera
## guarda il giocatore, ma il giocatore non si muove in base alla camera che
## arena ha scelto. Nessuna delle due foglie dipende dall'altra.

## Quanto sopra il bersaglio.
const HEIGHT := 34.0
## Quanto indietro rispetto al bersaglio.
const BACK := 24.0
## Quanto sopra il bersaglio guarda: il centro dell'arena, non i piedi.
const LOOK_HEIGHT := 1.0
## Con quanto slancio insegue. 8 = il bersaglio ci arriva in circa un otto di
## secondo, che si sente morbido ma non acquoso.
const FOLLOW_SPEED := 8.0
## Metri entro cui la camera resta: oltre, il bersaglio e' spinto indietro e si
## comincia a vedere il vuoto oltre il muro.
const EDGE_MARGIN := 6.0
## ## m12: IL SUOLO **DEL MONDO PIATTO**, non il suolo della torre
##
## `0,0` era «la quota del punto guardato» quando l'arena era un disco solo. Adesso
## la quota la dà **il giocatore** (`_clamped()` sotto) e questo numero e' il
## **ripiego per il caso senza torre**: con `Game.floor_height == 0.0` il giocatore
## e' a `0,0` e la riga restituisce questa costante, quindi **identica**. Non e'
## una copia di `arena_radius` e non e' un numero nuovo: e' lo stesso zero di prima,
## con un significato piu' stretto e dichiarato. `tests/test_arena.gd::_m11_raggio`
## lo legge e lo confronta, quindi se qualcuno lo cambiasse da solo la porta va
## rossa.
const ARENA_FLOOR := 0.0
## ## FALLBACK RADIUS: un fallback **dichiarato**, non una fonte (criterio n. 2 di m9)
##
## Vivi **solo** quando il contratto non e' raggiungibile: su un progetto senza
## autoload, in un processo di test lanciato con `--script` prima che l'arena si
## registri. In partita questo numero **non viene mai usato**: `arena_radius()`
## legge `Game.arena_radius`, e quel valore lo scrive `src/render/arena.gd`, che
## e' la **fonte unica** (piano 1.12-bis, copia 1 di 6).
##
## Perche' il fallback vale 35.0 e non il numero vecchio: un fallback che dicesse
## il numero sostituito mentirebbe proprio nel caso in cui nessuno lo guarda, cioe'
## quando l'arena non e' ancora registrata, e la camera taglierebbe il bersaglio a
## 60 m su una torre larga 70 m: l'ancora finirebbe **fuori dal disco** e si
## comincerebbe a vedere il vuoto oltre il muro. Il numero non e' qui scelto: e'
## quello della fonte, `src/render/arena.gd`, con la tabella e il motivo scritti
## accanto.
##
## ## Perche' non puo' DIVERGERE, che e' il punto del criterio n. 2
##
## Il criterio non e' che questo numero sparisca: e' che non possa mentire in
## silenzio. `tests/test_arena.gd` legge questa riga **dal sorgente** e la
## confronta con la fonte: se qualcuno la cambia da sola, la porta va rossa con
## i due numeri nel messaggio. Un fallback che puo' divergere e' una sesta
## copia, ed una sesta copia mente alla prima riga cambiata.
const FALLBACK_RADIUS := 35.0

var _contract_cache: Node = null
var _placed: bool = false
var _focus := Vector3.ZERO
var _anchor := Vector3.ZERO

func _ready() -> void:
	# La camera dell'arena e' quella attiva: nessun'altra ce n'e' e il progetto
	# non ha una camera di fallback.
	current = true
	fov = 62.0
	near = 0.5
	far = 220.0

func _process(delta: float) -> void:
	track(desired_focus(), delta)

## Mette la camera dove deve per `focus`, con slancio `delta`. Pubblico perche' il
## test lo chiami senza far avanzare il motore.
func track(focus: Vector3, delta: float) -> void:
	if not _placed:
		# Il primo passo non slancia: partirei dal centro dell'arena e
		# attraverserei tutta la partita prima di arrivare al giocatore.
		_placed = true
		_focus = focus
	else:
		_focus = _focus.lerp(focus, clampf(delta * FOLLOW_SPEED, 0.0, 1.0))

	var anchor := _clamped(_focus)
	_anchor = anchor
	global_position = anchor + Vector3(0.0, HEIGHT, BACK)
	look_at(anchor + Vector3.UP * LOOK_HEIGHT, Vector3.UP)

## Il punto del terreno che la camera sta davvero guardando, dopo il taglio ai
## bordi. Non e' il giocatore: quando il giocatore e' contro il muro, e' il muro.
## Serve al test perche' la posizione della camera, di per se', include i suoi
## 24 metri di ritardo e quindi esce dal raggio anche quando il bersaglio no.
func anchor() -> Vector3:
	return _anchor

## Il punto da guardare. Tollerante: se il contratto non e' ancora popolato
## guarda il centro dell'arena invece di fermarsi su un `Vector3.ZERO` che e'
## anche il segnale di "non implementato" del contratto.
func desired_focus() -> Vector3:
	var game := _contract()
	if game == null:
		return Vector3.ZERO
	if game.has_impl("player_position"):
		var p: Vector3 = game.player_position()
		if p.length_squared() > 0.000001:
			return p
	var player = game.get("player")
	if player is Node3D:
		return (player as Node3D).global_position
	return Vector3.ZERO

func arena_radius() -> float:
	var game := _contract()
	if game == null:
		return FALLBACK_RADIUS
	var value = game.get("arena_radius")
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return maxf(float(value), 6.0)
	return FALLBACK_RADIUS

func _clamped(focus: Vector3) -> Vector3:
	# ## m12: IL VERTICALE SEGUE IL GIOCATORE, L'ORIZZONTALE RESTA CLAMPATO
	#
	# Il clamp e' **sui due assi del piano**, ed e' quello di prima: il punto
	# guardato non esce dal disco. La `y` invece **non e' piu' fissata** a
	# `ARENA_FLOOR`: su una torre di 80 m una camera ancorata a quota zero guarderebbe
	# il pavimento del piano 0 mentre il giocatore e' in cima, e la regola di
	# nascita fuori schermo (`ground_visible`, che misura l'impronta **di questo**
	# frustum) diventerebbe falsa su tutti i piani tranne il primo.
	#
	# ## PERCHE' `ARENA_FLOOR` RESTA E NON VIENE CANCELLATO
	#
	# Perche' `ARENA_FLOOR` **non e' diventato inutile**: e' il suolo del **mondo
	# piatto**, cioe' di quando `Game.floor_height == 0.0`. In quel mondo la quota
	# del giocatore e' `0.0` gia', quindi la riga sotto restituisce `ARENA_FLOOR` e
	# **identica** — e i criteri di inquadratura di m9 e m11, che leggono questa
	# costante e la confrontano con `ARENA_FLOOR`, restano veri senza che nessuno
	# li tocchi. Cancellarla avrebbe fatto fallire `_m11_raggio` perche' la
	# costante non esiste piu', non perche' la camera sbaglia.
	#
	# Il clamp verticale che **non** c'e': sul piano XZ si puo' finire fuori dal
	# muro, in verticale no perche' la torre e' chiusa sotto e sopra. Quindi non si
	# inventa un margine verticale che non ha nessun muro davanti.
	var suolo := focus.y if floor_height() > 0.0 else ARENA_FLOOR
	var out := Vector3(focus.x, suolo, focus.z)
	var flat := Vector2(out.x, out.z)
	var limit := maxf(0.0, arena_radius() - EDGE_MARGIN)
	if flat.length() > limit:
		out.x = flat.normalized().x * limit
		out.z = flat.normalized().y * limit
	return out

## L'altezza di un piano, **dal contratto**. `-1.0` se il campo non c'e': e' un
## difetto del vertice e non un mondo piatto, quindi non si finge.
func floor_height() -> float:
	var game := _contract()
	if game == null:
		return -1.0
	var v = game.get("floor_height")
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return -1.0

## Vedi la nota in `horde_renderer.gd`: l'autoload lo prendo dal campo `/root`,
## perche' questi script possono essere caricati con `load()` anche dai test in
## `--script`, dove l'identificatore nudo non e' garantito (piano 5.3).
func _contract() -> Node:
	if _contract_cache != null and is_instance_valid(_contract_cache):
		return _contract_cache
	var tree := get_tree()
	if tree != null:
		_contract_cache = tree.root.get_node_or_null("Game")
	return _contract_cache