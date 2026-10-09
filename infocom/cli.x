; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/cli.x -- the command line
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; x -l infocom -- [OPTIONS] STORY plays STORY, or with an inspecting option
; describes it and stops.  The options are declared once, in zm-options:
; the declaration is what --help prints and what the line is parsed
; against.  zm-cli-plan turns a line into what to do, with no side
; effects, and zm-main does it; standard input, which under the launcher
; waits on descriptor 3, is reclaimed only for play.

(import x/sys/opts)
(import x/repl/term)

(provide infocom/cli zm-argv zm-main zm-cli-plan zm-options zm-usage)

(def zm-options
  (Opts declare "infocom" "[OPTIONS] STORY"
    "Play a Z-machine story (versions 3, 4, 5 and 8), or describe it"
    (list
      (Opts text "Play:")
      (Opts flag "-p" "--plain" "Print lines, not a drawn screen")
      (Opts flag "-u" "--upper" "On printed lines, the status line and upper window too")
      (Opts arg "-w" "--width" "N" "Wrap printed lines at N columns (0: never)")
      (Opts arg "-s" "--seed" "N" "Seed the random numbers, for play that repeats")
      (Opts arg "-r" "--restore" "FILE" "Begin from a saved game")
      (Opts arg "-S" "--save-dir" "DIR" "Put save files in DIR")
      (Opts flag "-e" "--echo" "Echo each command read, as a transcript shows it")
      (Opts arg "-H" "--history" "FILE" "Keep the commands typed at a terminal in FILE (empty: nowhere)")
      (Opts arg "-T" "--transcript" "FILE" "Write the transcript to FILE when the story starts one")
      (Opts arg "-R" "--record" "FILE" "Record the commands typed in FILE")
      (Opts arg "-P" "--replay" "FILE" "Take commands from FILE first, then from the keyboard")
      (Opts text "Describe, then stop:")
      (Opts flag "-i" "--info" "The header")
      (Opts flag "-o" "--objects" "The objects, attributes and properties")
      (Opts flag "-t" "--tree" "The object tree")
      (Opts flag "-d" "--dict" "The dictionary")
      (Opts flag "-a" "--abbrevs" "The abbreviations")
      (Opts arg "-D" "--dis" "ADDR" "Disassemble the routine at byte ADDR (hex; 0, the start)"))))

(def zm-usage (fn (_) (Opts usage zm-options)))

(def %zm-engine-flag?
  (fn (_ s)
    (if (str=? s "--batch") #t
      (if (str=? s "--no-color") #t (str=? s "--verbose")))))

(def zm-argv
  (fn (_ raw)
    (def ops
      (List filter (fn (_ a) (not (%zm-engine-flag? a)))
        (if (pair? raw) (rest raw) ())))
    (if (if (pair? ops) (str=? (first ops) "--") #f) (rest ops) ops)))

; A number from text: decimal, or hexadecimal when hex? or led by 0x.
; Answers () for anything else.
(def %zm-number
  (fn (_ s hex?)
    (def n (%zm-byte-len s))
    (def c (fn (_ i) (%zm-char->int (%zm-byte-ref s i))))
    (def x? (if (zm< 2 n) (if (zm= (c 0) 48) (if (zm= (c 1) 120) #t (zm= (c 1) 88)) #f) #f))
    (def base (if (if hex? #t x?) 16 10))
    (def digit
      (fn (_ d)
        (match
          ((if (zm< d 48) #f (zm< d 58)) (zm- d 48))
          ((if (zm= base 16) (if (zm< d 97) #f (zm< d 103)) #f) (zm- d 87))
          ((if (zm= base 16) (if (zm< d 65) #f (zm< d 71)) #f) (zm- d 55))
          (#t -1))))
    (def go
      (fn (self i acc)
        (if (zm< i n)
          (do
            (def v (digit (c i)))
            (if (zm< v 0) () (self (zm+ i 1) (zm+ (zm* acc base) v))))
          acc)))
    (if (zm= n 0) () (go (if x? 2 0) 0))))

; What a command line asks for:
;   (help)                      --help or -h
;   (refuse MESSAGE)            a line that does not run; MESSAGE may be ()
;   (describe STORY VIEWS)      VIEWS, in order: info objects tree dict
;                               abbrevs (dis . ADDR)
;   (play STORY SETTINGS)       SETTINGS an alist: plain width seed restore
;                               save-dir echo upper history transcript
;                               record replay
(def zm-cli-plan
  (fn (_ argv)
    (if (if (Opts help? zm-options argv) #t
          (if (pair? argv) (str=? (first argv) "-h") #f))
      (list (lit help))
      (do
        (def o (Opts parse zm-options argv))
        (def ops (Opts operands o))
        (def on? (fn (_ f) (Opts on? o f)))
        (def val (fn (_ f) (Opts value o f)))
        (def num
          (fn (_ f hex?)
            (if (null? (val f)) () (%zm-number (val f) hex?))))
        (match
          ((not (null? (Opts unknown o)))
            (list (lit refuse) (Str8 append "unrecognized option '" (Str8 append (Opts unknown o) "'"))))
          ((null? ops) (list (lit refuse) ()))
          ((pair? (rest ops)) (list (lit refuse) "one story at a time"))
          ((if (on? "-w") (null? (num "-w" #f)) #f) (list (lit refuse) "--width takes a number"))
          ((if (on? "-s") (null? (num "-s" #f)) #f) (list (lit refuse) "--seed takes a number"))
          ((if (on? "-D") (null? (num "-D" #t)) #f) (list (lit refuse) "--dis takes a hexadecimal address"))
          (#t
            (do
              (def views
                (List append
                  (List filter (fn (_ v) (on? (first v)))
                    (list (pair "-i" (lit info)) (pair "-o" (lit objects)) (pair "-t" (lit tree))
                          (pair "-d" (lit dict)) (pair "-a" (lit abbrevs))))
                  (if (on? "-D") (list (pair "-D" (pair (lit dis) (num "-D" #t)))) ())))
              (if (pair? views)
                (list (lit describe) (first ops) (List map (fn (_ v) (rest v)) views))
                (list (lit play) (first ops)
                  (list (pair (lit plain) (on? "-p"))
                        (pair (lit width) (if (on? "-w") (num "-w" #f) 80))
                        (pair (lit seed) (if (on? "-s") (num "-s" #f) ()))
                        (pair (lit restore) (val "-r"))
                        (pair (lit save-dir) (val "-S"))
                        (pair (lit echo) (on? "-e"))
                        (pair (lit upper) (on? "-u"))
                        (pair (lit history) (val "-H"))
                        (pair (lit transcript) (val "-T"))
                        (pair (lit record) (val "-R"))
                        (pair (lit replay) (val "-P"))))))))))))

(def %zm-say-err (fn (_ s) (zm-file-write 2 s (%zm-byte-len s))))

(def %zm-setting (fn (_ al k) (rest (%zm-assq k al))))

; The terminal screen when standard output is a terminal that is not
; "dumb" and --plain was not given; else the plain one.
;
; --plain on such a terminal still prints styles and colours, with no
; drawing; through a pipe the lines are the text alone.
(def %zm-screen-choose!
  (fn (_ plain? width)
    (def term (Sys getenv "TERM"))
    (def terminal? (if (Sys isatty 1) (if (null? term) #t (not (str=? term "dumb"))) #f))
    (if (if plain? #f terminal?)
      (do
        (def w (Term window 1))
        (zm-screen-ansi! (first w) (rest w) #f))
      (do
        (zm-screen-plain! width)
        (zm-plain-sgr! terminal?)))))

(def %zm-describe
  (fn (_ story views)
    (zm-screen-plain! 0)
    (zm-start! story)
    (def show
      (fn (self vs)
        (if (null? vs) ()
          (do
            (def v (first vs))
            (match
              ((eq? v (lit info)) (zm-info-header))
              ((eq? v (lit objects)) (zm-info-objects))
              ((eq? v (lit tree)) (zm-info-tree))
              ((eq? v (lit dict)) (zm-info-dict))
              ((eq? v (lit abbrevs)) (zm-info-abbrevs))
              (#t
                (if (zm= (rest v) 0) (zm-dis-code zm-hdr-pc) (zm-dis-routine-at (rest v)))))
            (self (rest vs))))))
    (show views)
    (zm-flush)))

(def %zm-play
  (fn (_ story settings)
    (zm-sys-dup2 3 0)
    (zm-sys-close 3)
    (zm-history! (%zm-setting settings (lit history)))
    (zm-transcript-file! (%zm-setting settings (lit transcript)))
    (zm-input-fd! 0)
    (if (%zm-setting settings (lit echo)) (zm-echo! #t))
    (zm-plain-upper! (%zm-setting settings (lit upper)))
    (if (null? (%zm-setting settings (lit save-dir))) ()
      (zm-save-dir! (%zm-setting settings (lit save-dir))))
    (%zm-screen-choose! (%zm-setting settings (lit plain)) (%zm-setting settings (lit width)))
    (def pc0 (zm-start! story))
    (def record (%zm-setting settings (lit record)))
    (if (null? record) () (do (zm-record-file! record) (zm-record-start!)))
    (def replay (%zm-setting settings (lit replay)))
    (if (if (null? replay) #f (not (zm-replay-file! replay)))
      (do (zm-screen-end!)
          (%zm-say-err (Str8 append "infocom: cannot read " replay "\n"))
          (zm-sys-exit 1)))
    (def seed (%zm-setting settings (lit seed)))
    (zm-seed! (if (null? seed) (%zm-clock-seed) seed))
    (def file (%zm-setting settings (lit restore)))
    (def pc
      (if (null? file) pc0
        (do
          (def r (zm-restore-file file))
          (if (null? r)
            (do (zm-screen-end!)
                (%zm-say-err (Str8 append "infocom: cannot restore " (Str8 append file "\n")))
                (zm-sys-exit 1))
            r))))
    (zm-run pc)
    (zm-screen-end!)))

(def zm-main
  (fn (_ raw)
    (def plan (zm-cli-plan (zm-argv raw)))
    (def label (first plan))
    (match
      ((eq? label (lit help))
        (do (zm-file-write 1 (zm-usage) (%zm-byte-len (zm-usage))) (zm-sys-exit 0)))
      ((eq? label (lit refuse))
        (do
          (if (null? (first (rest plan))) ()
            (%zm-say-err (Str8 append "infocom: " (Str8 append (first (rest plan)) "\n"))))
          (%zm-say-err (zm-usage))
          (zm-sys-exit 2)))
      ((not (File exists? (first (rest plan))))
        (do
          (%zm-say-err (Str8 append "infocom: no such file: " (Str8 append (first (rest plan)) "\n")))
          (zm-sys-exit 1)))
      ((eq? label (lit describe))
        (do (%zm-describe (first (rest plan)) (first (rest (rest plan)))) (zm-sys-exit 0)))
      (#t
        (do (%zm-play (first (rest plan)) (first (rest (rest plan)))) (zm-sys-exit 0))))))
