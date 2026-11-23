; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/base.x -- the machine, assembled
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The machine is one module written in several files.  Each part is headed
; with this module's name, so they share its names, the zm- ones and the
; private %zm- ones, and call each other through them at run time; the
; order below is only the order of loading.  What leaves the module is the
; provide at the end, after every part has defined its names.

(module infocom/base)

(def infocom-version "0.1.0")

(include-once "./prims.x")
(include-once "./mem.x")
(include-once "./text.x")
(include-once "./obj.x")
(include-once "./input.x")
(include-once "./cpu.x")
(include-once "./decode.x")
(include-once "./ops.x")
(include-once "./quetzal.x")
(include-once "./streams.x")
(include-once "./undo.x")
(include-once "./screen.x")
(include-once "./machine.x")
(include-once "./dis.x")
(include-once "./debug.x")
(include-once "./info.x")
(include-once "./cli.x")

; The machine's state that a part rebinds while it runs -- the header fields
; read when a story loads, the story's size and version, the window, the
; screen's mode, a call's argument count -- is not provided: a copy taken
; by an import would keep the value it had then.
(provide infocom/base
  infocom-version zm-play zm-start! zm-run zm-main zm-cli-plan zm-options
  zm-usage zm-push zm-pop zm-var zm-var-set! zm-var-peek zm-var-poke!
  zm-call zm-call-now zm-return zm-throw zm-frame-id zm-cpu-reset! zm-random
  zm-stack-ref zm-locals-ref zm-locals-copy zm-debug zm-parse zm-insn-at
  zm-link-at zm-decode-reset! zm-op-entry zm-dis zm-dis-at zm-dis-code
  zm-dis-routine zm-dis-routine-at zm-trace-run zm-info-header
  zm-info-object zm-info-objects zm-info-tree zm-info-dict zm-info-abbrevs
  zm-object-count zm-input-fd! zm-input-script! zm-read-line
  zm-read-raw-line zm-read-char zm-echo! zm-tokenise! zm-lookup zm-history!
  zm-restart! zm-sread zm-aread zm-scan-table zm-encode-text! zm-copy-table!
  zm-print-table zm-rb zm-rw zm-wb! zm-ww! zm-signed zm-unpack-routine
  zm-unpack-string zm-load! zm-reset-memory! zm-checksum zm-obj-parent
  zm-obj-sibling zm-obj-child zm-attr? zm-attr-set! zm-attr-clear!
  zm-obj-insert! zm-obj-remove! zm-obj-name zm-prop zm-prop-addr zm-prop-len
  zm-prop-next zm-prop-put! zm-ops-install! zm-quit-pc zm+ zm- zm* zm/ zm%
  zm& zm| zm^ zm<< zm>> zm< zm= zm-file-size zm-file-read-all zm-file-write
  zm-file-read zm-sys-exit zm-sys-dup2 zm-sys-close zm-save zm-restore
  zm-restore-file zm-save-dir! zm-save-table zm-restore-table
  zm-screen-plain! zm-screen-ansi! zm-screen-start! zm-screen-end!
  zm-status! zm-status-codes zm-before-read! zm-plain-upper! zm-split!
  zm-set-window! zm-erase-window! zm-erase-line! zm-set-cursor! zm-cursor
  zm-text-style! zm-upper-zscii zm-upper-unicode zm-set-colour!
  zm-set-true-colour! zm-plain-sgr! zm-beep! zm-transcript-file!
  zm-script-zscii zm-script-unicode zm-script-close! zm-record-file!
  zm-record-start! zm-record-stop! zm-line-typed zm-replay-file!
  zm-input-stream! zm-zstring zm-zstring-at zm-encode-word zm-out-zscii
  zm-out-codes zm-out-num zm-out-ascii zm-out-unicode zm-flush zm-stream!
  zm-text-reset! zm-output-fd! zm-width! zm-col-reset! zm-lines-before-line
  zm-row-str zm-set-font! zm-save-undo zm-restore-undo zm-undo-reset!)
