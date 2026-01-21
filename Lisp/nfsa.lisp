; Bertinelli	Gioele	923893
; Gianoli	Matteo	924072
; Martinalli	Marco	924003

;;; ===========================================================================
;;; DICHIARAZIONE FUNZIONI: per evitare warning 
;;; (nel caso venga chiamata prima di essere letta)
;;; ===========================================================================

(declaim (ftype (function (t t t t t) t) recognize-from-state))
(declaim (ftype (function (t t t t t) t) try-epsilon-transitions))
(declaim (ftype (function (t t t t) t) try-symbol-transitions))

;;; ===========================================================================
;;; FUNZIONE PRINCIPALE: is_regex
;;; Verifica se RE è una regex valida
;;; ===========================================================================

(defun is-regex (RE)
  
  (cond
   
   ((null RE) nil)
   
   ;; Atomo, e' sempre una regex valida (anche 'a, 'c, 'z, 'o come simboli)
   ((atom RE) t)
   
   ;; Lista, controllo operatore
   ((listp RE)
    (cond
     
     ;; Operatore 'c' (sequenza): almeno un argomento, tutti regex valide
     ((eq (first RE) 'c)
      (and (>= (length (rest RE)) 1)  
           (every #'is-regex (rest RE))))
     
     ;; Operatore 'a' (alternativa): almeno un argomento, tutti regex valide
     ((eq (first RE) 'a)
      (and (>= (length (rest RE)) 1)
           (every #'is-regex (rest RE))))
     
     ;; Operatore 'z' (chiusura di Kleene): un argomento, regex valida
     ((eq (first RE) 'z)
      (and (= (length (rest RE)) 1)  
           (is-regex (second RE))))
     
     ;; Operatore 'o' (uno o più): un argomento, regex valida
     ((eq (first RE) 'o)
      (and (= (length (rest RE)) 1)
           (is-regex (second RE))))
     
     ;; Se non è un operatore riservato, è una S-expression
     ;; Esempio: (foo bar)
     (t t)))
   
   (t nil)))


;;; ----------------------------------------------------------------------------
;;; FUNZIONE: nfsa-compile-regex
;;; ritorna l’automa ottenuto dalla compilazione di RE, se è un’espressione regolare, 
;;; altrimenti ritorna NIL.
;;; ----------------------------------------------------------------------------

;;; Definizione della struttura dell'automa (NFSA)

(defstruct nfsa
  initial   ; Stato iniziale
  finals    ; Lista degli stati finali
  delta)    ; Lista delle transizioni (stato-da input stato-a)

;;; Variabile globale per contare gli stati e generare ID univoci.
(defparameter *state-counter* 0)

;;; Helper per generare un nuovo stato (semplicemente un numero intero)
(defun new-state ()
  (incf *state-counter*))

;;; Helper per creare una transizione.
;;; Se l'input è NIL, rappresenta una epsilon-transizione.
(defun make-transition (from input to)
  (list from input to))

;;; Funzione  che compila ricorsivamente la regex.
;;; Ritorna una lista di tre elementi: (stato-inizio stato-fine lista-transizioni)
;;; serve per collegare "i pezzi"
(defun compile-recursive (re)
  (cond
    ;; CASO 1: Atomo (Simbolo base o lista che non è un operatore)
    ((or (atom re)
         (and (listp re) 
              (not (member (first re) '(c a z o)))))
     (let ((start (new-state))
           (end (new-state)))
       (list start 
             end 
             (list (make-transition start re end)))))

    ;; CASO 2: Concatenazione ('c')
    ((eq (first re) 'c)
     (let* ((args (rest re))
            (first-res (compile-recursive (first args)))
            (current-start (first first-res))
            (current-end (second first-res))
            (current-trans (third first-res)))
       
     
       (dolist (next-re (rest args))
         (let* ((next-res (compile-recursive next-re))
                (next-start (first next-res))
                (next-end (second next-res))
                (next-trans (third next-res)))

           ;; Colleghiamo la fine del precedente all'inizio del successivo
           (push (make-transition current-end nil next-start) current-trans)
           ;; Uniamo le transizioni
           (setf current-trans (append current-trans next-trans))
           ;; Aggiorniamo la fine corrente
           (setf current-end next-end)))
       
       (list current-start current-end current-trans)))

    ;; CASO 3: Alternativa ('a' - OR)

    ((eq (first re) 'a)
     (let ((global-start (new-state))
           (global-end (new-state))
           (all-trans '()))
       
       (dolist (sub-re (rest re))
         (let* ((res (compile-recursive sub-re))
                (s (first res))
                (e (second res))
                (t-list (third res)))
           ;; Start globale -> Start sotto-regex
           (push (make-transition global-start nil s) all-trans)
           ;; End sotto-regex -> End globale
           (push (make-transition e nil global-end) all-trans)
           ;; Accumuliamo le transizioni interne
           (setf all-trans (append all-trans t-list))))
       
       (list global-start global-end all-trans)))

    ;; CASO 4: Stella di Kleene ('z' - Zero o più)
    ((eq (first re) 'z)
     (let* ((res (compile-recursive (second re))) ; L'argomento è il secondo elemento
            (s (first res))
            (e (second res))
            (t-list (third res))
            (new-s (new-state))
            (new-e (new-state)))
       
       ;; Aggiungiamo le 4 transizioni tipiche
       (push (make-transition new-s nil s) t-list)     ; Entrata
       (push (make-transition e nil new-e) t-list)     ; Uscita
       (push (make-transition e nil s) t-list)         ; Loop indietro
       (push (make-transition new-s nil new-e) t-list) ; Skip (caso zero volte)
       
       (list new-s new-e t-list)))

    ;; CASO 5: Uno o più ('o')
    ;; Simile alla stella, ma senza lo skip iniziale diretto
    ((eq (first re) 'o)
     (let* ((res (compile-recursive (second re)))
            (s (first res))
            (e (second res))
            (t-list (third res))
            (new-s (new-state))
            (new-e (new-state)))
       
       (push (make-transition new-s nil s) t-list)     ; Entrata
       (push (make-transition e nil new-e) t-list)     ; Uscita
       (push (make-transition e nil s) t-list)         ; Loop indietro
       ;; NON c'è la transizione new-s -> new-e perché deve farne almeno uno
       
       (list new-s new-e t-list)))))

;;; FUNZIONE PRINCIPALE RICHIESTA
(defun nfsa-compile-regex (RE)
  ;; Controllo preliminare usando la tua funzione is-regex
  (if (is-regex RE)
      (progn
        ;; Resettiamo il contatore per avere stati puliti partendo da 1 o 0
        (setf *state-counter* 0)
        ;; Compiliamo ottenendo i 3 pezzi (start end transitions)
        (let ((result (compile-recursive RE)))
          ;; Costruiamo e ritorniamo la struct finale
          (make-nfsa :initial (first result)
                     :finals (list (second result))
                     :delta (third result))))
      nil))


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
;;; Prova transizioni che consumano il prossimo simbolo dell'input
;;; ===========================================================================

(defun try-symbol-transitions (current-state remaining-input final-states 
                               transitions)
  (when remaining-input
    (let ((next-symbol (first remaining-input))
          (rest-input (rest remaining-input)))
      
      ;; Trova tutte le transizioni applicabili dallo stato corrente
      ;; che consumano esattamente il prossimo simbolo
      (some #'(lambda (trans)
                (let ((from-state (first trans))
                      (symbol (second trans))
                      (to-state (third trans)))
                  
                  ;; Controlla se questa transizione e' applicabile:
                  ;; 1. Parte dallo stato corrente
                  ;; 2. Il simbolo corrisponde (NON e' epsilon)
                  ;; 3. Il simbolo matcha con next-symbol
                  (when (and (eql from-state current-state)
                            (not (null symbol)) 
                            (equal symbol next-symbol))
                    
                    ;; Reset di visited-epsilon dopo transizione simbolo
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
   ;; Input esaurito: controlla se stato finale
   ;; altrimenti prova a raggiungerlo con epsilon transizioni
   ((null remaining-input)
    (if (member current-state final-states)
        t
        (try-epsilon-transitions current-state remaining-input final-states 
                                transitions visited-epsilon)))
   
   ;; Input rimanente: prova transizioni simbolo poi epsilon
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
  (unless (nfsa-p FA)
    (error "~A non è un automa." FA))
  
  ;; Input deve essere una lista, altrimenti ritorna NIL
  (if (listp Input)
      ;; Estrae i componenti dell'automa e avvia il riconoscimento
      ;; partendo dallo stato iniziale
      (let ((start (nfsa-initial FA))
            (final-states (nfsa-finals FA))
            (transitions (nfsa-delta FA)))
        (recognize-from-state start Input final-states transitions '()))
      nil))

