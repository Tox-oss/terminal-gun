extends Node
## Contratto di interfecce di terminal-gun. Autoload `Game`.
##
## REGOLA AUREA: il contratto **dichiara**, le implementazioni **si registrano**.
##
## DATI — nel proprio `_ready()`, una volta sola:
##     Game.player = self
##     Game.horde = self
##     Game.arena_radius = 28.0
##
## METODI — nel proprio `_ready()`, una volta sola:
##     Game.register_impl("nearest_enemy", self._nearest_enemy)
##     Game.register_impl("damage_enemy", self._damage_enemy)
##     Game.register_impl("spawn_projectile", self._spawn_projectile)
##     Game.register_impl("random_spawn_point", self._random_spawn_point)
##     Game.register_impl("player_position", self._player_position)
##
## ⚠ Perché non `Game.nearest_enemy = self._nearest_enemy`: GDScript lo RIFIUTA.
## Un nome che è già un `func` dello script non è assegnabile ("Invalid assignment
## of property or key ... with value of type 'Callable'"). Quindi la registrazione
## dei metodi passa da `register_impl`, che è la sola forma che funziona.
## Chiamare invece i metodi col nome normale: `Game.nearest_enemy(pos, 12.0)`,
## non `Game.nearest_enemy.call(pos, 12.0)`.
##
## Nessuna foglia modifica questo file. Se serve un campo o un metodo nuovo,
## non si anticipa qui: si chiede al vertice, che decide e aggiorna questo file.
##
## Sotto il contratto valgono tre regole (piano §5):
##   1. nessun nodo per nemico: l'orda tiene `count`/`transforms`/`colors`;
##   2. nessuna allocazione nel ciclo di gioco: capacità fissa assegnata all'avvio;
##   3. nessuna dipendenza circolare tra foglie: ciò che l'API non espone si chiede al vertice.
##
## Le stringhe che finiscono a schermo sono solo ASCII, accenti compresi. Non è
## pignoleria: la console di Windows e il pipe di `OS.execute` rimangono in
## codepage e un accento diventa spazzatura illeggibile proprio nel messaggio che
## serve a capire un fallimento. I commenti invece possono tenerli.

## I metodi che il contratto dichiara. Serve a `register_impl` per rifiutare un
## nome che non esiste: una foglia che registra una API inesistente deve
## fallire subito e rumorosamente, non diventare una chiamata che non porta da
## nessuna parte fra tre settimane.
const API := [
	"nearest_enemy",
	"damage_enemy",
	"spawn_projectile",
	"random_spawn_point",
	"player_position",
]

# --- Dati esposti dalle foglie -------------------------------------------------

## -gameplay. Il nodo del giocatore. Non nodo per nemico: il giocatore è uno solo.
var player: Node3D

## -orda (src/sim/horde.gd). I nemici vivi sono **record in array**, non nodi:
## horde.count / horde.transforms / horde.colors.
var horde: Node

## -arena. Raggio utile dell'arena, in metri. Dato, non calcolato: nessuno lo
## deve derivare dalla geometria della scena per evitare dipendenze circolari.
var arena_radius: float = 28.0

# --- Registrazione -------------------------------------------------------------

## Implementazioni dei metodi, per nome di API. Stringhe perché GDScript non
## permette di riassegnare un `func` (vedi avvertenza in testa al file).
var _impl: Dictionary = {}

## Registra l'implementazione di un metodo del contratto.
##
##     Game.register_impl("nearest_enemy", self._nearest_enemy)   # Callable
##     Game.register_impl("nearest_enemy", self)                   # metodo omonimo
##
## La seconda forma è più corta: se `impl` è un oggetto, si assume il metodo
## con lo stesso nome della API.
func register_impl(api: String, impl: Variant) -> void:
	if not API.has(api):
		push_error("Game.register_impl: \"%s\" non e' un'API del contratto (le note: %s). Si chiede al vertice." % [api, ", ".join(API)])
		return
	var callable: Callable
	if impl is Callable:
		callable = impl
	elif impl is Object:
		callable = Callable(impl, api)
	else:
		push_error("Game.register_impl(\"%s\"): ci si aspetta una Callable o un oggetto, ricevuto %s" % [api, type_string(typeof(impl))])
		return
	if not callable.is_valid():
		push_error("Game.register_impl(\"%s\"): l'oggetto non ha il metodo %s" % [api, api])
		return
	_impl[api] = callable
	print("Game: %s implementato da %s" % [api, callable.get_object().get_class()])

## Un'API è registrata? Per i test e per il debug. Le foglie non ne hanno bisogno.
func has_impl(api: String) -> bool:
	return _impl.has(api)

# --- API dichiarate ------------------------------------------------------------
#
# Finché una foglia non registra la propria implementazione, il metodo resta
# uno stub: restituisce un valore neutro e avvisa una volta sola. Non è un
# fallback deliberato, è un rumore esplicito: un test che lo chiama deve
# fallire con un messaggio che dice chi deve registrarla.

## -orda. Nemico vivo più vicino a `from` entro `radius`, o null se non ce n'è.
func nearest_enemy(from: Vector3, radius: float) -> Node3D:
	if _impl.has("nearest_enemy"):
		return _impl["nearest_enemy"].call(from, radius) as Node3D
	_missing("nearest_enemy", "terminal-gun-orda")
	return null

## -orda. Applica `amount` di danno al nemico di indice `index` e gli impartisce
## `knockback` (spinta già calcolata e normalizzata dal chiamante).
func damage_enemy(index: int, amount: float, knockback: Vector3) -> void:
	if _impl.has("damage_enemy"):
		_impl["damage_enemy"].call(index, amount, knockback)
		return
	_missing("damage_enemy", "terminal-gun-orda")

## -gameplay. Crea un proiettile che viaggia da `pos` in `dir` a `speed`.
func spawn_projectile(pos: Vector3, dir: Vector3, speed: float) -> Node3D:
	if _impl.has("spawn_projectile"):
		return _impl["spawn_projectile"].call(pos, dir, speed) as Node3D
	_missing("spawn_projectile", "terminal-gun-gameplay")
	return null

## -orda. Punto di arrivo casuale dentro l'arena, a una distanza comoda dal
## giocatore. Non va mai restituito come origine: Vector3.ZERO è ambiguo, è
## anche sotto il giocatore, quindi è un segnale di "non implementato".
func random_spawn_point() -> Vector3:
	if _impl.has("random_spawn_point"):
		return _impl["random_spawn_point"].call() as Vector3
	_missing("random_spawn_point", "terminal-gun-orda")
	return Vector3.ZERO

## -orda/-gameplay. Posizione corrente del giocatore.
func player_position() -> Vector3:
	if _impl.has("player_position"):
		return _impl["player_position"].call() as Vector3
	_missing("player_position", "terminal-gun-gameplay")
	return Vector3.ZERO

# --- Interno -------------------------------------------------------------------

## Avvisa una volta sola per metodo, dicendo chi deve registrarlo. Lo spam di
## warning ogni frame nasconderebbe il rumore utile.
var _warned: Dictionary = {}

func _missing(api: String, owner_agent: String) -> void:
	if _warned.has(api):
		return
	_warned[api] = true
	push_warning("Game.%s() non e' ancora registrata: tocca a %s farlo con Game.register_impl(\"%s\", self) nel proprio _ready()." % [api, owner_agent, api])