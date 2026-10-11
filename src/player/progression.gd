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

## Nuova partita: la progressione torna esattamente all'avvio.
##
## La chiama `player.reset_run()`, e serve al **restart** del criterio n. 4 di m2.
## Senza questa funzione un restart azzererebbe l'onda e riderebbe il giocatore con
## il livello 7 e la vita potenziata: la partita ripartirebbe gia' vinta, che e'
## l'unico modo che un restart non sia un restart.
##
## Non crea e non libera niente: sono cinque numeri e un array, quindi nessun nodo
## duplicato e nessuna allocazione (la coda delle offerte si svuota sulla stessa
## lista che chi la guarda, non con una nuova).
func reset() -> void:
	xp = 0.0
	xp_earned = 0.0
	level = 1
	kills = 0
	offers.clear()
	_rng.seed = rng_seed

## XP necessari per passare da `at_level` a `at_level + 1`.
func xp_to_next(at_level: int = -1) -> float:
	var l := level if at_level < 0 else at_level
	return XP_BASE + XP_STEP * float(maxi(l - 1, 0))

## Quanto del livello corrente e' fatto, da 0 a 1. Per l'interfaccia.
##
## ## Perche' la guardia sui numeri non finiti sta qui e non solo nella HUD
##
## `clampf(NAN, 0.0, 1.0)` restituisce `NAN`, non 0: ogni confronto con `NaN` e'
## falso, quindi il clamp non lo ferma e la barra che ne nasce non si vede. Il
## criterio n. 2 di m2 chiede che la barra XP sia **sempre** in `[0, next]` e
## mai `NaN`/`INF`, e la fonte dei numeri e' questa: se qui dentro non c'e' la
## guardia, il difetto arriva alla HUD e la HUD lo deve nascondere da sola, cioe'
## due foglie che si difendono dalla stessa cosa invece di una sola che la ferma
## alla radice. `tests/test_ui.gd` prova comunque la HUD con `NAN` e `INF`
## dalla porta: quello resta giusto, e non rende di piu' necessaria la guardia
## qui sotto.
func progress() -> float:
	if not is_finite(xp) or xp < 0.0:
		return 0.0
	var need := xp_to_next()
	if not is_finite(need) or need <= 0.0:
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
##
## `INF` e `NaN` non vengono accettati: `NaN <= 0.0` e' falso, quindi senza la
## guardia un `NaN` entrerebbe nell'XP, il ciclo dei livelli non partirebbe
## (`NaN >= soglia` e' falso) e `xp` resterebbe `NaN` **senza che nessuna
## asserzione se ne accorga**: il criterio n. 2 di m2 chiede che la barra sia
## sempre un numero. Un numero non finito non e' XP e viene respinto come uno
## zero.
func add_xp(amount: float) -> int:
	if not is_finite(amount) or amount <= 0.0:
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
			# Rianimare un morto non e' un potenziamento. `player.heal()` ha gia'
			# questa regola scritta ("rianimare un morto e' un bug, non una
			# feature") e un upgrade che la scavalca la rende falsa: chi applica
			# potenziamenti a menu aperto durante il game_over si ritroverebbe in
			# piedi senza aver premuto il tasto del restart. Con la vita a zero la
			# soglia di sopravvivenza sale e basta.
			var vita: float = player.hp
			if vita > 0.0:
				player.hp = vita + 20.0
		"range":
			w.projectile_life *= 1.25
		_:
			return false
	upgrade_applied.emit(id)
	return true