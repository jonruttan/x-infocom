; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/cli.x -- the command line
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; x -l infocom -- STORY plays STORY on the terminal: lines are read from
; standard input, which under the launcher waits on descriptor 3 until it
; is reclaimed.

(provide infocom/cli zm-argv zm-main)

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

(def zm-main
  (fn (_ raw)
    (def argv (zm-argv raw))
    (if (null? argv)
      (do (zm-file-write 2 "usage: x -l infocom -- STORY\n" 29) (zm-sys-exit 2)))
    (zm-sys-dup2 3 0)
    (zm-sys-close 3)
    (zm-input-fd! 0)
    (zm-run (zm-start! (first argv)))
    (zm-flush)
    (zm-sys-exit 0)))
