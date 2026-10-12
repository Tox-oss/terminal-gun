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
## - m6: il pannello di `-ui` chiede il nome e l'effetto di un'offerta con
##   `offer_label(index)` e `offer_effect(index)`. Le due cifre non sono
##   ricopiate a mano: escono dal fattore che `apply()` usa davvero. Vedi la
##   nota lunga sulla tabella `UPGRADES`, che e' la scelta di questo file.

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

## ## I potenziamenti: nome e **quanto**, in un posto solo
##
## Qui dentro c'e' **una copia sola** di ogni numero che un potenziamento
## muove, ed e' `numero` (fattore moltiplicativo) o `somma` (incremento
## secco). Poi:
##
##   - `apply(id)` legge quella cifra e **calcola** sui campi del giocatore e
##     dell'arma;
##   - `offer_effect(index)` fa il conto sulla **stessa** cifra e la scrive in
##     una stringa per il pannello.
##
## Quindi se il fattore cambia, cambiano insieme il gioco e la carta che lo
## descrive, e non possono divergere: e' il difetto che m6 vuole chiuso (una
## carta che promette «+25%» mentre `apply()` fa `*= 1.30`).
##
## Cosa **non** e' in tabella: il campo che ogni potenziamento tocca. Quello
## sta nel `match` di `apply()`, che e' il posto dove viene usato: copiarlo
## qui sarebbe una seconda copia di una cosa che `apply()` racconta gia'
## leggibilmente riga per riga.
##
## `inversa: true` dice che `numero` moltiplica l'**intervallo** fra due colpi,
## mentre il nome della carta parla della grandezza che ne e' l'inverso, cioe'
## la cadenza. Per questo `0.85` sul campo `fire_interval` e' una cadenza
## `1 / 0.85 = +17,6%`, e la carta scrive «+18%»: quel numero e' calcolato, non
## scritto.
##
## Solo ASCII nelle stringhe: la console di Windows mangia gli accenti
## (piano §5.1) e questi finiscono in una Label, cioe' a schermo.
const UPGRADES := {
	"damage": {"label": "Danno", "numero": 1.25},
	"fire_rate": {"label": "Cadenza", "numero": 0.85, "inversa": true},
	"move_speed": {"label": "Corsa", "numero": 1.10},
	"projectile_speed": {"label": "Velocita' proiettile", "numero": 1.20},
	"knockback": {"label": "Spinta", "numero": 1.30},
	"pierce": {"label": "Perforante", "somma": 1.0, "unita": "nemico"},
	"vitality": {"label": "Vita massima", "somma": 20.0},
	"range": {"label": "Gittata", "numero": 1.25},
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
## fuori qui, una volta sola per livello e **solo se non ne sono rimaste**: e'
## `choose()` a svuotarle, quindi lo svuotamento non e' una scelta di stile ma la
## condizione che rilancia il ciclo (vedi la nota lunga sotto `choose`).
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

## Il nome leggibile dell'offerta numero `index`: «Danno», «Cadenza», «Spinta».
## Stringa vuota se l'indice non esiste.
##
## `index` e' relativo a **`offers` adesso**, non a un menu stabile, e la
## finestra di validita' di un indice finisce con la coda: `choose(index)`
## applica la scelta e **svuota** `offers`, quindi dopo una scelta ogni indice
## risponde stringa vuota e chi ha disegnato le carte deve rileggere `offers`
## prima di ridisegnarle. E' il contratto con `-ui`, ed e' la ragione per cui
## questo metodo legge `offers` invece di tenere una copia sua: se tenesse una
## copia, mostrerebbe tre nomi dove il click non applicherebbe piu' niente.
func offer_label(index: int) -> String:
	var def := _def_offerta(index)
	return str(def["label"]) if not def.is_empty() else ""

## Quanto fa l'offerta numero `index`, per esempio «+25%» o «+1 nemico».
## Stringa vuota se l'indice non esiste.
##
## Il numero qui dentro e' **calcolato sul fattore** che `apply()` usa, mai
## riscritto: cambio la tabella e cambia qui dentro insieme al gioco. Se
## `apply()` facesse `*= 1.30` e la carta dicesse «+25%», questa funzione
## continuerebbe a dire «+30%» e sarebbe lei a dare la notizia sbagliata
## all'interfaccia, che e' il difetto che m6 chiude.
##
## Le due forme sono due **nature** di potenziamento, non due stili: `somma` e'
## un incremento secco («+20» di vita) e si scrive per intero, `numero` e' un
## fattore e si scrive in percentuale arrotondata all'intero («+25%»).
func offer_effect(index: int) -> String:
	var def := _def_offerta(index)
	if def.is_empty():
		return ""
	if def.has("somma"):
		var piatto := "+%d" % int(roundf(float(def["somma"])))
		var unita := str(def.get("unita", ""))
		return "%s %s" % [piatto, unita] if unita != "" else piatto
	return "+%d%%" % int(roundf(_crescita(def) * 100.0))

## Applica la scelta numero `index` e **scarta le altre offerte**. Restituisce
## l'id applicato, o "" se l'indice non esiste.
##
## ## Una scelta sola, e le altre due si buttano
##
## La regola e' **dell'utente**, non dedotta dal codice (2026-10-13): si sale di
## livello, si sceglie **uno**, gli altri due si buttano, e al livello
## successivo ne arrivano altri tre. «Me li fa scegliere tutti e 3, non solo 1»
## era il difetto che m6 chiude: se ne prendi tre non e' una scelta, e' un
## malloppo. Il commento che stava qui prima prometteva il contrario di quello
## che il criterio n. 3 chiede, ed e' stato quello che ha fatto scrivere la
## specifica sbagliata al vertice.
##
## Il pannello di `-ui` **non cambia**: chiama `choose(i)` una volta sola e fa
## esattamente quello che faceva. Cambia solo la semantica di questa funzione.
##
## ## Perche' lo svuotamento e' la condizione che fa tornare il ciclo
##
## Non e' una questione di stile, e' il meccanismo: `add_xp` rulla le offerte
## solo se la coda e' vuota (`if gained > 0 and offers.is_empty()`). Tenere le
## due pending fa fallire quella riga al livello dopo, e il ciclo dei livelli si
## ferma: il giocatore sale di livello e non gli viene piu' niente da scegliere.
## Quindi qui si svuota **la stessa lista** (`clear()`, non `offers = []`), e non
## si svuota altrove: se un domani un altro pezzo riempiisse `offers` senza
## passare da `roll()`, il ciclo smetterebbe di rullare senza che nessuna
## asserzione se ne accorgesse.
func choose(index: int) -> String:
	if index < 0 or index >= offers.size():
		return ""
	var id: String = offers[index]
	offers.clear()
	apply(id)
	return id

## Applica un potenziamento dal suo id.
##
## ## Perche' il numero arriva dalla tabella e non e' scritto qui
##
## Il `match` sotto sceglie **il campo** da toccare; il **quanto** lo legge da
## `UPGRADES` con `_numero_di(id)`. Quella e' l'unica copia del fattore in tutto
## il progetto: `offer_effect()` fa il conto sulla stessa cifra. Se qui ci fosse
## un `*= 1.25` scritto a mano, il progetto avrebbe due numeri e uno dei due
## mentirebbe appena l'altro cambia.
func apply(id: String) -> bool:
	if player == null:
		return false
	var def := _def(id)
	if def.is_empty():
		return false
	var w = player.weapon
	var needs_weapon := id in ["damage", "fire_rate", "projectile_speed", "knockback", "pierce", "range"]
	if needs_weapon and w == null:
		return false
	# Zero non e' un potenziamento: e' anche il modo in cui una voce di tabella
	# senza numero arriva qui, e in entrambi i casi `apply()` non fa niente.
	var n := _numero_di(def)
	if n == 0.0:
		return false
	var fatto := false
	match id:
		"damage":
			w.damage *= n
			fatto = true
		"fire_rate":
			w.fire_interval *= n
			fatto = true
		"move_speed":
			player.move_speed *= n
			fatto = true
		"projectile_speed":
			w.projectile_speed *= n
			fatto = true
		"knockback":
			w.knockback *= n
			fatto = true
		"pierce":
			w.pierce = mini(int(w.pierce) + int(roundf(n)), ProjectileScript.MAX_PIERCE)
			fatto = true
		"vitality":
			player.max_hp += n
			# Rianimare un morto non e' un potenziamento. `player.heal()` ha gia'
			# questa regola scritta ("rianimare un morto e' un bug, non una
			# feature") e un upgrade che la scavalca la rende falsa: chi applica
			# potenziamenti a menu aperto durante il game_over si ritroverebbe in
			# piedi senza aver premuto il tasto del restart. Con la vita a zero la
			# soglia di sopravvivenza sale e basta.
			var vita: float = player.hp
			if vita > 0.0:
				player.hp = vita + n
			fatto = true
		"range":
			w.projectile_life *= n
			fatto = true
	if not fatto:
		return false
	upgrade_applied.emit(id)
	return true

# --- Interno: la tabella letta da due punti solo --------------------------------

## La voce di tabella dell'id, o un dizionario vuoto se l'id non esiste. Vuoto e
## non `null`: i due metodi pubblici restituiscono una **stringa vuota** quando
## l'indice non esiste, e questo e' il posto dove la domanda diventa una
## risposta vuota.
func _def(id: String) -> Dictionary:
	var def: Variant = UPGRADES.get(id, null)
	return def if def is Dictionary else {}

## La voce di tabella dell'offerta numero `index`, cioe' dell'id che `offers`
## tiene in quella posizione **adesso**.
func _def_offerta(index: int) -> Dictionary:
	if index < 0 or index >= offers.size():
		return {}
	return _def(str(offers[index]))

## La cifra che muove il potenziamento: il fattore o l'incremento secco. `0.0`
## quando la voce non ha nessuno dei due, cioe' quando la voce non e' un
## potenziamento e `apply()` non deve fare niente.
func _numero_di(def: Dictionary) -> float:
	if def.has("somma"):
		return float(def["somma"])
	if def.has("numero"):
		return float(def["numero"])
	return 0.0

## Quanto cresce, in frazione, la grandezza che la carta nomina.
##
## Il caso `inversa` e' quello della cadenza: il fattore moltiplica l'intervallo
## fra due colpi e la carta parla del suo inverso, quindi cresce di `1 / n - 1`.
func _crescita(def: Dictionary) -> float:
	var n := _numero_di(def)
	return (1.0 / n - 1.0) if bool(def.get("inversa", false)) else (n - 1.0)