extends SceneTree
## Porta di verifica di terminal-gun. w1.
##
##     godot --headless --path . --script tools/gate.gd
##
## scansione di res://tests/test_*.gd in ordine alfabetico, esecuzione di ogni
## test in un PROCESSO SEPARATO, una riga per test, riga finale `GATE: N/M`,
## exit 0 solo se tutto passa.
##
## Perché un processo per test e non un `load()` in questo stesso processo:
## un test che va in crash o che lascia allocazioni appese non può abbattere
## il gate né falsare i test successivi. Il verdetto di un test è il suo
## codice di uscita; il motivo di un FAIL è la sua stdout.
##
## TIMEOUT PER TEST (criterio n. 6 di m2, debito di m1 chiuso). Un test che si
## blocca non blocca più il gate: il figlio viene sorvegliato e, superata la
## soglia, ucciso con `OS.kill` e riportato come FAIL dichiarato.
##
## Perché `OS.execute_with_pipe` e non `OS.execute`: `OS.execute` cattura la
## stdout ma è BLOCCANTE e senza timeout, quindi non può fare le due cose.
## `execute_with_pipe` in modo non bloccante restituisce sia il pid sia la pipe:
## si legge a pezzi mentre si sorveglia `OS.is_process_running`. Il verdetto
## resta il codice di uscita del figlio, il motivo resta la sua stdout.
##
## SKIP non è un fallimento: un test previsto e non ancora scritto non deve
## far fallire l'onda che sta costruendo le altre foglie. Il vertice legge
## le righe SKIP per capire se manca qualcuno.
##
## Un test che stampa PASS ma lascia un ERROR in stderr è un FAIL: un errore
## runtime di GDScript interrompe la funzione e le asserzioni successive non
## girano, quindi il PASS sarebbe su un test mai finito.

const TESTS_DIR := "res://tests"
const PREFIX := "test_"

## Scadenza per un singolo test. Generosa abbastanza da non tagliare un test
## legittimamente lento su una macchina carica, e abbastanza stretta da non
## congelare un gate per sempre. I test di oggi durano da 0.16 s a pochi secondi:
## il margine e' di un ordine di grandezza, non di un soffio.
const TEST_TIMEOUT_MS := 120000
const POLL_MS := 5

## I test che il piano (docs/piramide/piano.md §6) prevede. Un file scritto da
## una foglia e non qui dentro viene comunque eseguito: questa lista serve solo
## a poter dire SKIP su un test che non è ancora stato scritto.
const EXPECTED := ["test_arena", "test_gameplay", "test_orda", "test_smoke"]

## Argomenti utente supportati, dopo `--` sulla riga di comando:
##   --only <nome>   esegue un solo test (usato dal test di fumo per non
##                   ricorsare su tutti i test delle altre foglie)
##   --gate-child    dice ai test di non lanciare a loro volta il gate
var _only: String = ""
var _gate_child: bool = false

func _initialize() -> void:
	var user_args := OS.get_cmdline_user_args()
	var i := 0
	while i < user_args.size():
		match user_args[i]:
			"--only":
				i += 1
				_only = user_args[i] if i < user_args.size() else ""
			"--gate-child":
				_gate_child = true
		i += 1

	var plan := _plan()
	var passed := 0
	var failed := 0
	var skipped: Array[String] = []

	# Un `--only` sbagliato non può produrre un gate verde con 0/0.
	if _only != "" and not plan.has(_only):
		print("FAIL gate: --only \"%s\" non corrisponde a nessun test previsto ne' scritto" % _only)
		print("GATE: 0/0")
		quit(1)
		return

	for name in plan:
		if _only != "" and name != _only:
			continue
		var path := "%s/%s.gd" % [TESTS_DIR, name]
		if not FileAccess.file_exists(path):
			print("SKIP %s: non scritto (previsto dal piano sez. 6)" % name)
			skipped.append(name)
			continue

		var output: Array = []
		var result := _run(path, output)
		var code: int = result[0]
		var timed_out: bool = result[1]
		var lines := _lines(output)
		var verdict := _verdict(lines)
		var errors := _engine_errors(lines)
		var reason := ""

		if timed_out:
			# Un test che si blocca è un FAIL dichiarato, non un gate congelato:
			# il figlio è stato ucciso e il motivo è il timeout, non il codice.
			reason = "timeout: il test non e' terminato entro %.1f s, processo ucciso" % (TEST_TIMEOUT_MS / 1000.0)
		elif not errors.is_empty():
			# Un errore di GDScript in un test è un FAIL anche se il test ha
			# stampato PASS ed è uscito 0: l'errore runtime aborta il resto della
			# funzione, quindi le asserzioni successive non girano e il verdetto
			# è green su un test che in realtà non è stato eseguito.
			reason = "SCRIPT ERROR durante il test: %s" % errors[0]
		elif code != 0:
			reason = "uscito con codice %d%s" % [code, "" if verdict != "" else " senza stampare un verdetto"]

		if verdict.begins_with("FAIL") or reason != "":
			failed += 1
			if verdict.begins_with("FAIL"):
				print(verdict)  # la riga del test è già nel formato giusto
			else:
				print("FAIL %s: %s" % [name, reason])
			if verdict.begins_with("PASS"):
				print("  anche: il test diceva PASS ma non puo' aver girato tutto")
			_dump(lines, verdict)
		else:
			passed += 1
			print("PASS %s" % name)
			_dump(lines, verdict)

	if not skipped.is_empty():
		print("GATE: eseguiti %d test, non scritti: %s (previsti dal piano sez. 6)" % [passed + failed, ", ".join(skipped)])

	# Un gate che non esegue niente non è verde: è rotto. `GATE: 0/0` con exit 0
	# è il falso verde peggiore, perché il vertice lo legge come un successo.
	if passed + failed == 0:
		print("FAIL gate: nessun test da eseguire")
		print("GATE: 0/0")
		quit(1)
		return

	# Il denominatore è quello che è stato davvero eseguito: un SKIP non è un
	# fallimento, quindi non può entrare nel conto. In w1: GATE: 1/1.
	print("GATE: %d/%d" % [passed, passed + failed])
	quit(0 if failed == 0 else 1)

## Previsti dal piano ∪ presenti su disco, in ordine alfabetico.
func _plan() -> Array[String]:
	var names: Array[String] = []
	for name in EXPECTED:
		names.append(name)
	if DirAccess.dir_exists_absolute(TESTS_DIR):
		for file in DirAccess.get_files_at(TESTS_DIR):
			if file.begins_with(PREFIX) and file.ends_with(".gd"):
				var name := file.get_basename()  # test_arena.gd → test_arena
				if not names.has(name):
					names.append(name)
	names.sort()
	return names

## Un test, un processo, con una scadenza. `output` accumula la stdout e la
## stderr del figlio (un SCRIPT ERROR su stderr deve finire nel motivo di un FAIL).
##
## Restituisce `[codice_uscita, scaduto]`. `scaduto` è vero solo se il figlio ha
## superato `TEST_TIMEOUT_MS` ed è stato ucciso: in quel caso il codice di uscita
## non significa niente e il ciclo principale deve usare il timeout come motivo.
func _run(path: String, output: Array) -> Array:
	var exe := OS.get_executable_path()
	var args := PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", path,
	])
	# Doppio vincolo anti-ricorsione, indipendenti: il test di fumo lancia il
	# gate che lo rilancia, e i due canali non possono fallire insieme.
	if _gate_child:
		args.append_array(["--", "--gate-child"])

	# Godot 4.7: `execute_with_pipe(path, args, blocking)` NON ha un parametro
	# `read_stderr` e restituisce un Dictionary, non un Array:
	#     { "pid": int, "stdio": FileAccess (stdin+stdout), "stderr": FileAccess }
	# stdout e stderr sono quindi DUE pipe separate: vanno lette ENTRAMBE,
	# altrimenti `_engine_errors` smette di vedere gli SCRIPT ERROR e il gate
	# perde il controllo piu' importante che ha. (Il diff in
	# docs/piramide/gate_timeout.md le assumeva fuse: era la sua seconda lacuna.)
	var handle := OS.execute_with_pipe(exe, args, false)
	if handle.is_empty():
		# Nessun handle: la pipe non è disponibile su questa piattaforma.
		# Non si torna a `OS.execute` perché significherebbe rinunciare al
		# timeout, che è il punto di questa funzione: si esegue e si dichiara.
		output.append("gate: execute_with_pipe non ha restituito un handle")
		return [OS.execute(exe, args, output, true, false), false]

	var pid: int = handle["pid"]
	var out_pipe: FileAccess = handle["stdio"]
	var err_pipe: FileAccess = handle["stderr"]
	var raw := PackedByteArray()
	var deadline := Time.get_ticks_msec() + TEST_TIMEOUT_MS
	var timed_out := false
	var alive := true

	while alive:
		_drain_into(out_pipe, raw)
		_drain_into(err_pipe, raw)
		alive = OS.is_process_running(pid)
		if alive and Time.get_ticks_msec() > deadline:
			timed_out = true
			OS.kill(pid)
			alive = false
		elif alive:
			OS.delay_msec(POLL_MS)

	# Ultimo giro: il processo è uscito, ma le pipe possono avere ancora roba
	# in transito. Senza questo l'ultima riga del test — quella che decide
	# PASS o FAIL — può perdersi proprio nel caso limite.
	_drain_into(out_pipe, raw)
	_drain_into(err_pipe, raw)
	if out_pipe != null:
		out_pipe.close()
	if err_pipe != null:
		err_pipe.close()

	if raw.size() > 0:
		output.append(raw.get_string_from_utf8())
	return [OS.get_process_exit_code(pid), timed_out]

## Legge tutto cio' che una pipe NON BLOCCANTE ha già pronto e lo accumula,
## senza mai attendere. In `blocking=false` una lettura torna subito, quindi un
## giro a vuoto è un giro a vuoto e non una scadenza mancata. I byte si
## accumulano e si decodificano una volta sola, alla fine: decodificare pezzo
## per pezzo spezzerebbe a metà un carattere multibyte sull'ultima riga, che è
## esattamente quella che decide PASS o FAIL.
func _drain_into(pipe: FileAccess, raw: PackedByteArray) -> void:
	if pipe == null:
		return
	while true:
		var chunk := pipe.get_buffer(65536)
		if chunk.is_empty():
			break
		raw.append_array(chunk)

## La stdout del test, divisa in righe.
##
## `execute_with_pipe` NON garantisce un elemento per riga: su Windows arriva un unico
## elemento con tutto il testo, con dentro i ritorni a capo. Se si scandisce
## `output` direttamente, una riga `FAIL ...` dentro quel blocco non è mai
## riconosciuta e il gate perde il motivo di ogni fallimento. Qui si appiattisce
## e da qui in poi le righe sono righe.
func _lines(output: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	for chunk in output:
		for raw in str(chunk).split("\n"):
			var text := raw.strip_edges()
			if text != "":
				lines.append(text)
	return lines

## L'ultima riga `PASS ...` / `FAIL ...` del test, o "" se non ce l'è.
func _verdict(lines: PackedStringArray) -> String:
	var found := ""
	for line in lines:
		if line.begins_with("PASS ") or line.begins_with("FAIL "):
			found = line
	return found

## Righe di errore del motore nella stdout+stderr del test. Non ci si fiderebbe
## del solo codice di uscita: vedi il commento sopra, nel ciclo dei test.
func _engine_errors(lines: PackedStringArray) -> PackedStringArray:
	var found := PackedStringArray()
	for line in lines:
		if (line.begins_with("SCRIPT ERROR") or line.begins_with("USER SCRIPT ERROR")
				or line.begins_with("ERROR:") or line.begins_with("USER ERROR:")):
			found.append(line)
	return found

## Eco della stdout del test, indentato, senza la riga di verdetto già riportata:
## un FAIL con due righe di contesto vale più di un FAIL muto.
func _dump(lines: PackedStringArray, skip: String) -> void:
	for line in lines:
		if line == skip or line.begins_with("Godot Engine v"):
			continue
		print("  | %s" % line)