; Bertinelli	Gioele	923893
; Gianoli	Matteo	924072
; Martinalli	Marco	924003


;;; Dichiarazione funzioni per evitare warning in fase di compilazione
;;; nel caso venga chiamata prima di essere letta
(declaim (ftype (function (t t t t t) t) recognize-from-state))
(declaim (ftype (function (t t t t t) t) try-epsilon-transitions))
(declaim (ftype (function (t t t t) t) try-symbol-transitions))

;;; Definizione della struttura dell'automa (NFSA)
(defstruct nfsa
  initial    ; Stato iniziale
  finals     ; Lista degli stati finali
  delta)     ; Lista delle transizioni (stato-da input stato-a)


;;; ===========================================================================
;;; FUNZIONE PRINCIPALE: is_regex
;;; Verifica se RE è una regex valida
;;; ===========================================================================

(defun is-regex (RE)
  
  (cond
   
   ((null RE) nil)
   
   ;; Atomo e' sempre una regex valida (anche 'a, 'c, 'z, 'o come simboli)
   ((atom RE) t)
   
   ;; Se è una lista controllo operatore
   ((listp RE)
    (cond
     
     ;; Operatore 'c' (sequenza): almeno due argomenti e tutti regex valide
     ((eq (first RE) 'c)
      (and (>= (length (rest RE)) 2)  
           (every #'is-regex (rest RE))))
     
     ;; Operatore 'a' (alternativa): almeno due argomenti e tutti regex valide
     ((eq (first RE) 'a)
      (and (>= (length (rest RE)) 2)
           (every #'is-regex (rest RE))))
     
     ;; Operatore 'z' (chiusura di Kleene): un argomento e regex valida
     ((eq (first RE) 'z)
      (and (= (length (rest RE)) 1)  
           (is-regex (second RE))))
     
     ;; Operatore 'o' (uno o più): un argomento e regex valida
     ((eq (first RE) 'o)
      (and (= (length (rest RE)) 1)
           (is-regex (second RE))))
     
     ;; Se non è un operatore riservato è una S-expression
     ;; Esempio: (foo bar)
     (t t)))
   
   (t nil)))


;;; ===========================================================================
;;; FUNZIONE: nfsa-compile-regex
;;; ritorna l’automa ottenuto dalla compilazione di RE, se è 
;;; un’espressione regolare, altrimenti ritorna NIL.
;;; ===========================================================================

;;; Helper per creare una transizione. 
;;; Se l'input è NIL, rappresenta una epsilon-transizione.
(defun make-transition (from input to)
  (list from input to))

;;; ===========================================================================
;;; FUNZIONE HELPER: compile-recursive
;;; Funzione che compila ricorsivamente la regex.
;;; Ritorna una lista di tre elementi:
;;; (stato-inizio stato-fine lista-transizioni)
;;; ===========================================================================

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

;;; ===========================================================================
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
;;; ===========================================================================


;;; ===========================================================================
;;; FUNZIONE HELPER: try-epsilon-transitions 
;;; Prova tutte le epsilon-transizioni (simbolo NIL), non consumano input
;;; ===========================================================================

(defun try-epsilon-transitions (current-state remaining-input final-states 
                                transitions visited-epsilon)
  
  ;; Evita cicli infiniti su epsilon-transizioni
  (when (member current-state visited-epsilon)
    (return-from try-epsilon-transitions nil))
  
  (let ((new-visited (cons current-state visited-epsilon)))
    (some #'(lambda (trans)
              (let ((from-state (first trans))
                    (symbol (second trans))
                    (to-state (third trans)))
                (when (and (eql from-state current-state)
                          (null symbol))
                  (recognize-from-state to-state remaining-input final-states 
                                      transitions new-visited))))
          transitions)))

;;; ===========================================================================
;;; FUNZIONE HELPER: try-symbol-transitions
;;; Prova tutte le transizioni che consumano un simbolo
;;; ===========================================================================

(defun try-symbol-transitions (current-state remaining-input final-states 
                               transitions)
  (when remaining-input
    (let ((next-symbol (first remaining-input))
          (rest-input (rest remaining-input)))
      
      ;; Trova tutte le transizioni che si possono applicare dallo stato attuale
      ;; che consumano il prossimo simbolo
      (some #'(lambda (trans)
                (let ((from-state (first trans))
                      (symbol (second trans))
                      (to-state (third trans)))
                  
                  ;; Controlla se questa transizione e' applicabile:
                  ;; 1. Parte dallo stato attuale
                  ;; 2. Il simbolo corrisponde (NON e' epsilon)
                  ;; 3. Il simbolo è uguale al primo da consumare
                  (when (and (eql from-state current-state)
                            (not (null symbol)) 
                            (equal symbol next-symbol))
                    
                    ;; Si resetta visited-epsilon dopo una transizione che
                    ;; ha consumato un simbolo
                    (recognize-from-state to-state rest-input final-states 
                                         transitions '()))))
            transitions))))

;;; ===========================================================================
;;; FUNZIONE HELPER: recognize-from-state
;;; Funzione ricorsiva che esplora l'automa con backtracking 
;;; ===========================================================================

(defun recognize-from-state (current-state remaining-input final-states 
                             transitions visited-epsilon)
  (cond
   ;; Input esaurito: controlla se siamo in uno stato finale
   ;; altrimenti prova a raggiungerlo con le epsilon transizioni
   ((null remaining-input)
    (if (member current-state final-states)
        t
        (try-epsilon-transitions current-state remaining-input final-states 
                                transitions visited-epsilon)))
   
   ;; Input rimanente: prova transizioni (prima simbolo e poi epsilon)
   (t
    (or (try-symbol-transitions current-state remaining-input final-states 
                               transitions)
        (try-epsilon-transitions current-state remaining-input final-states 
                                transitions visited-epsilon)))))


;;; ===========================================================================
;;; FUNZIONE PRINCIPALE: nfsa-recognize
;;; Riconosce se Input appartiene al linguaggio dell'automa FA
;;; ===========================================================================

(defun nfsa-recognize (FA Input)
  
  ;; Controllo che FA sia un automa valido
  (unless (nfsa-p FA)
    (error "~A non è un automa." FA))
  
  ;; Se Input non è una lista ritorna nil
  (if (listp Input)
      ;; Estrae i componenti dell'automa e avvia il riconoscimento
      ;; partendo dallo stato iniziale
      (let ((start (nfsa-initial FA))
            (final-states (nfsa-finals FA))
            (transitions (nfsa-delta FA)))
        (recognize-from-state start Input final-states transitions '()))
      nil))