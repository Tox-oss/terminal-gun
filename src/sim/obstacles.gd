extends RefCounted
## I **numeri** della geometria statica del mondo (milestone 10) e la sua
## costruzione. Qui non si disegna niente: qui si dichiara **che forma ha** il
## campo statico, e `-arena` lo mette in scena.
##
## ## Chi possiede questi numeri, e perche' sono qui
##
## Il vertice ha deciso l'ordine di consegna di m10 (§3.11): «la geometria la
## sceglie `-orda` e la costruisce `-arena`». Il motivo e' dichiarato: il criterio
## n. 2 e' **nostro**, e un numero che una foglia non ha misurato non lo deve
## scrivere. Percio' `layout()` e' la fonte unica dei dischi: chi li costruisce
## deve chiamare questa funzione e non riscoprire i numeri, perche' due copie di
## un raggio che divergono sono il difetto che m9 ha gia' chiuso una volta
## (sei copie di `28.0`, nessuna porta rossa).
##
##     const OBST = preload("res://src/sim/obstacles.gd")
##     game.obstacles = OBST.layout(game.arena_radius)   # -arena, in _enter_tree()
##
## ## La forma che esce e' quella congelata dal vertice
##
## Un elemento = `Vector3(centro_x, RAGGIO, centro_z)`: il raggio sta in `y` e
## non e' un'altezza. Non si deve leggere `y` come una quota (contratto di m10,
## punto 2), e questa funzione non ne produce nessuna: tutti i dischi sono sul
## piano XZ a `y = raggio`.
##
## ## Perche' tre anelli e non una disposizione a caso
##
## Il nemico insegue **in linea retta**, quindi la domanda che conta non e'
## "quanto campo c'e'" ma **"quanta parte delle traiettorie rette viene
## attraversata"**. Con ostacoli sparsi a caso la densita' areale giusta
## (~11%) produrrebbe qualche deviazione ogni tanto e il gioco resterebbe
## invariato. Tre anelli concentrici mettono invece un ostacolo **sulla strada**
## di ogni nemico che arriva da fuori, e la densita' areale resta la stessa.
##
## ## La garanzia che conta: nessuna coppia di ostacoli si tocca
##
## Un ostacolo che blocca e non si aggira e' un muro, e due muri che si toccano
## sono un muro solo. Quindi la regola e' una e la verifica e' geometrica:
## **la distanza fra due centri deve superare `2 * raggio + BOSSO`**, cosi' il
## passaggio fra due ostacoli e' piu' largo della sagoma del nemico piu' grosso
## (`RADIUS[BOSS] = 1.9`, diametro 3.8 m). Un nemico che entra in una fessura
## piu' stretta di se e' un nemico incastrato, e l'incastrato e' il difetto
## tipico di un campo di percorrenza (criterio n. 4 della milestone).
##
## Con i numeri qui sotto il minimo e' **12,0 m** fra due ostacoli di anelli
## diversi (distanza radiale fra un anello e il successivo) e **15,1 m** sullo
## stesso anello (corda minima, anello interno, 6 ostacoli): il passaggio utile
## e' quindi di **6,0 m**, cioe' 1,6 volte la sagoma del boss.
##
## Nessun anello si chiude su se stesso perche' le corde sono tutte molto piu'
## grandi di `2 * raggio`: il campo libero resta **connesso**, e questa e' la
## proprieta' che tiene il giocatore raggiungibile ovunque si metta.

## Quanti ostacoli, in tutto: `RING_COUNTS` la sua somma.
const OBSTACLE_COUNT := 27
## Raggio di ogni disco, come **frazione** del raggio dell'arena. Non un numero
## in metri perche' un numero in metri qui dentro sarebbe una copia del raggio
## dell'arena scritta a mano, cioe' la classe di difetto di §1.12-bis. A
## `ARENA_RADIUS = 46.0` questo vale **2,99 m**, dichiarato come ~3,0 m.
const RADIUS_FRACTION := 0.065
## Raggio dei tre anelli, sempre come frazione del raggio dell'arena.
## A 46,0 m sono **15,18 / 27,14 / 39,10 m**.
const RING_RADII := [0.33, 0.59, 0.85]
## Quanti ostacoli su ciascun anello: 6 + 9 + 12 = `OBSTACLE_COUNT`.
const RING_COUNTS := [6, 9, 12]
## Sfasamento angolare fra un anello e il successivo, in frazione del passo
## angolare. Serve ache' i dischi di due anelli diversi non si allineino: senza
## sfasamento l'anello interno e quello esterno avrebbero ostacoli uno dietro
## l'altro e la distanza fra loro sarebbe **radiale**, cioe' la minima possibile.
const PHASE := 0.41
## Jitter angolare, in frazione del passo angolare. Buca il reticolo perfetto
## (che si vede) senza toccare la garanzia: al massimo l'angolo si sposta del
## 10% del passo, quindi la corda minima dell'anello interno scende da 15,1 a
## **14,2 m**, ancora 5,2 volte il raggio del disco.
const ANGLE_JITTER := 0.10
## Il raggio del disco in metri, per un'arena di raggio `arena_radius`.
static func radius_for(arena_radius: float) -> float:
	return maxf(0.5, maxf(arena_radius, 1.0) * RADIUS_FRACTION)

## Margine con cui un punto viene tenuto **fuori** dal disco invece che sul suo
## bordo. **1 millimetro**, e non e' una patch: e' il numero che tiene chiuso il
## criterio n. 5 e il criterio n. 2 insieme.
##
## ## Perche' serve, e perche' qui
##
## La domanda «un punto e' dentro un disco?» si fa in due posti con lo stesso
## segno: chi **produce** il punto (`Spawner.free_point`, `Flow.push_out`) spinge
## fuori, e chi **verifica** (`flow_field.contains`, `tests/test_orda.gd`) conta
## con `d2 < rr * rr`, cioe' **stretto**. I due numeri, se sono uguali, sono
## uguali per aritmetica e non per costruzione: chi spinge fuori calcola lo
## scarto in `float` e lo **somma** alla posizione, e la somma sbaglia di qualche
## ulp. Il punto finisce a `-0.00000` m dentro il disco, il confronto stretto
## lo dichiara dentro, e il criterio dice `FAIL` su un numero che non e' un
## difetto di steering ma di aritmetica: **778 su 4800** posizioni iniziali su
## 24 semi, tutte a zero.
##
## Il rimedio non e' arrotondare il confronto (allora il vincolo si sposta e
## diventa inafferrabile) e non e' spingere piu' forte: e' **un margine
## dichiarato** sulla spinta, piu' grande dell'errore di somma e piu' piccolo di
## qualsiasi cosa che si veda. `1e-3 m` su un disco di 2,99 m e' lo 0,03%.
##
## ## Perche' sta in questo file e non nei due che lo usano
##
## Perche' `obstacles.gd` e' il **produttore unico dei numeri** di m10 (§3.11):
## un millimetro scritto in `spawner.gd` e un millimetro scritto in
## `flow_field.gd` sono due numeri che possono divergere, e il difetto che m9 ha
## gia' chiuso una volta (sei copie di `28.0`, nessuna porta rossa) si ripete
## identico a un ordine di grandezza piu' piccolo. Una costante sola, due
## lettori.
const SKIN_EPS := 1.0e-3

## I dischi, gia' nella forma del contratto: `Vector3(cx, RAGGIO, cz)`.
##
## Determinismo: nessun `RandomNumberGenerator`, solo un hash intero dei numeri
## d'indice. Due foglie che chiamano questa funzione con lo stesso raggio
## ottengono **gli stessi dischi**, che e' il motivo per cui il numero non e'
## scritto due volte.
static func layout(arena_radius: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(OBSTACLE_COUNT)
	var r := radius_for(arena_radius)
	var k := 0
	for anello in RING_RADII.size():
		var n: int = RING_COUNTS[anello]
		var passo := TAU / float(n)
		var base := passo * PHASE * float(anello + 1)
		var rr: float = arena_radius * float(RING_RADII[anello])
		for i in n:
			# il jitter e' sul passo angolare, mai sul raggio: il raggio tiene
			# la distanza fra due anelli, che e' la garanzia che conta
			var a := passo * (float(i) + ANGLE_JITTER * (_hash01(k) * 2.0 - 1.0))
			out[k] = Vector3(cos(a + base) * rr, r, sin(a + base) * rr)
			k += 1
	return out

## Il punto piu' vicino a un ostacolo, in metri: `0` se l'insieme e' vuoto. E' il
## numero con cui si controlla che nessuno ci si perda dentro, e la sua versione
## con il corpo dell'enemy dentro e' il criterio n. 2.
static func min_separation(obstacles: PackedVector3Array) -> float:
	var minimo := 1.0e9
	for a in obstacles.size():
		for b in range(a + 1, obstacles.size()):
			var pa := obstacles[a]
			var pb := obstacles[b]
			var d := Vector2(pa.x - pb.x, pa.z - pb.z).length()
			if d < minimo:
				minimo = d
	return 0.0 if obstacles.size() < 2 else minimo

## Numero pseudo-casuale **deterministico** in [0, 1). Serve a bucare il
## reticolo senza un generatore: due foglie ottengono la stessa sequenza.
static func _hash01(n: int) -> float:
	var x := (n * 2654435761) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	x = x ^ (x >> 16)
	return float((x & 0xffff) % 65536) / 65536.0