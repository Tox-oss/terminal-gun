extends RefCounted
## XP, curva di livello e i tre potenziamenti da scegliere. -gameplay.
##
## Non e' un nodo e non ha bisogno di esserlo: e' un oggetto che il giocatore
## tiene e a cui l'interfaccia chiede "quanto manca al livello successivo?" e
## "cosa mi offri?". Vive dietro il giocatore, non nella scena, perche' nessuno
## deve cercarlo con `get_node("../..")` (piano §5, regola 3).
##
## La curva e' lineare e volutamente ripida: in un bullet heaven il livello deve
## arrivare spesso, perche' e' il momento in cui il giocatore sceglie e smette
## di correre per un attimo.
##
## NOTE PER IL VERTICE
## - L'uccisione la dice `Game.damage_enemy(index, amount, knockback) -> bool`
##   (piano §5.2): il `true` e' l'unico modo onesto di sapere che un nemico e'
##   morto, e senza quell'indice non si sa *chi* e' morto. Il percorso e'
##   `projectile_pool._collide` -> `weapon_base.on_kill()` ->
##   `player.on_enemy_killed()` -> `on_kill(1)` qui sotto. Non esiste piu' il
##   ponte che contava la differenza di `horde.count`: quello non sapeva chi era
##   morto e regalava XP al primo frame dopo qualunque `clear()`.
## - Il danno per uccisione e' un campo (`xp_per_kill`), non una voce del
##   contratto: lo chiama chi scopre l'uccisione.
## - I potenziamenti sono una tabella di id, non un elenco di nodi: applicarne
##   uno e' scrivere sui campi dell'arma e del giocatore, zero istanze nuove.

const ProjectileScript := preload("res://src/weapons/projectile.gd")

## XP per nemico ucciso. Dieci uccisioni fanno 30 XP: oltre la prima soglia
## (8) e dentro la seconda (14), quindi "10 uccisioni -> almeno un livello" ha
## margine e non dipende dalla curva.
const XP_PER_KILL := 3.0
## XP che mancano al livello 2.
const XP_BASE := 8.0
## Quanto sale la soglia a ogni livello.
const XP_STEP := 6.0
## Quante scelte offre un livello. Tre: abbastanza per essere una decisione,
## non abbastanza per essere un menu.
const OFFERS := 3
## Quanti potenziamenti diversi esistono: con 8, i tre offerti non possono essere
## sempre gli stessi tre.
const UPGRADE_IDS := ["damage", "fire_rate", "move_speed", "projectile_speed",
	"knockback", "pierce", "vitality", "range"]

## Testo per l'interfaccia. Solo ASCII: la console di Windows mangia gli accenti
## (piano §5.1) e questi finiscono anche nelle stampe di debug.
const LABELS := {
	"damage": "Danno +25%",
	"fire_rate": "Cadenza +15%",
	"move_speed": "Velocita' +10%",
	"projectile_speed": "Proiettili piu' veloci +20%",
	"knockback": "Spinta +30%",
	"pierce": "Attraversa 1 nemico in piu'",
	"vitality": "Vita massima +20",
	"range": "Gittata +25%",
}

## sale a ogni livello. La UI si aggancia qui per il riquadro di scelta.
signal leveled_up(level: int)
## Le tre scelte sono pronte: `ids` e' la lista degli id offerti.
signal offers_ready(ids: Array)
## Un potenziamento e' stato applicato: `id` e' quello scelto.
signal upgrade_applied(id: String)

## XP non ancora speso. `level` parte da 1.
var xp := 0.0
## XP totale mai speso, cioe' **tutto** quello che e' entrato, anche quello che il
## salire di livello ha poi consumato. Serve a chi vuole sapere quanto ha reso un
## colpo senza dover sommare le soglie, e al test che vuole dire "questa XP e'
## arrivata da dieci `damage_enemy` che hanno risposto `true`": `xp` da solo non
## basta, perche' a ogni livello lo rispedisce indietro.
var xp_earned := 0.0
var level := 1
## Nemici uccisi contati qui: solo quelli che hanno prodotto XP.
var kills := 0
## XP per uccisione. Un campo, non una costante: cosi' un'onda piu' difficile
## puo' alzarlo senza toccare la curva.
var xp_per_kill := XP_PER_KILL
## Le scelte pending, in ordine. Vuota = nessun livello da spendere.
var offers: Array = []
## Seme dei lanci. Dichiarato perche' un test che fissa il seme ottiene sempre
## le stesse offerte: nessun test deve dipendere dalla fortuna.
var rng_seed := 20240501
## Il giocatore che i potenziamenti modificano. Senza tipo: `progression.gd` non
## deve niente a `player.gd`, altrimenti i due si preloaded a vicenda e GDScript
## chiama quello un errore di riferimento circolare.
var player = null

var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.seed = rng_seed

func bind(owner_player) -> void:
	player = owner_player

## XP necessari per passare da `at_level` a `at_level + 1`.
func xp_to_next(at_level: int = -1) -> float:
	var l := level if at_level < 0 else at_level
	return XP_BASE + XP_STEP * float(maxi(l - 1, 0))

## Quanto del livello corrente e' fatto, da 0 a 1. Per l'interfaccia.
func progress() -> float:
	var need := xp_to_next()
	if need <= 0.0:
		return 1.0
	return clampf(xp / need, 0.0, 1.0)

## `kills` uccisioni, con XP annesso. E' la via normale: chi sa che un nemico
## e' morto chiama questo e non `add_xp` a mano.
func on_kill(n: int = 1) -> int:
	if n <= 0:
		return 0
	kills += n
	return add_xp(xp_per_kill * float(n))

## Aggiunge XP e restituisce quanti livelli sono saliti. Le offerte le tira
## fuori qui, una volta sola per livello e solo se non ne sono rimaste.
func add_xp(amount: float) -> int:
	if amount <= 0.0:
		return 0
	xp += amount
	xp_earned += amount
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained += 1
		leveled_up.emit(level)
	if gained > 0 and offers.is_empty():
		roll()
	return gained

## Tira `OFFERS` potenziamenti diversi e li tiene in `offers`.
func roll() -> Array:
	offers = []
	var remaining := UPGRADE_IDS.duplicate()
	_rng.seed = rng_seed + level * 977 + kills
	while offers.size() < OFFERS and not remaining.is_empty():
		var i := _rng.randi_range(0, remaining.size() - 1)
		offers.append(remaining[i])
		remaining.remove_at(i)
	offers_ready.emit(offers)
	return offers

## Quante scelte non ancora prese.
func pending() -> int:
	return offers.size()

## Applica la scelta numero `index` e la toglie dalle pending. Restituisce l'id
## applicato, o "" se l'indice non esiste. Le altre pending restano: si
## applicano una alla volta, sempre con lo stesso indice.
func choose(index: int) -> String:
	if index < 0 or index >= offers.size():
		return ""
	var id: String = offers[index]
	offers.remove_at(index)
	apply(id)
	return id

## Applica un potenziamento dal suo id.
func apply(id: String) -> bool:
	if player == null:
		return false
	var w = player.weapon
	var needs_weapon := id in ["damage", "fire_rate", "projectile_speed", "knockback", "pierce", "range"]
	if needs_weapon and w == null:
		return false
	match id:
		"damage":
			w.damage *= 1.25
		"fire_rate":
			w.fire_interval *= 0.85
		"move_speed":
			player.move_speed *= 1.10
		"projectile_speed":
			w.projectile_speed *= 1.20
		"knockback":
			w.knockback *= 1.30
		"pierce":
			w.pierce = mini(int(w.pierce) + 1, ProjectileScript.MAX_PIERCE)
		"vitality":
			player.max_hp += 20.0
			player.hp += 20.0
		"range":
			w.projectile_life *= 1.25
		_:
			return false
	upgrade_applied.emit(id)
	return true