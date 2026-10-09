; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/streams.x -- the transcript, recording commands, and playing
; them back
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Output stream 2 is the transcript: the lower window's text, whether or
; not the screen shows it, and the commands as they are typed.  It is on
; while the header's flags 2 bit 0 is -- output_stream 2 sets the bit, and
; a version 3 story sets it itself (Zork's SCRIPT) -- so the bit is read as
; the text goes.  Output stream 4 records each command typed; input stream
; 1 reads commands from such a file, echoing each, until it ends.
;
; Each file is the one the command line names, else asked for as a save
; file is, offered as <story>.scr or <story>.rec.

(provide infocom/streams
  zm-transcript-file! zm-script-zscii zm-script-unicode zm-script-close!
  zm-record-file! zm-record-start! zm-record-stop! zm-line-typed
  zm-replay-file! zm-input-stream!)

(def %zm-write-str
  (fn (_ fd s) (zm-file-write fd s (%zm-byte-len s))))

(def %zm-open-write
  (fn (_ path) (File open path (list (lit wronly) (lit creat) (lit trunc)) 420)))

; --- the transcript ----------------------------------------------------------

(def %zm-script-path ())
(def %zm-script-fd ())
(def %zm-script-line ())
(def %zm-script-asking? #f)

(def zm-transcript-file! (fn (_ path) (set! %zm-script-path path)))

(def %zm-script-off-bit!
  (fn (_) (zm-wb! 17 (zm& (zm-rb 17) 254))))

; The file opens when the bit is first seen set; a name that cannot be
; opened turns the bit off again.  While the name is being asked for the
; prompt's own text is not transcribed.
(def %zm-script-open!
  (fn (_)
    (set! %zm-script-asking? #t)
    (def path
      (if (null? %zm-script-path)
        (%qz-ask-file (Str8 append %zm-story-name ".scr"))
        %zm-script-path))
    (set! %zm-script-asking? #f)
    (def fd (if (null? path) -1 (%zm-open-write path)))
    (if (zm< fd 0) (%zm-script-off-bit!) (set! %zm-script-fd fd))))

(def zm-script-close!
  (fn (_)
    (if (null? %zm-script-fd) ()
      (do
        (if (null? %zm-script-line) ()
          (%zm-write-str %zm-script-fd (%qz-codes->str (%zm-rev %zm-script-line))))
        (File close %zm-script-fd)
        (set! %zm-script-fd ())
        (set! %zm-script-line ())))))

(def %zm-script-on?
  (fn (_)
    (if %zm-script-asking? #f
      (do
        (def want (not (zm= (zm& (zm-rb 17) 1) 0)))
        (match
          ((if want (null? %zm-script-fd) #f) (%zm-script-open!))
          ((if want #f (not (null? %zm-script-fd))) (zm-script-close!)))
        (not (null? %zm-script-fd))))))

; A character of the lower window, as a code point; Return ends the line.
(def zm-script-unicode
  (fn (_ u)
    (if (if (if (zm= (zm& (%zm-pref %zm-ptr 17 1) 1) 0) (null? %zm-script-fd) #f) #f (%zm-script-on?))
      (if (zm= u 13)
        (do
          (%zm-write-str %zm-script-fd
            (%qz-codes->str (%zm-rev (pair 10 %zm-script-line))))
          (set! %zm-script-line ()))
        (set! %zm-script-line (pair u %zm-script-line))))))

; Every character of the lower window passes here, so while the bit is off
; and no file is open nothing more is done than read it.
(def zm-script-zscii
  (fn (_ c)
    (if (if (zm= (zm& (%zm-pref %zm-ptr 17 1) 1) 0) (null? %zm-script-fd) #f) ()
      (if (if (zm= c 13) #t (zm= c 10)) (zm-script-unicode 13)
        (do
          (def u (%zm-zscii->unicode c))
          (if (null? u) () (zm-script-unicode u)))))))

; --- recording commands ------------------------------------------------------

(def %zm-record-path ())
(def %zm-record-fd ())

(def zm-record-file! (fn (_ path) (set! %zm-record-path path)))

(def zm-record-start!
  (fn (_)
    (if (null? %zm-record-fd)
      (do
        (def path
          (if (null? %zm-record-path)
            (%qz-ask-file (Str8 append %zm-story-name ".rec"))
            %zm-record-path))
        (def fd (if (null? path) -1 (%zm-open-write path)))
        (if (zm< fd 0) () (set! %zm-record-fd fd))))))

(def zm-record-stop!
  (fn (_)
    (if (null? %zm-record-fd) ()
      (do (File close %zm-record-fd) (set! %zm-record-fd ())))))

; A command as typed: to the recording, and to the transcript when the
; screen did not echo it (a terminal echoes it itself).
(def zm-line-typed
  (fn (_ codes echoed?)
    (if (null? %zm-record-fd) ()
      (%zm-write-str %zm-record-fd (%qz-codes->str (List append codes (list 10)))))
    (if echoed? ()
      (do
        (def go (fn (self cs) (if (null? cs) () (do (zm-script-zscii (first cs)) (self (rest cs))))))
        (go codes)
        (zm-script-zscii 13)))))

; --- playing commands back ---------------------------------------------------

; While a file plays, its lines are the source, each echoed after the
; prompt as a transcript shows it; at its end the keyboard is the source
; again.
(def %zm-replay-back ())

(def %zm-replay-stop!
  (fn (_)
    (if (null? %zm-replay-back) ()
      (do
        (def back %zm-replay-back)
        (set! %zm-replay-back ())
        (File close (first back))
        (set! %zm-source (first (rest back)))
        (set! %zm-echo? (rest (rest back)))))))

(def zm-replay-file!
  (fn (_ path)
    (def fd (if (null? path) -1 (File open path (lit rdonly))))
    (if (zm< fd 0) #f
      (do
        (%zm-replay-stop!)
        (set! %zm-replay-back (pair fd (pair %zm-source %zm-echo?)))
        (set! %zm-echo? #t)
        (def buf (%zm-str-make 1))
        (set! %zm-source
          (fn (_)
            (def go
              (fn (self acc)
                (def n (zm-file-read fd buf 1))
                (if (zm< n 1)
                  (if (null? acc) () (pair #t (%zm-rev acc)))
                  (do
                    (def c (zm& (%zm-pref (%zm-str->ptr buf) 0 1) 255))
                    (match
                      ((zm= c 10) (pair #t (%zm-rev acc)))
                      ((zm= c 13) (self acc))
                      (#t (self (pair c acc))))))))
            (def got (go ()))
            (if (null? got)
              (do (%zm-replay-stop!) (%zm-source))
              got)))
        #t))))

; input_stream: 1 plays a file of commands back, 0 the keyboard again.
(def zm-input-stream!
  (fn (_ n)
    (match
      ((zm= n 1) (zm-replay-file! (%qz-ask-file (Str8 append %zm-story-name ".rec"))))
      ((zm= n 0) (%zm-replay-stop!)))))
