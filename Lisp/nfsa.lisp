; Bertinelli	Gioele	923893
; Gianoli	Matteo	924072
; Martinalli	Marco	924003

;;; ----------------------------------------------------------------------------
;;; FUNZIONE: is-regex
;;; Controlla se l'espressione RE è una regex valida
;;; Ritorna T se RE e' una regex valida, NIL altrimenti
;;; ----------------------------------------------------------------------------

(defun is-regex (RE)
  
  (cond
   
   ; Lista vuota non e' una regex valida
   ((null RE) nil)
   
   ;; Caso base: un atomo (simbolo o numero) e' sempre una regex valida
   ;; Questo include anche 'a, 'c, 'z, 'o quando sono usati come simboli
   ((atom RE) t)
   
   ;; Caso lista: dobbiamo controllare se e' un operatore valido
   ((listp RE)
    (cond
     
     ;; Operatore 'c' (sequenza): deve avere almeno un argomento
     ;; e tutti gli argomenti devono essere regex valide
     ((eq (first RE) 'c)
      (and (>= (length (rest RE)) 1)  ; almeno un argomento
           (every #'is-regex (rest RE))))  ; controllo ricorsivo
     
     ;; Operatore 'a' (alternativa): deve avere almeno un argomento
     ;; e tutti gli argomenti devono essere regex valide
     ((eq (first RE) 'a)
      (and (>= (length (rest RE)) 1)
           (every #'is-regex (rest RE))))
     
     ;; Operatore 'z' (stella di Kleene): deve avere esattamente un argomento
     ;; che deve essere una regex valida
     ((eq (first RE) 'z)
      (and (= (length (rest RE)) 1)  ; esattamente un argomento
           (is-regex (second RE))))  ; controllo ricorsivo
     
     ;; Operatore 'o' (uno-o-piu'): deve avere esattamente un argomento
     ;; che deve essere una regex valida
     ((eq (first RE) 'o)
      (and (= (length (rest RE)) 1)
           (is-regex (second RE))))
     
     ;; Se il primo elemento NON e' uno degli operatori riservati (c, a, z, o),
     ;; allora questa e' una S-expression che rappresenta un simbolo dell'alfabeto
     ;; e quindi e' una regex valida
     ;; Esempio: (foo bar) e' un simbolo valido dell'alfabeto
     (t t)))
   
   ;; Altri casi (per evitare bug)
   (t nil)))


;;; ----------------------------------------------------------------------------
;;; FUNZIONE: nfsa-compile-regex
;;; ritorna l’automa ottenuto dalla compilazione di RE, se è 
;;; un’espressione regolare, altrimenti ritorna NIL.
;;; ----------------------------------------------------------------------------

;;; Definizione della struttura dell'automa (NFSA)
(defstruct nfsa
  initial    ; Stato iniziale
  finals     ; Lista degli stati finali
  delta)     ; Lista delle transizioni (stato-da input stato-a)

;;; Helper per creare una transizione. 
;;; Se l'input è NIL, rappresenta una epsilon-transizione.
(defun make-transition (from input to)
  (list from input to))

;;;----------------------------------------------------------------------------
;;; FUNZIONE HELPER
;;; Funzione che compila ricorsivamente la regex.
;;; Ritorna una lista di tre elementi:
;;; (stato-inizio stato-fine lista-transizioni)
(defun compile-recursive (re)
  (cond
    ;; CASO BASE: Atomo o primo elemento della lista non è una operazione
    ((or (atom re)
         (and (listp re) 
              (not (member (first re) '(c a z o)))))
     ;; con gensym assegno etichetta allo stato iniziale e a quello finale        
     (let ((start (gensym "Q")) 
           (end (gensym "Q")))
        ;; lista che contiene lo stato iniziale, finale e una lista con
        ;; la transizione
       (list start 
             end 
             (list (make-transition start re end)))))

    ;; CASO 2: Concatenazione ('c')
    ((eq (first re) 'c)
     ;; la funzione reduce permette di usare una unica lista per effettuare 
     ;; la funzione lambda su tutte le chiamate ricorsive della funzione 
     ;; "compile-recursive"  la funzione lambda concatena l'automa parziale 
     ;; con l'automa del simbolo successivo in particolare crea una lista con:
     ;; stato inizale è lo stato iniziale automa parziale
     ;; stato finale è lo stato finale del'automa da concatenare.
     ;; con un append mette in un unica lista le transizioni dei 2 e la 
     ;; epsilon mossa.
     (reduce (lambda (actual-automa concat-automa)
               (list (first actual-automa)
                     (second concat-automa)        
                     (append (third actual-automa) 
                             (third concat-automa)  
                             ;; effettua una epsilon-mossa per concatenare
                             ;; lo stato finale dell'automa parziale con lo
                             ;; stato iniziale dell'automa da concatenare 
                             (list (make-transition (second actual-automa) 
                                                    nil 
                                                    (first concat-automa))))))
             (mapcar #'compile-recursive (rest re))))

    ;; CASO 3: Alternativa ('a')
    ((eq (first re) 'a)
    ;; con gensym assegno etichetta allo stato iniziale e a quello finale   
     (let ((start (gensym))
           (end (gensym)))
       ;; crea una lista con stato iniziale, finale, e una lista con le 
       ;; transizioni
       (list start
             end
             (apply #'append 
                    ;; esegue questa operazione su tutto il resto della re
                    (mapcar (lambda (sotto-regex)
                              ;; la funzione lambda genera l'automa per la
                              ;; sotto-regex e definisce stato iniziale,
                              ;; stato finale e transizioni usando la 
                              ;; struttura della lista
                              (let* ((child-automa 
                                      (compile-recursive sotto-regex))
                                     (start-child (first child-automa))
                                     (end-child  (second child-automa))
                                     (trans-child 
                                      (third child-automa)))
                                ;; con le epsilon mosse fa le transizioni
                                ;; tra stato iniziale e stato iniziale figlio
                                ;; e tra stato finale figlio e stato finale
                                ;; e con append le unisce alle transizioni
                                ;; dell' automa figlio
                                (append (list (make-transition start 
                                                               nil 
                                                               start-child)
                                              (make-transition end-child 
                                                               nil 
                                                               end))
                                        trans-child)))
                            (rest re))))))

    ;; CASO 4: Stella di Kleene ('z')
    ((eq (first re) 'z)
      ;; si usa let* perchè usando let non potrei usare nelle definizioni
      ;; successive quelle create in precedenza perchè con let vengono 
      ;; create tutte in contemporanea
      ;; viene creato un automa usando le chiamate ricorsive per analizzare
      ;; ogni simbolo della re
     (let* ((symbol-automa      (compile-recursive (second re)))
            (start-symbol      (first symbol-automa))
            (end-symbol      (second symbol-automa))
            (trans-symbol  (third symbol-automa))
            ;; con gensym assegno etichetta a stato inziale e finale
            (start (gensym))
            (end   (gensym)))
       ;; creo lista con stato iniziale, finale e transizioni
       (list start
             end
                           ;; con una epsilon mossa entra nel simbolo
             (append (list (make-transition start nil start-symbol)
                           ;; dall'ultimo va allo stato finale
                           (make-transition end-symbol nil end) 
                           ;; fa il loop: ovvero transizione che dall'ultimo
                           ;; torna al primo   
                           (make-transition end-symbol nil 
                                            start-symbol)  
                           ;; è presente 0 volte, quindi basta una epsilon
                           ;; mossa      
                           (make-transition start nil end))          
                     trans-symbol))))

    ;; CASO 5: Uno o più ('o')
    ;; Funziona esattamente come la chiusura di Kleene solo che non c'è
    ;; il caso skip perchè non possono esserci 0 volte.
    ((eq (first re) 'o)
     (let* ((automa-interno      (compile-recursive (second re)))
            (inizio-interno      (first automa-interno))
            (fine-interna        (second automa-interno))
            (transizioni-interne (third automa-interno))
            (start (gensym))
            (end   (gensym)))
       (list start
             end
             (append (list (make-transition start nil inizio-interno)
                           (make-transition fine-interna nil end)     
                           (make-transition fine-interna nil 
                                            inizio-interno))           
                     transizioni-interne))))))

;;; --------------------------------------------------------------------------
;;; FUNZIONE PRINCIPALE

(defun nfsa-compile-regex (RE)
  (if (is-regex RE)
      (let ((result (compile-recursive RE)))
        ;; una volta creata la struct Lisp genera questa funzioni per 
        ;;costruire gli elementi.
        (make-nfsa :initial (first result)
                   :finals (list (second result))
                   :delta (third result)))
      nil))
;;; --------------------------------------------------------------------------

;; Dichiarazione funzioni per evitare warning 
;; (nel caso venga chiamata prima di essere letta)
(declaim (ftype (function (t t t t t) t) recognize-from-state))
(declaim (ftype (function (t t t t t) t) try-epsilon-transitions))
(declaim (ftype (function (t t t t) t) try-symbol-transitions))

;;; ----------------------------------------------------------------------------
;;; FUNZIONE HELPER: try-epsilon-transitions
;;; Prova tutte le epsilon-transizioni (quelle con simbolo NIL)
;;; Non consumano input, quindi passiamo lo stesso remaining-input
;;; Ritorna T se almeno una porta al successo, NIL altrimenti
;;; ----------------------------------------------------------------------------


(defun try-epsilon-transitions (current-state remaining-input final-states 
                                transitions visited-epsilon)
  
  ;; CONTROLLO ANTI-LOOP: Se questo stato è già in visited-epsilon, FERMATI!
  (when (member current-state visited-epsilon)
    (return-from try-epsilon-transitions nil))
  
  ;; Aggiungi current-state ai visitati PRIMA di esplorare
  (let ((new-visited (cons current-state visited-epsilon)))
    (some #'(lambda (trans)
              (let ((from-state (first trans))
                    (symbol (second trans))
                    (to-state (third trans)))
                (when (and (eql from-state current-state)
                          (null symbol))
                  ;; Passa new-visited alla chiamata ricorsiva
                  (recognize-from-state to-state remaining-input final-states 
                                      transitions new-visited))))
          transitions)))


;;; ----------------------------------------------------------------------------
;;; FUNZIONE HELPER: try-symbol-transitions
;;; Prova tutte le transizioni che consumano il prossimo simbolo dell'input
;;; Ritorna T se almeno una porta al successo, NIL altrimenti
;;; ----------------------------------------------------------------------------

(defun try-symbol-transitions (current-state remaining-input final-states 
                               transitions)
  (when remaining-input  ; Controllo di sicurezza
    (let ((next-symbol (first remaining-input))
          (rest-input (rest remaining-input)))
      
      ;; Troviamo tutte le transizioni applicabili dallo stato corrente
      ;; che consumano esattamente il prossimo simbolo
      (some #'(lambda (trans)
                (let ((from-state (first trans))
                      (symbol (second trans))
                      (to-state (third trans)))
                  
                  ;; Controlliamo se questa transizione e' applicabile:
                  ;; 1. Parte dallo stato corrente
                  ;; 2. Il simbolo corrisponde (NON e' epsilon)
                  ;; 3. Il simbolo matcha con next-symbol
                  (when (and (eql from-state current-state)
                            (not (null symbol))  ; NON epsilon
                            (equal symbol next-symbol))
                    
                    ;; Proviamo a continuare da questo nuovo stato
                    ;; consumando il resto dell'input
                    ;; IMPORTANTE: resettiamo visited-epsilon 
                    (recognize-from-state to-state rest-input final-states 
                                         transitions '()))))
            transitions))))


;;; ----------------------------------------------------------------------------
;;; FUNZIONE HELPER: recognize-from-state
;;; Funzione ricorsiva che esplora l'automa con backtracking
;;; 
;;; Parametri:
;;;   current-state: lo stato in cui ci troviamo ora
;;;   remaining-input: la lista di simboli ancora da consumare
;;;   final-states: lista degli stati finali
;;;   transitions: lista di tutte le transizioni dell'automa
;;;
;;; Logica:
;;;   1. Se l'input e' finito E siamo in uno stato finale -> successo (T)
;;;   2. Altrimenti proviamo tutte le transizioni possibili
;;;   3. Se almeno UN percorso porta al successo -> T, altrimenti NIL
;;; ----------------------------------------------------------------------------

(defun recognize-from-state (current-state remaining-input final-states 
                             transitions visited-epsilon)
  (cond
   ;; CASO BASE: Input esaurito
   ;; Controlliamo se siamo in uno stato finale
   ((null remaining-input)
    (if (member current-state final-states)
        t  ; Successo! Abbiamo riconosciuto l'input
        ;; Anche se l'input e' finito, potremmo raggiungere uno stato finale
        ;; tramite epsilon-transizioni, quindi le proviamo
        (try-epsilon-transitions current-state remaining-input final-states 
                                transitions visited-epsilon)))
   
   ;; CASO RICORSIVO: Abbiamo ancora simboli da consumare
   (t
    ;; Proviamo prima le transizioni che consumano il prossimo simbolo
    ;; e poi le epsilon-transizioni (per esplorarle tutte)
    (or (try-symbol-transitions current-state remaining-input final-states 
                               transitions)
        (try-epsilon-transitions current-state remaining-input final-states 
                                transitions visited-epsilon)))))


;;; ----------------------------------------------------------------------------
;;; FUNZIONE: nfsa-recognize
;;; Riconosce se l'input appartiene al linguaggio dell'automa FA
;;; Ritorna T se l'input viene accettato, NIL altrimenti
;;; Genera un errore se FA non e' un automa valido
;;; ----------------------------------------------------------------------------

(defun nfsa-recognize (FA Input)
  ;; Controllo che FA e' un automa valido
  (unless (nfsa-p FA)
    (error "~A non è un automa." FA))
  
  ;; Se input non e' una lista, ritorna NIL 
  ;; (come esempio (nfsa-recognize basic-nfsa-1 'a) -> NIL)
  (if (listp Input)
      ;; Estrazione componenti dell'automa
      (let ((start (nfsa-initial FA))        ; Stato iniziale
            (final-states (nfsa-finals FA))  ; Stati finali
            (transitions (nfsa-delta FA)))   ; Transizioni
        
        ;; Chiamata alla funzione helper
        (recognize-from-state start Input final-states transitions '()))
      nil))

