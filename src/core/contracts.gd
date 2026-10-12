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

# --- Superficie di milestone 2 ----------------------------------------------------
#
# In m1 il contratto dichiarava i cinque metodi che le foglie si passavano. In m2
# la partita ha un inizio, una crescita e una fine, quindi **tre** foglie hanno da
# guardarsi negli occhi: -orda conta le uccisioni, -gameplay fa salire di livello
# il giocatore, -ui mostra entrambe.
#
# Quei nomi, fino a m2, se li erano concordati **leggendo il codice dell'altra**:
# -ui fa `Game.horde.wave` perche' -orda espone `wave` come campo e non come
# metodo `wave()`, perche' a un certo punto l'HUD lo leggeva gia'. Funziona, ma
# funziona per fortuna. Qui sotto e' **dichiarato**, con nomi e firme esatti: chi
# lo cambia non sta piu' implementando un contratto, sta cambiando il contratto,
# e il vertice deve saperlo.
#
# Queste voci **non** passano da `register_impl`: sono campi e metodi pubblici
# gia' esposti da un oggetto che il contratto contiene gia' (`Game.horde`,
# `Game.player`). Il contratto le dichiara, nessuno le registra.

## Superficie di m2, per proprietario. I valori sono i **nomi esatti** dei membri:
## `prop` e' il campo dati del contratto che contiene l'oggetto, `member` e' il
## membro su quell'oggetto, `kind` dice se e' un campo o un metodo.
const M2_SURFACE := [
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "wave", "kind": "field"},
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "wave_total", "kind": "method"},
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "wave_remaining", "kind": "method"},
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "wave_killed", "kind": "method"},
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "wave_bar_ratio", "kind": "method"},
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "wave_hp_scale", "kind": "method"},
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "run_state", "kind": "method"},
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "is_game_over", "kind": "method"},
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "restart_run", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "player", "member": "hp", "kind": "field"},
	{"owner": "terminal-gun-gameplay", "prop": "player", "member": "max_hp", "kind": "field"},
	{"owner": "terminal-gun-gameplay", "prop": "player", "member": "progression", "kind": "field"},
	{"owner": "terminal-gun-gameplay", "prop": "player", "member": "health_ratio", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "player", "member": "grant_xp", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "level", "kind": "field"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "xp", "kind": "field"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "kills", "kind": "field"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "offers", "kind": "field"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "progress", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "xp_to_next", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "pending", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "choose", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "apply", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "on_kill", "kind": "method"},
]

## L'oggetto di m2 che -gameplay registra. Non e' un nodo: e' il
## `RefCounted` di `src/player/progression.gd`, che sta dietro il giocatore.
## -ui lo raggiunge per contratto e non con `get_node("../..")`.
var progression = null

## La superficie di m2 che non e' ancora li'. Lista **vuota** = contratto rispettato.
##
## Non e' un controllo di stile: senza questo, un membro rinominato da una foglia
## fa fallire le altre tre con un `Invalid get index` che non dice quale delle
## quattro foglie ha rotto il contratto, e il messaggio arriva a un'onda di
## distanza dal rename. Con questo arriva subito e con il nome del membro.
func verify_m2_surface() -> Array[String]:
	var missing: Array[String] = []
	for row in M2_SURFACE:
		var holder = self.get(row["prop"])
		if holder == null or not is_instance_valid(holder):
			missing.append("%s.%s manca: il contratto non ha ancora '%s'" % [row["owner"], row["member"], row["prop"]])
			continue
		var v: Variant = holder.get(row["member"])
		if v == null:
			missing.append("%s.%s non c'e'" % [row["owner"], row["member"]])
		elif row["kind"] == "method" and not (holder.get(row["member"]) is Callable):
			missing.append("%s.%s non e' un metodo" % [row["owner"], row["member"]])
	return missing

# --- Superficie di milestone 3 ---------------------------------------------------
#
# **Non e' una API registrata.** `reseed` e `worst_bucket`/`grid_overflowed` sono
# metodi pubblici di `src/sim/horde.gd`, che -arena raggiunge attraverso il nodo
# `Horde` della scena vera, come gia' fa con `step()`, `damage_enemy()` e i tre
# campi di massa. Non passano da `register_impl` perche' nessuna delle due
# foglie li registra: sono la superficie **della simulazione**, non del contratto.
#
# Sono qui perche' m3 e' la prima onda che mette **due foglie sullo stesso
# oggetto**: `horde.gd` e' di -orda e `tests/test_arena.gd` e' di -arena, e il
# piano registra gia' il caso in cui due foglie hanno concordato un nome senza
# che nessuno lo decidesse (il campo `wave` letto per nome dall'HUD). Il rimedio
# non e' fidarsi, e' una riga scritta qui **prima** che le foglie lavorino.

## Dichiarato dal vertice il 2026-10-12, **congelato**: i due nomi qui sotto sono
## le uniche due firme che -orda scrive e -arena chiama. Cambiarne una durante
## l'onda significa fermare l'onda e tornare dal vertice.
##
##     horde.reseed(s)              # -orda la scrive, -arena la chiama
##     horde.worst_bucket()         # gia' esiste: il contratto ne dichiara il significato
##     horde.grid_overflowed()      # gia' esiste
##
## `reseed(s)` e' l'API che manca e che rende questa onda possibile:
##
##   - `horde.seed` (campo pubblico, `src/sim/horde.gd:92`) e' letto **una volta
##     sola**, dentro `_build()`, che gira nel `_ready()`. Sulla scena vera
##     l'orda la crea `arena_main.tscn`: nessun codice esterno puo' scrivere
##     `seed` prima che `_build()` giri. Il campo sembra la riproducibilita' e
##     sulla scena vera e' **irraggiungibile**: `seed = 0` sempre, `_rng.randomize()`
##     sempre. Il difetto di m3 e' questo, non la casualita'.
##   - `reseed(s)` rende la disposizione una **funzione del seme** anche quando
##     l'orda e' nata dentro una scena.
##
## Semantica congelata, in cinque punti. Ogni altro comportamento e' di -orda:
##
##   1. scrive il campo pubblico `seed` con `s`;
##   2. `s == 0` mantiene il significato dichiarato del campo: `randomize()`, cioe'
##      casuale a ogni avvio (non "seme zero");
##   3. con `s != 0` fissa `_rng` sul seme e **ripopola a `population`** con
##      **lo stesso percorso del primo frame** (`_populate`), non con un mestiere
##      diverso: due versioni della stessa disposizione sarebbero due numeri che
##      possono divergere, ed e' la lezione gia' scritta in `_populate`;
##   4. **non tocca** `run`, `wave`, `kills` ne `population`. E' un'operazione di
##      **disposizione**, non di stato di partita: `restart_run()` resta l'unica
##      cosa che rimette a posto la partita, e le due non vanno confuse;
##   5. ricostruisce la griglia, cosi' `worst_bucket()` e `grid_overflowed()`
##      parlano della disposizione appena scritta e non di quella precedente.
##
## Perche' il punto 5 e' nel contratto e non un dettaglio: senza, il chiamante
## misura la griglia della disposizione **precedente** e il numero che ne ricava
## e' vero ma non risponde alla domanda che ha fatto.

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

## -orda. **Indice** del nemico vivo piu vicino a `from` entro `radius`, oppure
## -1 se non c'e' nessuno. Restituisce l'indice, NON un nodo: la regola "nessun
## nodo per nemico" (piano sez. 5, regola 1) rende un Node3D qualcosa che non
## esiste da restituire. E l'indice e' esattamente quello che `damage_enemy` si
## aspetta, cosi si spara a un nemico senza trasformare la referenza in un nodo.
func nearest_enemy(from: Vector3, radius: float) -> int:
	if _impl.has("nearest_enemy"):
		return _impl["nearest_enemy"].call(from, radius) as int
	_missing("nearest_enemy", "terminal-gun-orda")
	return -1

## -orda. Applica `amount` di danno al nemico di indice `index` e gli somma
## `knockback` alla velocita'. Restituisce `true` se il nemico e' morto: e' l'unico
## modo per sapere di aver ucciso qualcosa senza aggiungere un segnale, e serve a
## -gameplay per l'XP.
##
## `knockback` e' un **impulso in m/s, gia' scalato dal chiamante, non
## normalizzato qui**: sommato cosi' alla velocita' del nemico, il suo modulo non
## dice gli metri spostati. Per verificare il criterio n. 4 ("knockback >= 0.3
## unita'") si simula un passo di tempo fisso e si misura la delta di posizione.
func damage_enemy(index: int, amount: float, knockback: Vector3) -> bool:
	if _impl.has("damage_enemy"):
		return _impl["damage_enemy"].call(index, amount, knockback) as bool
	_missing("damage_enemy", "terminal-gun-orda")
	return false

## -gameplay. Tira un proiettile da `pos` verso `dir` alla velocita' `speed`.
## Restituisce `true` se ha ottenuto uno slot dal pool, `false` se il pool era
## pieno. Come `nearest_enemy`, non restituisce un nodo: i proiettili non sono
## nodi, sono record come i nemici.
func spawn_projectile(pos: Vector3, dir: Vector3, speed: float) -> bool:
	if _impl.has("spawn_projectile"):
		return _impl["spawn_projectile"].call(pos, dir, speed) as bool
	_missing("spawn_projectile", "terminal-gun-gameplay")
	return false

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