; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/debug.x -- a debugger over the running machine
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The story stops before an instruction and the (zdb) prompt takes a
; command; between stops the story runs as it would, reading its own input.
; Commands are read as the story's lines are -- the line editor and its
; history at a terminal, a script's lines in a spec -- so one script can
; carry both.  Instructions show as the disassembler shows them.
;
;   s [N]       step N instructions (1), each shown before it runs
;   n           step, over a call: the routine it calls runs to its return
;   fin         run until the routine stopped in returns
;   c           continue until a breakpoint, or the story ends
;   b [ADDR]    break before the instruction at ADDR; alone, list them
;   d ADDR      delete the breakpoint at ADDR
;   bt          the frames: where each routine will return to
;   l           the locals of the routine stopped in
;   sp          its evaluation stack, the top last
;   g N         global N, as the disassembler numbers them (g00 ...)
;   x ADDR [N]  N bytes of memory from ADDR (16)
;   o N         object N: attributes, relations, properties
;   pc          the instruction stopped before
;   q           leave the story
;
; Addresses and global numbers are hexadecimal; counts and objects are
; decimal.

(provide infocom/debug zm-debug)

(def %zdb-breaks ())

(def %zdb-say (fn (_ s) (zm-out-ascii s)))
(def %zdb-nl (fn (_) (zm-out-zscii 13)))
(def %zdb-hex (fn (_ v n) (zm-out-codes (%zm-hex v n))))

; The command's words, as strings.
(def %zdb-words
  (fn (_ codes)
    (def word (fn (_ cs) (%qz-codes->str (%zm-rev cs))))
    (def go
      (fn (self cs acc words)
        (match
          ((null? cs) (%zm-rev (if (null? acc) words (pair (word acc) words))))
          ((zm= (first cs) 32) (self (rest cs) () (if (null? acc) words (pair (word acc) words))))
          (#t (self (rest cs) (pair (first cs) acc) words)))))
    (go codes () ())))

(def %zdb-arg
  (fn (_ words i hex? dflt)
    (def go (fn (self ws i) (if (null? ws) () (if (zm= i 0) (first ws) (self (rest ws) (zm- i 1))))))
    (def w (go words i))
    (if (null? w) dflt
      (do (def v (%zm-number w hex?)) (if (null? v) dflt v)))))

; Where the machine stops: before the instruction at pc, shown; or the
; story's end.
(def %zdb-show
  (fn (_ pc)
    (if (zm< pc 0)
      (do (%zdb-say "the story has ended") (%zdb-nl))
      (zm-dis-at pc))))

(def %zdb-break?
  (fn (_ pc)
    (def go (fn (self bs) (if (null? bs) #f (if (zm= (first bs) pc) #t (self (rest bs))))))
    (go %zdb-breaks)))

; Run from pc until stop? says so of the pc about to run, or the story
; ends; the first instruction always runs.  Answers the pc stopped at.
(def %zdb-run
  (fn (_ pc stop?)
    (def go
      (fn (self pc k)
        (match
          ((zm< pc 0) pc)
          ((if (zm< 0 k) (stop? pc) #f) pc)
          ((zm= (zm% k 50000) 49999) (do (Heap collect) (self ((zm-insn-at pc)) (zm+ k 1))))
          (#t (self ((zm-insn-at pc)) (zm+ k 1))))))
    (go pc 0)))

; n instructions; the first was shown at the stop, the rest as they come.
(def %zdb-step
  (fn (_ pc n)
    (def go
      (fn (self pc k)
        (if (if (zm< pc 0) #t (zm= k n)) pc
          (do (if (zm< 0 k) (zm-dis-at pc)) (self ((zm-insn-at pc)) (zm+ k 1))))))
    (go pc 0)))

(def %zdb-bt
  (fn (_ pc)
    (%zdb-say "  ") (%zdb-hex pc 4) (%zdb-nl)
    (def go
      (fn (self fs)
        (if (null? fs) ()
          (do
            (def back (first (first fs)))
            (%zdb-say "  ") (if (zm< back 0) (%zdb-say "(called now)") (%zdb-hex back 4)) (%zdb-nl)
            (self (rest fs))))))
    (go %zm-frames)))

(def %zdb-locals
  (fn (_)
    (def go
      (fn (self i)
        (if (zm< %zm-nlocals i) ()
          (do
            (%zdb-say "  l") (%zdb-hex i 2) (%zdb-say " ")
            (%zdb-hex (%zm-obj-ref %zm-locals i) 4) (%zdb-nl)
            (self (zm+ i 1))))))
    (if (zm= %zm-nlocals 0) (do (%zdb-say "  none") (%zdb-nl)) (go 1))))

(def %zdb-stack
  (fn (_)
    (def go
      (fn (self i)
        (if (zm< %zm-sp i) ()
          (do (%zdb-say "  ") (%zdb-hex (%zm-obj-ref %zm-stack i) 4) (%zdb-nl) (self (zm+ i 1))))))
    (if (zm= %zm-sp %zm-base) (do (%zdb-say "  empty") (%zdb-nl)) (go (zm+ %zm-base 1)))))

(def %zdb-memory
  (fn (_ a n)
    (def go
      (fn (self i)
        (if (zm< i n)
          (do
            (if (zm= (zm% i 16) 0)
              (do (if (zm< 0 i) (%zdb-nl)) (%zdb-hex (zm+ a i) 4) (%zdb-say ":")))
            (%zdb-say " ") (%zdb-hex (zm-rb (zm+ a i)) 2)
            (self (zm+ i 1))))))
    (go 0)
    (%zdb-nl)))

(def %zdb-list-breaks
  (fn (_)
    (if (null? %zdb-breaks) (do (%zdb-say "  no breakpoints") (%zdb-nl))
      (do
        (def go (fn (self bs) (if (null? bs) () (do (%zdb-say "  ") (%zdb-hex (first bs) 4) (%zdb-nl) (self (rest bs))))))
        (go (%zm-rev %zdb-breaks))))))

(def %zdb-remove
  (fn (self bs a)
    (if (null? bs) () (if (zm= (first bs) a) (rest bs) (pair (first bs) (self (rest bs) a))))))

; A command on the machine stopped at pc: answers the pc to stop at next,
; or () to leave.
(def %zdb-command
  (fn (_ pc words)
    (def cmd (if (null? words) "" (first words)))
    (def depth (zm-frame-id))
    (match
      ((str=? cmd "q") ())
      ((if (str=? cmd "s") #t (str=? cmd "")) (%zdb-step pc (%zdb-arg words 1 #f 1)))
      ((str=? cmd "n")
        (%zdb-run pc (fn (_ p) (if (zm< depth (zm-frame-id)) #f #t))))
      ((str=? cmd "fin")
        (%zdb-run pc (fn (_ p) (zm< (zm-frame-id) depth))))
      ((str=? cmd "c") (%zdb-run pc %zdb-break?))
      ((str=? cmd "b")
        (do
          (def a (%zdb-arg words 1 #t ()))
          (if (null? a) (%zdb-list-breaks)
            (if (%zdb-break? a) () (set! %zdb-breaks (pair a %zdb-breaks))))
          pc))
      ((str=? cmd "d")
        (do
          (def a (%zdb-arg words 1 #t ()))
          (if (null? a) () (set! %zdb-breaks (%zdb-remove %zdb-breaks a)))
          pc))
      ((str=? cmd "bt") (do (%zdb-bt pc) pc))
      ((str=? cmd "l") (do (%zdb-locals) pc))
      ((str=? cmd "sp") (do (%zdb-stack) pc))
      ((str=? cmd "g")
        (do
          (def n (%zdb-arg words 1 #t 0))
          (%zdb-say "  g") (%zdb-hex n 2) (%zdb-say " ") (%zdb-hex (zm-var (zm+ n 16)) 4) (%zdb-nl)
          pc))
      ((str=? cmd "x") (do (%zdb-memory (%zdb-arg words 1 #t 0) (%zdb-arg words 2 #f 16)) pc))
      ((str=? cmd "o")
        (do
          (def o (%zdb-arg words 1 #f 0))
          (if (if (zm< 0 o) (zm< o (zm+ (zm-object-count) 1)) #f) (zm-info-object o)
            (do (%zdb-say "  no object ") (%zdb-say (Str8 str o)) (%zdb-nl)))
          pc))
      ((str=? cmd "pc") pc)
      (#t (do (%zdb-say "  ? s n fin c b d bt l sp g x o pc q") (%zdb-nl) pc)))))

; The session: from pc, stopped, until q or the story's end.  A stop shows
; the instruction next to run when the machine has moved, or on pc.
(def zm-debug
  (fn (_ pc)
    (set! %zdb-breaks ())
    (def go
      (fn (self pc show?)
        (if show? (%zdb-show pc))
        (if (zm< pc 0) ()
          (do
            (%zdb-say "(zdb) ")
            (def line (zm-read-raw-line))
            (def words (if (null? line) () (%zdb-words (rest line))))
            (def next (if (null? line) () (%zdb-command pc words)))
            (if (null? next) ()
              (self next
                (if (zm= next pc) (if (null? words) #f (str=? (first words) "pc")) #t)))))))
    (go pc #t)
    (zm-flush)
    ()))
