extends RefCounted
## Disposizione procedurale dell'arena e scelta dei punti di spawn.

## Le tabelle delle specie. `enemy.gd` non preloada niente, quindi questo
## preload non puo' diventare un riferimento circolare.
const E = preload("res://src/sim/enemy.gd")
## I numeri della geometria statica di m10. Da li' viene `SKIN_EPS`, il margine
## con cui un punto di nascita viene tenuto **oltre** il bordo del disco invece
## che sul bordo: il produttore e' `obstacles.gd` (§3.11) e la dichiarazione di
## quel numero, con la sua misura, sta in testa a quel file.
const OBST = preload("res://src/sim/obstacles.gd")
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
## Sono i pesi **da cui parte `wave_weights(w)`**, e restano tali per sempre.
## Sull'**onda 1** pero' il boss non li prende: la ragione, e l'unica cosa che
## questo giro ha cambiato, sta in `BOSS_WAVE1` qui sotto.
## `static var` e non `const`: su Godot 4.7 un array compattato non e' un'espressione
## costante (vedi src/sim/enemy.gd, stessa cosa).
static var KIND_WEIGHTS := PackedFloat32Array([50.0, 30.0, 17.0, 3.0])

## ## Il boss esce dall'onda 1
##
## Unica variabile cambiata in questo giro, e il numero e' **0,0**: il peso del
## boss sull'onda 1. Prima valeva `3,0`, cioe' il boss era il 3% delle nascite
## della prima onda.
##
## | onda | pesi prima | pesi adesso |
## |---|---|---|
## | **1** | runner 50,0 - grunt 30,0 - brute 17,0 - **boss 3,0** | runner 50,0 - grunt 30,0 - brute 17,0 - **boss 0,0** |
## | 2 | runner 47,5 - grunt 30,0 - brute 18,8 - boss 5,0 | **identici, bit per bit** |
## | 8 | runner 32,5 - grunt 30,0 - brute 29,6 - boss 17,0 | **identici, bit per bit** |
##
## Le tre ragioni, in ordine di quanto costa sbagliare.
##
## **1. Nell'onda in cui compare il boss uccide, e lo ha ucciso in tre semi su
## tre.** A 6 nemici in campo insegue a **1,7 m/s** (`SPEED[BOSS]`), il piu'
## lento dei quattro, ha **6,91 m** di portata e **13,71 hp** a morso: dieci
## morsi sono 137 hp e il giocatore ne ha 100. La prima onda che contiene un
## boss lo uccide, e l'onda 1 e la prima.
##
## **2. Sull'onda 1 non c'e' niente da misurare, quindi non si sceglie niente.**
## Il giocatore oggi muore **nell'onda 1**, al passo equivalente a **44,20 s**
## sui tre semi, e non arriva mai all'onda 2. Quindi **l'onda in cui il boss
## torna non e' ancora un numero che si possa scegliere**: si sceglie dopo che
## la rampa sara' allungata. Scriverlo adesso sarebbe un numero scritto prima
## della misura, che e' la regola che questo progetto vieta.
## Dichiarato, quindi: **il peso del boss e' 0 sull'onda 1, e da quale onda torna
## sara' deciso su misura.** Il salto e' discontinuo per scelta: 0,0 sull'onda 1
## e 5,0 dall'onda 2 com'era, cosi' le onde che il gioco raggiunge restano quelle
## che erano.
##
## **3. Le onde da 2 in poi non si toccano.** Non e' una promessa, e' un criterio:
## `wave_weights(2)` e' asserito **bit-identico** in `tests/test_orda.gd`. Una
## leva che si rovescia sulle onde che non deve toccare non e' una leva.
##
## Nessun altro numero si e' mosso: le altre tre specie pesano come prima, e i
## 27 dischi, `MAX_ENEMIES = 200`, `SPAWN_RATE = 8.0`, `TOUCH_REACH`, `GRID_CEILING`,
## `arena_radius = 60.0`, `POP_BASE = 25` e `POP_STEP` restano quelli di prima.
##
## `static var` e non `const`: non perche' il numero sia provvisorio, ma perche'
## `tests/test_orda.gd` deve poter rimettere **3,0** qui dentro, misurare i boss
## che tornano, e rimettere **0,0** nella stessa sezione. Un criterio che vuole
## avere i denti deve poter accendere il difetto da solo: se il numero fosse
## una `const` l'unico modo di provarlo sarebbe editare il sorgente a mano, e
## quello non lascia traccia. Il ripristino e' asserito subito dopo, quindi se
## il blocco si interrompesse a meta' il test andrebbe rosso invece di partire
## con il boss a zero senza saperlo.
static var BOSS_WAVE1 := 0.0

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
##
## ## m10: nessuno nasce dentro un ostacolo
##
## Un anello di disposizione puo' passare esattamente dove passa un disco, e un
## nemico che nasce dentro un ostacolo e' un nemico che il criterio n. 2 vede
## **al frame zero**: non e' un difetto che si accomoda in un secondo, e' una
## disposizione sbagliata. Quindi il punto va spinto fuori, e `skin` e' il
## raggio del **nemico piu' grosso**: e' il raggio che garantisce che nessuna
## specie nasca dentro, per tutte e quattro e non solo per quella che si e' capita
## di pescare. Il criterio e' dichiarato sul minimo dei tre, non sul massimo.
static func layout_point(radius: float, i: int, count: int, rng: RandomNumberGenerator,
		obstacles: PackedVector3Array = PackedVector3Array(), skin: float = 0.0) -> Vector3:
	var t := 0.0 if count <= 1 else float(i) / float(count - 1)
	var inner := minf(LAYOUT_INNER, radius * 0.45)
	var rr := inner + (radius - inner) * sqrt(1.0 - clampf(t, 0.0, 1.0))
	rr = clampf(rr + rng.randf_range(-1.0, 1.0) * radius * 0.05, inner, radius)
	var a := rng.randf() * TAU
	return free_point(Vector3(cos(a) * rr, 0.0, sin(a) * rr), obstacles, skin, radius)

## Spinge `p` fuori da ogni disco che lo contiene, con `skin` di margine, e lo
## riporta dentro l'arena. Due passaggi perche' due dischi vicini possono
## spingere lo stesso punto in due direzioni diverse, e un punto spinto fuori
## dall'arena che si riporta dentro puo' finire dentro un disco: il secondo
## passaggio chiude la cosa.
##
## Il criterio n. 5 e' scritto su questa funzione e non sul `spawn_point`: e' l'unico
## posto dove un punto di nascita viene deciso, e decidere lo in due posti
## significa che uno dei due non e' governato.
##
## ## Il margine `SKIN_EPS`: perche' il punto non puo' finire sul bordo
##
## Il raggio di riferimento qui e' `ob.y + skin + SKIN_EPS`, non
## `ob.y + skin`. Non e' pignoleria: il punto di nascita e' una **somma**
## (`posizione + scarto`) in `float`, e chi verifica il criterio conta con
## `d2 < rr * rr`, **stretto**. Un punto lasciato esattamente sul bordo
## sbaglia di qualche ulp verso l'interno e il criterio n. 5 lo dichiara dentro:
## misurato, **778 su 4800** posizioni iniziali su 24 semi, tutte a `-0.00000`
## m dentro il disco. Non era un difetto della disposizione, era il bordo.
## Il numero e' di `obstacles.gd`, dichiarato e misurato in testa a quel file.
static func free_point(p: Vector3, obstacles: PackedVector3Array, skin: float,
		arena_radius: float) -> Vector3:
	var q := p
	if obstacles.is_empty():
		return q
	for _giro in 3:
		var mosso := false
		for k in obstacles.size():
			var ob := obstacles[k]
			var rr := ob.y + maxf(0.0, skin) + OBST.SKIN_EPS
			var dx := q.x - ob.x
			var dz := q.z - ob.z
			var d2 := dx * dx + dz * dz
			if d2 >= rr * rr:
				continue
			mosso = true
			var d := sqrt(d2)
			if d < 0.0001:
				q.x += rr
			else:
				q.x += dx / d * (rr - d)
				q.z += dz / d * (rr - d)
		var fuori := Vector2(q.x, q.z).length()
		if fuori > arena_radius and fuori > 0.0001:
			var k2 := arena_radius / fuori
			q.x *= k2
			q.z *= k2
		if not mosso:
			break
	return q

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
##
## ## m10: il punto di spawn e' fuori dagli ostacoli, per costruzione
##
## Un tiro che capita dentro un disco viene **rifiutato** e si ritira, e il
## fallback dell'ultimo tentativo viene comunque spinto fuori: e' l'unico modo
## perche' il criterio n. 5 valga **su tutti i semi** e non in media. Il margine
## e' il raggio del nemico piu' grosso per la stessa ragione che vale nella
## disposizione iniziale.
static func spawn_point(radius: float, focus: Vector3, rng: RandomNumberGenerator,
		min_gap: float, obstacles: PackedVector3Array = PackedVector3Array(),
		skin: float = 0.0) -> Vector3:
	var fallback := random_point(radius, rng)
	for _try in PLACEMENT_TRIES:
		var p := random_point(radius * 0.96, rng)
		if p.distance_squared_to(focus) < min_gap * min_gap:
			continue
		if _dentro(p, obstacles, skin):
			continue
		return p
	return free_point(fallback, obstacles, skin, radius)

## Il punto e' dentro un disco, corpo compreso? Usato dal tentativo di spawn e
## dai test, perche' la risposta deve essere la stessa nei due posti.
##
## `SKIN_EPS` anche qui, e dalla parte giusta: il confronto e' **stretto**
## (`d2 < rr * rr`), quindi un punto a pelo del bordo e' fuori. Con il margine
## il «fuori» di questa funzione e il «fuori» di `free_point` sono la stessa
## frontiera, ed e' quello che rende il criterio n. 5 vero su **tutti** i semi
## e non in media.
static func _dentro(p: Vector3, obstacles: PackedVector3Array, skin: float) -> bool:
	for k in obstacles.size():
		var ob := obstacles[k]
		var rr := ob.y + maxf(0.0, skin) + OBST.SKIN_EPS
		var dx := p.x - ob.x
		var dz := p.z - ob.z
		if dx * dx + dz * dz < rr * rr:
			return true
	return false

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
## nasce. Da `w = 2` in poi partono da `KIND_WEIGHTS` e li spostano con le onde;
## sull'**`w = 1`** il boss e' a `BOSS_WAVE1` invece che a `KIND_WEIGHTS[BOSS]`,
## per la ragione lunga dichiarata su quella costante.
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
	# `n <= 0` e' `wave <= 1`. Il ramo e' scritto per intero e non per sottrazione
	# (`KIND_WEIGHTS[BOSS] - 3,0`): sottraendo, il peso dell'onda 2 diventerebbe
	# 2,0 invece di 5,0 e la rampa ripartirebbe da capo. Qui la condizione dice
	# esattamente quello che vuol dire -- sull'onda 1 il boss e' a zero, da `w = 2`
	# in poi la rampa e' quella di prima, termine per termine.
	out[E.BOSS] = BOSS_WAVE1 if n <= 0.0 else KIND_WEIGHTS[E.BOSS] + minf(27.0, 2.0 * n)
	return out

## Quanti nemici per specie in un'onda. La coda e' lunga `total` e ogni specie
## occupa la sua fetta: e' lo stesso effetto di `pick_kind` ma senza casualita',
## cosi' l'inizio di un'onda e' leggibile nei numeri.
##
## **Non e' sul cammino dello spawn.** Nessuno la chiama: `horde.gd::_populate` e
## `horde.gd::_spawn_one` passano entrambi da `_pick_kind()`, che legge
## `wave_weights(run.wave)`. Quindi questa funzione non conta niente di quello che
## il gioco vede, ed e' rimasta com'era perche' toccarla sarebbe un'altra
## variabile in un giro che ne dichiara una sola.
##
## Il numero che contiene pero' e' adesso **stale**: usa `KIND_WEIGHTS` piatto, e
## `KIND_WEIGHTS[BOSS]` e' ancora `3,0` mentre il peso del boss sull'onda 1 e' a
## `0,0` (`BOSS_WAVE1`). Se qualcuno la collegasse allo spawn, l'onda 1
## rinascerebbe col 3% di boss, cioe' esattamente il difetto che `BOSS_WAVE1`
## chiude. Va rimessa a `wave_weights(1)` **misurando** la soglia di rientro del
## boss, non prima.
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