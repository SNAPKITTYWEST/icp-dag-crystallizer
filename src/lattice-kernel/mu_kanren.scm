;; SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
;; CLONE_GATE: mu_kanren_lattice_kernel
;;
;; mu_kanren.scm — Relational Lattice Kernel (Scheme / μKanren)
;;
;; Relational kernel: unify, interleaving streams, constraints,
;; lists, Peano, full-adder, evalo, path+SMT stub, FSM.
;;
;; Compatible with Chez Scheme, Guile, Racket (with #lang scheme).
;; No imports required beyond the host reader.

;; ============================================================
;; 0. VARIABLES AND SUBSTITUTIONS
;; ============================================================

;; Variables are vectors of one integer: #(0), #(1), ...
(define (var n) (vector n))
(define (var? x) (vector? x))
(define (var=? x y) (= (vector-ref x 0) (vector-ref y 0)))

;; A substitution is an assoc-list of (var . val)
(define empty-s '())

;; walk : term × subst → term
(define (walk u s)
  (cond
    ((and (var? u) (assv (vector-ref u 0) s))
     => (lambda (pr) (walk (cdr pr) s)))
    (else u)))

;; occurs? : var × term × subst → bool
(define (occurs? x v s)
  (let ((v (walk v s)))
    (cond
      ((var? v) (var=? x v))
      ((pair? v) (or (occurs? x (car v) s)
                     (occurs? x (cdr v) s)))
      (else #f))))

;; ext-s : var × term × subst → subst | #f
(define (ext-s x v s)
  (if (occurs? x v s)
      #f
      (cons (cons (vector-ref x 0) v) s)))

;; unify : term × term × subst → subst | #f
(define (unify u v s)
  (let ((u (walk u s))
        (v (walk v s)))
    (cond
      ((and (var? u) (var? v) (var=? u v)) s)
      ((var? u) (ext-s u v s))
      ((var? v) (ext-s v u s))
      ((and (pair? u) (pair? v))
       (let ((s (unify (car u) (car v) s)))
         (and s (unify (cdr u) (cdr v) s))))
      (else (and (equal? u v) s)))))

;; ============================================================
;; 1. STATES AND STREAMS
;; ============================================================

;; A state is (subst . constraint-store)
;; For this kernel the constraint store is a list of disequality pairs.
(define (make-state s c) (cons s c))
(define (state-s st) (car st))
(define (state-c st) (cdr st))
(define empty-state (make-state empty-s '()))

;; Streams: '() | (state . stream) | thunk
(define mzero '())
(define (unit st) (cons st mzero))

(define (mplus s1 s2)
  (cond
    ((null? s1) s2)
    ((procedure? s1) (lambda () (mplus s2 (s1))))
    (else (cons (car s1) (mplus (cdr s1) s2)))))

(define (bind s g)
  (cond
    ((null? s) mzero)
    ((procedure? s) (lambda () (bind (s) g)))
    (else (mplus (g (car s)) (bind (cdr s) g)))))

;; ============================================================
;; 2. CORE GOALS
;; ============================================================

;; == : term × term → goal
(define (== u v)
  (lambda (st)
    (let ((s (unify u v (state-s st))))
      (if s
          (unit (make-state s (state-c st)))
          mzero))))

;; =/= : term × term → goal  (disequality constraint)
(define (=/= u v)
  (lambda (st)
    (let ((s (unify u v (state-s st))))
      (cond
        ((not s) (unit st))           ; already distinct — succeed
        ((equal? s (state-s st)) mzero) ; unification added nothing — same var — fail
        (else
         ;; record the disequality in the constraint store
         (unit (make-state (state-s st)
                           (cons (cons u v) (state-c st)))))))))

;; succeed / fail
(define succeed (lambda (st) (unit st)))
(define fail    (lambda (st) mzero))

;; conj2 / disj2
(define (conj2 g1 g2) (lambda (st) (bind (g1 st) g2)))
(define (disj2 g1 g2) (lambda (st) (mplus (g1 st) (g2 st))))

;; Variadic conj / disj
(define (conj . gs)
  (cond ((null? gs) succeed)
        ((null? (cdr gs)) (car gs))
        (else (conj2 (car gs) (apply conj (cdr gs))))))

(define (disj . gs)
  (cond ((null? gs) fail)
        ((null? (cdr gs)) (car gs))
        (else (disj2 (car gs) (apply disj (cdr gs))))))

;; fresh : (var ...) body → goal
;; Usage: (fresh (x y z) body)
;; (implemented as a macro in real miniKanren; here as a procedure factory)
(define *var-counter* 0)
(define (new-var!)
  (let ((n *var-counter*))
    (set! *var-counter* (+ n 1))
    (var n)))

(define-syntax fresh
  (syntax-rules ()
    ((_ () g ...) (conj g ...))
    ((_ (x . rest) g ...)
     (let ((x (new-var!)))
       (fresh rest g ...)))))

;; conde
(define-syntax conde
  (syntax-rules ()
    ((_ (g ...) ...) (disj (conj g ...) ...))))

;; run : n × var × goal → list of reified values
(define (reify-s v s)
  (let ((v (walk v s)))
    (cond
      ((var? v)
       (let ((n (length (filter (lambda (b) (var? (cdr b))) s))))
         (cons (cons (vector-ref v 0) (string->symbol (string-append "_" (number->string n)))) s)))
      ((pair? v) (reify-s (cdr v) (reify-s (car v) s)))
      (else s))))

(define (reify v st)
  (let ((v (walk* v (state-s st))))
    (walk* v (reify-s v '()))))

(define (walk* v s)
  (let ((v (walk v s)))
    (if (pair? v)
        (cons (walk* (car v) s) (walk* (cdr v) s))
        v)))

(define (take n s)
  (if (or (null? s) (and n (= n 0)))
      '()
      (cons (car s)
            (take (and n (- n 1))
                  (if (procedure? (cdr s)) ((cdr s)) (cdr s))))))

(define-syntax run
  (syntax-rules ()
    ((_ n (q) g ...)
     (let ((q (new-var!)))
       (map (lambda (st) (reify q st))
            (take n ((conj g ...) empty-state)))))))

(define-syntax run*
  (syntax-rules ()
    ((_ (q) g ...)
     (run #f (q) g ...))))

;; ============================================================
;; 3. LIST RELATIONS
;; ============================================================

(define (conso a d p) (== (cons a d) p))
(define (nullo x) (== x '()))
(define (caro p a) (fresh (d) (conso a d p)))
(define (cdro p d) (fresh (a) (conso a d p)))
(define (pairo p) (fresh (a d) (conso a d p)))

(define (listo x)
  (conde
    ((nullo x))
    ((fresh (d) (cdro x d) (listo d)))))

(define (appendo l s out)
  (conde
    ((nullo l) (== s out))
    ((fresh (a d res)
       (conso a d l)
       (conso a res out)
       (appendo d s res)))))

(define (membero x l)
  (fresh (a d)
    (conso a d l)
    (conde
      ((== x a))
      ((membero x d)))))

(define (rembero x l out)
  (conde
    ((nullo l) (nullo out))
    ((fresh (a d)
       (conso a d l)
       (conde
         ((== a x) (== d out))
         ((fresh (r)
            (=/= a x)
            (conso a r out)
            (rembero x d r))))))))

(define (reverseo l o) (rev-acco l '() o))
(define (rev-acco l acc o)
  (conde
    ((nullo l) (== acc o))
    ((fresh (a d)
       (conso a d l)
       (rev-acco d (cons a acc) o)))))

(define (lengtho l n)
  (conde
    ((nullo l) (== n 'z))
    ((fresh (d m)
       (cdro l d)
       (lengtho d m)
       (== n `(s ,m))))))

(define (distincto l)
  (conde
    ((nullo l))
    ((fresh (a d)
       (conso a d l)
       (not-membero a d)
       (distincto d)))))

(define (not-membero x l)
  (conde
    ((nullo l))
    ((fresh (a d)
       (conso a d l)
       (=/= x a)
       (not-membero x d)))))

(define (permuteo l o)
  (conde
    ((nullo l) (nullo o))
    ((fresh (a d r)
       (conso a d l)
       (permuteo d r)
       (inserto a r o)))))

(define (inserto x l o)
  (conde
    ((conso x l o))
    ((fresh (a d r)
       (conso a d l)
       (conso a r o)
       (inserto x d r)))))

;; ============================================================
;; 4. PEANO ARITHMETIC
;; ============================================================

(define (zeroo n) (== n 'z))
(define (succo n m) (== m `(s ,n)))
(define (nato n)
  (conde
    ((zeroo n))
    ((fresh (m) (succo m n) (nato m)))))

(define (addo n m k)
  (conde
    ((zeroo n) (== m k))
    ((fresh (n1 k1)
       (succo n1 n)
       (succo k1 k)
       (addo n1 m k1)))))

(define (mulo n m k)
  (conde
    ((zeroo n) (zeroo k))
    ((fresh (n1 k1)
       (succo n1 n)
       (addo m k1 k)
       (mulo n1 m k1)))))

;; ============================================================
;; 5. BIT ARITHMETIC — FULL ADDER
;; ============================================================

(define (bito b) (conde ((== b 0)) ((== b 1))))

(define (half-addo a b s c)
  (conde
    ((== a 0) (== b 0) (== s 0) (== c 0))
    ((== a 1) (== b 0) (== s 1) (== c 0))
    ((== a 0) (== b 1) (== s 1) (== c 0))
    ((== a 1) (== b 1) (== s 0) (== c 1))))

(define (full-addo a b cin s cout)
  (fresh (w c1 c2)
    (half-addo a b w c1)
    (half-addo w cin s c2)
    (conde
      ((== c1 0) (== c2 0) (== cout 0))
      ((== c1 1) (== c2 0) (== cout 1))
      ((== c1 0) (== c2 1) (== cout 1)))))

;; n-bit ripple carry adder: run-adder : bits × bits × cin → (sum-bits, cout)
(define (addero n m sum cin cout)
  (conde
    ((nullo n) (nullo m) (nullo sum) (== cin cout))
    ((fresh (a d b e s r c-mid)
       (conso a d n)
       (conso b e m)
       (conso s r sum)
       (full-addo a b cin s c-mid)
       (addero d e r c-mid cout)))))

;; ============================================================
;; 6. RELATIONAL INTERPRETER (evalo)
;; ============================================================

(define (lookupo x env v)
  (fresh (rest key val)
    (conso (cons key val) rest env)
    (conde
      ((== key x) (== val v))
      ((=/= key x) (lookupo x rest v)))))

(define (eval-expro exp env v)
  (conde
    ;; quote
    ((fresh (c) (== exp `(quote ,c)) (== v c)))
    ;; variable
    ((fresh () (symbolo exp) (lookupo exp env v)))
    ;; lambda
    ((fresh (x body)
       (== exp `(lambda (,x) ,body))
       (== v `(closure ,x ,body ,env))))
    ;; application
    ((fresh (rator rand arg clo x body clo-env)
       (== exp `(,rator ,rand))
       (eval-expro rator env clo)
       (eval-expro rand env arg)
       (applyo clo arg v)))
    ;; cons
    ((fresh (a d va vd)
       (== exp `(cons ,a ,d))
       (eval-expro a env va)
       (eval-expro d env vd)
       (== v (cons va vd))))
    ;; car / cdr
    ((fresh (e pv)
       (== exp `(car ,e))
       (eval-expro e env pv)
       (fresh (d) (conso v d pv))))
    ((fresh (e pv)
       (== exp `(cdr ,e))
       (eval-expro e env pv)
       (fresh (a) (conso a v pv))))
    ;; if
    ((fresh (c t el cv)
       (== exp `(if ,c ,t ,el))
       (eval-expro c env cv)
       (conde
         ((=/= cv #f) (eval-expro t env v))
         ((== cv #f)  (eval-expro el env v)))))
    ;; null?
    ((fresh (e ev)
       (== exp `(null? ,e))
       (eval-expro e env ev)
       (conde
         ((nullo ev) (== v #t))
         ((pairo ev) (== v #f)))))))

(define (applyo clo arg v)
  (fresh (x body env)
    (== clo `(closure ,x ,body ,env))
    (eval-expro body (cons (cons x arg) env) v)))

(define (evalo exp v)
  (eval-expro exp '() v))

;; symbolo — succeeds if x is a non-variable symbol
(define (symbolo x)
  (lambda (st)
    (let ((x (walk x (state-s st))))
      (if (and (symbol? x) (not (var? x)))
          (unit st)
          mzero))))

;; ============================================================
;; 7. SMT STUB
;; ============================================================

;; smt-ando / smt-noto / smt-varo — build SMT terms relationally
(define (smt-ando a b c) (== c `(and ,a ,b)))
(define (smt-noto a c)   (== c `(not ,a)))
(define (smt-varo n v)   (== v `(var ,n)))

;; is-sato — naive contradiction check (no external solver)
(define (is-sato phi)
  (lambda (st)
    (let ((phi (walk* phi (state-s st))))
      (if (sat-check phi)
          (unit st)
          mzero))))

(define (sat-check phi)
  (let ((atoms (collect-atoms phi '())))
    (not (any-contradiction? atoms))))

(define (collect-atoms phi acc)
  (cond
    ((and (pair? phi) (eq? (car phi) 'and))
     (collect-atoms (cadr phi) (collect-atoms (caddr phi) acc)))
    (else (cons phi acc))))

(define (any-contradiction? atoms)
  (any (lambda (a)
         (cond
           ((and (pair? a) (eq? (car a) 'not))
            (member (cadr a) atoms))
           (else
            (member `(not ,a) atoms))))
       atoms))

(define (any pred lst)
  (cond ((null? lst) #f)
        ((pred (car lst)) #t)
        (else (any pred (cdr lst)))))

;; ============================================================
;; 8. EDB FACT STORE (Formulog-style extensional database)
;; ============================================================

(define *edb* '())

(define (assert-edb! rel . args)
  (set! *edb* (cons (cons rel args) *edb*)))

(define (edb-lookupo rel args)
  (lambda (st)
    (let loop ((db *edb*) (s mzero))
      (if (null? db)
          s
          (let ((entry (car db)))
            (if (equal? (car entry) rel)
                (let ((new-s ((== args (cdr entry)) st)))
                  (loop (cdr db) (mplus new-s s)))
                (loop (cdr db) s)))))))

;; ============================================================
;; 9. PARAMETERIZED PATH / REACHABILITY
;; ============================================================

;; patho : rel × node × node × path-term × phi → goal
(define (patho rel x y path phi)
  (conde
    ;; base: direct edge with guard
    ((edb-lookupo rel (list x y phi))
     (== path `(path ,y))
     (is-sato phi))
    ;; step: x→z→...→y
    ((fresh (z e rest phi2)
       (edb-lookupo rel (list x z e))
       (is-sato e)
       (patho rel z y rest phi2)
       (== path `(path ,z ,rest))
       (smt-ando e phi2 phi)))))

;; reacho : rel × source × target → goal
(define (reacho rel s t)
  (conde
    ((== s t))
    ((fresh (mid)
       (edb-lookupo rel (list s mid #t))
       (reacho rel mid t)))))

;; ============================================================
;; 10. FSM RELATIONS
;; ============================================================

;; fsm transitions: (fsm-id state input next-state output)
(define (assert-fsm-transition! id st inp nst out)
  (assert-edb! 'fsm id st inp nst out))

(define (fsmo id st inp nst out)
  (edb-lookupo 'fsm (list id st inp nst out)))

;; fsm-traceo : id × state × inputs × outputs → goal
(define (fsm-traceo id s0 inputs outputs)
  (conde
    ((nullo inputs) (nullo outputs))
    ((fresh (i rest-in o rest-out s1)
       (conso i rest-in inputs)
       (conso o rest-out outputs)
       (fsmo id s0 i s1 o)
       (fsm-traceo id s1 rest-in rest-out)))))

;; ============================================================
;; 11. REFINEMENT LATTICE
;; ============================================================

;; refineo : abstract × concrete → goal
(define (refineo abs conc)
  (conde
    ;; concrete value matches
    ((fresh (c) (== abs `(conc ,c)) (== conc c)))
    ;; top refines everything
    ((== abs 'top))
    ;; interval
    ((fresh (lo hi)
       (== abs `(interval ,lo ,hi))
       (leq-nato lo conc)
       (leq-nato conc hi)))))

;; leq-nato : Peano × Peano → goal  (n ≤ m)
(define (leq-nato n m)
  (conde
    ((zeroo n))
    ((fresh (n1 m1)
       (succo n1 n)
       (succo m1 m)
       (leq-nato n1 m1)))))

;; ============================================================
;; 12. SEED DATA AND SMOKE TESTS
;; ============================================================

(define (seed-db!)
  ;; Edge relations
  (assert-edb! 'edge 0 1 '(bv-slt (var x) (var y)))
  (assert-edb! 'edge 1 2 '(bv-slt (var y) (var z)))
  (assert-edb! 'edge 2 3 '(and (var p) (not (var q))))
  (assert-edb! 'edge 0 2 #t)
  (assert-edb! 'edge 1 3 #t)
  ;; FSM transitions (two-state toggle)
  (assert-fsm-transition! 'fsm0 's0 0 's0 0)
  (assert-fsm-transition! 'fsm0 's0 1 's1 0)
  (assert-fsm-transition! 'fsm0 's1 0 's0 1)
  (assert-fsm-transition! 'fsm0 's1 1 's1 1))

(define (run-tests!)
  (seed-db!)
  (display "=== mu_kanren Lattice Kernel ===") (newline)

  ;; appendo
  (display "appendo: ")
  (display (run* (q) (appendo '(1 2) '(3) q)))
  (newline)

  ;; addo: 1 + 2 = 3 (Peano)
  (display "addo(s(z), s(s(z)), ?): ")
  (display (run* (q) (addo '(s z) '(s (s z)) q)))
  (newline)

  ;; full-addo: 1+1+0 = (s=0,cout=1)
  (display "full-addo(1,1,0,s,c): ")
  (display (run* (q) (fresh (s c) (full-addo 1 1 0 s c) (== q (list s c)))))
  (newline)

  ;; evalo: identity function applied to symbol
  (display "evalo((lambda (x) x) applied to 'a): ")
  (display (run 1 (q) (evalo '((lambda (x) x) (quote a)) q)))
  (newline)

  ;; reachability
  (display "reachable from 0: ")
  (display (run* (q) (reacho 'edge 0 q)))
  (newline)

  ;; FSM trace
  (display "FSM trace (0 1 0): ")
  (display (run* (q) (fsm-traceo 'fsm0 's0 '(0 1 0) q)))
  (newline)

  ;; refinement
  (display "refines(interval(1,3), 2): ")
  (display (run 1 (q) (refineo '(interval (s z) (s (s (s z)))) '(s (s z)))))
  (newline)

  ;; disequality
  (display "=/= test: ")
  (display (run* (q) (fresh (x) (== x 1) (=/= x 2) (== q x))))
  (newline)

  ;; sat stub
  (display "is-sat (and p (not q)): ")
  (display (run 1 (q) (is-sato '(and (var p) (not (var q)))) (== q #t)))
  (newline)

  ;; contradiction check
  (display "is-sat (and p (not p)) should be empty: ")
  (display (run 1 (q) (is-sato '(and (var p) (not (var p)))) (== q #t)))
  (newline)

  (display "=== ALL TESTS COMPLETE ===") (newline))

(run-tests!)
