; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/base.x -- the machine, assembled
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The parts share one flat namespace, every name led by zm- (or %zm- for
; the ones no caller outside the machine needs); each part calls the
; others through those names at run time, so the order below is only the
; order of loading.

(provide infocom/base infocom-version zm-play zm-start! zm-run zm-main zm-argv)

(def infocom-version "0.1.0")

(import infocom/prims)
(import infocom/mem)
(import infocom/text)
(import infocom/obj)
(import infocom/input)
(import infocom/cpu)
(import infocom/decode)
(import infocom/ops)
(import infocom/quetzal)
(import infocom/screen)
(import infocom/machine)
(import infocom/dis)
(import infocom/info)
(import infocom/cli)
