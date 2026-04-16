# Progetto_LP_2026 - Compilatore Regex in NFSA

Questo repository ospita l'implementazione di un compilatore da espressioni regolari (regex) ad Automi a Stati Finiti Non Deterministici (NFSA). Il progetto è stato sviluppato per il corso di Linguaggi di Programmazione e prevede due implementazioni distinte, scritte adottando due diversi paradigmi di programmazione: funzionale (Common Lisp) e logico (Prolog).

Il nucleo dell'algoritmo di conversione si basa sulla **Costruzione di Thompson** in entrambe le implementazioni.

## Struttura del Repository

Il progetto è organizzato in due macro-sezioni indipendenti. Ognuna contiene il proprio codice sorgente e un `README.txt` specifico che entra nel dettaglio tecnico delle scelte progettuali.

* 📂 **`Lisp/`**
    * Implementazione in **Common Lisp**.
    * Il file sorgente principale è `nfsa.lisp`.
    * Il `README.txt` dedicato spiega l'utilizzo delle struct, delle S-expressions per la rappresentazione dei dati e la logica ricorsiva applicata alle transizioni.

* 📂 **`Prolog/`**
    * Implementazione in **Prolog**.
    * Il file sorgente principale è `nfsa.pl`.
    * Il `README.txt` dedicato chiarisce la gestione del database dinamico (per il salvataggio in run-time degli stati dell'automa), l'uso della libreria `gensym` e la gestione dei funtori riservati.

> **Importante:** Si raccomanda di consultare i file `README.txt` presenti nelle rispettive cartelle per le istruzioni dettagliate sull'avvio, il caricamento dei file e l'architettura specifica di ogni linguaggio.

## Funzionalità Principali

Entrambi i moduli, pur differendo nel paradigma, espongono le stesse tre funzionalità fondamentali per interagire con le espressioni regolari:

1.  **Validazione (`is-regex` / `is_regex/1`)**:
    Controlla ricorsivamente che la struttura passata sia un'espressione regolare sintatticamente ben formata e valida, verificando la corretta applicazione degli operatori (sequenza `c`, alternativa `a`, chiusura di Kleene `z`, e operatore uno o più `o`).
2.  **Compilazione (`nfsa-compile-regex` / `nfsa_compile_regex/2`)**:
    Trasforma l'espressione regolare validata in un automa NFSA. Crea e collega dinamicamente gli stati attraverso le transizioni standard e le epsilon-mosse (transizioni vuote).
3.  **Riconoscimento (`nfsa-recognize` / `nfsa_recognize/2`)**:
    Prende in input un automa e una stringa (sotto forma di lista di simboli) e verifica, tramite algoritmi di backtracking, se la stringa appartiene al linguaggio definito dall'automa.

## Requisiti di Esecuzione

A seconda del modulo che si desidera testare, sono necessari i seguenti ambienti:
* **Prolog**: Un interprete Prolog (fortemente consigliato **SWI-Prolog**), che disponga del supporto alla libreria standard `gensym`.
* **Lisp**: Un interprete Common Lisp (es. LispWorks, SBCL, o equivalenti).
