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

; The machine is the scoped module infocom/base.  The public names the specs
; call are imported by name; the privates a spec names are reached through
; the module, and the state the machine rebinds while it runs is read
; through %base-ref, which evaluates in the module, since a copy taken here
; would keep the value it had when it was taken.
(import infocom/base
  infocom-version zm& zm+ zm- zm-aread zm-beep! zm-before-read! zm-call-now
  zm-checksum zm-cli-plan zm-debug zm-dis-code zm-echo! zm-file-read-all
  zm-file-size zm-file-write zm-flush zm-frame-id zm-info-abbrevs
  zm-info-dict zm-info-header zm-info-objects zm-info-tree zm-input-script!
  zm-main zm-options zm-out-ascii zm-out-unicode zm-out-zscii zm-output-fd!
  zm-plain-upper! zm-play zm-rb zm-read-char zm-read-line zm-record-file!
  zm-record-start! zm-replay-file! zm-restore-file zm-restore-table
  zm-row-str zm-run zm-rw zm-save-dir! zm-save-table zm-screen-ansi!
  zm-screen-end! zm-screen-plain! zm-set-colour! zm-set-cursor! zm-set-font!
  zm-set-true-colour! zm-set-window! zm-split! zm-start! zm-status-codes
  zm-text-style! zm-transcript-file! zm-unpack-routine zm-unpack-string
  zm-usage zm-wb! zm-ww! zm< zm= zm>>)
(def %base-ref (fn (_ name) (eval name (module infocom/base))))
(def %zm-byte-len (eval (lit %zm-byte-len) (module infocom/base)))
(def %zm-byte-ref (eval (lit %zm-byte-ref) (module infocom/base)))
(def %zm-char->int (eval (lit %zm-char->int) (module infocom/base)))
(def %zm-int->ptr (eval (lit %zm-int->ptr) (module infocom/base)))
(def %zm-length (eval (lit %zm-length) (module infocom/base)))
(def %zm-mem-copy (eval (lit %zm-mem-copy) (module infocom/base)))
(def %zm-pref (eval (lit %zm-pref) (module infocom/base)))
(def %zm-pset! (eval (lit %zm-pset!) (module infocom/base)))
(def %zm-ptr->int (eval (lit %zm-ptr->int) (module infocom/base)))
(def %zm-str->ptr (eval (lit %zm-str->ptr) (module infocom/base)))
(def %zm-str-make (eval (lit %zm-str-make) (module infocom/base)))

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

; The first n lines a thunk prints through the machine's output, shown: for
; views too long to hold whole in a spec.
(def zm-first-lines
  (fn (_ n thunk)
    (def file "/tmp/x-infocom-lines.out")
    (def fd (File open file (list (lit wronly) (lit creat) (lit trunc)) 420))
    (zm-output-fd! fd)
    (thunk)
    (zm-flush)
    (zm-output-fd! 1)
    (File close fd)
    (def go
      (fn (self ls k)
        (if (if (null? ls) #t (zm= k n)) ()
          (do (display (first ls)) (newline) (self (rest ls) (zm+ k 1))))))
    (go (Str8 split "\n" (File read-all file)) 0)))
