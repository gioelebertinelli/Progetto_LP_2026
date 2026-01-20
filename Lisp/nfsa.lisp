; Bertinelli	Gioele	923893
; Gianoli	Matteo	924072
; Martinalli	Marco	924003

;;; ----------------------------------------------------------------------------
;;; FUNZIONE: is-regex
;;; Controlla se l'espressione RE è una regex valida.
;;; Ritorna T se RE e' un' espressione regolare, NIL altrimenti.
;;; ----------------------------------------------------------------------------

(defun is-regex (RE)
  
  (cond
   
   ; Caso lista vuota: non e' una regex valida
   ((null RE) nil)
   
   ;; Caso atomo: e' sempre una regex valida 
   ;; (anche 'a, 'c, 'z, 'o quando sono usati come simboli)
   ((atom RE) t)
   
   ;; Caso lista: controllo se l'operatore è valido
   ((listp RE)
    (cond
     
     ;; Caso operatore 'c' (sequenza): deve avere almeno un argomento
     ;; e tutti gli argomenti devono essere regex valide
     ((eq (first RE) 'c)
      (and (>= (length (rest RE)) 1)  
           (every #'is-regex (rest RE))))
     
     ;; Caso operatore 'a' (alternativa): deve avere almeno un argomento
     ;; e tutti gli argomenti devono essere regex valide
     ((eq (first RE) 'a)
      (and (>= (length (rest RE)) 1)
           (every #'is-regex (rest RE))))
     
     ;; Caso operatore 'z' (chiusura di Kleene):
     ;; deve avere esattamente un argomento che deve essere una regex valida
     ((eq (first RE) 'z)
      (and (= (length (rest RE)) 1)  
           (is-regex (second RE))))
     
     ;; Caso operatore 'o' (ripetizione uno-o-piu'):
     ;; deve avere esattamente un argomento che deve essere una regex valida
     ((eq (first RE) 'o)
      (and (= (length (rest RE)) 1)
           (is-regex (second RE))))
     
     ;; Se il primo elemento NON e' uno degli operatori riservati (c, a, z, o),
     ;; allora questa e' una S-expression che rappresenta un simbolo
     ;; dell'alfabeto e quindi e' una regex valida. Esempio: (foo bar) 
     (t t)))
   
   ;; Altri casi: catch-all per tipi non previsti
   (t nil)))