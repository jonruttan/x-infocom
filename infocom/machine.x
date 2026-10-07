; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/machine.x -- starting a story, the run loop, and the
; operations that reach outside the instruction set
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The loop is one tail call an instruction: fetch the closure for pc, run
; it, take the pc it answers.

(provide infocom/machine
  zm-start! zm-run zm-play zm-restart!
  zm-sread zm-aread zm-scan-table zm-encode-text!
  zm-copy-table! zm-print-table)

; The story's file name without its directory or extension: the stem a
; save file is named for.
(def %zm-stem
  (fn (_ path)
    (def n (%zm-byte-len path))
    (def c (fn (_ i) (%zm-char->int (%zm-byte-ref path i))))
    (def slash (fn (self i) (if (zm< i 0) 0 (if (zm= (c i) 47) (zm+ i 1) (self (zm- i 1))))))
    (def s (slash (zm- n 1)))
    (def dot (fn (self i) (if (zm< i s) n (if (zm= (c i) 46) i (self (zm- i 1))))))
    (def e (dot (zm- n 1)))
    (Str8 sub s (zm- (if (zm= e s) n e) s) path)))

(def zm-start!
  (fn (_ path)
    (zm-load! path)
    ; the first byte of a story is its version, 1 to 8; anything else is
    ; not a story file at all
    (if (if (zm< zm-version 1) #t (zm< 8 zm-version))
      (Err raise (lit infocom)
        (Str8 append "not a Z-machine story file (version byte " (Str8 append (%zm-hex-str zm-version) ")"))
        zm-version))
    (if (if (zm< zm-version 3) #t (if (zm= zm-version 6) #t (zm= zm-version 7)))
      (Err raise (lit infocom)
        (Str8 append "story version " (Str8 append (%zm-hex-str zm-version) " not served (3, 4, 5 and 8 are)"))
        zm-version))
    (set! %zm-story-name (%zm-stem path))
    (set! %qz-default ())
    (zm-decode-reset!)
    (zm-text-reset!)
    (zm-cpu-reset!)
    (zm-undo-reset!)
    (zm-ops-install!)
    (zm-seed! 1)
    (zm-screen-start!)
    zm-hdr-pc))

; Run from pc until an instruction answers a negative pc.  Between two
; instructions nothing is mid-flight, so every %zm-run-sweep of them the
; loop collects: a story can run long before its first read, where the
; other collect is.
(def %zm-run-sweep 50000)
(def %zm-run-from
  (fn (self pc k)
    (if (zm< pc 0) pc
      (if (zm= k 0)
        (do (Heap collect) (self pc %zm-run-sweep))
        (self ((zm-insn-at pc)) (zm- k 1))))))
(def zm-run (fn (_ pc) (%zm-run-from pc %zm-run-sweep)))

; Run the story at path on the given command lines, echoed as typed.
(def zm-play
  (fn (_ path lines)
    (zm-input-script! lines)
    (def pc (zm-start! path))
    (zm-run pc)
    (zm-screen-end!)
    ()))

(def zm-restart!
  (fn (_)
    (zm-flush)
    (zm-reset-memory!)
    (zm-cpu-reset!)
    (zm-undo-reset!)
    (zm-text-reset!)
    (zm-screen-start!)
    zm-hdr-pc))


; sread (versions 1 to 4): text from byte 1, ended by a zero byte.
(def zm-sread
  (fn (_ t p)
    (def line (zm-read-line (zm- (zm-rb t) 1)))
    (if (null? line) #f
      (do
        (def put
          (fn (self cs i)
            (if (null? cs) (zm-wb! (zm+ (zm+ t 1) i) 0)
              (do (zm-wb! (zm+ (zm+ t 1) i) (first cs)) (self (rest cs) (zm+ i 1))))))
        (put (rest line) 0)
        (if (zm= p 0) () (zm-tokenise! t p 0 #f))
        #t))))

; aread (version 5 on): the count in byte 1, text from byte 2.
(def zm-aread
  (fn (_ t p)
    (def line (zm-read-line (zm-rb t)))
    (if (null? line) #f
      (do
        (def put
          (fn (self cs i)
            (if (null? cs) (zm-wb! (zm+ t 1) i)
              (do (zm-wb! (zm+ (zm+ t 2) i) (first cs)) (self (rest cs) (zm+ i 1))))))
        (put (rest line) 0)
        (if (zm= p 0) () (zm-tokenise! t p 0 #f))
        #t))))


(def zm-scan-table
  (fn (_ x t n form)
    (def size (zm& form 127))
    (def word? (not (zm= (zm& form 128) 0)))
    (def go
      (fn (self i)
        (if (zm< i n)
          (do
            (def a (zm+ t (zm* i size)))
            (if (zm= (if word? (zm-rw a) (zm-rb a)) x) a (self (zm+ i 1))))
          0)))
    (go 0)))

(def zm-encode-text!
  (fn (_ t n from to)
    (def codes
      (fn (self i)
        (if (zm< i n) (pair (zm-rb (zm+ (zm+ t from) i)) (self (zm+ i 1))) ())))
    (def put
      (fn (self ws a)
        (if (null? ws) () (do (zm-ww! a (first ws)) (self (rest ws) (zm+ a 2))))))
    (put (zm-encode-word (codes 0)) to)))

(def zm-copy-table!
  (fn (_ a b size)
    (def s (zm-signed size))
    (def n (if (zm< s 0) (zm- 0 s) s))
    (def fwd
      (fn (self i)
        (if (zm< i n) (do (zm-wb! (zm+ b i) (zm-rb (zm+ a i))) (self (zm+ i 1))))))
    (def back
      (fn (self i)
        (if (zm< i 0) () (do (zm-wb! (zm+ b i) (zm-rb (zm+ a i))) (self (zm- i 1))))))
    (def zero
      (fn (self i)
        (if (zm< i n) (do (zm-wb! (zm+ a i) 0) (self (zm+ i 1))))))
    (match
      ((zm= b 0) (zero 0))
      ((zm< s 0) (fwd 0))
      ((zm< a b) (back (zm- n 1)))
      (#t (fwd 0)))))

(def zm-print-table
  (fn (_ t w h skip)
    (def row
      (fn (self a i)
        (if (zm< i w) (do (zm-out-zscii (zm-rb (zm+ a i))) (self a (zm+ i 1))))))
    (def rows
      (fn (self r)
        (if (zm< r h)
          (do
            (if (zm< 0 r) (zm-out-zscii 13))
            (row (zm+ t (zm* r (zm+ w skip))) 0)
            (self (zm+ r 1))))))
    (rows 0)))
