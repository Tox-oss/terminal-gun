extends Camera3D
## La camera dell'arena: fissa in alto e indietro, segue il giocatore.
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
## Sotto questo orizzonte il gioco non c'e'.
const ARENA_FLOOR := 0.0
## Raggio di fallback se il contratto non e' ancora raggiungibile.
const FALLBACK_RADIUS := 28.0

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
	var out := Vector3(focus.x, ARENA_FLOOR, focus.z)
	var flat := Vector2(out.x, out.z)
	var limit := maxf(0.0, arena_radius() - EDGE_MARGIN)
	if flat.length() > limit:
		out.x = flat.normalized().x * limit
		out.z = flat.normalized().y * limit
	return out

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