; # x-infocom -- a Z-machine on x-lang
;
; ## lib/infocom/run.x -- the entry
;
; @description An Infocom Z-machine: `x -l infocom -- STORY` plays a
;   story file on the terminal.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
(module infocom/run)
(import infocom/base infocom-version zm-main)

(set! %lang-name "INFOCOM")
(set! %lang-version infocom-version)
(set! %repl-prompt "infocom> ")

; With operands, zm-main plays them; with none the session goes on to the
; REPL.
(def main
  (fn (_)
    (let ((ops (rest (Sys args (lit program)))))
      (unless (null? ops) (zm-main ops)))))

(provide infocom/run main)
