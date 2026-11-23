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

(module infocom/base)

(def %zm-undo ())
(def %zm-undo-depth 8)

(def zm-undo-reset! (fn (_) (set! %zm-undo ())))

; A frame is (return-pc store locals base argc nlocals); its locals are
; written in place, so a state keeps its own copy.
(def %zm-copy-frame
  (fn (_ f)
    (def r (rest (rest f)))
    (pair (first f) (pair (first (rest f)) (pair (zm-locals-copy (first r)) (rest r))))))

(def %zm-take
  (fn (self l n) (if (if (null? l) #t (zm= n 0)) () (pair (first l) (self (rest l) (zm- n 1))))))

; save_undo: keep the machine; answers 1, what save_undo stores now.
(def zm-save-undo
  (fn (_ next st)
    (def n zm-hdr-static)
    (def m (%zm-str-make (zm+ n 1)))
    (%zm-mem-copy (%zm-str->ptr m) %zm-ptr n)
    ; the stack's words up to the top, as one block
    (def bytes (zm<< (zm+ %zm-sp 1) 1))
    (def stack (%zm-str-make (zm+ bytes 1)))
    (%zm-mem-copy (%zm-str->ptr stack) %zm-sptr bytes)
    (def state
      (list m stack %zm-sp %zm-base zm-argc %zm-nlocals (zm-locals-copy %zm-locals)
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
        (%zm-mem-copy %zm-sptr (%zm-str->ptr stack) (zm<< (zm+ sp 1) 1))
        (def r2 (rest (rest r)))
        (set! %zm-sp sp)
        (set! %zm-base (first r2))
        (set! zm-argc (first (rest r2)))
        (set! %zm-nlocals (first (rest (rest r2))))
        (%zm-locals! (first (rest (rest (rest r2)))))
        (def r3 (rest (rest (rest (rest r2)))))
        (set! %zm-frames (first r3))
        (def next (first (rest r3)))
        (zm-var-set! (first (rest (rest r3))) 2)
        next))))
