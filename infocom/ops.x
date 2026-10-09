; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/ops.x -- what each instruction does
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; A builder takes an instruction's operand getters, store variable, branch,
; text and next pc, and answers the closure that runs it.  Operands are
; fetched left to right, each once, since a stack operand pops.  The table
; is filled for the story's version, so an opcode another version gives a
; different shape -- save, restore, pop/catch, not/call_1n -- is decoded as
; the story expects.

(provide infocom/ops zm-ops-install! zm-quit-pc)

(def zm-quit-pc -1)

(def %zm-zero (fn (_) 0))

(def %zm-g
  (fn (self ops i)
    (if (null? ops) %zm-zero
      (if (zm= i 0) (first ops) (self (rest ops) (zm- i 1))))))

(def %zm-br
  (fn (_ c br next)
    (if (if c (first br) (not (first br)))
      (if (zm< (rest br) 2) (zm-return (rest br)) (rest br))
      next)))

(def %zm-eval-all
  (fn (self gs) (if (null? gs) () (do (def v ((first gs))) (pair v (self (rest gs)))))))

; --- builder shapes --------------------------------------------------------

(def %zm-store1
  (fn (_ f)
    (fn (_ ops st br tx next)
      (def a (%zm-g ops 0))
      (fn (_) (zm-var-set! st (f (a))) next))))

(def %zm-store2
  (fn (_ f)
    (fn (_ ops st br tx next)
      (def a (%zm-g ops 0))
      (def b (%zm-g ops 1))
      (fn (_)
        (def x (a))
        (def y (b))
        (zm-var-set! st (f x y))
        next))))

(def %zm-branch1
  (fn (_ f)
    (fn (_ ops st br tx next)
      (def a (%zm-g ops 0))
      (fn (_) (%zm-br (f (a)) br next)))))

(def %zm-branch2
  (fn (_ f)
    (fn (_ ops st br tx next)
      (def a (%zm-g ops 0))
      (def b (%zm-g ops 1))
      (fn (_)
        (def x (a))
        (def y (b))
        (%zm-br (f x y) br next)))))

(def %zm-do1
  (fn (_ f)
    (fn (_ ops st br tx next)
      (def a (%zm-g ops 0))
      (fn (_) (f (a)) next))))

(def %zm-do2
  (fn (_ f)
    (fn (_ ops st br tx next)
      (def a (%zm-g ops 0))
      (def b (%zm-g ops 1))
      (fn (_)
        (def x (a))
        (def y (b))
        (f x y)
        next))))

(def %zm-do3
  (fn (_ f)
    (fn (_ ops st br tx next)
      (def a (%zm-g ops 0))
      (def b (%zm-g ops 1))
      (def c (%zm-g ops 2))
      (fn (_)
        (def x (a))
        (def y (b))
        (def z (c))
        (f x y z)
        next))))

(def %zm-do0
  (fn (_ f)
    (fn (_ ops st br tx next) (fn (_) (f) next))))

; A call: the routine, then its arguments; store -1 for the call_*n forms.
; The auxiliary save and restore: table, bytes, name and prompt, the last
; two optional, f's answer stored.
(def %zm-table-op
  (fn (_ ops st next f)
    (def n (%zm-length ops))
    (def gt (%zm-g ops 0))
    (def gb (%zm-g ops 1))
    (def gn (%zm-g ops 2))
    (def gp (%zm-g ops 3))
    (fn (_)
      (def table (gt))
      (def bytes (gb))
      (def name (if (zm< n 3) 0 (gn)))
      (def prompt? (if (zm< n 4) #t (not (zm= (gp) 0))))
      (zm-var-set! st (f table bytes name prompt?))
      next)))

(def %zm-caller
  (fn (_ store?)
    (fn (_ ops st br tx next)
      (def r (%zm-g ops 0))
      (def as (if (null? ops) () (rest ops)))
      (def s (if store? st -1))
      (fn (_)
        (def p (r))
        (zm-call p (%zm-eval-all as) s next)))))

(def %zm-w (fn (_ v) (zm& v 65535)))
(def %zm-s (fn (_ v) (zm-signed v)))

(def %zm-div
  (fn (_ x y)
    (if (zm= y 0) (Err raise (lit infocom) "division by zero" x)
      (%zm-w (zm/ (%zm-s x) (%zm-s y))))))

(def %zm-mod
  (fn (_ x y)
    (if (zm= y 0) (Err raise (lit infocom) "division by zero" x)
      (%zm-w (zm% (%zm-s x) (%zm-s y))))))

(def %zm-print-codes (fn (_ cs) (zm-out-codes cs)))

; --- the table -------------------------------------------------------------

(def %zm-op!
  (fn (_ kind op name store? branch? text? builder)
    (%zm-optab-set! kind op (list name store? branch? text? builder))))

(def zm-ops-install!
  (fn (_)
    (def v zm-version)

    ; 2OP
    (%zm-op! 2 1 "je" #f #t #f
      (fn (_ ops st br tx next)
        (def a (%zm-g ops 0))
        (def bs (if (null? ops) () (rest ops)))
        (fn (_)
          (def x (a))
          (def ys (%zm-eval-all bs))
          (def any (fn (self l) (if (null? l) #f (if (zm= (first l) x) #t (self (rest l))))))
          (%zm-br (any ys) br next))))
    (%zm-op! 2 2 "jl" #f #t #f (%zm-branch2 (fn (_ x y) (zm< (%zm-s x) (%zm-s y)))))
    (%zm-op! 2 3 "jg" #f #t #f (%zm-branch2 (fn (_ x y) (zm< (%zm-s y) (%zm-s x)))))
    (%zm-op! 2 4 "dec_chk" #f #t #f
      (%zm-branch2
        (fn (_ var y)
          (def n (%zm-w (zm- (zm-var-peek var) 1)))
          (zm-var-poke! var n)
          (zm< (%zm-s n) (%zm-s y)))))
    (%zm-op! 2 5 "inc_chk" #f #t #f
      (%zm-branch2
        (fn (_ var y)
          (def n (%zm-w (zm+ (zm-var-peek var) 1)))
          (zm-var-poke! var n)
          (zm< (%zm-s y) (%zm-s n)))))
    (%zm-op! 2 6 "jin" #f #t #f (%zm-branch2 (fn (_ x y) (zm= (zm-obj-parent x) y))))
    (%zm-op! 2 7 "test" #f #t #f (%zm-branch2 (fn (_ x y) (zm= (zm& x y) y))))
    (%zm-op! 2 8 "or" #t #f #f (%zm-store2 (fn (_ x y) (zm| x y))))
    (%zm-op! 2 9 "and" #t #f #f (%zm-store2 (fn (_ x y) (zm& x y))))
    (%zm-op! 2 10 "test_attr" #f #t #f (%zm-branch2 (fn (_ o a) (zm-attr? o a))))
    (%zm-op! 2 11 "set_attr" #f #f #f (%zm-do2 zm-attr-set!))
    (%zm-op! 2 12 "clear_attr" #f #f #f (%zm-do2 zm-attr-clear!))
    (%zm-op! 2 13 "store" #f #f #f (%zm-do2 zm-var-poke!))
    (%zm-op! 2 14 "insert_obj" #f #f #f (%zm-do2 zm-obj-insert!))
    (%zm-op! 2 15 "loadw" #t #f #f
      (%zm-store2 (fn (_ a i) (zm-rw (%zm-w (zm+ a (zm<< i 1)))))))
    (%zm-op! 2 16 "loadb" #t #f #f (%zm-store2 (fn (_ a i) (zm-rb (%zm-w (zm+ a i))))))
    (%zm-op! 2 17 "get_prop" #t #f #f (%zm-store2 zm-prop))
    (%zm-op! 2 18 "get_prop_addr" #t #f #f (%zm-store2 zm-prop-addr))
    (%zm-op! 2 19 "get_next_prop" #t #f #f (%zm-store2 zm-prop-next))
    (%zm-op! 2 20 "add" #t #f #f (%zm-store2 (fn (_ x y) (%zm-w (zm+ x y)))))
    (%zm-op! 2 21 "sub" #t #f #f (%zm-store2 (fn (_ x y) (%zm-w (zm- x y)))))
    (%zm-op! 2 22 "mul" #t #f #f (%zm-store2 (fn (_ x y) (%zm-w (zm* x y)))))
    (%zm-op! 2 23 "div" #t #f #f (%zm-store2 %zm-div))
    (%zm-op! 2 24 "mod" #t #f #f (%zm-store2 %zm-mod))
    (if (zm< v 4) ()
      (%zm-op! 2 25 "call_2s" #t #f #f (%zm-caller #t)))
    (if (zm< v 5) ()
      (do
        (%zm-op! 2 26 "call_2n" #f #f #f (%zm-caller #f))
        (%zm-op! 2 27 "set_colour" #f #f #f (%zm-do2 zm-set-colour!))
        (%zm-op! 2 28 "throw" #f #f #f
          (fn (_ ops st br tx next)
            (def a (%zm-g ops 0))
            (def b (%zm-g ops 1))
            (fn (_) (def x (a)) (def y (b)) (zm-throw x y))))))

    ; 1OP
    (%zm-op! 1 0 "jz" #f #t #f (%zm-branch1 (fn (_ x) (zm= x 0))))
    (%zm-op! 1 1 "get_sibling" #t #t #f
      (fn (_ ops st br tx next)
        (def a (%zm-g ops 0))
        (fn (_) (def o (zm-obj-sibling (a))) (zm-var-set! st o) (%zm-br (not (zm= o 0)) br next))))
    (%zm-op! 1 2 "get_child" #t #t #f
      (fn (_ ops st br tx next)
        (def a (%zm-g ops 0))
        (fn (_) (def o (zm-obj-child (a))) (zm-var-set! st o) (%zm-br (not (zm= o 0)) br next))))
    (%zm-op! 1 3 "get_parent" #t #f #f (%zm-store1 zm-obj-parent))
    (%zm-op! 1 4 "get_prop_len" #t #f #f (%zm-store1 zm-prop-len))
    (%zm-op! 1 5 "inc" #f #f #f
      (%zm-do1 (fn (_ var) (zm-var-poke! var (%zm-w (zm+ (zm-var-peek var) 1))))))
    (%zm-op! 1 6 "dec" #f #f #f
      (%zm-do1 (fn (_ var) (zm-var-poke! var (%zm-w (zm- (zm-var-peek var) 1))))))
    (%zm-op! 1 7 "print_addr" #f #f #f (%zm-do1 (fn (_ a) (%zm-print-codes (zm-zstring a)))))
    (if (zm< v 4) ()
      (%zm-op! 1 8 "call_1s" #t #f #f (%zm-caller #t)))
    (%zm-op! 1 9 "remove_obj" #f #f #f (%zm-do1 zm-obj-remove!))
    (%zm-op! 1 10 "print_obj" #f #f #f (%zm-do1 (fn (_ o) (%zm-print-codes (zm-obj-name o)))))
    (%zm-op! 1 11 "ret" #f #f #f
      (fn (_ ops st br tx next) (def a (%zm-g ops 0)) (fn (_) (zm-return (a)))))
    (%zm-op! 1 12 "jump" #f #f #f
      (fn (_ ops st br tx next)
        (def a (%zm-g ops 0))
        (fn (_) (zm- (zm+ next (%zm-s (a))) 2))))
    (%zm-op! 1 13 "print_paddr" #f #f #f
      (%zm-do1 (fn (_ p) (%zm-print-codes (zm-zstring (zm-unpack p))))))
    (%zm-op! 1 14 "load" #t #f #f (%zm-store1 zm-var-peek))
    (if (zm< v 5)
      (%zm-op! 1 15 "not" #t #f #f (%zm-store1 (fn (_ x) (zm^ x 65535))))
      (%zm-op! 1 15 "call_1n" #f #f #f (%zm-caller #f)))

    ; 0OP
    (%zm-op! 0 0 "rtrue" #f #f #f (fn (_ ops st br tx next) (fn (_) (zm-return 1))))
    (%zm-op! 0 1 "rfalse" #f #f #f (fn (_ ops st br tx next) (fn (_) (zm-return 0))))
    (%zm-op! 0 2 "print" #f #f #t
      (fn (_ ops st br tx next) (fn (_) (%zm-print-codes tx) next)))
    (%zm-op! 0 3 "print_ret" #f #f #t
      (fn (_ ops st br tx next)
        (fn (_) (%zm-print-codes tx) (zm-out-zscii 13) (zm-return 1))))
    (%zm-op! 0 4 "nop" #f #f #f (%zm-do0 (fn (_) ())))
    (if (zm< v 4)
      (do
        ; the branch data follows the one opcode byte
        (%zm-op! 0 5 "save" #f #t #f
          (fn (_ ops st br tx next)
            (def at (zm+ %zm-building-pc 1))
            (fn (_) (%zm-br (zm-save at) br next))))
        (%zm-op! 0 6 "restore" #f #t #f
          (fn (_ ops st br tx next)
            (fn (_) (def pc (zm-restore)) (if (null? pc) (%zm-br #f br next) pc)))))
      (if (zm< v 5)
        (do
          (%zm-op! 0 5 "save" #t #f #f
            (fn (_ ops st br tx next)
              (def at (zm- next 1))
              (fn (_) (zm-var-set! st (if (zm-save at) 1 0)) next)))
          (%zm-op! 0 6 "restore" #t #f #f
            (fn (_ ops st br tx next)
              (fn (_) (def pc (zm-restore)) (if (null? pc) (do (zm-var-set! st 0) next) pc)))))))
    (%zm-op! 0 7 "restart" #f #f #f (fn (_ ops st br tx next) (fn (_) (zm-restart!))))
    (%zm-op! 0 8 "ret_popped" #f #f #f (fn (_ ops st br tx next) (fn (_) (zm-return (zm-pop)))))
    (if (zm< v 5)
      (%zm-op! 0 9 "pop" #f #f #f (%zm-do0 zm-pop))
      (%zm-op! 0 9 "catch" #t #f #f
        (fn (_ ops st br tx next) (fn (_) (zm-var-set! st (zm-frame-id)) next))))
    (%zm-op! 0 10 "quit" #f #f #f (fn (_ ops st br tx next) (fn (_) (zm-flush) zm-quit-pc)))
    (%zm-op! 0 11 "new_line" #f #f #f (%zm-do0 (fn (_) (zm-out-zscii 13))))
    (if (zm< v 4)
      (%zm-op! 0 12 "show_status" #f #f #f (%zm-do0 zm-status!)))
    (%zm-op! 0 13 "verify" #f #t #f
      (fn (_ ops st br tx next)
        (fn (_) (%zm-br (zm= (zm-checksum) (zm-rw 28)) br next))))
    (%zm-op! 0 15 "piracy" #f #t #f
      (fn (_ ops st br tx next) (fn (_) (%zm-br #t br next))))

    ; VAR
    (%zm-op! 3 0 (if (zm< v 4) "call" "call_vs") #t #f #f (%zm-caller #t))
    (%zm-op! 3 1 "storew" #f #f #f
      (%zm-do3 (fn (_ a i x) (zm-ww! (%zm-w (zm+ a (zm<< i 1))) x))))
    (%zm-op! 3 2 "storeb" #f #f #f (%zm-do3 (fn (_ a i x) (zm-wb! (%zm-w (zm+ a i)) x))))
    (%zm-op! 3 3 "put_prop" #f #f #f (%zm-do3 zm-prop-put!))
    ; sread and aread: text, parse, then (from version 4) a timer of tenths
    ; and the routine it calls; aread stores the terminator
    (if (zm< v 5)
      (%zm-op! 3 4 "sread" #f #f #f
        (fn (_ ops st br tx next)
          (def a (%zm-g ops 0))
          (def b (%zm-g ops 1))
          (def tm (%zm-g ops 2))
          (def rt (%zm-g ops 3))
          (fn (_)
            (def t (a))
            (def p (b))
            (def tenths (tm))
            (def timer (pair tenths (rt)))
            (if (null? (zm-sread t p timer)) zm-quit-pc next))))
      (%zm-op! 3 4 "aread" #t #f #f
        (fn (_ ops st br tx next)
          (def a (%zm-g ops 0))
          (def b (%zm-g ops 1))
          (def tm (%zm-g ops 2))
          (def rt (%zm-g ops 3))
          (fn (_)
            (def t (a))
            (def p (b))
            (def tenths (tm))
            (def timer (pair tenths (rt)))
            (def term (zm-aread t p timer))
            (if (null? term) zm-quit-pc (do (zm-var-set! st term) next))))))
    (%zm-op! 3 5 "print_char" #f #f #f (%zm-do1 zm-out-zscii))
    (%zm-op! 3 6 "print_num" #f #f #f (%zm-do1 zm-out-num))
    (%zm-op! 3 7 "random" #t #f #f (%zm-store1 zm-random))
    (%zm-op! 3 8 "push" #f #f #f (%zm-do1 zm-push))
    (%zm-op! 3 9 "pull" #f #f #f (%zm-do1 (fn (_ var) (def x (zm-pop)) (zm-var-poke! var x))))
    (%zm-op! 3 10 "split_window" #f #f #f (%zm-do1 zm-split!))
    (%zm-op! 3 11 "set_window" #f #f #f (%zm-do1 zm-set-window!))
    (%zm-op! 3 19 "output_stream" #f #f #f (%zm-do2 zm-stream!))
    (%zm-op! 3 20 "input_stream" #f #f #f (%zm-do1 zm-input-stream!))
    ; sound_effect: 1 and 2 are the high and low beeps (no operand, the
    ; first); the sampled sounds of a story's own are not played
    (%zm-op! 3 21 "sound_effect" #f #f #f
      (fn (_ ops st br tx next)
        (fn (_)
          (def vs (%zm-eval-all ops))
          (zm-beep! (if (null? vs) 1 (first vs)))
          next)))
    (if (zm< v 4) ()
      (do
        (%zm-op! 3 12 "call_vs2" #t #f #f (%zm-caller #t))
        (%zm-op! 3 13 "erase_window" #f #f #f (%zm-do1 zm-erase-window!))
        (%zm-op! 3 14 "erase_line" #f #f #f (%zm-do1 zm-erase-line!))
        (%zm-op! 3 15 "set_cursor" #f #f #f (%zm-do2 zm-set-cursor!))
        (%zm-op! 3 16 "get_cursor" #f #f #f
          (%zm-do1 (fn (_ a) (def c (zm-cursor)) (zm-ww! a (first c)) (zm-ww! (zm+ a 2) (rest c)))))
        (%zm-op! 3 17 "set_text_style" #f #f #f (%zm-do1 zm-text-style!))
        (%zm-op! 3 18 "buffer_mode" #f #f #f (%zm-do1 (fn (_ f) ())))
        (%zm-op! 3 22 "read_char" #t #f #f
          (fn (_ ops st br tx next)
            (def g1 (%zm-g ops 0))
            (def tm (%zm-g ops 1))
            (def rt (%zm-g ops 2))
            (fn (_)
              (g1)
              (def tenths (tm))
              (def timer (pair tenths (rt)))
              (def c (zm-read-char timer))
              (if (null? c) zm-quit-pc (do (zm-var-set! st c) next)))))
        (%zm-op! 3 23 "scan_table" #t #t #f
          (fn (_ ops st br tx next)
            (def gx (%zm-g ops 0))
            (def gt (%zm-g ops 1))
            (def gn (%zm-g ops 2))
            (def gf (if (zm< (%zm-length ops) 4) (fn (_) 130) (%zm-g ops 3)))
            (fn (_)
              (def x (gx))
              (def t (gt))
              (def n (gn))
              (def f (gf))
              (def hit (zm-scan-table x t n f))
              (zm-var-set! st hit)
              (%zm-br (not (zm= hit 0)) br next))))))
    (if (zm< v 5) ()
      (do
        (%zm-op! 3 24 "not" #t #f #f (%zm-store1 (fn (_ x) (zm^ x 65535))))
        (%zm-op! 3 25 "call_vn" #f #f #f (%zm-caller #f))
        (%zm-op! 3 26 "call_vn2" #f #f #f (%zm-caller #f))
        (%zm-op! 3 27 "tokenise" #f #f #f
          (fn (_ ops st br tx next)
            (def gt (%zm-g ops 0))
            (def gp (%zm-g ops 1))
            (def gd (%zm-g ops 2))
            (def gf (%zm-g ops 3))
            (fn (_)
              (def t (gt))
              (def p (gp))
              (def d (gd))
              (def f (gf))
              (zm-tokenise! t p d (not (zm= f 0)))
              next)))
        (%zm-op! 3 28 "encode_text" #f #f #f
          (fn (_ ops st br tx next)
            (def g0 (%zm-g ops 0))
            (def g1 (%zm-g ops 1))
            (def g2 (%zm-g ops 2))
            (def g3 (%zm-g ops 3))
            (fn (_)
              (def t (g0))
              (def n (g1))
              (def from (g2))
              (def to (g3))
              (zm-encode-text! t n from to)
              next)))
        (%zm-op! 3 29 "copy_table" #f #f #f (%zm-do3 zm-copy-table!))
        (%zm-op! 3 30 "print_table" #f #f #f
          (fn (_ ops st br tx next)
            (def g0 (%zm-g ops 0))
            (def g1 (%zm-g ops 1))
            (def g2 (if (zm< (%zm-length ops) 3) (fn (_) 1) (%zm-g ops 2)))
            (def g3 (%zm-g ops 3))
            (fn (_)
              (def t (g0))
              (def w (g1))
              (def h (g2))
              (def s (g3))
              (zm-print-table t w h s)
              next)))
        (%zm-op! 3 31 "check_arg_count" #f #t #f (%zm-branch1 (fn (_ n) (zm< (zm- n 1) zm-argc))))

        ; EXT.  save and restore with operands are the auxiliary forms on a
        ; table: table, bytes, then a name (0 for none) and whether to ask
        ; for it (asked when the operand is not given).
        (%zm-op! 4 0 "save" #t #f #f
          (fn (_ ops st br tx next)
            (def at (zm- next 1))
            (if (null? ops)
              (fn (_) (zm-var-set! st (if (zm-save at) 1 0)) next)
              (%zm-table-op ops st next zm-save-table))))
        (%zm-op! 4 1 "restore" #t #f #f
          (fn (_ ops st br tx next)
            (if (null? ops)
              (fn (_) (def pc (zm-restore)) (if (null? pc) (do (zm-var-set! st 0) next) pc))
              (%zm-table-op ops st next zm-restore-table))))
        (%zm-op! 4 2 "log_shift" #t #f #f
          (%zm-store2
            (fn (_ x p)
              (def n (%zm-s p))
              (if (zm< n 0) (zm>> x (zm- 0 n)) (%zm-w (zm<< x n))))))
        (%zm-op! 4 3 "art_shift" #t #f #f
          (%zm-store2
            (fn (_ x p)
              (def n (%zm-s p))
              (if (zm< n 0) (%zm-w (zm>> (%zm-s x) (zm- 0 n))) (%zm-w (zm<< x n))))))
        (%zm-op! 4 4 "set_font" #t #f #f (%zm-store1 zm-set-font!))
        (%zm-op! 4 9 "save_undo" #t #f #f
          (fn (_ ops st br tx next) (fn (_) (zm-var-set! st (zm-save-undo next st)) next)))
        (%zm-op! 4 10 "restore_undo" #t #f #f
          (fn (_ ops st br tx next)
            (fn (_) (def pc (zm-restore-undo)) (if (null? pc) (do (zm-var-set! st 0) next) pc))))
        (%zm-op! 4 11 "print_unicode" #f #f #f (%zm-do1 zm-out-unicode))
        (%zm-op! 4 12 "check_unicode" #t #f #f (%zm-store1 (fn (_ c) (if (zm< c 128) 3 1))))
        (%zm-op! 4 13 "set_true_colour" #f #f #f (%zm-do2 zm-set-true-colour!))))
    v))
