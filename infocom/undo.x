; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/undo.x -- save_undo and restore_undo
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; An undo state is the machine as save_undo found it: dynamic memory (one
; block copy), the stack up to its top, the frames with copies of their
; locals, and where save_undo goes on to.  Up to eight are kept, newest
; first, so a game can undo several turns.  restore_undo puts the newest
; back and finishes that save_undo a second time, storing 2.

(provide infocom/undo zm-save-undo zm-restore-undo zm-undo-reset!)

(def %zm-undo ())
(def %zm-undo-depth 8)

(def zm-undo-reset! (fn (_) (set! %zm-undo ())))

(def %zm-copy-locals
  (fn (_ v)
    (def c (%zm-vec 15))
    (def go (fn (self i) (if (zm< i 16) (do (%zm-obj-set! c i (%zm-obj-ref v i)) (self (zm+ i 1))))))
    (go 1)
    c))

; A frame is (return-pc store locals base argc nlocals); its locals are
; written in place, so a state keeps its own copy.
(def %zm-copy-frame
  (fn (_ f)
    (def r (rest (rest f)))
    (pair (first f) (pair (first (rest f)) (pair (%zm-copy-locals (first r)) (rest r))))))

(def %zm-take
  (fn (self l n) (if (if (null? l) #t (zm= n 0)) () (pair (first l) (self (rest l) (zm- n 1))))))

; save_undo: keep the machine; answers 1, what save_undo stores now.
(def zm-save-undo
  (fn (_ next st)
    (def n zm-hdr-static)
    (def m (%zm-str-make (zm+ n 1)))
    (%zm-mem-copy (%zm-str->ptr m) %zm-ptr n)
    (def stack (%zm-vec %zm-sp))
    (def copy (fn (self i) (if (zm< %zm-sp i) () (do (%zm-obj-set! stack i (%zm-obj-ref %zm-stack i)) (self (zm+ i 1))))))
    (copy 1)
    (def state
      (list m stack %zm-sp %zm-base zm-argc %zm-nlocals (%zm-copy-locals %zm-locals)
        (List map %zm-copy-frame %zm-frames) next st))
    (set! %zm-undo (%zm-take (pair state %zm-undo) %zm-undo-depth))
    1))

; restore_undo: the newest state back, its save_undo storing 2; answers
; the pc to go on from, or () when there is none.
(def zm-restore-undo
  (fn (_)
    (if (null? %zm-undo) ()
      (do
        (def s (first %zm-undo))
        (set! %zm-undo (rest %zm-undo))
        (def keep (zm& (zm-rb 17) 3))
        (%zm-mem-copy %zm-ptr (%zm-str->ptr (first s)) zm-hdr-static)
        (zm-wb! 17 (zm| (zm& (zm-rb 17) 252) keep))
        (def r (rest s))
        (def stack (first r))
        (def sp (first (rest r)))
        (def put (fn (self i) (if (zm< sp i) () (do (%zm-obj-set! %zm-stack i (%zm-obj-ref stack i)) (self (zm+ i 1))))))
        (put 1)
        (def r2 (rest (rest r)))
        (set! %zm-sp sp)
        (set! %zm-base (first r2))
        (set! zm-argc (first (rest r2)))
        (set! %zm-nlocals (first (rest (rest r2))))
        (set! %zm-locals (first (rest (rest (rest r2)))))
        (def r3 (rest (rest (rest (rest r2)))))
        (set! %zm-frames (first r3))
        (def next (first (rest r3)))
        (zm-var-set! (first (rest (rest r3))) 2)
        next))))
