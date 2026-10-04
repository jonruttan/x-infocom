; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/cpu.x -- variables, the stack, calls and returns
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Variable 0 is the top of the stack, 1..15 the routine's locals, 16..255
; the globals table.  The stack is one vector with a top index; a frame
; keeps where its routine's part of the stack began, so a return drops
; whatever the routine left.  Frames are (return-pc store locals base argc)
; for the caller, pushed on a call and popped on a return.  Program
; counters are plain addresses, and every operation answers the next one;
; a negative pc stops the machine.

(provide infocom/cpu
  zm-push zm-pop zm-var zm-var-set! zm-var-peek zm-var-poke!
  zm-call zm-return zm-throw zm-frame-id zm-argc zm-cpu-reset!
  zm-random)

(def %zm-stack-size 32768)
(def %zm-stack ())
(def %zm-sp 0)
(def %zm-base 0)
(def %zm-locals ())
(def %zm-frames ())
(def zm-argc 0)

(def zm-cpu-reset!
  (fn (_)
    (set! %zm-stack (%zm-vec %zm-stack-size))
    (set! %zm-sp 0)
    (set! %zm-base 0)
    (set! %zm-locals (%zm-new-locals))
    (set! %zm-frames ())
    (set! zm-argc 0)))

; Locals: always 15 slots, so a stray local number reads 0, not past the end.
(def %zm-new-locals
  (fn (_)
    (def v (%zm-vec 15))
    (def go (fn (self i) (if (zm< i 16) (do (%zm-obj-set! v i 0) (self (zm+ i 1))))))
    (go 1)
    v))

(def zm-push
  (fn (_ x)
    (if (zm< %zm-sp %zm-stack-size) ()
      (Err raise (lit infocom) "stack overflow" %zm-sp))
    (set! %zm-sp (zm+ %zm-sp 1))
    (%zm-obj-set! %zm-stack %zm-sp x)))

(def zm-pop
  (fn (_)
    (if (zm< %zm-base %zm-sp) ()
      (Err raise (lit infocom) "stack underflow" %zm-sp))
    (def x (%zm-obj-ref %zm-stack %zm-sp))
    (set! %zm-sp (zm- %zm-sp 1))
    x))

(def %zm-global-addr (fn (_ v) (zm+ zm-hdr-globals (zm<< (zm- v 16) 1))))

(def zm-var
  (fn (_ v)
    (if (zm= v 0) (zm-pop)
      (if (zm< v 16) (%zm-obj-ref %zm-locals v)
        (zm-rw (%zm-global-addr v))))))

(def zm-var-set!
  (fn (_ v x)
    (if (zm= v 0) (zm-push x)
      (if (zm< v 16) (%zm-obj-set! %zm-locals v x)
        (zm-ww! (%zm-global-addr v) x)))))

; The indirect forms (inc, dec, load, store, pull...): variable 0 is the
; top of the stack read or written in place.
(def zm-var-peek
  (fn (_ v)
    (if (zm= v 0)
      (if (zm< %zm-base %zm-sp) (%zm-obj-ref %zm-stack %zm-sp)
        (Err raise (lit infocom) "stack underflow" %zm-sp))
      (zm-var v))))

(def zm-var-poke!
  (fn (_ v x)
    (if (zm= v 0)
      (if (zm< %zm-base %zm-sp) (%zm-obj-set! %zm-stack %zm-sp x)
        (Err raise (lit infocom) "stack underflow" %zm-sp))
      (zm-var-set! v x))))

; Call the routine at packed address paddr with args; store is the result
; variable, -1 for none; next is the pc to come back to.  Answers the pc
; to run.  Calling address 0 answers false without running anything.
(def zm-call
  (fn (_ paddr args store next)
    (if (zm= paddr 0)
      (do (if (zm< store 0) () (zm-var-set! store 0)) next)
      (do
        (def a (zm-unpack paddr))
        (def n (zm-rb a))
        (set! %zm-frames (pair (list next store %zm-locals %zm-base zm-argc) %zm-frames))
        (def locals (%zm-new-locals))
        (if (zm< zm-version 5)
          (do
            (def init
              (fn (self i)
                (if (zm< n i) ()
                  (do (%zm-obj-set! locals i (zm-rw (zm+ (zm+ a 1) (zm<< (zm- i 1) 1))))
                      (self (zm+ i 1))))))
            (init 1)))
        (def fill
          (fn (self i as)
            (if (if (null? as) #t (zm< n i)) ()
              (do (%zm-obj-set! locals i (first as)) (self (zm+ i 1) (rest as))))))
        (fill 1 args)
        (set! %zm-locals locals)
        (set! %zm-base %zm-sp)
        (set! zm-argc (%zm-length args))
        (if (zm< zm-version 5) (zm+ (zm+ a 1) (zm<< n 1)) (zm+ a 1))))))

; Return v from the running routine: answers the caller's pc.
(def zm-return
  (fn (_ v)
    (if (null? %zm-frames) (Err raise (lit infocom) "return from the main routine" v))
    (def f (first %zm-frames))
    (set! %zm-frames (rest %zm-frames))
    (set! %zm-sp %zm-base)
    (def r (rest f))
    (def store (first r))
    (set! %zm-locals (first (rest r)))
    (set! %zm-base (first (rest (rest r))))
    (set! zm-argc (first (rest (rest (rest r)))))
    (if (zm< store 0) () (zm-var-set! store v))
    (first f)))

; catch answers the current frame's identity; throw returns from it.
(def zm-frame-id (fn (_) (%zm-length %zm-frames)))
(def zm-throw
  (fn (_ v id)
    (def unwind
      (fn (self)
        (if (zm< id (%zm-length %zm-frames))
          (do
            (def f (first %zm-frames))
            (set! %zm-frames (rest %zm-frames))
            (set! %zm-sp %zm-base)
            (def r (rest f))
            (set! %zm-locals (first (rest r)))
            (set! %zm-base (first (rest (rest r))))
            (set! zm-argc (first (rest (rest (rest r)))))
            (self)))))
    (unwind)
    (zm-return v)))

; ---------------------------------------------------------------------------
; random: n > 0 a number in 1..n; n < 0 seeds (below 1000, the predictable
; mode that counts 1, 2, ... n); 0 seeds from the clock.

(def %zm-rng 1)
(def %zm-rng-cycle 0)
(def %zm-rng-count 0)

(def %zm-xorshift
  (fn (_)
    (def x %zm-rng)
    (def x1 (zm& (zm^ x (zm<< x 13)) 4294967295))
    (def x2 (zm^ x1 (zm>> x1 17)))
    (def x3 (zm& (zm^ x2 (zm<< x2 5)) 4294967295))
    (set! %zm-rng (if (zm= x3 0) 1 x3))
    %zm-rng))

(def zm-seed!
  (fn (_ s)
    (set! %zm-rng-cycle 0)
    (set! %zm-rng (if (zm= s 0) 1 (zm& s 4294967295)))))

(def zm-random
  (fn (_ r)
    (def n (zm-signed r))
    (match
      ((zm< 0 n)
        (if (zm= %zm-rng-cycle 0)
          (zm+ (zm% (zm>> (%zm-xorshift) 1) n) 1)
          (do
            (set! %zm-rng-count (zm+ (zm% %zm-rng-count %zm-rng-cycle) 1))
            (zm+ (zm% (zm- %zm-rng-count 1) n) 1))))
      ((zm= n 0) (do (zm-seed! (%zm-clock-seed)) 0))
      ((zm< n -999) (do (zm-seed! (zm- 0 n)) 0))
      (#t (do (set! %zm-rng-cycle (zm- 0 n)) (set! %zm-rng-count 0) 0)))))

(def %zm-clock-seed
  (fn (_) (zm& (zm+ (Sys getpid) (zm* %zm-rng 69069)) 4294967295)))
