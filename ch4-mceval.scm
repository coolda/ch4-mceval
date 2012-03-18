;;;; METACIRCULAR EVALUATOR FROM CHAPTER 4 (SECTIONS 4.1.1-4.1.4) of
;;;; STRUCTURE AND INTERPRETATION OF COMPUTER PROGRAMS
;;;; http://www.mitpress.mit.edu/sicp/full-text/book/book.html
;;;; Matches code in ch4.scm
;;;; This file can be loaded into Scheme as a whole.
;;;; start by doing  (driver-loop)
;;;; quit by typing **quit** with no parens
;;;; done by prof. Berthold K.P. Horn
;;;; http://people.csail.mit.edu/bkph/courses/6001/

;;;SECTION 4.1.1
;; true? and false? moved from 4_1_3
(define error #f)

(define (true? x)
  (not (eq? x #f)))

(define (false? x)
  (eq? x #f))

(define (eval exp env)
  (cond ((self-evaluating? exp) exp)
        ((variable? exp) (lookup-variable-value exp env))
        ((quoted? exp) (text-of-quotation exp))
        ((assignment? exp) (eval-assignment exp env))
        ((definition? exp) (eval-definition exp env))
        ((if? exp) (eval-if exp env))
        ((lambda? exp)
         (make-procedure (lambda-parameters exp)
                         (lambda-body exp)
                         env))
        ((begin? exp) 
         (eval-sequence (begin-actions exp) env))
        ((cond? exp) (eval (cond->if exp) env))
        ((let? exp) (eval (let->application exp) env)) ; rewrite rule ?
        ((let*? exp) (eval (let*->application exp) env)) ; new  ?
        ((application? exp)
         (apply (eval (operator exp) env)
                (list-of-values (operands exp) env)))
        (else
         (error "Unknown expression type -- EVAL" exp))))

(define (apply procedure arguments)
  (cond ((primitive-procedure? procedure)
         (apply-primitive-procedure procedure arguments))
        ((compound-procedure? procedure)
         (eval-sequence
           (procedure-body procedure)
           (extend-environment
             (procedure-parameters procedure)
             arguments
             (procedure-environment procedure))))
        (else
         (error
          "Unknown procedure type -- APPLY" procedure))))

(define apply-in-underlying-scheme apply)

(define (list-of-values exps env)
  (if (no-operands? exps)
      '()
      (cons (eval (first-operand exps) env)
            (list-of-values (rest-operands exps) env))))

;;(define (eval-if exp env)
;;  (if (true? (eval (if-predicate exp) env))
;;      (eval (if-consequent exp) env)
;;      (eval (if-alternative exp) env)))

(define (eval-if exp env)
  (if (eval (if-predicate exp) env)
      (eval (if-consequent exp) env)
      (if (not (eq? (if-alternative exp) 'false))
          (eval (if-alternative exp) env))))

(define (eval-sequence exps env)
  (cond ((last-exp? exps) (eval (first-exp exps) env))
        (else (eval (first-exp exps) env)
              (eval-sequence (rest-exps exps) env))))

(define (eval-assignment exp env)
  (set-variable-value! (assignment-variable exp)
                       (eval (assignment-value exp) env)
                       env)
  'ok)

(define (eval-definition exp env)
  (define-variable! (definition-variable exp)
                    (eval (definition-value exp) env)
                    env)
  'ok)

(define (let->application expr)
  (let ((names (let-bound-variables expr))
        (values (let-values expr))
        (body (let-body expr)))
    (make-application (make-lambda names body) values)))

;;; Try for let* ?
(define (let*? expr) (tagged-list? expr 'let*))
(define (make-let* bindings body)
  (cons 'let* (cons bindings body)))

(define (let*->application expr)
  (let ((bindings (let-bindings expr))
        (names (let-bound-variables expr))
        (values (let-values expr))
        (body (let-body expr)))
    (cond ((null? bindings) body) ;;; (make-begin body) ?
          ((null? (cdr bindings)) ;;; single variable and value
;;;           (my-display (make-let bindings body)))
           (make-let bindings body))
;;;          (else (my-display (make-let (list (list (car names) (car values)))
;;;                       (list (make-let* (cdr bindings) body))))))))
          (else (make-let (list (list (car names) (car values)))
                          (list (make-let* (cdr bindings) body)))))))

(define (cond->if expr)
  (let ((clauses (cond-clauses expr)))
    (if (null? clauses)
        'false	; #f ?
        (if (eq? (car (first-cond-clause clauses)) 'else)
            (make-begin (cdr (first-cond-clause clauses)))
            (make-if (car (first-cond-clause clauses))
                     (make-begin (cdr (first-cond-clause clauses)))
                     (make-cond (rest-cond-clauses clauses)))))))

(define (if->cond expr) ; ?
  (let ((predicate (if-predicate expr))
        (consequent (if-consequent expr))
        (alternative (if-alternative expr)))
    (if (eq? alternative 'false)
        (make-cond (list (list predicate consequent)))
        (make-cond (list (list predicate consequent)
                         (list 'else alternative))))))

;;;SECTION 4.1.2
(define (self-evaluating? exp)
  (cond ((number? exp) #t)
        ((string? exp) #t)
        ((char? exp) #t)    ;;; need to add char? in primitive
        ((boolean? exp) #t)
        ((not exp) #t)
        (else #f)))

(define (quoted? exp)
  (tagged-list? exp 'quote))

(define (text-of-quotation exp) (cadr exp))

(define (tagged-list? exp tag)
  (if (pair? exp)
      (eq? (car exp) tag)
      #f))

(define (variable? exp) (symbol? exp))

(define (assignment? exp)
  (tagged-list? exp 'set!))

(define (assignment-variable exp) (cadr exp))

(define (assignment-value exp) (caddr exp))

(define (definition? exp)
  (tagged-list? exp 'define))

(define (definition-variable exp)
  (if (symbol? (cadr exp))
      (cadr exp)
      (caadr exp)))

(define (definition-value exp)
  (if (symbol? (cadr exp))
      (caddr exp)
      (make-lambda (cdadr exp)
                   (cddr exp))))

(define (lambda? exp) (tagged-list? exp 'lambda))
(define (lambda-parameters exp) (cadr exp))
(define (lambda-body exp) (cddr exp))
(define (make-lambda parameters body)
  (cons 'lambda (cons parameters body)))

(define (if? exp) (tagged-list? exp 'if))
(define (if-predicate exp) (cadr exp))
(define (if-consequent exp) (caddr exp))
(define (if-alternative exp)
  (if (not (null? (cdddr exp)))
      (cadddr exp)
      'false))
(define (make-if predicate consequent alternative)
  (list 'if predicate consequent alternative))

(define (cond? exp) (tagged-list? exp 'cond))
(define (cond-clauses exp) (cdr exp))
(define (cond-else-clause? clause)
  (eq? (cond-predicate clause) 'else))
(define (cond-predicate clause) (car clause))
(define (cond-actions clause) (cdr clause))
(define (cond->if exp)
  (expand-clauses (cond-clauses exp)))
(define first-cond-clause car)
(define rest-cond-clauses cdr)
(define (make-cond seq) (cons 'cond seq))

;;; added let part
(define (let? expr) (tagged-list? expr 'let))
(define let-bindings cadr) ; second
(define (let-bound-variables expr) (map car (cadr expr)))
(define (let-values expr) (map cadr (cadr expr)))
;;; (define let-body caddr) ;lecture--body had only one experession
(define let-body cddr) 
(define (make-let bindings body)
  (cons 'let (cons bindings body)))

(define (begin? exp) (tagged-list? exp 'begin))

(define (begin-actions exp) (cdr exp))

(define (last-exp? seq) (null? (cdr seq)))
(define (first-exp seq) (car seq))
(define (rest-exps seq) (cdr seq))

(define (sequence->exp seq)
  (cond ((null? seq) seq)
        ((last-exp? seq) (first-exp seq))
        (else (make-begin seq))))

(define (make-begin seq) (cons 'begin seq))

(define (application? exp) (pair? exp))
(define (operator exp) (car exp))
(define (operands exp) (cdr exp))

(define (no-operands? ops) (null? ops))
(define (first-operand ops) (car ops))
(define (rest-operands ops) (cdr ops))

(define (make-application operator operands)
  (cons operator operands))

(define (expand-clauses clauses)
  (if (null? clauses)
      'false                          ; no else clause
      (let ((first (car clauses))
            (rest (cdr clauses)))
        (if (cond-else-clause? first)
            (if (null? rest)
                (sequence->exp (cond-actions first))
                (error "ELSE clause isn't last -- COND->IF"
                       clauses))
            (make-if (cond-predicate first)
                     (sequence->exp (cond-actions first))
                     (expand-clauses rest))))))

;;;SECTION 4.1.3
(define (make-procedure parameters body env)
  (list 'procedure parameters body env))

(define (compound-procedure? p)
  (tagged-list? p 'procedure))

(define (procedure-parameters p) (cadr p))
(define (procedure-body p) (caddr p))
(define (procedure-environment p) (cadddr p))

(define (enclosing-environment env) (cdr env))

(define (first-frame env) (car env))

(define the-empty-environment '())

(define (make-frame variables values)
  (cons variables values))

(define (frame-variables frame) (car frame))
(define (frame-values frame) (cdr frame))

(define (add-binding-to-frame! var val frame)
  (set-car! frame (cons var (car frame)))
  (set-cdr! frame (cons val (cdr frame))))

(define (extend-environment vars vals base-env)
  (if (= (length vars) (length vals))
      (cons (make-frame vars vals) base-env)
      (if (< (length vars) (length vals))
          (error "Too many arguments supplied" vars vals)
          (error "Too few arguments supplied" vars vals))))

(define (lookup-variable-value var env)
  (define (env-loop env)
    (define (scan vars vals)
      (cond ((null? vars)
             (env-loop (enclosing-environment env)))
            ((eq? var (car vars))
             (car vals))
            (else (scan (cdr vars) (cdr vals)))))
    (if (eq? env the-empty-environment)
        (error "Unbound variable" var)
        (let ((frame (first-frame env)))
          (scan (frame-variables frame)
                (frame-values frame)))))
  (env-loop env))

(define (set-variable-value! var val env)
  (define (env-loop env)
    (define (scan vars vals)
      (cond ((null? vars)
             (env-loop (enclosing-environment env)))
            ((eq? var (car vars))
             (set-car! vals val))
            (else (scan (cdr vars) (cdr vals)))))
    (if (eq? env the-empty-environment)
        (error "Unbound variable -- SET!" var)
        (let ((frame (first-frame env)))
          (scan (frame-variables frame)
                (frame-values frame)))))
  (env-loop env))

(define (define-variable! var val env)
  (let ((frame (first-frame env)))
    (define (scan vars vals)
      (cond ((null? vars)
             (add-binding-to-frame! var val frame))
            ((eq? var (car vars))
             (set-car! vals val))
            (else (scan (cdr vars) (cdr vals)))))
    (scan (frame-variables frame)
          (frame-values frame))))

;;;SECTION 4.1.4
(define (setup-environment)
  (let ((initial-env
         (extend-environment (primitive-procedure-names)
                             (primitive-procedure-objects)
                             the-empty-environment)))
    (define-variable! 'true #t initial-env)
    (define-variable! 'false #f initial-env)
    initial-env))

;;; (define exit-object (cons null? null?))
;;; (define (exit-driver) exit-object)

(define (primitive-procedure? proc)
  (tagged-list? proc 'primitive))

(define (primitive-implementation proc) (cadr proc))

(define primitive-procedures
  (list (list 'eqv? eqv?)
        (list 'eq? eq?)
        (list 'equal? equal?)
        (list 'number? number?)
        (list 'complex? complex?)
        (list 'real? real?)
        (list 'rational? rational?)
        (list 'integer? integer?)
        (list 'exact? exact?)
        (list 'inexact? inexact?)
        (list 'zero? zero?)
        (list 'positive? positive?)
        (list 'negative? negative?)
        (list 'odd? odd?)
        (list 'even? even?)
        (list 'max max)
        (list 'min min)
        (list '+ +)
        (list '- -)
        (list '* *)
        (list '/ /)
        (list 'abs abs)
        (list 'quotient quotient)
        (list 'remainder remainder)
        (list 'modulo modulo)
        (list 'gcd gcd)
        (list 'lcm lcm)
        (list 'numerator numerator)
        (list 'denominator denominator)
        (list 'floor floor)
        (list 'ceiling ceiling)
        (list 'truncate truncate)
        (list 'round round)
        (list 'rationalize rationalize)
        (list 'exp exp)
        (list 'log log)
        (list 'sin sin)
        (list 'cos cos)
        (list 'tan tan)
        (list 'asin asin)
        (list 'acos acos)
        (list 'atan atan)
        (list 'sqrt sqrt)
        (list 'expt expt)
        (list 'make-rectangular make-rectangular)
        (list 'make-polar make-polar)
        (list 'real-part real-part)
        (list 'imag-part imag-part)
        (list 'magnitude magnitude)
        (list 'angle angle)
        (list 'exact->inexact exact->inexact)
        (list 'inexact->exact inexact->exact)
        (list 'number->string number->string)
        (list 'string->number string->number)
        (list '#t #t)
        (list '#f #f)
        (list 'not not)
        (list 'boolean? boolean?)
        (list 'pair? pair?)
        (list 'cons cons)
        (list 'car car)
        (list 'cdr cdr)
        (list 'set-car! set-car!)   ;;; used to be known as rplaca
        (list 'set-cdr! set-cdr!)   ;;; used to be known as rplacd
        (list 'caar caar)           ;;; (car (car ls))
        (list 'cadr cadr)           ;;; (car (cdr ls))
        (list 'cdar cdar)           ;;; (cdr (car ls))
        (list 'cddr cddr)           ;;; (cdr (cdr ls))
        (list 'caaar caaar)         ;;; (car (car (car ls)))
        (list 'caadr caadr)         ;;; (car (car (cdr ls)))
        (list 'cadar cadar)         ;;; (car (cdr (car ls)))
        (list 'caddr caddr)         ;;; (car (cdr (cdr ls)))
        (list 'cdaar cdaar)         ;;; (cdr (car (car ls))) 
        (list 'cdadr cdadr)         ;;; (cdr (car (cdr ls)))
        (list 'cddar cddar)         ;;; (cdr (cdr (car ls)))
        (list 'cdddr cdddr)         ;;; (cdr (cdr (cdr ls)))
        (list 'caaaar caaaar)       ;;; (car (car (car (car ls))))
        (list 'caaadr caaadr)       ;;; (car (car (car (cdr ls))))
        (list 'caadar caadar)       ;;; (car (car (cdr (car ls))))
        (list 'caaddr caaddr)       ;;; (car (car (cdr (cdr ls))))
        (list 'cadaar cadaar)       ;;; (car (cdr (car (car ls))))
        (list 'cadadr cadadr)       ;;; (car (cdr (car (cdr ls))))
        (list 'caddar caddar)       ;;; (car (cdr (cdr (car ls))))
        (list 'cadddr cadddr)       ;;; (car (cdr (cdr (cdr ls))))
        (list 'cdaaar cdaaar)       ;;; (cdr (car (car (car ls))))
        (list 'cdaadr cdaadr)       ;;; (cdr (car (car (cdr ls))))
        (list 'cdadar cdadar)       ;;; (cdr (car (cdr (car ls))))
        (list 'cdaddr cdaddr)       ;;; (cdr (car (cdr (cdr ls))))
        (list 'cddaar cddaar)       ;;; (cdr (cdr (car (car ls))))
        (list 'cddadr cddadr)       ;;; (cdr (cdr (car (cdr ls))))
        (list 'cdddar cdddar)       ;;; (cdr (cdr (cdr (car ls))))
        (list 'cddddr cddddr)       ;;; (cdr (cdr (cdr (cdr ls))))
        (list 'null? null?)
        (list 'list? list?)
        (list 'length length)       ;;; length of the list
        (list 'append append)
        (list 'reverse! reverse)
        (list 'list-tail list-tail)
        (list 'list-ref list-ref)
        (list 'memq memq)
        (list 'memv memv)
        (list 'member member)
        (list 'assq assq)
        (list 'assv assv)
        (list 'assoc assoc)
        (list 'symbol? symbol?)
        (list 'symbol->string symbol->string)
        (list 'string->symbol string->symbol)
        (list 'char? char?)
        (list 'char=? char=?)
        (list 'char<? char<?)
        (list 'char>? char>?)
        (list 'char<=? char<=?)
        (list 'char>=? char>=?)
        (list 'char-ci=? char-ci=?)
        (list 'char-ci<? char-ci<?)
        (list 'char-ci>? char-ci>?)
        (list 'char-ci<=? char-ci<=?)
        (list 'char-ci>=? char-ci>=?)
        (list 'char-alphabetic? char-alphabetic?)
        (list 'char-numeric? char-numeric?)
        (list 'char-whitespace? char-whitespace?)
        (list 'char-upper-case? char-upper-case?)
        (list 'char-lower-case? char-lower-case?)
        (list 'char->integer char->integer)
        (list 'integer->char integer->char)
        (list 'char-upcase char-upcase)
        (list 'char-downcase char-downcase)
        (list 'string? string?)
        (list 'make-string make-string)
        (list 'string string)        ;;; string char ...
        (list 'string-length string-length)
        (list 'string-ref string-ref)
        (list 'string-set! string-set!)
        (list 'string=? string=?)
        (list 'string-ci=? string-ci=?)
        (list 'string<? string<?)
        (list 'string>? string>?)
        (list 'string<=? string<=?)
        (list 'string>=? string>=?)
        (list 'string-ci<? string-ci<?)
        (list 'string-ci>? string-ci>?)
        (list 'string-ci<=? string-ci<=?)
        (list 'string-ci>=? string-ci>=?)
        (list 'substring substring)
        (list 'string-append string-append)
        (list 'string->list string->list)
        (list 'list->string list->string)
        (list 'string-copy string-copy)
        (list 'string-fill! string-fill!)
        (list 'vector? vector?)
        (list 'make-vector make-vector)
        (list 'vector vector)
        (list 'vector-length vector-length)
        (list 'vector-ref vector-ref)
        (list 'vector-set! vector-set!)
        (list 'vector->list vector->list)
        (list 'list->vector list->vector)
        (list 'vector-fill! vector-fill!)
        (list 'procedure? procedure?)
        (list 'apply apply)
        (list 'map map)
        (list 'for-each for-each)
        (list 'force force)
        (list 'call-with-current-continuation call-with-current-continuation)
        (list 'values values)
        (list 'call-with-values call-with-values)
        (list 'dynamic-wind dynamic-wind)
        (list 'eval eval)
        (list 'scheme-report-environment scheme-report-environment)   ;;; 5
        (list 'null-environment null-environment)
        (list 'interaction-environment interaction-environment)
        (list 'call-with-input-file call-with-input-file)
        (list 'call-with-output-file call-with-output-file)
        (list 'input-port? input-port?)
        (list 'output-port? output-port?)
        (list 'current-input-port current-input-port)
        (list 'current-output-port current-output-port)
        (list 'with-input-from-file with-input-from-file)
        (list 'with-output-to-file with-output-to-file)
        (list 'open-input-file open-input-file)
        (list 'open-output-file open-output-file)
        (list 'close-input-port close-input-port)
        (list 'close-output-port close-output-port)
        (list 'read read)
        (list 'read-char read-char)
        (list 'peek-char peek-char)
        (list 'eof-object? eof-object?)
        (list 'char-ready? char-ready?)
        (list 'write write)
        (list 'display display)
        (list 'newline newline)
        (list 'write-char write-char)
        (list 'load load)
        (list 'transcript-on transcript-on)
        (list 'transcript-off transcript-off)
        (list 'atom? (lambda (x) (and (not (pair? x)) (not (null? x)))))
        (list '= =)
        (list '> >)
        (list '< <)
        (list '>= >=)
        (list '<= <=)
        (list 'null? null?)
;;      more primitives
        ))

(define (primitive-procedure-names)
  (map car
       primitive-procedures))

(define (primitive-procedure-objects)
  (map (lambda (proc) (list 'primitive (cadr proc)))
       primitive-procedures))

;[moved to start of file] (define apply-in-underlying-scheme apply)

(define (apply-primitive-procedure proc args)
  (display proc)
  (newline)
  (display args)
  (apply-in-underlying-scheme
   (primitive-implementation proc) args))

(define input-prompt ";;; M-Eval input:")
(define output-prompt ";;; M-Eval value:")

(define (driver-loop)
  (prompt-for-input input-prompt)
  (let ((input (read)))
    (if (eq? input '**quit**)
        'eval-done
    (let ((output (eval input the-global-environment)))
      (announce-output output-prompt)
      (display output)
 ;;;     (user-print output)))
  (driver-loop)))))

(define (prompt-for-input string)
  (newline) (newline) (display string) (newline))

(define (announce-output string)
  (newline) (display string) (newline))

(define (user-print object)
  (if (compound-procedure? object)
      (display (list 'compound-procedure
                     (procedure-parameters object)
                     (procedure-body object)
                     '<procedure-env>))
      (display object)))

;;; Following are commented out so as not to be evaluated 
;;; when the file is loaded.
(define the-global-environment (setup-environment))
;;; (driver-loop)
;;; 'METACIRCULAR-EVALUATOR-LOADED
