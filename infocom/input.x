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
(import x/repl/line)

(provide infocom/input
  zm-input-fd! zm-input-script! zm-read-line zm-read-raw-line zm-read-char
  zm-echo! zm-tokenise! zm-lookup zm-history!)

(def %zm-source ())
(def %zm-echo? #f)
(def %zm-ibuf ())

(def zm-input-fd!
  (fn (_ fd)
    (set! %zm-echo? #f)
    (set! %zm-pending ())
    (set! %zm-key-fd (if (Term tty? fd) fd ()))
    (set! %zm-ibuf (%zm-str-make 1))
    (Line fd fd)
    (set! %zm-source
      (if (Line available?) %zm-edited-line
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
          (go ()))))))

; A line typed at a terminal, through x-lang's line editor: the arrows move
; and browse the commands typed before, ctrl-r searches them.  The editor's
; redraw starts its row over, so the row the story has printed -- its prompt
; -- is handed to it as the prompt.  The painter and Tab's completer are
; x-lang's; a command is not x, so neither runs.  ctrl-d on an empty line
; and ctrl-c end the input.
;
; The keys the story names as terminating end the line too, taken ahead of
; the editor's own use of them; and a timed read's routine runs each time
; its tenths pass with no key, the line drawn again after it.
(def %zm-line-timer (pair 0 0))
(def %zm-edited-line
  (fn (_)
    (set! %repl-paint ())
    (set! %repl-marks ())
    (Line completer ())
    (def t %zm-line-timer)
    (set! %zm-line-timer %zm-no-timer)
    (def s
      (if (zm= (first t) 0)
        (Line read-until (zm-row-str) (%zm-end-keys))
        (Line read-until (zm-row-str) (%zm-end-keys) (pair (first t) (%zm-idle (rest t))))))
    (match
      ((str? s) (pair #t (%zm-codes-of s)))
      ((null? s) ())
      ((eq? s (lit eof)) ())
      ((eq? s (lit cancel)) ())
      ((eq? (first s) (lit stopped)) (pair 0 (%zm-codes-of (rest s))))
      (#t (pair (%zm-fkey-zscii (first s)) (%zm-codes-of (rest s)))))))

; The timer routine as the line editor calls it: true stops the read, as
; does the story quitting in it; else the row it leaves is the prompt.
(def %zm-idle
  (fn (_ routine)
    (fn (_)
      (def r (zm-call-now routine))
      (zm-before-read!)
      (zm-flush)
      (if (if (null? r) #t (not (zm= r 0))) #t (zm-row-str)))))

; The keys besides Return that end a read, by the names Term key gives them,
; with their ZSCII: the arrows, F1 to F12, the keypad's digits.
(def %zm-fkeys
  (list (pair (lit up) 129) (pair (lit down) 130) (pair (lit left) 131) (pair (lit right) 132)
        (pair (lit f1) 133) (pair (lit f2) 134) (pair (lit f3) 135) (pair (lit f4) 136)
        (pair (lit f5) 137) (pair (lit f6) 138) (pair (lit f7) 139) (pair (lit f8) 140)
        (pair (lit f9) 141) (pair (lit f10) 142) (pair (lit f11) 143) (pair (lit f12) 144)
        (pair (lit kp0) 145) (pair (lit kp1) 146) (pair (lit kp2) 147) (pair (lit kp3) 148)
        (pair (lit kp4) 149) (pair (lit kp5) 150) (pair (lit kp6) 151) (pair (lit kp7) 152)
        (pair (lit kp8) 153) (pair (lit kp9) 154)))

(def %zm-fkey-zscii
  (fn (_ k)
    (def go (fn (self ks) (if (null? ks) () (if (eq? (first (first ks)) k) (rest (first ks)) (self (rest ks))))))
    (go %zm-fkeys)))

; The story's terminating keys as Term key names them: the ones of the
; table at the header's word 0x2E that a terminal can send.
(def %zm-end-keys
  (fn (_)
    (List map (fn (_ kz) (first kz))
      (List filter (fn (_ kz) (%zm-terminator? (rest kz))) %zm-fkeys))))

; Where the commands typed are kept: FILE, or nowhere when FILE is empty;
; by default x/infocom-history under the XDG state directory.  Set before
; the first line, as the editor loads its history then.
(def zm-history!
  (fn (_ file)
    (def state (Sys getenv "XDG_STATE_HOME"))
    (def home (Sys getenv "HOME"))
    (def path
      (match
        ((not (null? file)) file)
        ((not (null? state)) (Str8 append state "/x/infocom-history"))
        ((not (null? home)) (Str8 append home "/.local/state/x/infocom-history"))
        (#t "")))
    (Sys setenv "X_HISTORY" path)))

(def %zm-codes-of
  (fn (_ s)
    (def n (%zm-byte-len s))
    (def go
      (fn (self i acc)
        (if (zm< i n)
          (self (zm+ i 1) (pair (%zm-char->int (%zm-byte-ref s i)) acc))
          (%zm-rev acc))))
    (go 0 ())))

; A script's lines are strings, each typed and ended with Return; a pair
; (text . key) is text typed and ended with a key instead -- a function key
; or an arrow, by its ZSCII; and the symbol tick is time passing.
(def zm-input-script!
  (fn (_ lines)
    (def left lines)
    (set! %zm-echo? #t)
    (set! %zm-pending ())
    (set! %zm-source
      (fn (_)
        (if (null? left) ()
          (do
            (def s (first left))
            (set! left (rest left))
            (match
              ((str? s) (pair #t (%zm-codes-of s)))
              ((eq? s (lit tick)) s)
              (#t (pair (rest s) (%zm-codes-of (first s)))))))))))

; A line from a source is (end . codes): end is #t for Return, or the
; ZSCII of the key that ended it.
;
; The keys that can end a line other than Return: the arrows and function
; keys 129-154, and the mouse and menu clicks 252-254.
(def %zm-function-key?
  (fn (_ c) (if (if (zm< c 129) #f (zm< c 155)) #t (if (zm< c 252) #f (zm< c 255)))))

; What read_char left of a line: the characters still to come, then what
; ended it -- Return (13) or a function key.  A line read takes them before
; the source's next line, as a terminal hands over the rest of what was
; typed.
(def %zm-pending ())

(def %zm-take-pending
  (fn (_)
    (def end? (fn (_ c) (if (zm= c 13) #t (%zm-function-key? c))))
    (def take (fn (self cs) (if (if (null? cs) #t (end? (first cs))) () (pair (first cs) (self (rest cs))))))
    (def ender (fn (self cs) (if (null? cs) 13 (if (end? (first cs)) (first cs) (self (rest cs))))))
    (def drop (fn (self cs) (if (null? cs) () (if (end? (first cs)) (rest cs) (self (rest cs))))))
    (def line (take %zm-pending))
    (def end (ender %zm-pending))
    (set! %zm-pending (drop %zm-pending))
    (pair (if (zm= end 13) #t end) line)))

; Time passing is a tick: a script says so with the symbol tick among its
; lines, and a terminal when a read's tenths pass with nothing typed; a
; pipe has no time between its lines.  Only a timed read has a use for a
; tick, so the source's next line is taken past any.
(def %zm-source-line
  (fn (self)
    (def got (%zm-source))
    (if (eq? got (lit tick)) (self) got)))

; What comes next for a read with a timer (tenths . routine), tenths 0 for
; none: what read_char left, else the source's next line, a tick, or () at
; the end of input.  At a terminal the line editor keeps the time itself,
; so the timer goes to it with the line.
(def %zm-next-input
  (fn (_ timer)
    (def tenths (first timer))
    (match
      ((not (null? %zm-pending)) (%zm-take-pending))
      ((eq? %zm-source %zm-edited-line) (do (set! %zm-line-timer timer) (%zm-source)))
      ((zm= tenths 0) (%zm-source-line))
      ((null? %zm-key-fd) (%zm-source))
      ((not (%zm-key-ready? tenths)) (lit tick))
      (#t (%zm-source)))))

(def %zm-next-line (fn (_) (%zm-next-input %zm-no-timer)))

; Whether a key comes at the terminal within tenths.  The terminal is raw
; for the wait: cooked, it would hand over nothing until Return and echo
; keys in its own way, an arrow as ^[[A.  The key stays unread for the
; read that follows.
(def %zm-key-ready?
  (fn (_ tenths)
    (def saved (Term raw-with-signals! %zm-key-fd))
    (def r (Sys poll (list (pair %zm-key-fd (list (lit in)))) (zm* tenths 100)))
    (Term restore! %zm-key-fd saved)
    (not (null? r))))

; A timer is (tenths . routine): each time a tick comes the routine is
; called, and when it answers true the read stops.  Answers what took the
; read: %zm-stopped when the routine stopped it, else the next input (never a
; tick), or () at the end of input or when the story quits in the routine.
(def %zm-no-timer (pair 0 0))
(def %zm-stopped (list (lit stopped)))
(def %zm-timed
  (fn (self timer next)
    (def got (next timer))
    (if (eq? got (lit tick))
      (do
        (def r (zm-call-now (rest timer)))
        (zm-before-read!)
        (zm-flush)
        (match
          ((null? r) ())
          ((zm= r 0) (self timer next))
          (#t %zm-stopped)))
      got)))

; Whether key ends a read: the story's terminating characters (version 5
; on) are a zero-ended table of ZSCII at the header's word 0x2E, 255 among
; them standing for every function key.
(def %zm-terminator?
  (fn (_ key)
    (def t (if (zm< zm-version 5) 0 (zm-rw 46)))
    (def go
      (fn (self a)
        (def b (zm-rb a))
        (match
          ((zm= b 0) #f)
          ((zm= b key) #t)
          ((zm= b 255) #t)
          (#t (self (zm+ a 1))))))
    (if (zm= t 0) #f (go t))))

; Nothing collects unless asked, and every instruction allocates; a read is
; where the machine is quiet -- the turn's work is done and the next has
; not begun -- so the sweep goes here, as the REPL's goes at its prompt.
;
; The next line, lower-cased and cut to max characters, as (terminator .
; codes): the terminator Return (13), a terminating key, or 0 when the
; timer's routine stopped the read; or () at the end of input.  A function
; key the story does not name ends nothing: what was typed stays, and the
; line goes on.
(def zm-read-line
  (fn (_ max . timer)
    (zm-before-read!)
    (zm-flush)
    (Heap collect)
    (def t (if (null? timer) %zm-no-timer (first timer)))
    (def go
      (fn (self typed)
        (def line (%zm-timed t %zm-next-input))
        (match
          ((null? line) ())
          ((eq? line %zm-stopped) (pair 0 typed))
          ((eq? (first line) #t) (pair 13 (List append typed (rest line))))
          ((zm= (first line) 0) (pair 0 (List append typed (rest line))))
          ((%zm-terminator? (first line)) (pair (first line) (List append typed (rest line))))
          (#t (self (List append typed (rest line)))))))
    (def got (go ()))
    (if (null? got) ()
      (do
        (match
          ((zm= (first got) 0) ())
          (%zm-echo? (do (zm-out-codes (rest got)) (zm-out-zscii 13)))
          (#t (zm-col-reset!)))
        ; the recording, and the transcript where nothing echoed it
        (if (zm= (first got) 0) () (zm-line-typed (rest got) %zm-echo?))
        (def cut
          (fn (self cs n)
            (if (if (null? cs) #t (zm= n 0)) ()
              (pair (%zm-lower (first cs)) (self (rest cs) (zm- n 1))))))
        (pair (first got) (cut (rest got) max))))))

; The next line as typed, for a file name: (#t . codes), or ().  It is
; recorded as a command is, so a recording played back answers the same
; question the same way.
(def zm-read-raw-line
  (fn (_)
    (zm-before-read!)
    (zm-flush)
    (def line (%zm-next-line))
    (if (null? line) ()
      (do
        (if %zm-echo? (do (zm-out-codes (rest line)) (zm-out-zscii 13)) (zm-col-reset!))
        (zm-line-typed (rest line) %zm-echo?)
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
      ((not (null? (%zm-fkey-zscii k))) (%zm-fkey-zscii k))
      ((eq? k (lit tab)) 9)
      ((eq? k (lit eof)) ())
      ((eq? k (lit interrupt)) ())
      (#t 27))))

; One key from the terminal: its ZSCII, or () when input has ended.
(def %zm-read-key
  (fn (_ fd)
    (zm-before-read!)
    (zm-flush)
    (def saved (Term raw-with-signals! fd))
    (def byte
      (fn (_)
        (def n (zm-file-read fd %zm-ibuf 1))
        (if (zm< n 1) () (zm& (%zm-pref (%zm-str->ptr %zm-ibuf) 0 1) 255))))
    (def k (Term key byte))
    (Term restore! fd saved)
    (%zm-key-zscii k)))

; The next key for a read_char whose timer is tenths (0: none): its ZSCII,
; a tick, or () at the end of input.  Away from a terminal the lines are
; keys as typed: one character a read_char, then Return (13) -- or the key
; that ended the line; what it leaves, a line read takes.
(def %zm-next-key
  (fn (_ timer)
    (def tenths (first timer))
    (if (null? %zm-key-fd)
      (do
        (zm-before-read!)
        (zm-flush)
        (def line
          (match
            ((not (null? %zm-pending)) ())
            ((zm= tenths 0) (%zm-source-line))
            (#t (%zm-source))))
        (match
          ((eq? line (lit tick)) line)
          ((not (null? line))
            (set! %zm-pending (List append (rest line) (list (if (eq? (first line) #t) 13 (first line)))))))
        (match
          ((eq? line (lit tick)) line)
          ((null? %zm-pending) ())
          (#t
            (do
              (def c (first %zm-pending))
              (set! %zm-pending (rest %zm-pending))
              c))))
      (do
        (zm-before-read!)
        (zm-flush)
        (if (if (zm= tenths 0) #f
              (not (%zm-key-ready? tenths)))
          (lit tick)
          (%zm-read-key %zm-key-fd))))))

; read_char's character: 0 when the timer's routine stopped the read, or ()
; at the end of input.
(def zm-read-char
  (fn (_ . timer)
    (def c (%zm-timed (if (null? timer) %zm-no-timer (first timer)) %zm-next-key))
    (if (eq? c %zm-stopped) 0 c)))
