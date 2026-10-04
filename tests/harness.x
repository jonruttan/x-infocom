; # x-infocom -- a Z-machine on x-lang
;
; ## tests/harness.x -- what the spec harness adds to the dialect
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The lang kit's generator writes tests/lib/harness.gen.x: the dialect
; lang.xon declares, the bundle's root on the import path, then this file.
; Stories under tests/stories are found on the import path, from any
; working directory.
(import infocom/base)

(def zm-story
  (fn (_ name) (%module-resolve-file (Str8 append "tests/stories/" name))))

; Saves from the specs go to the system's temporary directory; a case that
; restores a save kept with the suite points the machine at tests/saves.
(zm-save-dir! "/tmp")
(def zm-test-dir
  (fn (_ name)
    (def f (%module-resolve-file (Str8 append "tests/" (Str8 append name "/.keep"))))
    (Str8 sub 0 (zm- (%zm-byte-len f) 6) f)))

; Play a story with its output in a file, then show only the lines that
; hold one of needles: for a test story whose own verdicts are the check.
(def zm-play-grep
  (fn (_ name lines needles)
    (def file (Str8 append "/tmp/x-infocom-" (Str8 append name ".out")))
    (def fd (File open file (list (lit wronly) (lit creat) (lit trunc)) 420))
    (zm-output-fd! fd)
    (zm-play (zm-story name) lines)
    (zm-output-fd! 1)
    (File close fd)
    (def hit?
      (fn (self l ns) (if (null? ns) #f (if (Str8 includes? (first ns) l) #t (self l (rest ns))))))
    (List for-each
      (fn (_ l) (if (hit? l needles) (do (display l) (newline))))
      (Str8 split "\n" (File read-all file)))))
