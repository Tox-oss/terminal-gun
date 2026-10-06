extends RefCounted
class_name TestHarness
## Helper di asserzione condiviso dai test di terminal-gun.
##
## Un test è un processo a sé (`godot --headless --script res://tests/test_x.gd`)
## e parla col gate solo attraverso stdout e codice di uscita. Quindi:
##   - ogni test stampa ESATTAMENTE una riga `PASS <nome>` oppure `FAIL <nome>: <motivo>`;
##   - ed esce con 0 se e solo se è passato.
## Il gate non legge nient'altro: la riga e il codice di uscita sono tutto il contratto.
##
## I messaggi sono solo ASCII: la console di Windows e il pipe di `OS.execute`
## sono in codepage, e un accento in un messaggio di fallimento diventa
## spazzatura proprio dove serve leggerlo.
##
## Uso tipico:
##     extends SceneTree
##     const H = preload("res://tools/test_harness.gd")
##
##     func _initialize() -> void:
##         var h = H.new()
##         h.near(Game.arena_radius, 28.0, 0.001, "arena_radius")
##         h.check(x > 0, "x deve essere positivo")
##         quit(h.finish("smoke"))
##
## `finish()` stampa la riga e restituisce il codice di uscita: 0 solo se non
## c'è nessun fallimento. Non chiamare `quit()` da `check()`: il test deve
## raccogliere tutte le asserzioni e poi uscire una volta sola.

## Numero di asserzioni fatte finora, e quelle che sono fallite.
var checks: int = 0
var failures: Array[String] = []

# --- Asserzioni ----------------------------------------------------------------

## L'affermazione deve essere vera. Messaggio in chiaro: è la ragione che
## finisce in `FAIL`, e chi legge non ha il codice sotto gli occhi.
func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
	return condition

## Uguaglianza stretta, con repr dei due valori nel messaggio.
func eq(got: Variant, expected: Variant, message: String) -> bool:
	return check(got == expected, "%s: atteso %s, ottenuto %s" % [message, _repr(expected), _repr(got)])

## Uguaglianza numerica entro `eps`: i float del gameplay non sono mai esatti.
func near(got: float, expected: float, eps: float, message: String) -> bool:
	return check(absf(got - expected) <= eps, "%s: atteso %s +/- %s, ottenuto %s" % [message, expected, eps, got])

## Due vettori coincidenti entro `eps` componente per componente.
func vec_near(got: Vector3, expected: Vector3, eps: float, message: String) -> bool:
	var d := got - expected
	var ok := absf(d.x) <= eps and absf(d.y) <= eps and absf(d.z) <= eps
	return check(ok, "%s: atteso %s +/- %s, ottenuto %s" % [message, expected, eps, got])

## Il valore è finito (niente NaN, niente infinito: divergono i contatori).
func finite(value: float, message: String) -> bool:
	return check(is_finite(value), "%s: non finito (%s)" % [message, value])

## Il valore è > 0. Per distanze, conteggi, durate.
func positive(value: float, message: String) -> bool:
	return check(value > 0.0, "%s: atteso > 0, ottenuto %s" % [message, value])

## Fallisce sempre, con il motivo dato. Per le precondizioni esplicite.
func fail(message: String) -> void:
	check(false, message)

# --- Chiusura ------------------------------------------------------------------

func passed() -> bool:
	return failures.is_empty()

## Stampa la riga di verdetto e restituisce il codice di uscita del processo.
func finish(name: String) -> int:
	if passed():
		print("PASS %s (%d asserzioni)" % [name, checks])
		return 0
	print("FAIL %s: %s" % [name, failures[0]])
	for extra in failures.slice(1):
		print("  anche: %s" % extra)
	return 1

# --- Interno -------------------------------------------------------------------

func _repr(value: Variant) -> String:
	return str(value)