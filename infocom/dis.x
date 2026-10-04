; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/dis.x -- the disassembler
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Prints instructions from the parser the machine runs on, one a line, in
; the spirit of txd:
;
;   4f05: call 2a39 #8010 #ffff -> sp
;   4f0e: je l01 #03 ?~4f19
;
; Operands: #hex a constant, sp the stack, l01..l0f a local, g00..gef a
; global.  -> names the store; ? a branch taken when the test holds, ?~
; when it fails, to an address or rtrue/rfalse.  Text is shown quoted.

(provide infocom/dis zm-dis zm-dis-at zm-dis-code zm-dis-routine zm-dis-routine-at
  zm-trace-run)

(def %zm-hex-digit (fn (_ d) (if (zm< d 10) (zm+ d 48) (zm+ d 87))))

; v as at least n hex digits.
(def %zm-hex
  (fn (_ v n)
    (def go
      (fn (self v n acc)
        (if (if (zm= v 0) (zm< n 1) #f) acc
          (self (zm>> v 4) (zm- n 1) (pair (%zm-hex-digit (zm& v 15)) acc)))))
    (go v n ())))

(def %zm-put (fn (_ cs) (zm-out-codes cs)))
(def %zm-puts (fn (_ s) (zm-out-ascii s)))

(def %zm-dis-var
  (fn (_ v)
    (match
      ((zm= v 0) (%zm-puts "sp"))
      ((zm< v 16) (do (%zm-puts "l") (%zm-put (%zm-hex v 2))))
      (#t (do (%zm-puts "g") (%zm-put (%zm-hex (zm- v 16) 2)))))))

(def %zm-dis-operand
  (fn (_ o)
    (if (zm= (first o) 2)
      (%zm-dis-var (rest o))
      (do (%zm-puts "#") (%zm-put (%zm-hex (rest o) (if (zm= (first o) 0) 4 2)))))))

; One instruction at pc, printed; answers the next pc.
(def zm-dis-at
  (fn (_ pc)
    (def ins (zm-parse pc))
    (def kind (first ins))
    (def r (rest (rest ins)))
    (def entry (zm-op-entry kind (first (rest ins))))
    (%zm-put (%zm-hex pc 4))
    (%zm-puts ": ")
    (%zm-puts (first entry))
    (def ops
      (fn (self os)
        (if (null? os) ()
          (do (%zm-puts " ") (%zm-dis-operand (first os)) (self (rest os))))))
    (ops (first r))
    (def st (first (rest r)))
    (if (zm< st 0) () (do (%zm-puts " -> ") (%zm-dis-var st)))
    (def br (first (rest (rest r))))
    (if (null? br) ()
      (do
        (%zm-puts (if (first br) " ?" " ?~"))
        (match
          ((zm= (rest br) 0) (%zm-puts "rfalse"))
          ((zm= (rest br) 1) (%zm-puts "rtrue"))
          (#t (%zm-put (%zm-hex (rest br) 4))))))
    (def tx (first (rest (rest (rest r)))))
    (if (null? tx) () (do (%zm-puts " \"") (%zm-put tx) (%zm-puts "\"")))
    (zm-out-zscii 13)
    (first (rest (rest (rest (rest r)))))))

; n instructions from pc.
(def zm-dis
  (fn (_ pc n)
    (def go (fn (self pc k) (if (zm< k n) (self (zm-dis-at pc) (zm+ k 1)))))
    (go pc 0)
    (zm-flush)))

; Code from start until its last instruction: one that returns, jumps or
; quits, past every branch and jump target seen so far.
(def zm-dis-code
  (fn (_ start)
    (def go
      (fn (self pc far)
        (def ins (zm-parse pc))
        (def kind (first ins))
        (def op (first (rest ins)))
        (def br (first (rest (rest (rest (rest ins))))))
        (def far2 (if (null? br) far (if (zm< far (rest br)) (rest br) far)))
        (def ops (first (rest (rest ins))))
        (def o1 (if (null? ops) (pair 2 0) (first ops)))
        (def far3
          (if (if (zm= kind 1) (if (zm= op 12) (not (zm= (first o1) 2)) #f) #f)
            (do
              (def t (zm- (zm+ (first (rest (rest (rest (rest (rest (rest ins)))))))
                              (zm-signed (rest o1)))
                          2))
              (if (zm< far2 t) t far2))
            far2))
        (def next (zm-dis-at pc))
        (def ends?
          (match
            ((zm= kind 0) (%zm-member? op (list 0 1 3 7 8 10)))
            ((zm= kind 1) (if (zm= op 11) #t (zm= op 12)))
            (#t #f)))
        (if (if ends? (zm< far3 next) #f) () (self next far3))))
    (go start 0)
    (zm-flush)))

; The routine at byte address a: its header, then its code.
(def zm-dis-routine-at
  (fn (_ a)
    (def n (zm-rb a))
    (%zm-puts "routine ")
    (%zm-put (%zm-hex a 4))
    (%zm-puts ", ")
    (zm-out-num n)
    (%zm-puts " locals")
    (zm-out-zscii 13)
    (zm-dis-code (if (zm< zm-version 5) (zm+ (zm+ a 1) (zm<< n 1)) (zm+ a 1)))))

; The routine at packed address p.
(def zm-dis-routine (fn (_ p) (zm-dis-routine-at (zm-unpack p))))

; Run with every instruction printed before it runs: the pc and the
; instruction, as zm-dis prints it, for the first limit instructions.
(def zm-trace-run
  (fn (_ pc limit)
    (def go
      (fn (self pc k)
        (if (if (zm< pc 0) #t (zm< limit k)) pc
          (do
            (if (zm= (zm% k 1000) 999) (do (zm-flush) (Heap collect)))
            (zm-dis-at pc) (zm-flush)
            (self ((zm-insn-at pc)) (zm+ k 1))))))
    (go pc 0)))
