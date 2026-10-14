# Contratto di consegna per `kiro-cli`

Regola che vale per **qualsiasi** agente lanciato fuori da opencode, cioè con
`kiro-cli --no-interactive --trust-all-tools`. Vedi piano §1.14-undicesima per il fatto che
l'ha resa necessaria.

## Perché questo file esiste

`kiro-cli --trust-all-tools` **non ha allowlist**: può scrivere ovunque. E
`tools/check_perms.py` confronta i file di agente **opencode** contro `LEAVES` e `SCOPE`, quindi
**non vede un agente kiro**. Senza questo contratto, `PERM: 15/15` continuerebbe a significare
«i quindici permessi dei quindici agenti che conosco» e non «niente sta scrivendo fuori scope»:
una porta che mente per definizione, che è la classe di difetto che questo progetto ha già chiuso
tre volte (sonda mai eseguita, asserzione decorativa, criterio che nasce verde).

**Quindi: due canali, un solo verdetto.** Il commit è del vertice. `GATE` è l'unico che dichiara
verde. Un agente esterno produce file e numeri; **non dichiara niente**.

## Le quattro regole, in ordine di importanza

### 1. Se non puoi eseguire il test, non scrivere codice

`shell` è stato negato a un agente per tutta una sessione, e quello ha lasciato
`tests/test_orda.gd` **non compilante** con sei parse error. Quello è successo **quattro volte**
oggi. Un file non compilante è la cosa peggiore che si possa lasciare.

Se il comando di test non parte, il turno finisce lì con **«non eseguito»** e niente scritto.
Mezzo lavoro verificato batte tutto non eseguito.

### 2. Esegui il test dopo ogni edit, non alla fine

Il costo di ogni sezione va stampato. `TEST_TIMEOUT_MS` è **120 s** e l'utente ha deciso che **non
si alza**: se il tuo lavoro non ci sta, **la sezione si fa piccola**.

### 3. Non spostare un tetto per far entrare il numero

Se una banda cede, un tetto si allarga o una soglia si alza, quello è un **risultato**, non un
ostacolo: si scrive accanto al numero di prima e si dice che è successo. Spostare un tetto perché
il codice non ci arriva è il difetto che questo progetto vieta più spesso.

### 4. I denti si provano e si tolti

Se per far cadere un criterio metti un blocco di prova, **tiralo fuori dal file** prima di
finire. Una prova lasciata dentro è un numero che il prossimo leggerà come se fosse vivo.

## Cosa deve contenere il rapporto finale

Cinque righe, e ognuna con il numero o con la parola che la rende inutile:

1. `cosa fatto` — una frase
2. `file toccati` — i percorsi esatti, e `nessuno` se nessuno
3. **`PASS` + il numero di asserzioni, oppure il numero dell'errore** e il costo in ms
4. il numero che il lavoro cambia, **prima e dopo nella stessa frase**
5. che cosa **non** è stato fatto e resta aperto

Se una riga non la puoi riempire, **quella riga è il rapporto**: «non eseguito» è una risposta
valida, inventare un numero non lo è.

## Le due cose che non sono negoziabili

- **Il commit è del vertice.** Mai `git add`, mai `git commit`, mai `git checkout`, mai `git clean`.
- **La porta è del vertice.** Mai `godot --headless --path . --script tools/gate.gd`, mai
  `python tools/check_perms.py`, mai `--import`. Tu esegui **solo il test del tuo file**.

E se un turno finisce e l'albero è sporco, **dillo**: il vertice ripristina, e dirlo vale più che
lasciare mezza cosa e sperare.

## Il primo canale, che è anche il più pericoloso

`kiro-cli` **può scrivere in qualunque file** perché non ha allowlist. Questo contratto è quindi
**l'unico** confine che ha. Trattalo come un muro di vetro: dice che c'è, ma non impedisce niente,
e se lo ignori la porta non se ne accorge.

## Stato del canale

`kiro-cli-chat 2.31.0`, verificato il 2026-10-14 con
`kiro-cli chat --no-interactive --trust-all-tools`, che ha risposto `PRONTO`.
Quindi il binario c'è, l'account risponde, e la **quota è diversa** da quella di opencode: è il
motivo per cui il canale esiste.
