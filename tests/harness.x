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
