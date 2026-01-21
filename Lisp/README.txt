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
- Interprete Common Lisp (Lispworks Personal Edition)

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
   
   Casistiche:
   - Lista vuota: NIL (non valida)
   - Atomo: T (sempre valido, anche 'a, 'c, 'z, 'o quando usati come simboli)
   - Lista con operatore 'c' (sequenza): valida se ha almeno un argomento
     e tutti gli argomenti sono regex valide
   - Lista con operatore 'a' (alternativa): valida se ha almeno un argomento
     e tutti gli argomenti sono regex valide
   - Lista con operatore 'z' (chiusura di Kleene): valida se ha esattamente
     un argomento che è una regex valida
   - Lista con operatore 'o' (uno o più): valida se ha esattamente un argomento
     che è una regex valida
   - Lista che non inizia con operatori riservati (c, a, z, o): T (S-expression
     che rappresenta un simbolo dell'alfabeto, es: (foo bar))

2. nfsa-compile-regex (RE)
   Compila un'espressione regolare in un automa finito non deterministico.
   Ritorna l'automa (struct nfsa) se RE è valida, NIL altrimenti.

3. nfsa-recognize (FA Input)
   Riconosce se l'input appartiene al linguaggio dell'automa FA.
   Ritorna T se l'input viene accettato, NIL altrimenti.
   Genera un errore se FA non è un automa valido.

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

1. recognize-from-state (current-state remaining-input final-states 
                        transitions visited-epsilon)
   Funzione ricorsiva che esplora l'automa con backtracking.
   
   Parametri:
   - current-state: lo stato corrente in cui ci si trova
   - remaining-input: la lista di simboli ancora da consumare
   - final-states: lista degli stati finali
   - transitions: lista di tutte le transizioni dell'automa
   - visited-epsilon: lista degli stati visitati per epsilon-transizioni
                     (usato per prevenire loop infiniti)
   
   Comportamento:
   1. Se l'input è finito: controlla se si è in uno stato finale o se è
      raggiungibile uno stato finale tramite epsilon-transizioni
   2. Se c'è ancora input: prova prima le transizioni che consumano simboli,
      poi le epsilon-transizioni
   3. Ritorna T se almeno UN percorso porta al successo, NIL altrimenti

2. try-symbol-transitions (current-state remaining-input final-states transitions)
   Prova tutte le transizioni che consumano il prossimo simbolo dell'input.
   
   Parametri:
   - current-state: lo stato corrente
   - remaining-input: lista dei simboli ancora da consumare
   - final-states: lista degli stati finali
   - transitions: lista di tutte le transizioni
   
   Comportamento:
   - Cerca transizioni applicabili dallo stato corrente che:
     1. Partono dallo stato corrente
     2. Hanno un simbolo non-NIL (non epsilon)
     3. Il simbolo matcha con il primo simbolo di remaining-input
   - Dopo una transizione simbolo, resetta visited-epsilon (si può ri-entrare
     in stati già visitati)
   - Ritorna T se almeno una porta al successo, NIL altrimenti

3. try-epsilon-transitions (current-state remaining-input final-states 
                           transitions visited-epsilon)
   Prova tutte le epsilon-transizioni (quelle con simbolo NIL).
   
   Parametri:
   - current-state: lo stato corrente
   - remaining-input: lista dei simboli ancora da consumare (non consumato)
   - final-states: lista degli stati finali
   - transitions: lista di tutte le transizioni
   - visited-epsilon: lista degli stati già visitati per epsilon-transizioni
   
   Comportamento:
   - Implementa controllo anti-loop: se current-state è già in visited-epsilon,
     ritorna NIL immediatamente
   - Aggiunge current-state a visited-epsilon prima di esplorare
   - Non consuma input (remaining-input rimane invariato)
   - Ritorna T se almeno una porta al successo, NIL altrimenti

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

4. ORDINE DI PROVA:
   Si provano prima le transizioni normali, poi le epsilon. 

5. PREVENZIONE LOOP INFINITI:
   Le epsilon-transizioni possono creare cicli infiniti. Per prevenirli,
   recognize-from-state mantiene una lista visited-epsilon degli stati
   visitati tramite epsilon-transizioni. Quando si prova una epsilon-transizione,
   lo stato corrente viene aggiunto a visited-epsilon prima dell'esplorazione.
   Se uno stato è già in visited-epsilon, si ferma l'esplorazione da quello stato.
   Nota: visited-epsilon viene resettato dopo una transizione simbolo, permettendo
   di ri-entrare in stati già visitati quando si consuma input.

================================================================================