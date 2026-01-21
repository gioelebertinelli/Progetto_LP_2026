================================================================================
                    COMPILATORE REGEX -> NFSA IN COMMON LISP
================================================================================

DESCRIZIONE:
------------
Implementazione in Common Lisp di un compilatore da espressioni regolari a
automi finiti non deterministici (NFSA). Il programma permette di compilare
regex e riconoscere se una stringa appartiene al linguaggio definito.

REQUISITI:
----------
- Interprete Common Lisp (consigliato: Lispworks Personal Edition)
- Versione: ultima disponibile

ESECUZIONE:
-----------
1. Caricare il file nell'interprete Lisp:
   
   (load "nfsa.lisp")

2. Le funzioni principali saranno disponibili automaticamente.

FUNZIONI PRINCIPALI:
--------------------

1. is-regex (RE)
   Controlla se l'espressione RE è una regex valida.
   Ritorna T se RE è una regex valida, NIL altrimenti.

2. nfsa-compile-regex (RE)
   Compila un'espressione regolare in un automa finito non deterministico.
   Ritorna l'automa (struct nfsa) se RE è valida, NIL altrimenti.

3. nfsa-recognize (FA Input)
   Riconosce se l'input appartiene al linguaggio dell'automa FA.
   Ritorna T se l'input viene accettato, NIL altrimenti.
   Genera un errore se FA non è un automa valido o Input non è una lista.

ESEMPI DI UTILIZZO:
-------------------

;; Compilare una regex semplice
(defvar *automa1* (nfsa-compile-regex 'a))

;; Riconoscere una stringa
(nfsa-recognize *automa1* '(a))        ; -> T
(nfsa-recognize *automa1* '(b))        ; -> NIL

;; Regex più complessa
(defvar *automa2* (nfsa-compile-regex '(c a b)))
(nfsa-recognize *automa2* '(a b))      ; -> T

FUNZIONI HELPER (INTERNE):
--------------------------

1. recognize-from-state (current-state remaining-input final-states transitions)
   Funzione ricorsiva che esplora l'automa con backtracking.
   
   Parametri:
   - current-state: lo stato corrente in cui ci si trova
   - remaining-input: la lista di simboli ancora da consumare
   - final-states: lista degli stati finali
   - transitions: lista di tutte le transizioni dell'automa
   
   Logica:
   1. Se l'input è finito E ci si trova in uno stato finale -> successo (T)
   2. Altrimenti si provano tutte le transizioni possibili
   3. Se almeno UN percorso porta al successo -> T, altrimenti NIL

2. try-symbol-transitions (current-state remaining-input final-states transitions)
   Prova tutte le transizioni che consumano il prossimo simbolo dell'input.
   Ritorna T se almeno una porta al successo, NIL altrimenti.

3. try-epsilon-transitions (current-state remaining-input final-states transitions)
   Prova tutte le epsilon-transizioni (quelle con simbolo NIL).
   Non consumano input, quindi si passa lo stesso remaining-input.
   Ritorna T se almeno una porta al successo, NIL altrimenti.

NOTE SULL'IMPLEMENTAZIONE:
---------------------------

1. BACKTRACKING:
   La funzione 'some' esplora tutte le possibilità e ritorna T appena una
   ha successo.

2. EPSILON-TRANSIZIONI:
   Sono cruciali per gli operatori z (chiusura di Kleene) e a (alternativa) perché
   permettono di "saltare" senza consumare input.

3. CONFRONTO SIMBOLI:
   Si usa 'equal' invece di 'eql' perché i simboli possono essere liste
   (S-expressions).
   Esempio: il simbolo (foo bar) deve matchare con (foo bar).

4. SEPARAZIONE LOGICA:
   L'implementazione separa in 3 funzioni helper per chiarezza:
   - recognize-from-state: coordina la ricorsione principale
   - try-symbol-transitions: gestisce transizioni che consumano simboli
   - try-epsilon-transitions: gestisce epsilon-transizioni

5. ORDINE DI PROVA:
   Si provano prima le transizioni normali, poi le epsilon. In realtà per
   un NFSA l'ordine non dovrebbe cambiare il risultato finale (o accetta
   o no), ma può influenzare l'efficienza.

================================================================================