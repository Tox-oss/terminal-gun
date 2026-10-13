extends RefCounted
## Un nemico di terminal-gun: **i dati e il comportamento di un singolo nemico,
## ma non un nodo**.
##
## E' un record in un array parallelo di array compattati, non un oggetto di
## scena. Nessun `Node3D`, nessun `queue_free()`, nessun nodo per nemico: il
## criterio della milestone e' `node_count < 120` con `horde.count == 200`, e un
## nodo per nemico lo renderebbe impossibile da solo.
##
## Perche' `static var` e non `const`: in Godot 4.7 un `PackedFloat32Array([...])`
## NON e' un'espressione costante, quindi `const` su una tabella di questo tipo
## non compila ("Assigned value for constant ... isn't a constant expression").
## Le tabelle sono lette solo, quindi `static var` e' la forma giusta.
##
## `step()` scrive dentro gli array passati e non restituisce nulla: nel ciclo di
## gioco non viene allocato niente, perche' non viene creato niente.

## Le quattro specie. L'indice nel record e' questo intero (`kinds[i]`).
const RUNNER := 0
const GRUNT := 1
const BRUTE := 2
const BOSS := 3
const KIND_COUNT := 4
const KIND_NAMES := ["runner", "grunt", "brute", "boss"]

# Tabelle per specie, allineate 1:1 con KIND_NAMES. Indexate da `kind`.
static var HP_MAX := PackedFloat32Array([14.0, 34.0, 110.0, 900.0])
static var SPEED := PackedFloat32Array([6.6, 4.0, 2.3, 1.7])
static var RADIUS := PackedFloat32Array([0.45, 0.60, 1.00, 1.90])
static var MASS := PackedFloat32Array([0.7, 1.0, 2.6, 6.0])
## Quanto knockback il nemico si mangia: 0 = tutto, 0.9 = quasi immobile.
static var KNOCKBACK_RESIST := PackedFloat32Array([0.0, 0.20, 0.55, 0.90])
## Tinta per specie: e' quello che arena passa al MultiMesh, cosi' l'arena non
## deve sapere cosa sia un nemico.
static var COLOR := PackedColorArray([
	Color(0.98, 0.35, 0.30),
	Color(0.86, 0.20, 0.55),
	Color(0.55, 0.25, 0.88),
	Color(1.00, 0.76, 0.15),
])

## Oltre' questa distanza dal bersaglio il nemico rallenta (arrivo).
const ARRIVE_RADIUS := 3.0
## Costante di tempo dell'accelerazione: 1/ACCEL secondi per cambiare direzione.
const ACCEL := 8.0
## Tetto di velocita', cosi' un knockback non lancia un nemico fuori dal mondo.
const SPEED_MAX := 18.0
## Spinta verso il centro quando il nemico sborda l'arena.
const EDGE_PUSH := 3.0

# --- Il morso: cosa fa il nemico al giocatore (milestone 7) -------------------
#
# ## Tre costanti e nessuna tabella
#
# Il criterio n. 6 della milestone 7 chiede che un numero di danno non viva in
# due posti: quindi qui sotto ci sono **tre costanti e nessuna tabella**. Il
# danno e la cadenza di ogni specie escono da `MASS`, che e' gia' la tabella
# del progetto e gia' governa la separazione (`SEPARATION_FORCE / mass_of(kind)`
# in `horde.gd::_separation`). Una cosa sola dice "quanto e' pesante", e quella
# cosa governa sia quanto il nemico ti scarta dal tuo vicino, sia quanto ti
# morde: e' la stessa fisica, scritta una volta sola.
#
#     morso(specie)   = TOUCH_DAMAGE_BASE * massa / massa(runner)
#     periodo(specie) = TOUCH_PERIOD      * sqrt(massa / massa(runner))
#     dps(specie)     = morso / periodo   = base/periodo * sqrt(massa/runner)
#
# Il `sqrt` sul periodo e' quello che tiene il capo in gioco: senza, il boss
# (massa 6.0, otto volte e mezzo il runner) morderebbe 8,6 volte tanto e 8,6
# volte spesso, cioe' 74 volte la dps di un runner. Con il `sqrt` il capo
# mordere forte e piano, che e' quello che ci si aspetta da una cosa pesante.
#
# ## La portata del morso, e da dove viene
#
# `TOUCH_REACH` e' **misurato**, non scelto. Sull'orda a regime con un giocatore
# fermo al centro, passo fisso 1/60 s, 30 s di misura (i numeri sono quelli che
# escono da `tests/test_orda.gd`, sezione 11, e sono riprodotti a ogni lanzo):
#
# | vivi | a portata di morso | distanza minima mai vista |
# |---|---|---|
# | 25 (onda 1) | 5-6, cioe' il **20-24%** | 0.14 m |
# | 75 (curva a meta') | 10, il 13% | — |
# | 200 (onda 8) | 20, il **10%** (il 51% e' oltre 6 m) | 0.04 m |
#
# Con `1.2 m` l'onda 1 mette in contatto poco piu' di un quinto della folla: il
# nemico che ti morde deve **arrivarti addosso**, non colpirti da tre metri. La
# riga da 200 dice anche perche' il contatto **non** cresce con la popolazione: a
# 200 vivi meta' dell'orda non arriva nemmeno a sei metri, perche' l'anello
# intorno al giocatore e' saturo. Il danno che arriva addosso cresce quindi
# ~3.3 volte dall'onda 1 all'onda 8 e non 8.
const TOUCH_REACH := 1.2

## Danno di un morso di runner, e da dove viene questo numero.
##
## Il primo tentativo era **2.0** ed era **troppo forte**: misurava 6.40 s da fermo
## al centro dell'onda 1, cioe' un giocatore che sbaglia un attimo muore prima
## di capire cosa e' successo. Il numero e' stato abbassato a 1.6 e rimisurato.
## Il tetto alla cadenza (`TOUCH_INTERVAL` in `horde.gd`) e' stato messo **prima**
## di questo ritocco ed e' quello che tiene la curva: vedi la sezione "il morso"
## di `horde.gd`, che dichiara anche il primo tentativo sbagliato.
const TOUCH_DAMAGE_BASE := 1.6

## Secondi fra due morsi della stessa specie, per il runner. Il resto lo
## ricava da `MASS` con la radice quadrata (vedi sopra).
const TOUCH_PERIOD := 1.0

static func clamp_kind(kind: int) -> int:
	return clampi(kind, 0, KIND_COUNT - 1)

static func hp_of(kind: int) -> float:
	return HP_MAX[clamp_kind(kind)]

static func speed_of(kind: int) -> float:
	return SPEED[clamp_kind(kind)]

static func radius_of(kind: int) -> float:
	return RADIUS[clamp_kind(kind)]

static func mass_of(kind: int) -> float:
	return MASS[clamp_kind(kind)]

static func color_of(kind: int) -> Color:
	return COLOR[clamp_kind(kind)]

static func knockback_resist_of(kind: int) -> float:
	return KNOCKBACK_RESIST[clamp_kind(kind)]

## Quanto toglie hp un morso di questa specie. Vedi la sezione "il morso" in
## testa al file: una sola formula sulla tabella `MASS`, nessun numero scritto
## due volte.
static func touch_damage_of(kind: int) -> float:
	var k := clamp_kind(kind)
	return TOUCH_DAMAGE_BASE * MASS[k] / MASS[RUNNER]

## Quanti secondi devono passare fra due morsi della stessa specie. Stessa
## tabella, radice quadrata: piu' pesante significa piu' lento a mordere.
static func touch_period_of(kind: int) -> float:
	var k := clamp_kind(kind)
	return TOUCH_PERIOD * sqrt(MASS[k] / MASS[RUNNER])

## Un passo di simulazione del nemico `i`.
##
## `push` e' la spinta di separazione calcolata dalla griglia (l'horda la passa
## gia' pronta: qui dentro non si sa niente di griglie ne' di query).
##
## `has_target` dice se il bersaglio e' un **giocatore** e non un punto vuoto.
## Senza di esso nessun nemico morde: il morso e' l'unica azione che questa
## simulazione fa sul giocatore, e contro un bersaglio che non c'e' non ha
## senso accenderla. E' anche il motivo per cui nessun test che mette l'orda da
## sola si trova un morso senza avergli dato un giocatore.
##
## `bite_timers` e `bites` sono due array paralleli in scrittura: il primo
## tiene da quanto tempo questa specie e' in contatto, il secondo dice "questo
## passo morde" (1) o no (0). **La decisione del morso e' qui dentro**, dove
## stanno le specie; a chi tocca applicarlo (`horde.gd`) spetta solo il tetto
## dei morderci contemporanei e la chiamata al contratto.
##
## Tutti gli array sono paralleli e lunghi `count`: scrive solo `positions[i]`,
## `velocities[i]`, `timers[i]`, `bite_timers[i]` e `bites[i]`. Nessuna
## allocazione.
static func step(i: int, delta: float, target: Vector3, push: Vector3,
		positions: PackedVector3Array, velocities: PackedVector3Array,
		timers: PackedFloat32Array, kinds: PackedInt32Array,
		arena_radius: float, bite_timers: PackedFloat32Array,
		bites: PackedInt32Array, has_target: bool) -> void:
	var kind := clamp_kind(kinds[i])
	var pos := positions[i]
	var to_target := target - pos
	to_target.y = 0.0
	var dist := to_target.length()
	var dir := Vector3.ZERO
	if dist > 0.001:
		dir = to_target / dist

	# Arrivo: rallenta vicino al bersaglio, altrimenti gli si infila addosso e
	# i 200 nemici diventano un solo punto.
	var arrive := clampf(dist / ARRIVE_RADIUS, 0.0, 1.0)
	var wanted := dir * SPEED[kind] * arrive + push

	var vel := velocities[i]
	vel += (wanted - vel) * minf(1.0, delta * ACCEL)
	vel.y = 0.0
	vel = vel.limit_length(SPEED_MAX)

	# Banda elastica sul bordo dell'arena: il nemico puo' sbordare di qualche
	# decina (knockback), non deve poter sparire.
	var flat := Vector2(pos.x, pos.z)
	var r := flat.length()
	var limit := maxf(1.0, arena_radius - RADIUS[kind])
	if r > limit:
		# `flat` e' un Vector2 perche' la distanza dal centro si calcola sul piano:
		# la spinta pero' va su `vel`, che e' un Vector3, quindi il verso va
		# rimontato con y = 0 invece che promuoverlo (promuovere aggiungerebbe
		# anche una componente verticale, che qui non esiste).
		vel -= Vector3(flat.x, 0.0, flat.y) / maxf(r, 0.001) * (r - limit) * EDGE_PUSH

	timers[i] = maxf(0.0, timers[i] - delta)
	# Il morso riparte da zero quando il contatto si perde: una specie deve
	# restare addosso per un periodo **intero** prima di mordere, altrimenti un
	# nemico che sbatte sul bordo del contatto azzererebbe il timer ogni passo e
	# non morderebbe mai. E il prezzo e' dichiarato: chi entra ed esce spesso
	# non morde affatto.
	bites[i] = 0
	if has_target and dist <= RADIUS[kind] + TOUCH_REACH:
		var atteso := bite_timers[i] + delta
		if atteso >= touch_period_of(kind):
			bites[i] = 1
			bite_timers[i] = 0.0
		else:
			bite_timers[i] = atteso
	else:
		bite_timers[i] = 0.0
	velocities[i] = vel
	positions[i] = pos + vel * delta