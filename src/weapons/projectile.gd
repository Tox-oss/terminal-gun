extends RefCounted
## Un proiettile in volo. -gameplay.
##
## NON e' un nodo: e' un record in un array, come i nemici dell'orda
## (piano §5, regole 1 e 2). Nessun nodo per proiettile, nessuna `new()` /
## `instantiate()` / `queue_free()` nel ciclo di gioco. I 100 proiettili li
## crea **una volta sola** `projectile_pool.gd` all'avvio e poi li riusa; a
## disegnarli provvede l'unica `MultiMeshInstance3D` del pool, che legge `pos`
## da questi record. E' anche il motivo per cui il test di -orda
## (`node_count < 120` con `horde.count == 200`) resta verde con la torcia
## sparata: 100 proiettili come nodi l'avrebbero spassato da solo.
##
## Il "bonk" si sente solo se il colpo esiste davvero: per questo qui sotto ci
## sono solo numeri, e sono la regolazione del gioco, non segreti.

## Raggio del proiettile per il test di contatto, in metri.
const RADIUS := 0.16

## Quanti nemici può attraversare al massimo un proiettile. Il registro dei
## colpi (`hit_log`) è dimensionato su questo numero: `MAX_PIERCE + 1` slot per
## proiettile, assegnati una volta sola, mai uno in più a runtime.
const MAX_PIERCE := 7

## ## m10: `step()` qui sotto sposta e basta, e NON è un dimenticanza
##
## Un ostacolo non ferma un proiettile: in questo progetto l'ostacolo è solido
## per **chi cammina** (giocatore e nemico) e **trasparente** a chi spara. Il
## motivo è una combinazione degenerata — se fermasse anche i proiettili, il
## giocatore che ci si mette dietro sarebbe al sicuro e irraggiungibile per
## sempre, e il gioco si vincerebbe stando fermi — e la decisione è del vertice
## (`src/core/contracts.gd`, "Supersficie di milestone 10").
##
## Quindi `step()` non legge `Game.obstacles`, e non deve leggerlo. «Proiettili
## che si fermano» è **m11**. La dichiarazione corrispondente sta in
## `projectile_pool.gd` (`OBSTACLES_BLOCK_PROJECTILES = false`), che è il file
## dove il contatto viene davvero calcolato.

## Dove si trova adesso.
var pos := Vector3.ZERO
## Dove era al frame precedente: il test di contatto usa il **segmento** fra i
## due punti, non il punto finale (vedi `projectile_pool.gd`).
var prev_pos := Vector3.ZERO
## Direzione normalizzata, congelata alla nascita: è anche la direzione del
## knockback impartito ai nemici colpiti.
var dir := Vector3.FORWARD
var speed := 26.0
var damage := 10.0
## Spinta data al nemico colpito, in m/s (NON un vettore normalizzato: sotto i
## numeri c'è il conto del perché, e cosa mi aspetto da `Game.damage_enemy`).
var knockback := 10.0
var life := 1.4
var radius := RADIUS
var pierce := 0

## m15: da quale dei due **controfattuali** e' partito questo colpo (`true` =
## l'arma ha anticipato il bersaglio). E' un flag e nient'altro, e senza di questo
## il confronto fra i due bracci non avrebbe un numeratore per ciascuno: vedi i
## due campi in testa al file `projectile_pool.gd` e la sezione
## `_tasso_col_controfattuale` di `tests/test_progression.gd`.
var anticipato := false

## ## m15: la **distanza minima** che il segmento di questo colpo ha raggiunto da
## un centro nemico, in metri quadrati, su tutto il volo.
##
## E' il numero che dice «il predetto cade dentro il reach? e di quanto?», ed e'
## l'unico che regge: **un indice non e' un'identita'** e l'orda compatta i suoi
## array a ogni morte, quindi seguire il bersaglio fra un frame e l'altro non e'
## possibile (vedi il blocco lungo in `projectile_pool.gd`). Qui invece la minima
## e' calcolata **dentro il frame** e accumulata, e il confronto avviene quando il
## colpo lascia il pool. `INF` = il colpo non ha incontrato nessuno.
var scarto_min2 := INF

## Indici dei nemici già colpiti da questo proiettile, e quanti sono validi.
## È QUI che vive la regola "danno una volta sola": un proiettile che resta
## dentro un nemico per tre frame non deve spammare `damage_enemy`, e un
## proiettile che attraversa due nemici sovrapposti deve colpirne due, uno per
## uno. Nessun `Dictionary` e nessuna allocazione: array di interi preallocato.
var hit_log := PackedInt32Array()
var hit_count := 0

## Mette in volo il record riusato dal pool. Tutto ciò che il pool non passa
## qui viene dai potenziamenti, letti una volta sola dall'arma.
func launch(p_pos: Vector3, p_dir: Vector3, p_speed: float, p_damage: float,
		p_knockback: float, p_life: float, p_pierce: int) -> void:
	pos = p_pos
	prev_pos = p_pos
	dir = p_dir
	speed = p_speed
	damage = p_damage
	knockback = p_knockback
	life = p_life
	pierce = clampi(p_pierce, 0, MAX_PIERCE)
	hit_count = 0
	# m15: il minimo riparte da capo a ogni lancio, altrimenti un record riusato
	# porterebbe dentro il volo precedente il suo scarto. Vedi il blocco sopra.
	scarto_min2 = INF

## Un passo di integrazione. Solo movimento: la collisione la fa il pool, che è
## l'unico che può vedere gli indici dell'orda senza dipendere dal suo script.
##
## Solo movimento **e nient'altro**: niente ostacoli, e vedi il blocco sopra
## `MAX_PIERCE` per il perché.
func step(delta: float) -> void:
	prev_pos = pos
	pos += dir * speed * delta
	life -= delta

func expired() -> bool:
	return life <= 0.0

## Questo nemico è già stato colpito da questo proiettile?
func has_hit(enemy_index: int) -> bool:
	for i in hit_count:
		if hit_log[i] == enemy_index:
			return true
	return false

## Segna il nemico come colpito. Restituisce false se lo aveva già colpito:
## è la guardia che rende impossibile il doppio danno, chiamata dal pool.
func log_hit(enemy_index: int) -> bool:
	if has_hit(enemy_index):
		return false
	if hit_count >= hit_log.size():
		return false
	hit_log[hit_count] = enemy_index
	hit_count += 1
	return true

## Quanti nemici ha ancora il permesso di colpire prima di sparire.
func hits_left() -> int:
	return 1 + pierce - hit_count