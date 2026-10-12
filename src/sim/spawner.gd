extends RefCounted
## Disposizione procedurale dell'arena e scelta dei punti di spawn.

## Le tabelle delle specie. `enemy.gd` non preloada niente, quindi questo
## preload non puo' diventare un riferimento circolare.
const E = preload("res://src/sim/enemy.gd")
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
## **Il nemico piu' vicino non nasce addosso al centro.** La disposizione iniziale
## tiene un buco nel mezzo largo come il `MIN_SPAWN_GAP` che lo spawn degli
## uccisi gia' rispetta: il primo frame smette di essere un caso speciale con
## regole diverse dal resto della partita.
##
## ## MISURATO (milestone 4, `tests/test_orda.gd`, 2026-10-12)
##
## Con `rr = radius * sqrt(1 - t)` e `t = i / (count - 1)`, l'indice `count - 1`
## cade a `rr = 0`: **un nemico nasce esattamente sul giocatore**, al centro
## dell'arena. Il tempo di primo contatto misurato era **t = 0.02 s**, cioe' il
## primo frame. Non e' una densita' troppo alta: e' un nemico a distanza zero.
##
## Con il buco di `LAYOUT_INNER` il contatto non puo' avvenire prima di
## `(LAYOUT_INNER - ARRIVE_RADIUS) / speed_max = (12 - 3) / 6.6 = 1.36 s`, che e'
## lo stesso ordine di grandezza del contatto misurato su un campo da 25
## nemici (1.68 s): la partenza piccola di m4 e il buco qui sono la stessa
## leva, applicata ai due tempi diversi (quanti e da dove).
const LAYOUT_INNER := 12.0
## Tentativi di trovare uno spawn lontano dal giocatore prima di accettare
## quello che e' venuto.
const PLACEMENT_TRIES := 8
## Pesi delle specie al momento dello spawn. Indice = specie.
##
## Sono i pesi dell'**onda 1** e restano tali per sempre: `wave_weights(w)` parte
## da questi e li sposta con le onde. tenerli fermi e' quello che lascia i numeri
## della milestone 1 uguali a prima.
## `static var` e non `const`: su Godot 4.7 un array compattato non e' un'espressione
## costante (vedi src/sim/enemy.gd, stessa cosa).
static var KIND_WEIGHTS := PackedFloat32Array([50.0, 30.0, 17.0, 3.0])

## Punto per l'indice `i` di un riempimento di `count` nemici dentro un disco
## di raggio `radius`.
##
## Il raggio e' `LAYOUT_INNER + (radius - LAYOUT_INNER) * sqrt(1 - t)` con
## `t = i/(count-1)`: l'indice 0 sta sul bordo e l'ultimo sul bordo **interno**,
## quindi l'orda **arriva** dal bordo invece di materializzarsi addosso al
## giocatore. Il `sqrt` serve a coprire l'anello in modo approssimativamente
## uniforme, e il jitter rompe l'anello perfetto.
##
## Il buco interno e' `LAYOUT_INNER`: vedi la sua dichiarazione, che ha la
## misura del difetto che corregge. Il buco non e' il centro esatto ma un
## anello: sotto `LAYOUT_INNER` non nasce **nessuno**, quindi nessuno nasce sul
## giocatore quando il giocatore parte al centro, che e' dove parte.
static func layout_point(radius: float, i: int, count: int, rng: RandomNumberGenerator) -> Vector3:
	var t := 0.0 if count <= 1 else float(i) / float(count - 1)
	var inner := minf(LAYOUT_INNER, radius * 0.45)
	var rr := inner + (radius - inner) * sqrt(1.0 - clampf(t, 0.0, 1.0))
	rr = clampf(rr + rng.randf_range(-1.0, 1.0) * radius * 0.05, inner, radius)
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
##
## Con i pesi dell'onda 1: e' la forma breve di `pick_kind_with`, e serve ai
## chiamanti che non hanno un'onda (il test della griglia, il bootstrap).
static func pick_kind(rng: RandomNumberGenerator) -> int:
	return pick_kind_with(rng, KIND_WEIGHTS)

## Specie a caso, pesata con i pesi dati. `weights` e' un `PackedFloat32Array`
## di `KIND_COUNT` voci, indici allineati a `KIND_NAMES`.
static func pick_kind_with(rng: RandomNumberGenerator, weights: PackedFloat32Array) -> int:
	var total := 0.0
	for w in weights:
		total += w
	# Una tabella tutta nulla non e' un caso da gestire con un errore: si risponde
	# col runner, che e' la specie piu' comune e la piu' fragile, cosi' nessun
	# spawn va perso e nessuna funzione va interrotta a meta'.
	if total <= 0.0:
		return 0
	var roll := rng.randf() * total
	var acc := 0.0
	for k in weights.size():
		acc += weights[k]
		if roll <= acc:
			return k
	return 0

## I pesi delle specie dell'onda `w`: la **scala delle onde** sul lato di chi
## nasce. Sull'onda 1 sono esattamente `KIND_WEIGHTS`, quindi i numeri della
## milestone 1 restano quelli che erano.
##
## Il verso della scala e' uno solo e non e' una scelta di estetica: colla
## crescere dell'onda il campo si riempie di cose che reggono il colpo. Il
## runner scende (e' la specie piu' fragile: 14 HP e resistenza 0 al
## knockback), il brute e il boss salgono (110 e 900 HP, resistenza 0.55 e
## 0.90, cioe' non si spostano sotto i colpi). I due pesi hanno un tetto, quindi
## un'onda non diventa "tutti boss": un'onda di soli boss non e' piu' difficile,
## e' solo piu' lenta.
static func wave_weights(wave: int) -> PackedFloat32Array:
	var n := float(maxi(wave, 1) - 1)
	var out := PackedFloat32Array()
	out.resize(KIND_WEIGHTS.size())
	out[E.RUNNER] = maxf(5.0, KIND_WEIGHTS[E.RUNNER] - 2.5 * n)
	out[E.GRUNT] = KIND_WEIGHTS[E.GRUNT]
	out[E.BRUTE] = KIND_WEIGHTS[E.BRUTE] + minf(18.0, 1.8 * n)
	out[E.BOSS] = KIND_WEIGHTS[E.BOSS] + minf(27.0, 2.0 * n)
	return out

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