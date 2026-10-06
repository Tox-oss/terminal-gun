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

## Un passo di simulazione del nemico `i`.
##
## `push` e' la spinta di separazione calcolata dalla griglia (l'horda la passa
## gia' pronta: qui dentro non si sa niente di griglie ne' di query).
##
## Tutti gli array sono paralleli e lunghi `count`: scrive solo `positions[i]`,
## `velocities[i]` e `timers[i]`. Nessuna allocazione.
static func step(i: int, delta: float, target: Vector3, push: Vector3,
		positions: PackedVector3Array, velocities: PackedVector3Array,
		timers: PackedFloat32Array, kinds: PackedInt32Array,
		arena_radius: float) -> void:
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
	velocities[i] = vel
	positions[i] = pos + vel * delta