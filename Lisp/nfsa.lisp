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