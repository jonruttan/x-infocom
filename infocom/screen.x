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
  zm-ansi? zm-window zm-status! zm-status-codes zm-before-read! zm-plain-upper!
  zm-split! zm-set-window! zm-erase-window! zm-erase-line! zm-set-cursor!
  zm-cursor zm-text-style! zm-upper-zscii zm-upper-unicode
  zm-set-colour! zm-set-true-colour! zm-plain-sgr!)

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
    (set! %zm-plain-sgr? #f)
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
    (set! %zm-grid ())
    (set! %zm-status-shown ())
    (set! %zm-style 0)
    (set! %zm-fg "")
    (set! %zm-bg "")
    (if zm-ansi?
      (do
        (%zm-sgr!)
        (%zm-csi "[2J")
        (%zm-goto (zm+ (%zm-top) 1) 1)
        (%zm-region!)
        (%zm-goto (zm+ (%zm-top) 1) 1)))))

(def zm-screen-end!
  (fn (_)
    (zm-flush)
    (zm-script-close!)
    (zm-record-stop!)
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
        ; twelve-hour, as the games' own manuals show it: "Time:  8:00 am"
        (do
          (def h (zm% a 24))
          (def h12 (if (zm= (zm% h 12) 0) 12 (zm% h 12)))
          (List append (%zm-ascii-codes (if (zm< h12 10) "Time:  " "Time: "))
            (List append (%zm-num-codes h12)
              (List append (list 58 (zm+ 48 (zm/ b 10)) (zm+ 48 (zm% b 10)))
                (%zm-ascii-codes (if (zm< h 12) " am " " pm "))))))))
    (def lw (%zm-length place))
    (def rw (%zm-length right))
    (def gap (zm- width (zm+ lw rw)))
    (def spaces (fn (self n acc) (if (zm< 0 n) (self (zm- n 1) (pair 32 acc)) acc)))
    (if (zm< gap 1)
      (List append place (pair 32 right))
      (List append place (spaces gap right)))))

; Draw the status line on the terminal; on the plain screen it is one of
; the rows zm-before-read! prints, when they are printed at all.
(def zm-status!
  (fn (_)
    (if (if zm-ansi? (zm< zm-version 4) #f)
      (do
        (%zm-commit)
        (%zm-csi "7")
        (%zm-goto 1 1)
        (%zm-csi "[0;7m")
        (def go (fn (self cs) (if (null? cs) () (do (%zm-status-glyph (first cs)) (self (rest cs))))))
        (go (zm-status-codes %zm-width))
        (%zm-sgr!)
        (%zm-csi "8")))))

; --- the plain screen's fixed rows -------------------------------------------
; With zm-plain-upper! on, the plain screen prints what the fixed rows hold,
; as lines: the status line when it has changed, and the upper window's
; rows -- kept in a grid as a terminal would hold them -- that have changed
; and are not blank.  They are printed before each read and when the story
; goes back to the lower window, ahead of the line in progress, so a
; transcript reads them before the prompt they came with.

(def %zm-plain-upper? #f)
(def zm-plain-upper! (fn (_ on) (set! %zm-plain-upper? on)))
(def %zm-grid ())
(def %zm-grid-shown ())
(def %zm-status-shown ())

(def %zm-grid-width (fn (_) (if (zm< 0 %zm-width) %zm-width 80)))

(def %zm-blank-row
  (fn (_)
    (def w (%zm-grid-width))
    (def r (%zm-vec w))
    (def go (fn (self i) (if (zm< w i) () (do (%zm-obj-set! r i 32) (self (zm+ i 1))))))
    (go 1)
    r))

; A grid of n rows, those of the old one that fit kept.
(def %zm-grid-size!
  (fn (_ n keep?)
    (def g (%zm-vec n))
    (def s (%zm-vec n))
    (def old (if (null? %zm-grid) 0 (%zm-obj-ref %zm-grid 0)))
    (def go
      (fn (self i)
        (if (zm< n i) ()
          (do
            (if (if keep? (zm< old i) #t)
              (do (%zm-obj-set! g i (%zm-blank-row)) (%zm-obj-set! s i ()))
              (do (%zm-obj-set! g i (%zm-obj-ref %zm-grid i)) (%zm-obj-set! s i (%zm-obj-ref %zm-grid-shown i))))
            (self (zm+ i 1))))))
    (go 1)
    (set! %zm-grid g)
    (set! %zm-grid-shown s)))

(def %zm-grid-put!
  (fn (_ u)
    (if (if (null? %zm-grid) #f (if (zm< (%zm-obj-ref %zm-grid 0) %zm-urow) #f (zm< %zm-ucol (zm+ (%zm-grid-width) 1))))
      (%zm-obj-set! (%zm-obj-ref %zm-grid %zm-urow) %zm-ucol u))))

; A row's code points, its trailing blanks dropped.
(def %zm-row-text
  (fn (_ r)
    (def go
      (fn (self i acc)
        (if (zm< i 1) acc
          (self (zm- i 1) (if (if (null? acc) (zm= (%zm-obj-ref r i) 32) #f) acc (pair (%zm-obj-ref r i) acc))))))
    (go (%zm-obj-ref r 0) ())))

; The rows that changed since they were printed and are not blank, in order;
; each is marked printed.
(def %zm-grid-lines
  (fn (_)
    (def n (if (null? %zm-grid) 0 (%zm-obj-ref %zm-grid 0)))
    (def go
      (fn (self i acc)
        (if (zm< n i) (%zm-rev acc)
          (do
            (def t (%zm-row-text (%zm-obj-ref %zm-grid i)))
            (def changed? (not (equal? t (%zm-obj-ref %zm-grid-shown i))))
            (%zm-obj-set! %zm-grid-shown i t)
            (self (zm+ i 1) (if (if changed? (pair? t) #f) (pair t acc) acc))))))
    (go 1 ())))

; The status line as code points, trailing blanks dropped, when it changed.
(def %zm-status-line
  (fn (_)
    (if (zm< zm-version 4)
      (do
        (def cs (List filter (fn (_ u) (not (null? u))) (List map %zm-zscii->unicode (zm-status-codes (%zm-grid-width)))))
        (def trim (fn (self l) (if (null? l) () (if (zm= (first l) 32) (self (rest l)) l))))
        (def t (%zm-rev (trim (%zm-rev cs))))
        (if (equal? t %zm-status-shown) () (do (set! %zm-status-shown t) (list t))))
      ())))

(def %zm-plain-show!
  (fn (_ status?)
    (if (if zm-ansi? #f %zm-plain-upper?)
      (do
        (def lines (List append (if status? (%zm-status-line) ()) (%zm-grid-lines)))
        (if (null? lines) () (zm-lines-before-line lines))))))

; Before every read: the status line drawn, or the fixed rows printed.
(def zm-before-read!
  (fn (_)
    (zm-status!)
    (%zm-plain-show! #t)))

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
            (%zm-csi "8"))))
      (if %zm-plain-upper? (%zm-grid-size! n (not (zm< zm-version 4)))))))

; set_window: 1 the upper window, its cursor at the top left; 0 back to
; the lower window where it was left.
(def zm-set-window!
  (fn (_ w)
    (%zm-commit)
    (if (zm= w zm-window) ()
      (do
        (set! zm-window w)
        (if (zm= w 1) (do (set! %zm-urow 1) (set! %zm-ucol 1)))
        (if zm-ansi?
          (if (zm= w 1) (do (%zm-csi "7") (%zm-upper-goto)) (%zm-csi "8"))
          (if (zm= w 0) (%zm-plain-show! #f)))))))

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
        (#t ()))
      (if (if %zm-plain-upper? (if (zm< w 0) #t (zm= w 1)) #f)
        (%zm-grid-size! %zm-upper #f)))))

(def zm-erase-line!
  (fn (_ v)
    (if (if (zm= v 1) (zm= zm-window 1) #f)
      (if zm-ansi? (%zm-csi "[K")
        (if (if %zm-plain-upper? (not (null? %zm-grid)) #f)
          (do
            (def keep %zm-ucol)
            (def go (fn (self) (if (zm< (%zm-grid-width) %zm-ucol) () (do (%zm-grid-put! 32) (set! %zm-ucol (zm+ %zm-ucol 1)) (self)))))
            (go)
            (set! %zm-ucol keep)))))))

; A character in the upper window: placed, never wrapped, cut at the edge.
(def zm-upper-zscii
  (fn (_ c)
    (if (if (zm= c 13) #t (zm= c 10))
      (do
        (set! %zm-urow (zm+ %zm-urow 1))
        (set! %zm-ucol 1)
        (if zm-ansi? (%zm-upper-goto)))
      (do
        (def u (%zm-zscii->unicode c))
        (if (null? u) () (zm-upper-unicode u))))))

(def zm-upper-unicode
  (fn (_ u)
    (if zm-ansi?
      (if (zm< %zm-width %zm-ucol) () (%zm-glyph u))
      (if %zm-plain-upper? (%zm-grid-put! u)))
    (set! %zm-ucol (zm+ %zm-ucol 1))))

; --- styles and colours ------------------------------------------------------
; The text's look is one SGR state -- the style, then the foreground and
; background as SGR parameters, "" for the terminal's own -- sent whole on
; every change, so a style of 0 keeps the colours and the status line puts
; them back after drawing in reverse.  The drawn screen sends it, and so
; does the plain one when it prints to a terminal (zm-plain-sgr!).

(def %zm-style 0)
(def %zm-fg "")
(def %zm-bg "")
(def %zm-plain-sgr? #f)
(def zm-plain-sgr! (fn (_ on) (set! %zm-plain-sgr? on)))
(def %zm-sgr? (fn (_) (if zm-ansi? #t %zm-plain-sgr?)))

(def %zm-sgr!
  (fn (_)
    (%zm-csi (Str8 append "[0"
               (if (zm= (zm& %zm-style 1) 0) "" ";7")
               (if (zm= (zm& %zm-style 2) 0) "" ";1")
               (if (zm= (zm& %zm-style 4) 0) "" ";3")
               %zm-fg %zm-bg "m"))))

; The spaces held before the change are written first, in the look they
; were typed in.
(def %zm-look!
  (fn (_) (if (%zm-sgr?) (do (%zm-commit) (%zm-out-spaces) (%zm-sgr!)))))

; set_text_style: 0 roman, else a sum of 1 reverse, 2 bold, 4 italic, 8
; fixed pitch (which a terminal always is), added to the styles already on
; (Standard 1.1: bold then italic is bold italic).
(def zm-text-style!
  (fn (_ s)
    (set! %zm-style (if (zm= s 0) 0 (zm| %zm-style s)))
    (%zm-look!)))

; set_colour: 0 keeps a colour, 1 is the terminal's own, 2 to 9 are black,
; red, green, yellow, blue, magenta, cyan and white -- ANSI's order, from
; 30 for the foreground and 40 for the background.
(def %zm-colour-sgr
  (fn (_ c base was)
    (match
      ((zm= c 0) was)
      ((zm= c 1) "")
      ((if (zm< c 2) #f (zm< c 10)) (Str8 append ";" (%zm-digits (zm+ base (zm- c 2)))))
      (#t was))))

(def zm-set-colour!
  (fn (_ f b)
    (set! %zm-fg (%zm-colour-sgr f 30 %zm-fg))
    (set! %zm-bg (%zm-colour-sgr b 40 %zm-bg))
    (%zm-look!)))

; set_true_colour: fifteen bits, five each of red, green and blue from the
; low end, sent as 24-bit colour; -1 (65535) the terminal's own, -2 (65534)
; keeps the colour.
(def %zm-true-sgr
  (fn (_ c lead was)
    (match
      ((zm= c 65535) "")
      ((zm= c 65534) was)
      (#t
        (do
          (def ch (fn (_ k) (%zm-digits (zm/ (zm* (zm& (zm>> c k) 31) 255) 31))))
          (Str8 append ";" lead ";2;" (ch 0) ";" (ch 5) ";" (ch 10)))))))

(def zm-set-true-colour!
  (fn (_ f b)
    (set! %zm-fg (%zm-true-sgr f "38" %zm-fg))
    (set! %zm-bg (%zm-true-sgr b "48" %zm-bg))
    (%zm-look!)))

; A ZSCII character of the status line, as the screen draws it.
(def %zm-status-glyph
  (fn (_ c)
    (def u (%zm-zscii->unicode c))
    (if (null? u) () (%zm-glyph u))))
