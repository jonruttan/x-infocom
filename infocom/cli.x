; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/cli.x -- the command line
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; x -l infocom -- [--plain] STORY plays STORY: lines are read from
; standard input, which under the launcher waits on descriptor 3 until it
; is reclaimed.  On a terminal the screen is drawn (screen.x): the status
; line, the upper window, styles; --plain, a pipe or TERM=dumb print lines.

(provide infocom/cli zm-argv zm-main)

(import x/repl/term)

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

(def %zm-usage "usage: x -l infocom -- [--plain] STORY\n")

; The terminal screen when standard output is a terminal that is not
; "dumb" and --plain was not given; else the plain one, at 80 columns.
(def %zm-screen-choose!
  (fn (_ plain?)
    (def term (Sys getenv "TERM"))
    (if (if plain? #f
          (if (Sys isatty 1) (if (null? term) #t (not (str=? term "dumb"))) #f))
      (do
        (def w (Term window 1))
        (zm-screen-ansi! (first w) (rest w) #f))
      (zm-screen-plain! 80))))

(def zm-main
  (fn (_ raw)
    (def argv (zm-argv raw))
    (def plain? (if (pair? argv) (str=? (first argv) "--plain") #f))
    (def ops (if plain? (rest argv) argv))
    (if (if (null? ops) #t (pair? (rest ops)))
      (do (zm-file-write 2 %zm-usage (%zm-byte-len %zm-usage)) (zm-sys-exit 2)))
    (zm-sys-dup2 3 0)
    (zm-sys-close 3)
    (zm-input-fd! 0)
    (%zm-screen-choose! plain?)
    (zm-run (zm-start! (first ops)))
    (zm-screen-end!)
    (zm-sys-exit 0)))
