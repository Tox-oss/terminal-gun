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
## NOTA: `OS.execute` è bloccante e senza timeout. Un test che si blocca
## blocca il gate: è una scelta consapevole, perché il gate deve poter
## stampare il perché di un fallimento e `OS.execute` è l'unica API che
## cattura la stdout. Se un test si blocca, il rimedio è nel test.
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
		var code := _run(path, output)
		var lines := _lines(output)
		var verdict := _verdict(lines)
		var errors := _engine_errors(lines)
		var reason := ""

		if not errors.is_empty():
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

## Un test, un processo. `output` accumulates le righe di stdout (e stderr,
## perché un SCRIPT ERROR deve finire nel motivo di un FAIL).
func _run(path: String, output: Array) -> int:
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
	return OS.execute(exe, args, output, true, false)

## La stdout del test, divisa in righe.
##
## `OS.execute` NON garantisce un elemento per riga: su Windows arriva un unico
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