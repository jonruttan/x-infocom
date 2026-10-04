; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/decode.x -- instructions, read once and kept as closures
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; An instruction is parsed into a record -- (kind op operands store branch
; text next) -- which the disassembler can print and the machine builds
; into a closure.  The closure does the operation and answers the next pc.
; Code at or past the static base cannot change, so the closure built for
; an address there is kept in a vector over the story and the instruction
; is never read again; below the base it is read on every visit.
;
; kind: 0 0OP, 1 1OP, 2 2OP, 3 VAR, 4 EXT.  An operand is (type . value):
; type 0 a word constant, 1 a byte constant, 2 a variable number.  A branch
; is (on-true . target), target 0 or 1 for return false or true, else the
; address.  store is the variable number, or -1.

(provide infocom/decode
  zm-parse zm-insn-at zm-decode-reset! zm-op-entry
  %zm-optab-set!)

; One table a kind, 32 entries, each (name store? branch? text? builder);
; ops.x fills them for the story's version.
(def %zm-optab ())

(def %zm-optab-set!
  (fn (_ kind op entry)
    (%zm-obj-set! (%zm-obj-ref %zm-optab (zm+ kind 1)) (zm+ op 1) entry)))

(def zm-op-entry
  (fn (_ kind op)
    (%zm-obj-ref (%zm-obj-ref %zm-optab (zm+ kind 1)) (zm+ op 1))))

(def %zm-icache ())

(def zm-decode-reset!
  (fn (_)
    (set! %zm-icache (%zm-vec zm-size))
    (set! %zm-optab (%zm-vec 5))
    (def go (fn (self k) (if (zm< k 6) (do (%zm-obj-set! %zm-optab k (%zm-vec 32)) (self (zm+ k 1))))))
    (go 1)))

; Operand types from n type bytes at a, stopping at the first "omitted".
(def %zm-types
  (fn (_ a n)
    (def byte-types
      (fn (_ b)
        (list (zm& (zm>> b 6) 3) (zm& (zm>> b 4) 3) (zm& (zm>> b 2) 3) (zm& b 3))))
    (def all
      (if (zm= n 1) (byte-types (zm-rb a))
        (List append (byte-types (zm-rb a)) (byte-types (zm-rb (zm+ a 1))))))
    (def take (fn (self ts) (if (if (null? ts) #t (zm= (first ts) 3)) () (pair (first ts) (self (rest ts))))))
    (take all)))

; Operands of the given types from a: (operands . next-address).
(def %zm-operands
  (fn (_ types a)
    (def go
      (fn (self ts a acc)
        (if (null? ts) (pair (%zm-rev acc) a)
          (if (zm= (first ts) 0)
            (self (rest ts) (zm+ a 2) (pair (pair 0 (zm-rw a)) acc))
            (self (rest ts) (zm+ a 1) (pair (pair (first ts) (zm-rb a)) acc))))))
    (go types a ())))

(def zm-parse
  (fn (_ pc)
    (def b (zm-rb pc))
    (match
      ((if (zm= b 190) (zm< 4 zm-version) #f)
        (%zm-parse-tail pc 4 (zm-rb (zm+ pc 1)) (%zm-types (zm+ pc 2) 1) (zm+ pc 3)))
      ((zm< 191 b)
        (do
          (def op (zm& b 31))
          (def kind (if (zm= (zm& b 32) 0) 2 3))
          (def two? (if (zm= kind 3) (if (zm= op 12) #t (zm= op 26)) #f))
          (%zm-parse-tail pc kind op (%zm-types (zm+ pc 1) (if two? 2 1))
            (zm+ pc (if two? 3 2)))))
      ((zm< 127 b)
        (do
          (def t (zm& (zm>> b 4) 3))
          (if (zm= t 3)
            (%zm-parse-tail pc 0 (zm& b 15) () (zm+ pc 1))
            (%zm-parse-tail pc 1 (zm& b 15) (list t) (zm+ pc 1)))))
      (#t
        (%zm-parse-tail pc 2 (zm& b 31)
          (list (if (zm= (zm& b 64) 0) 1 2) (if (zm= (zm& b 32) 0) 1 2))
          (zm+ pc 1))))))

(def %zm-parse-tail
  (fn (_ pc kind op types a)
    (def entry (zm-op-entry kind op))
    (if (null? entry)
      (Err raise (lit infocom)
        (Str8 append "illegal opcode at "
          (Str8 append (%zm-hex-str pc)
            (Str8 append ": kind " (Str8 append (%zm-hex-str kind)
              (Str8 append " op " (%zm-hex-str op))))))
        (list pc kind op)))
    (def flags (rest entry))
    (def ops (%zm-operands types a))
    (def a1 (rest ops))
    (def st (if (first flags) (zm-rb a1) -1))
    (def a2 (if (first flags) (zm+ a1 1) a1))
    (def br (if (first (rest flags)) (%zm-branch-at a2) ()))
    (def a3 (if (null? br) a2 (rest br)))
    (def tx (if (first (rest (rest flags))) (zm-zstring-at a3) ()))
    (def next (if (null? tx) a3 (rest tx)))
    (list kind op (first ops) st (if (null? br) () (first br))
      (if (null? tx) () (first tx)) next)))

; A branch at a: ((on-true . target) . next-address).
(def %zm-branch-at
  (fn (_ a)
    (def b (zm-rb a))
    (def on (not (zm= (zm& b 128) 0)))
    (if (zm= (zm& b 64) 0)
      (do
        (def raw (zm| (zm<< (zm& b 63) 8) (zm-rb (zm+ a 1))))
        (def off (if (zm< raw 8192) raw (zm- raw 16384)))
        (pair (pair on (%zm-branch-target off (zm+ a 2))) (zm+ a 2)))
      (pair (pair on (%zm-branch-target (zm& b 63) (zm+ a 1))) (zm+ a 1)))))

(def %zm-branch-target
  (fn (_ off after)
    (if (if (zm= off 0) #t (zm= off 1)) off (zm- (zm+ after off) 2))))

; An operand as a getter: a constant answers itself, variable 0 pops.
(def %zm-getter
  (fn (_ o)
    (def v (rest o))
    (if (zm= (first o) 2)
      (if (zm= v 0) zm-pop
        (if (zm< v 16)
          (fn (_) (%zm-obj-ref %zm-locals v))
          (do (def g (%zm-global-addr v)) (fn (_) (zm-rw g)))))
      (fn (_) v))))

; The address of the instruction being built, for the one builder that
; needs its own address rather than the next: a save records where its
; branch data is.
(def %zm-building-pc 0)

(def %zm-build
  (fn (_ pc)
    (set! %zm-building-pc pc)
    (def ins (zm-parse pc))
    (def kind (first ins))
    (def r (rest (rest ins)))
    (def builder (first (rest (rest (rest (rest (zm-op-entry kind (first (rest ins)))))))))
    (builder (List map %zm-getter (first r)) (first (rest r)) (first (rest (rest r)))
      (first (rest (rest (rest r)))) (first (rest (rest (rest (rest r))))))))

(def zm-insn-at
  (fn (_ pc)
    (if (zm< pc zm-hdr-static)
      (%zm-build pc)
      (do
        (def hit (%zm-obj-ref %zm-icache (zm+ pc 1)))
        (if (null? hit)
          (do
            (def c (%zm-build pc))
            (%zm-obj-set! %zm-icache (zm+ pc 1) c)
            c)
          hit)))))
