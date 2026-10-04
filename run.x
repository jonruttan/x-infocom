; # x-infocom -- a Z-machine on x-lang
;
; ## run.x -- the entry
;
; @description An Infocom Z-machine: `x -l infocom -- STORY` plays a
;   story file on the terminal.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
(import infocom/base)

(set! %lang-name "INFOCOM")
(set! %lang-version infocom-version)
(set! %repl-prompt "infocom> ")

(unless (null? (zm-argv args))
  (zm-main args))
