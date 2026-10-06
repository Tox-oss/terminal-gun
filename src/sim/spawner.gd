extends RefCounted
## Disposizione procedurale dell'arena e scelta dei punti di spawn.
##
## Nessuna geometria qui dentro: questo file dice **dove mettere i nemici**,
## non che forma hanno. E' il posto giusto per la densita', perche' la densita'
## e' una regola di gioco, non un asset.
##
## Funzioncchie statiche pure: nessuno stato, nessuna allocazione che duri, e
## l'orda le chiama dal ciclo di gioco senza costruire nulla.

## Quanti anelli concentrici usa il riempimento iniziale.
const RINGS := 7
## Semi dell'anello in cui i nemici sono sparsi davvero (fuori = sul bordo).
const INNER_RING := 0.35
## Tentativi di trovare uno spawn lontano dal giocatore prima di accettare
## quello che e' venuto.
const PLACEMENT_TRIES := 8
## Pesi delle specie al momento dello spawn. Indice = specie.
## `static var` e non `const`: su Godot 4.7 un array compattato non e' un'espressione
## costante (vedi src/sim/enemy.gd, stessa cosa).
static var KIND_WEIGHTS := PackedFloat32Array([50.0, 30.0, 17.0, 3.0])

## Punto per l'indice `i` di un riempimento di `count` nemici dentro un disco
## di raggio `radius`.
##
## Il raggio e' `radius * sqrt(1 - t)` con `t = i/(count-1)`: l'indice 0 sta sul
## bordo e l'ultimo al centro, quindi l'orda **arriva** dal bordo invece di
## materializzarsi addosso al giocatore. Il `sqrt` serve a coprire il disco in
## modo approssimativamente uniforme, e il jitter rompe l'anello perfetto.
static func layout_point(radius: float, i: int, count: int, rng: RandomNumberGenerator) -> Vector3:
	var t := 0.0 if count <= 1 else float(i) / float(count - 1)
	var rr := radius * sqrt(1.0 - clampf(t, 0.0, 1.0))
	rr = clampf(rr + rng.randf_range(-1.0, 1.0) * radius * 0.05, 0.0, radius)
	var a := rng.randf() * TAU
	return Vector3(cos(a) * rr, 0.0, sin(a) * rr)

## Riempie `out[0..count-1]` con una disposizione ad anelli.
static func fill_layout(radius: float, count: int, rng: RandomNumberGenerator,
		out: PackedVector3Array) -> void:
	for i in count:
		out[i] = layout_point(radius, i, count, rng)

## Punto casuale **uniforme in area** dentro il disco: `sqrt` sul raggio, non un
## raggio uniforme (che addenserebbe tutto al centro).
static func random_point(radius: float, rng: RandomNumberGenerator) -> Vector3:
	var rr := radius * sqrt(rng.randf())
	var a := rng.randf() * TAU
	return Vector3(cos(a) * rr, 0.0, sin(a) * rr)

## Punto di spawn: casuale, dentro l'arena e ad almeno `min_gap` dal
## giocatore. Non puo' restituire `Vector3.ZERO`: il contratto usa ZERO come
## "non implementato", e ZERO e' anche sotto il giocatore, quindi restituirlo
## sarebbe un segnale falso. Con `radius >= 1` il punto ha modulo >= 1.
static func spawn_point(radius: float, focus: Vector3, rng: RandomNumberGenerator,
		min_gap: float) -> Vector3:
	var fallback := random_point(radius, rng)
	for _try in PLACEMENT_TRIES:
		var p := random_point(radius * 0.96, rng)
		if p.distance_squared_to(focus) >= min_gap * min_gap:
			return p
	return fallback

## Specie a caso, pesata. Il boss resta raro perche' e' lento e grosso: 200
## nemici non possono essere 200 boss.
static func pick_kind(rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in KIND_WEIGHTS:
		total += w
	var roll := rng.randf() * total
	var acc := 0.0
	for k in KIND_WEIGHTS.size():
		acc += KIND_WEIGHTS[k]
		if roll <= acc:
			return k
	return 0

## Quanti nemici per specie in un'onda. La coda e' lunga `total` e ogni specie
## occupa la sua fetta: e' lo stesso effetto di `pick_kind` ma senza casualita',
## cosi' l'inizio di un'onda e' leggibile nei numeri.
static func wave_mix(total: int) -> PackedInt32Array:
	var sum := 0.0
	for w in KIND_WEIGHTS:
		sum += w
	var out := PackedInt32Array()
	out.resize(KIND_WEIGHTS.size())
	var used := 0
	for k in KIND_WEIGHTS.size():
		var n := int(round(float(total) * KIND_WEIGHTS[k] / sum))
		out[k] = n
		used += n
	# La differenza la mette sul runner, cosi' `sum(out) == total` sempre.
	out[0] += total - used
	return out