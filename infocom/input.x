; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/input.x -- reading a line, and splitting it into words
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Lines come from a source: a function answering the next line as a list
; of character codes, or () when input has ended.  The command line reads
; descriptor 0 a byte at a time, so nothing waits on more than one line;
; a spec hands over a list of strings and echoes each one, as a transcript
; would show it.

(import x/repl/term)

(provide infocom/input
  zm-input-fd! zm-input-script! zm-read-line zm-read-raw-line zm-read-char
  zm-echo! zm-tokenise! zm-lookup)

(def %zm-source ())
(def %zm-echo? #f)
(def %zm-ibuf ())

(def zm-input-fd!
  (fn (_ fd)
    (set! %zm-echo? #f)
    (set! %zm-key-fd (if (Term tty? fd) fd ()))
    (set! %zm-ibuf (%zm-str-make 1))
    (set! %zm-source
      (fn (_)
        (def go
          (fn (self acc)
            (def n (zm-file-read fd %zm-ibuf 1))
            (if (zm< n 1)
              (if (null? acc) () (pair #t (%zm-rev acc)))
              (do
                (def c (zm& (%zm-pref (%zm-str->ptr %zm-ibuf) 0 1) 255))
                (if (zm= c 10) (pair #t (%zm-rev acc))
                  (if (zm= c 13) (self acc) (self (pair c acc))))))))
        (go ())))))

(def %zm-codes-of
  (fn (_ s)
    (def n (%zm-byte-len s))
    (def go
      (fn (self i acc)
        (if (zm< i n)
          (self (zm+ i 1) (pair (%zm-char->int (%zm-byte-ref s i)) acc))
          (%zm-rev acc))))
    (go 0 ())))

(def zm-input-script!
  (fn (_ lines)
    (def left lines)
    (set! %zm-echo? #t)
    (set! %zm-source
      (fn (_)
        (if (null? left) ()
          (do
            (def s (first left))
            (set! left (rest left))
            (pair #t (%zm-codes-of s))))))))

; The next line, lower-cased and cut to max characters, as (#t . codes) --
; an empty line is (#t) -- or () at end of input.
;
; Nothing collects unless asked, and every instruction allocates; a read is
; where the machine is quiet -- the turn's work is done and the next has
; not begun -- so the sweep goes here, as the REPL's goes at its prompt.
(def zm-read-line
  (fn (_ max)
    (zm-flush)
    (Heap collect)
    (def line (%zm-source))
    (if (null? line) ()
      (do
        (if %zm-echo? (do (zm-out-codes (rest line)) (zm-out-zscii 13)) (zm-col-reset!))
        (def cut
          (fn (self cs n)
            (if (if (null? cs) #t (zm= n 0)) ()
              (pair (%zm-lower (first cs)) (self (rest cs) (zm- n 1))))))
        (pair #t (cut (rest line) max))))))

; The next line as typed, for a file name: (#t . codes), or ().
(def zm-read-raw-line
  (fn (_)
    (zm-flush)
    (def line (%zm-source))
    (if (null? line) ()
      (do
        (if %zm-echo? (do (zm-out-codes (rest line)) (zm-out-zscii 13)) (zm-col-reset!))
        line))))

(def %zm-lower
  (fn (_ c) (if (if (zm< c 65) #f (zm< c 91)) (zm+ c 32) c)))

; ---------------------------------------------------------------------------
; The dictionary: separators, entry length, a count (negative when the
; entries are not sorted), then the entries, each led by its encoded word.

(def %zm-dict-seps
  (fn (_ d)
    (def n (zm-rb d))
    (def go
      (fn (self i acc)
        (if (zm< i n) (self (zm+ i 1) (pair (zm-rb (zm+ (zm+ d 1) i)) acc)) acc)))
    (go 0 ())))

(def %zm-member?
  (fn (self c l)
    (if (null? l) #f (if (zm= (first l) c) #t (self c (rest l))))))

; Compare entry e's encoded words with ws: -1, 0 or 1.
(def %zm-entry-cmp
  (fn (self e ws)
    (if (null? ws) 0
      (do
        (def w (zm-rw e))
        (if (zm= w (first ws)) (self (zm+ e 2) (rest ws))
          (if (zm< w (first ws)) -1 1))))))

(def zm-lookup
  (fn (_ d codes)
    (def ws (zm-encode-word codes))
    (def n (zm-rb d))
    (def elen (zm-rb (zm+ (zm+ d 1) n)))
    (def count (zm-signed (zm-rw (zm+ (zm+ d 2) n))))
    (def start (zm+ (zm+ d 4) n))
    (if (zm< count 0)
      (do
        (def lin
          (fn (self i)
            (if (zm< i (zm- 0 count))
              (do
                (def e (zm+ start (zm* i elen)))
                (if (zm= (%zm-entry-cmp e ws) 0) e (self (zm+ i 1))))
              0)))
        (lin 0))
      (do
        (def bin
          (fn (self lo hi)
            (if (zm< hi lo) 0
              (do
                (def mid (zm>> (zm+ lo hi) 1))
                (def e (zm+ start (zm* mid elen)))
                (def c (%zm-entry-cmp e ws))
                (if (zm= c 0) e
                  (if (zm< c 0) (self (zm+ mid 1) hi) (self lo (zm- mid 1))))))))
        (bin 0 (zm- count 1))))))

; Words of the text at t (len characters from t+off), as (position length
; codes) with position counted from the buffer's start.  Spaces separate;
; a separator is a word of its own.
(def %zm-split
  (fn (_ t off len seps)
    (def flush
      (fn (_ start acc words)
        (if (null? acc) words (pair (list start (%zm-length acc) (%zm-rev acc)) words))))
    (def go
      (fn (self i start acc words)
        (if (zm< i len)
          (do
            (def c (zm-rb (zm+ (zm+ t off) i)))
            (def pos (zm+ off i))
            (match
              ((zm= c 32) (self (zm+ i 1) 0 () (flush start acc words)))
              ((%zm-member? c seps)
                (self (zm+ i 1) 0 ()
                  (pair (list pos 1 (list c)) (flush start acc words))))
              (#t (self (zm+ i 1) (if (null? acc) pos start) (pair c acc) words))))
          (%zm-rev (flush start acc words)))))
    (go 0 0 () ())))

; tokenise: fill the parse buffer p from the text buffer t.
(def zm-tokenise!
  (fn (_ t p d skip?)
    (def dict (if (zm= d 0) zm-hdr-dict d))
    (def off (if (zm< zm-version 5) 1 2))
    (def len
      (if (zm< zm-version 5)
        (do
          (def z (fn (self i) (if (zm= (zm-rb (zm+ (zm+ t 1) i)) 0) i (self (zm+ i 1)))))
          (z 0))
        (zm-rb (zm+ t 1))))
    (def words (%zm-split t off len (%zm-dict-seps dict)))
    (def max (zm-rb p))
    (def go
      (fn (self ws k)
        (if (if (null? ws) #t (zm= k max)) k
          (do
            (def w (first ws))
            (def addr (zm-lookup dict (first (rest (rest w)))))
            (def e (zm+ (zm+ p 2) (zm<< k 2)))
            (if (if skip? (zm= addr 0) #f) ()
              (do
                (zm-ww! e addr)
                (zm-wb! (zm+ e 2) (first (rest w)))
                (zm-wb! (zm+ e 3) (first w))))
            (self (rest ws) (zm+ k 1))))))
    (zm-wb! (zm+ p 1) (go words 0))))

; --- single keys -------------------------------------------------------------
; read_char on a terminal takes one key, with the terminal raw for just that
; read; anywhere else it takes the next line's first character.

(def %zm-key-fd ())
(def zm-echo! (fn (_ on) (set! %zm-echo? on)))

; A key as Term decodes it, in ZSCII: Return 13, Delete 8, Escape 27, the
; arrows 129-132; text, its first byte.
(def %zm-key-zscii
  (fn (_ k)
    (match
      ((null? k) ())
      ((str? k) (if (zm= (%zm-byte-len k) 0) 13 (%zm-char->int (%zm-byte-ref k 0))))
      ((eq? k (lit enter)) 13)
      ((eq? k (lit backspace)) 8)
      ((eq? k (lit delete)) 8)
      ((eq? k (lit escape)) 27)
      ((eq? k (lit up)) 129)
      ((eq? k (lit down)) 130)
      ((eq? k (lit left)) 131)
      ((eq? k (lit right)) 132)
      ((eq? k (lit tab)) 9)
      ((eq? k (lit eof)) ())
      ((eq? k (lit interrupt)) ())
      (#t 27))))

; One key from the terminal: its ZSCII, or () when input has ended.
(def %zm-read-key
  (fn (_ fd)
    (zm-flush)
    (def saved (Term raw-with-signals! fd))
    (def byte
      (fn (_)
        (def n (zm-file-read fd %zm-ibuf 1))
        (if (zm< n 1) () (zm& (%zm-pref (%zm-str->ptr %zm-ibuf) 0 1) 255))))
    (def k (Term key byte))
    (Term restore! fd saved)
    (%zm-key-zscii k)))

; read_char's character, or () at end of input.
(def zm-read-char
  (fn (_)
    (if (null? %zm-key-fd)
      (do
        (def line (zm-read-line 1))
        (if (null? line) () (if (null? (rest line)) 13 (first (rest line)))))
      (%zm-read-key %zm-key-fd))))
