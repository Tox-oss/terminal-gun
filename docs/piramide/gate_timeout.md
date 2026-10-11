# `tools/gate.gd`: timeout per test — applicazione pronta, in attesa del permesso

**Stato: scritto e non applicato.** Il vertice ha ricevuto `Permission denied: edit`
su `tools/gate.gd`, che il piano §3.3 gli assegna. Per §11.5 il vertice non puo'
riscrivere la propria allowlist, quindi **la riga che abilita questa modifica e'
dell'utente** (vedi in fondo).

Questo file contiene **la modifica esatta**, non un'idea: e' un diff unificato su
`tools/gate.gd`. Serve a chiudere il **criterio n. 6 di m2** e il debito di m1
«il gate non ha timeout».

## Perche' serve e perche' non basta un `if` qualsiasi

Oggi il gate chiama `OS.execute`, che e' **bloccante e senza scadenza**: un test che
si blocca blocca il gate, e il vertice non distingue «il test e' lento» da «il test
e' impiantato». La soluzione non e' un timeout intorno a `OS.execute`, perche' durante
l'attesa non si puo' ne' leggere l'output ne' sapere se il figlio e' vivo.

`OS.execute_with_pipe(exe, args, blocking=false, read_stderr=true)` restituisce
`[pid, pipe]`: con il **pid** si puo' sorvegliare `OS.is_process_running`, e con la
**pipe** si puo' leggere l'output a pezzi mentre si aspetta. Le due cose che
`OS.execute` faceva — catturare la stdout per il **motivo** di un FAIL e usare il
**codice di uscita** come verdetto — restano intatte. Sul timeout si chiama
`OS.kill(pid)` e il test diventa un **FAIL dichiarato**.

## Il diff

```diff
--- a/tools/gate.gd
+++ b/tools/gate.gd
@@ -12,10 +12,15 @@
 ## né falsare i test successivi. Il verdetto di un test è il suo codice di uscita;
 ## il motivo di un FAIL è la sua stdout.
 ##
-## NOTA: `OS.execute` è bloccante e senza timeout. Un test che si blocca
-## blocca il gate: è una scelta consapevole, perché il gate deve poter
-## stampare il perché di un fallimento e `OS.execute` è l'unica API che
-## cattura la stdout. Se un test si blocca, il rimedio è nel test.
+## TIMEOUT PER TEST (criterio n. 6 di m2, debito di m1 chiuso). Un test che si
+## blocca non blocca più il gate: il figlio viene sorvegliato e, superata la
+## soglia, ucciso con `OS.kill` e riportato come FAIL dichiarato.
+##
+## Perché `OS.execute_with_pipe` e non `OS.execute`: `OS.execute` cattura la
+## stdout ma è BLOCCANTE e senza timeout, quindi non può fare le due cose.
+## `execute_with_pipe` in modo non bloccante restituisce sia il pid sia la pipe:
+## si legge a pezzi mentre si sorveglia `OS.is_process_running`. Il verdetto
+## resta il codice di uscita del figlio, il motivo resta la sua stdout.
 ##
 ## SKIP non è un fallimento: un test previsto e non ancora scritto non deve
 ## far fallire l'onda che sta costruendo le altre foglie. Il vertice legge
@@ -27,6 +32,13 @@
 
 const TESTS_DIR := "res://tests"
 const PREFIX := "test_"
+
+## Scadenza per un singolo test. Generosa abbastanza da non tagliare un test
+## legittimamente lento su una macchina carica, e abbastanza stretta da non
+## congelare un gate per sempre. I test di oggi durano da 0.16 s a pochi secondi:
+## il margine e' di un ordine di grandezza, non di un soffio.
+const TEST_TIMEOUT_MS := 120000
+const POLL_MS := 5

 ## I test che il piano (docs/piramide/piano.md §6) prevede. Un file scritto da
 ## una foglia e non qui dentro viene comunque eseguito: questa lista serve solo
 ## a poter dire SKIP su un test che non è ancora stato scritto.
@@ -74,8 +86,10 @@
 			continue
 
 		var output: Array = []
-		var code := _run(path, output)
+		var result := _run(path, output)
+		var code: int = result[0]
+		var timed_out: bool = result[1]
 		var lines := _lines(output)
 		var verdict := _verdict(lines)
 		var errors := _engine_errors(lines)
 		var reason := ""
 
-		if not errors.is_empty():
+		if timed_out:
+			# Un test che si blocca è un FAIL dichiarato, non un gate congelato:
+			# il figlio è stato ucciso e il motivo è il timeout, non il codice.
+			reason = "timeout: il test non e' terminato entro %.1f s, processo ucciso" % (TEST_TIMEOUT_MS / 1000.0)
+		elif not errors.is_empty():
 			# Un errore di GDScript in un test è un FAIL anche se il test ha
 			# stampato PASS ed è uscito 0: l'errore runtime aborta il resto della
 			# funzione, quindi le asserzioni successive non girano e il verdetto
@@ -134,19 +148,52 @@
 	names.sort()
 	return names
 
-## Un test, un processo. `output` accumulates le righe di stdout (e stderr,
-## perché un SCRIPT ERROR deve finire nel motivo di un FAIL).
-func _run(path: String, output: Array) -> int:
+## Un test, un processo, con una scadenza. `output` accumula le righe di stdout
+## (e stderr, perché un SCRIPT ERROR deve finire nel motivo di un FAIL).
+##
+## Restituisce `[codice_uscita, scaduto]`. `scaduto` è vero solo se il figlio ha
+## superato `TEST_TIMEOUT_MS` ed è stato ucciso: in quel caso il codice di uscita
+## non significa niente e il ciclo principale deve usare il timeout come motivo.
+func _run(path: String, output: Array) -> Array:
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
-	return OS.execute(exe, args, output, true, false)
+
+	var handle := OS.execute_with_pipe(exe, args, false, true)
+	if handle.is_empty():
+		# Nessun handle: la pipe non è disponibile su questa piattaforma.
+		# Non si torna a `OS.execute` perché significherebbe rinunciare al
+		# timeout, che è il punto di questa funzione: si esegue e si dichiara.
+		output.append("gate: execute_with_pipe non ha restituito un handle")
+		return [OS.execute(exe, args, output, true, false), false]
+
+	var pid: int = handle[0]
+	var pipe: FileAccess = handle[1]
+	var text := ""
+	var deadline := Time.get_ticks_msec() + TEST_TIMEOUT_MS
+	var timed_out := false
+	var alive := true
+
+	while alive:
+		# Si legge solo cio' che c'è: `get_buffer` su una pipe non bloccante
+		# con 0 byte disponibili resterebbe in attesa, che è proprio la
+		# scadenza che si sta cercando di evitare.
+		if pipe != null:
+			var avail := pipe.get_available_bytes()
+			if avail > 0:
+				text += pipe.get_buffer(avail).get_string_from_utf8()
+		alive = OS.is_process_running(pid)
+		if alive and Time.get_ticks_msec() > deadline:
+			timed_out = true
+			OS.kill(pid)
+			alive = false
+		elif alive:
+			OS.delay_msec(POLL_MS)
+
+	# Ultimo giro: il processo è uscito, ma la pipe può avere ancora roba
+	# in transito. Senza questo l'ultima riga del test — quella che decide
+	# PASS o FAIL — può perdersi proprio nel caso limite.
+	if pipe != null:
+		while true:
+			var avail := pipe.get_available_bytes()
+			if avail <= 0:
+				break
+			text += pipe.get_buffer(avail).get_string_from_utf8()
+		pipe.close()
+
+	if text != "":
+		output.append(text)
+	return [OS.get_process_exit_code(pid), timed_out]
```

## Cosa va verificato dopo averlo applicato

Non basta che il gate resti verde: **una porta che non si sa far fallire non e' una
porta**, e questa ne introduce un path nuovo. Quindi:

1. **Il gate normale deve restare identico**: stesso `GATE: N/N`, stesso verdetto per
   ogni test, stessi motivi di FAIL. `execute_with_pipe` cambia il modo di leggere
   l'output, e i motivi di FAIL passano da `output` come **array di elementi** a **un
   solo blocco di testo**: `_lines()` gia' appiattisce su `\n`, quindi la forma e'
   compatibile, ma va **controllata con un test che fallisce davvero**, non con uno
   che passa.
2. **Il timeout deve poter scattare**: un test che si blocca deve diventare
   `FAIL <nome>: timeout: ...`, non un gate fermo. Il modo piu' onesto di provarlo e'
   un test finto che dorme, eseguito una volta a mano con `--only`, **non** lasciato
   nel repo: un test che dorme apposta e' un debito che qualcuno prima o poi dimentica
   di togliere.
3. **`OS.kill` va provato davvero**: se il figlio sopravvive, il gate dichiara un
   timeout che non c'e'. Il controllo e' `OS.is_process_running(pid)` dopo il `kill`.

## La riga che serve all'utente

Nel blocco `edit` di **`terminal-gun.md`**, accanto agli altri allow di scrittura del
vertice (quelli per `src/core/contracts.gd`, `tools/env.sh`, `tools/check_perms.py`):

```yaml
  - action: edit
    resource: "tools/gate.gd"
```

Poi **gli stessi due passi del 2026-10-06**, perche' `perm_mirror` confronta byte e
non testo normalizzato:

```sh
# nel repo (mirror, fonte di verità)
# poi in ~/.config/opencode/agents/ (installazione)
# poi: riavviare opencode, i permessi si caricano all'avvio
```

E **insieme** la stessa riga in `SCOPE` dentro `tools/check_perms.py`, che e' scope
del vertice: senza quella, `perm_scope` confronta l'allow nuovo contro uno `SCOPE` che
non lo contiene e va rosso al primo check. Il vertice puo' applicare quella meta' da
solo, appena la prima meta' e' a terra.

**Verifica finale, due numeri separati e non uno:**

```sh
godot --headless --path . --script tools/gate.gd   # GATE: N/N
python tools/check_perms.py                          # PERM: 15/15
```
