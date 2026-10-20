# terminal-gun — design: integrazione comandi Linux nella pipeline (fornita dall'utente)

## Struttura dati in Godot: CommandResource
Invece di hardcodare i comandi, creare una classe basata su Resource (`CommandData.gd`) che definisce ogni singolo comando Linux:

- Nome del comando (es. grep, tar, chmod, ping)
- Tipo di nodo:
  - Command (attivo/spara qualcosa: echo, ping, curl)
  - Modifier (modifica il comportamento: -f, grep, chmod, sudo)
  - Operator (logica di flusso: |, &&, background)
- Costo RAM: quanti slot occupa nella stringa (comandi base costano 1, macro complesse come tar costano 2 o 3)
- Effetto / script logico: il pezzo di codice GDScript che si attiva quando la pipeline esegue quel nodo

## Distribuzione nel gioco
- Level-Up (3 carte): non solo potenziamenti numerici astratti, ma sblocco di nuovi token di comando o modificatori (es. la carta offre il token grep o il modificatore -f). Una volta scelto, entra nell'inventario dei comandi disponibili.
- Casse (sui 27 ostacoli): non danno XP permanente, ma possono rilasciare moduli temporanei o pacchetti compressi (stile tar) utilizzabili per quella run o per ricaricare la RAM istantaneamente.

## Esempi di integrazione nella pipeline
- Filtri di mira (05-text-processing): se il giocatore inserisce grep prima di un proiettile, la pipeline filtra i bersagli: il codice di sparo cicla i nemici nell'arena e seleziona solo quelli che corrispondono al criterio (es. solo i Brute o i Trojan), ignorando i runner minori.
- Compressione di payload (07-storage-archives): usare tar nella stringa permette di concatenare tre comandi ravvicinati (es. ping + cp + rm) trattandoli come un unico blocco compatto, riducendo il consumo totale di RAM e rilasciando un colpo combinato all'impatto.
- Automazione temporale (08-system-admin): il comando crontab agisce come trigger basato sul tempo: inserito nella pipeline, spara automaticamente un ping difensivo ogni 3 secondi senza premere il grilletto, aiutando a gestire le ondate quando accerchiato.

Questo è il focus per le armi.
