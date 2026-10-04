; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/screen.x -- the status line, the upper window and text styles
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Two screens.  The plain one is a stream of lines: the lower window only,
; wrapped, which is what a pipe, a transcript and a spec want, and what
; dfrotz's transcripts are compared with.  The terminal one is drawn with
; ANSI sequences: a scroll region holds the lower window under the fixed
; rows above it -- the status line before version 4, the upper window from
; split_window -- and those rows are written by cursor position, never
; wrapped and never scrolled.  Styles become SGR codes in both directions
; of the same byte stream, so nothing is reordered.
;
; The lower window's own output stays in text.x; this file owns everything
; drawn by position, and the switch between the two.

(provide infocom/screen
  zm-screen-plain! zm-screen-ansi! zm-screen-start! zm-screen-end!
  zm-ansi? zm-window zm-status! zm-status-codes
  zm-split! zm-set-window! zm-erase-window! zm-erase-line! zm-set-cursor!
  zm-cursor zm-text-style! zm-upper-zscii)

(def zm-ansi? #f)
(def %zm-esc-visible? #f)
(def %zm-rows 24)
(def zm-window 0)
(def %zm-upper 0)
(def %zm-urow 1)
(def %zm-ucol 1)

; The plain screen: lines, wrapped at width (0, never).
(def zm-screen-plain!
  (fn (_ width)
    (set! zm-ansi? #f)
    (zm-width! width)))

; The terminal screen, width by rows; visible? writes ESC as ^[ so a spec
; can read what would be drawn.
(def zm-screen-ansi!
  (fn (_ width rows visible?)
    (set! zm-ansi? #t)
    (set! %zm-esc-visible? visible?)
    (set! %zm-rows rows)
    (zm-width! width)))

; --- escapes -----------------------------------------------------------------

(def %zm-bytes
  (fn (_ s)
    (def n (%zm-byte-len s))
    (def go (fn (self i) (if (zm< i n) (do (%zm-out-byte (%zm-char->int (%zm-byte-ref s i))) (self (zm+ i 1))))))
    (go 0)))

(def %zm-csi
  (fn (_ s)
    (if %zm-esc-visible? (%zm-bytes "^[") (%zm-out-byte 27))
    (%zm-bytes s)))

(def %zm-digits
  (fn (_ n)
    (def go (fn (self n acc) (if (zm< n 10) (pair (zm+ n 48) acc) (self (zm/ n 10) (pair (zm+ (zm% n 10) 48) acc)))))
    (%qz-codes->str (go n ()))))

(def %zm-goto
  (fn (_ row col)
    (%zm-csi (Str8 append "[" (Str8 append (%zm-digits row) (Str8 append ";" (Str8 append (%zm-digits col) "H")))))))

; The fixed rows: the status line (before version 4), then the upper window.
(def %zm-status-rows (fn (_) (if (zm< zm-version 4) 1 0)))
(def %zm-top (fn (_) (zm+ (%zm-status-rows) %zm-upper)))

; The lower window scrolls below the fixed rows; setting the region homes
; the cursor, so the lower window's place is saved around it.
(def %zm-region!
  (fn (_)
    (%zm-csi "7")
    (%zm-csi (Str8 append "[" (Str8 append (%zm-digits (zm+ (%zm-top) 1))
               (Str8 append ";" (Str8 append (%zm-digits %zm-rows) "r")))))
    (%zm-csi "8")))

; --- the screen's life -------------------------------------------------------

(def zm-screen-start!
  (fn (_)
    (set! zm-window 0)
    (set! %zm-upper 0)
    (if zm-ansi?
      (do
        (%zm-csi "[2J")
        (%zm-goto (zm+ (%zm-top) 1) 1)
        (%zm-region!)
        (%zm-goto (zm+ (%zm-top) 1) 1)))))

(def zm-screen-end!
  (fn (_)
    (zm-flush)
    (if zm-ansi?
      (do
        (%zm-csi "[0m")
        (%zm-csi "[r")
        (%zm-goto %zm-rows 1)
        (%zm-out-byte 10)
        (zm-flush)))))

; --- the status line ---------------------------------------------------------

(def %zm-num-codes
  (fn (_ v)
    (def s (zm-signed v))
    (def go (fn (self n acc) (if (zm< n 10) (pair (zm+ n 48) acc) (self (zm/ n 10) (pair (zm+ (zm% n 10) 48) acc)))))
    (if (zm< s 0) (pair 45 (go (zm- 0 s) ())) (go s ()))))

(def %zm-ascii-codes
  (fn (_ s)
    (def n (%zm-byte-len s))
    (def go (fn (self i) (if (zm< i n) (pair (%zm-char->int (%zm-byte-ref s i)) (self (zm+ i 1))) ())))
    (go 0)))

; The status line's text, width wide: the location on the left, the score
; and moves -- or, in a time game (flags 1 bit 1), the time -- on the right.
(def zm-status-codes
  (fn (_ width)
    (def place (pair 32 (zm-obj-name (zm-var 16))))
    (def a (zm-var 17))
    (def b (zm-var 18))
    (def right
      (if (zm= (zm& (zm-rb 1) 2) 0)
        (List append (%zm-ascii-codes "Score: ")
          (List append (%zm-num-codes a)
            (List append (%zm-ascii-codes "  Moves: ") (List append (%zm-num-codes b) (list 32)))))
        (List append (%zm-ascii-codes "Time: ")
          (List append (%zm-num-codes a)
            (List append (list 58 (zm+ 48 (zm/ b 10)) (zm+ 48 (zm% b 10))) (list 32))))))
    (def lw (%zm-length place))
    (def rw (%zm-length right))
    (def gap (zm- width (zm+ lw rw)))
    (def spaces (fn (self n acc) (if (zm< 0 n) (self (zm- n 1) (pair 32 acc)) acc)))
    (if (zm< gap 1)
      (List append place (pair 32 right))
      (List append place (spaces gap right)))))

; Draw the status line on the terminal; nothing on the plain screen.
(def zm-status!
  (fn (_)
    (if (if zm-ansi? (zm< zm-version 4) #f)
      (do
        (%zm-commit)
        (%zm-csi "7")
        (%zm-goto 1 1)
        (%zm-csi "[7m")
        (def go (fn (self cs) (if (null? cs) () (do (%zm-glyph (first cs)) (self (rest cs))))))
        (go (zm-status-codes %zm-width))
        (%zm-csi "[0m")
        (%zm-csi "8")))))

; --- the upper window --------------------------------------------------------

(def %zm-upper-goto
  (fn (_) (%zm-goto (zm+ (%zm-status-rows) %zm-urow) %zm-ucol)))

(def %zm-clear-rows
  (fn (_ from to)
    (def go (fn (self r) (if (zm< to r) () (do (%zm-goto r 1) (%zm-csi "[2K") (self (zm+ r 1))))))
    (go from)))

; split_window: the upper window becomes n rows (before version 4 it is
; cleared too).
(def zm-split!
  (fn (_ n)
    (%zm-commit)
    (set! %zm-upper n)
    (if zm-ansi?
      (do
        (%zm-region!)
        (if (zm< zm-version 4)
          (do
            (%zm-csi "7")
            (%zm-clear-rows (zm+ (%zm-status-rows) 1) (%zm-top))
            (%zm-csi "8")))))))

; set_window: 1 the upper window, its cursor at the top left; 0 back to
; the lower window where it was left.
(def zm-set-window!
  (fn (_ w)
    (%zm-commit)
    (if (zm= w zm-window) ()
      (do
        (set! zm-window w)
        (if zm-ansi?
          (if (zm= w 1)
            (do (%zm-csi "7") (set! %zm-urow 1) (set! %zm-ucol 1) (%zm-upper-goto))
            (%zm-csi "8")))))))

(def zm-set-cursor!
  (fn (_ line col)
    (if (zm= zm-window 1)
      (do
        (set! %zm-urow line)
        (set! %zm-ucol col)
        (if zm-ansi? (%zm-upper-goto))))))

(def zm-cursor
  (fn (_) (if (zm= zm-window 1) (pair %zm-urow %zm-ucol) (pair 1 1))))

; erase_window: -1 clears everything and unsplits, -2 clears everything,
; 0 the lower window, 1 the upper.
(def zm-erase-window!
  (fn (_ n)
    (%zm-commit)
    (def w (zm-signed n))
    (if (zm= w -1) (do (set! %zm-upper 0) (set! zm-window 0)))
    (if zm-ansi?
      (match
        ((zm< w 0)
          (do (%zm-csi "[2J") (%zm-region!) (%zm-goto (zm+ (%zm-top) 1) 1)))
        ((zm= w 0)
          (do (%zm-clear-rows (zm+ (%zm-top) 1) %zm-rows) (%zm-goto (zm+ (%zm-top) 1) 1)))
        ((zm= w 1)
          (do
            (%zm-csi "7")
            (%zm-clear-rows (zm+ (%zm-status-rows) 1) (%zm-top))
            (%zm-csi "8")))
        (#t ())))))

(def zm-erase-line!
  (fn (_ v)
    (if (if zm-ansi? (if (zm= v 1) (zm= zm-window 1) #f) #f) (%zm-csi "[K"))))

; A character in the upper window: placed, never wrapped, cut at the edge.
(def zm-upper-zscii
  (fn (_ c)
    (if zm-ansi?
      (if (if (zm= c 13) #t (zm= c 10))
        (do (set! %zm-urow (zm+ %zm-urow 1)) (set! %zm-ucol 1) (%zm-upper-goto))
        (do
          (if (zm< %zm-width %zm-ucol) () (%zm-glyph c))
          (set! %zm-ucol (zm+ %zm-ucol 1)))))))

; set_text_style: 0 roman, else a sum of 1 reverse, 2 bold, 4 italic, 8
; fixed pitch (which a terminal always is).
(def zm-text-style!
  (fn (_ s)
    (if zm-ansi?
      (do
        (%zm-commit)
        (if (zm= s 0) (%zm-csi "[0m")
          (do
            (if (zm= (zm& s 1) 0) () (%zm-csi "[7m"))
            (if (zm= (zm& s 2) 0) () (%zm-csi "[1m"))
            (if (zm= (zm& s 4) 0) () (%zm-csi "[3m"))))))))
