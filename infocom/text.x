; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/text.x -- Z-strings and the output streams
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; A Z-string is packed three 5-bit Z-characters to a word, the last word
; marked by its top bit.  Decoding gives a list of ZSCII codes, which is
; what the output side takes: stream 3 (a table in memory) when one is
; open, else the screen.  The screen is a byte buffer written out on a
; flush, with ZSCII 155..223 sent as the UTF-8 of the default Unicode
; table.  Versions 1 and 2, whose shift rules differ, are not served.

(provide infocom/text
  zm-zstring zm-zstring-at zm-encode-word
  zm-out-zscii zm-out-codes zm-out-num zm-out-ascii zm-out-unicode zm-flush
  zm-stream! zm-text-reset! zm-output-fd! zm-width! zm-col-reset!
  zm-lines-before-line zm-row-str)

; Alphabet 2 from Z-character 6: 6 is the escape (never looked up), 7 a
; newline, then the punctuation row.
(def %zm-a2
  (Vector from-list
    (list 0 13 48 49 50 51 52 53 54 55 56 57 46 44 33 63 95 35 39 34
          47 92 45 58 40 41)))

(def %zm-alpha
  (fn (_ alpha c)
    (if (zm= alpha 0) (zm+ c 91)
      (if (zm= alpha 1) (zm+ c 59)
        (%zm-obj-ref %zm-a2 (zm- c 5))))))

; Z-characters of the string at byte address a: (zchars . next-address).
(def %zm-zchars
  (fn (_ a)
    (def go
      (fn (self a acc)
        (def w (zm-rw a))
        (def acc2
          (pair (zm& w 31) (pair (zm& (zm>> w 5) 31) (pair (zm& (zm>> w 10) 31) acc))))
        (if (zm= (zm& w 32768) 0)
          (self (zm+ a 2) acc2)
          (pair (%zm-rev acc2) (zm+ a 2)))))
    (go a ())))

(def %zm-abbrevs ())

; Abbreviation i (0..95), decoded once.
(def %zm-abbrev
  (fn (_ i)
    (def hit (%zm-obj-ref %zm-abbrevs (zm+ i 1)))
    (if (null? hit)
      (do
        (def codes
          (%zm-zdecode
            (first (%zm-zchars (zm<< (zm-rw (zm+ zm-hdr-abbrev (zm<< i 1))) 1)))
            #f))
        (%zm-obj-set! %zm-abbrevs (zm+ i 1) codes)
        codes)
      hit)))

; Z-characters to ZSCII.  A shift (4, 5) lasts one character; 1..3 name an
; abbreviation with the character after; alphabet 2's 6 escapes a 10-bit
; code in the next two.  A string cut off mid-sequence drops the tail.
(def %zm-zdecode
  (fn (_ zs abbrevs?)
    (def go
      (fn (self zs alpha out)
        (if (null? zs) (%zm-rev out)
          (%zm-zdecode-1 self (first zs) (rest zs) alpha out abbrevs?))))
    (go zs 0 ())))

(def %zm-zdecode-1
  (fn (_ go c r alpha out abbrevs?)
    (match
      ((zm= c 0) (go r 0 (pair 32 out)))
      ((zm< c 4)
        (if (if abbrevs? (pair? r) #f)
          (go (rest r) 0
            (%zm-rev-onto (%zm-abbrev (zm+ (zm<< (zm- c 1) 5) (first r))) out))
          (%zm-rev out)))
      ((zm= c 4) (go r 1 out))
      ((zm= c 5) (go r 2 out))
      ((if (zm= alpha 2) (zm= c 6) #f)
        (if (if (pair? r) (pair? (rest r)) #f)
          (go (rest (rest r)) 0
            (pair (zm| (zm<< (first r) 5) (first (rest r))) out))
          (%zm-rev out)))
      (#t (go r 0 (pair (%zm-alpha alpha c) out))))))

; The string at byte address a: (codes . next-address).
(def zm-zstring-at
  (fn (_ a)
    (def zs (%zm-zchars a))
    (pair (%zm-zdecode (first zs) #t) (rest zs))))

; Strings at or past the static base never change, so their decodings are
; kept; a print_paddr in a loop decodes once.
(def %zm-scache ())
(def zm-zstring
  (fn (_ a)
    (if (zm< a zm-hdr-static)
      (first (zm-zstring-at a))
      (do
        (def hit (%zm-obj-ref %zm-scache (zm+ a 1)))
        (if (null? hit)
          (do
            (def codes (first (zm-zstring-at a)))
            (%zm-obj-set! %zm-scache (zm+ a 1) codes)
            codes)
          hit)))))

; ---------------------------------------------------------------------------
; Encoding, for dictionary lookup: ZSCII codes to the dictionary's packed
; words -- 6 Z-characters in two words before version 4, 9 in three after.

(def %zm-a2-index
  (fn (_ c)
    (def go
      (fn (self i)
        (if (zm< i 32)
          (if (zm= (%zm-obj-ref %zm-a2 (zm- i 5)) c) i (self (zm+ i 1)))
          0)))
    (go 8)))

(def %zm-zchars-of
  (fn (_ c)
    (match
      ((if (zm< c 97) #f (zm< c 123)) (list (zm- c 91)))
      ((if (zm< c 65) #f (zm< c 91)) (list 4 (zm- c 59)))
      (#t
        (do
          (def i (%zm-a2-index c))
          (if (zm= i 0)
            (list 5 6 (zm& (zm>> c 5) 31) (zm& c 31))
            (list 5 i)))))))

(def %zm-take-pad
  (fn (self zs n)
    (if (zm= n 0) ()
      (if (null? zs) (pair 5 (self () (zm- n 1)))
        (pair (first zs) (self (rest zs) (zm- n 1)))))))

(def zm-encode-word
  (fn (_ codes)
    (def n (if (zm< zm-version 4) 6 9))
    (def flat
      (fn (self cs acc)
        (if (null? cs) (%zm-rev acc)
          (self (rest cs) (%zm-rev-onto (%zm-zchars-of (first cs)) acc)))))
    (def zs (%zm-take-pad (flat codes ()) n))
    (def words
      (fn (self zs)
        (if (null? zs) ()
          (do
            (def w (zm| (zm<< (first zs) 10)
                    (zm| (zm<< (first (rest zs)) 5) (first (rest (rest zs))))))
            (def more (rest (rest (rest zs))))
            (pair (if (null? more) (zm| w 32768) w) (self more))))))
    (words zs)))

; ---------------------------------------------------------------------------
; Output.

(def %zm-unicode
  (Vector from-list
    (list 228 246 252 196 214 220 223 187 171 235 239 255 203 207 225 233
          237 243 250 253 193 201 205 211 218 221 224 232 236 242 249 192
          200 204 210 217 226 234 238 244 251 194 202 206 212 219 229 197
          248 216 227 241 245 195 209 213 230 198 231 199 254 240 222 208
          163 339 338 161 191)))

(def %zm-obuf ())
(def %zm-optr ())
(def %zm-olen 0)
(def %zm-obuf-size 8192)
(def %zm-out-fd 1)
(def zm-output-fd! (fn (_ fd) (zm-flush) (set! %zm-out-fd fd)))
(def %zm-stream1 #t)
(def %zm-stream3 ())

(def zm-text-reset!
  (fn (_)
    (set! %zm-abbrevs (%zm-vec 96))
    (set! %zm-scache (%zm-vec zm-size))
    (%zm-utable-set!)
    (if (null? %zm-obuf)
      (do
        (set! %zm-obuf (%zm-str-make %zm-obuf-size))
        (set! %zm-optr (%zm-str->ptr %zm-obuf))))
    (set! %zm-olen 0)
    (set! %zm-col 0)
    (set! %zm-lower-row ())
    (set! %zm-line-start 0)
    (set! %zm-word ())
    (set! %zm-wlen 0)
    (set! %zm-spaces 0)
    (set! %zm-stream1 #t)
    (set! %zm-stream3 ())))

; Where the line in progress begins in the byte buffer: 0 after a write
; that ended a line, -1 once a write has sent part of the line out.
(def %zm-line-start 0)

; The byte buffer, written out when full and on every flush.
(def %zm-write-out
  (fn (_)
    (if (zm< 0 %zm-olen)
      (do
        (zm-file-write %zm-out-fd %zm-obuf %zm-olen)
        (set! %zm-line-start (if (zm= %zm-line-start %zm-olen) 0 -1))
        (set! %zm-olen 0)))))

; Whole lines -- each a list of Unicode code points -- out ahead of the line
; in progress, so they read before the prompt they belong to; when part of
; that line has already been written, after it instead, on lines of their
; own.  Nothing they hold is wrapped or counted as the line's.
(def zm-lines-before-line
  (fn (_ lines)
    (%zm-commit)
    (def put
      (fn (self ls)
        (if (null? ls) ()
          (do
            (def go (fn (self cs) (if (null? cs) () (do (%zm-glyph (first cs)) (self (rest cs))))))
            (go (first ls))
            (%zm-out-byte 10)
            (self (rest ls))))))
    (if (zm< %zm-line-start 0)
      (do (%zm-out-byte 10) (put lines) (set! %zm-col 0))
      (do
        (def take
          (fn (self i acc)
            (if (zm< i %zm-line-start) acc
              (self (zm- i 1) (pair (zm& (%zm-pref %zm-optr i 1) 255) acc)))))
        (def held (take (zm- %zm-olen 1) ()))
        (set! %zm-olen %zm-line-start)
        (put lines)
        (def back (fn (self bs) (if (null? bs) () (do (%zm-out-byte (first bs)) (self (rest bs))))))
        (back held)))))

; Everything held, out: the word in hand, the spaces after it, the buffer.
(def zm-flush
  (fn (_)
    (%zm-commit)
    (%zm-out-spaces)
    (%zm-write-out)))

; A line typed at the terminal ends with the user's own Return.
(def zm-col-reset! (fn (_) (set! %zm-col 0) (set! %zm-lower-row ()) (set! %zm-line-start %zm-olen)))

(def %zm-out-byte
  (fn (_ b)
    (if (zm< %zm-olen %zm-obuf-size) () (%zm-write-out))
    (%zm-pset! %zm-optr %zm-olen b 1)
    (set! %zm-olen (zm+ %zm-olen 1))
    (if (zm= b 10) (set! %zm-line-start %zm-olen))))

; A Unicode code point as UTF-8.
(def %zm-out-unicode
  (fn (_ u)
    (match
      ((zm< u 128) (%zm-out-byte u))
      ((zm< u 2048)
        (do (%zm-out-byte (zm| 192 (zm>> u 6)))
            (%zm-out-byte (zm| 128 (zm& u 63)))))
      (#t
        (do (%zm-out-byte (zm| 224 (zm>> u 12)))
            (%zm-out-byte (zm| 128 (zm& (zm>> u 6) 63)))
            (%zm-out-byte (zm| 128 (zm& u 63))))))))

; The screen wraps at word boundaries, as a terminal interpreter does: a
; word is held until a space, a newline or a flush ends it, then goes on
; the line if it fits after the spaces before it, else starts the next
; line and the spaces are dropped.  Width 0 never wraps.
(def %zm-width 80)
(def %zm-col 0)

; The lower window's row in progress, newest code point first: what a line
; editor redraws as its prompt, since its redraw starts the row over.
(def %zm-lower-row ())

; The row as a string.
(def zm-row-str (fn (_) (%qz-codes->str (%zm-rev %zm-lower-row))))

(def %zm-word ())
(def %zm-wlen 0)
(def %zm-spaces 0)

(def zm-width! (fn (_ w) (set! %zm-width w)))

(def %zm-glyph (fn (_ u) (%zm-out-unicode u)))

; ZSCII to Unicode: 32-126 are ASCII; 155 on go through the story's own
; translation table when its header extension names one (version 5 on),
; else the default table of the standard; anything else prints nothing.
(def %zm-utable ())
(def %zm-utable-set!
  (fn (_)
    (set! %zm-utable %zm-unicode)
    (if (zm< zm-version 5) ()
      (do
        (def ext (zm-rw 54))
        (if (if (zm= ext 0) #f (zm< 2 (zm-rw ext)))
          (do
            (def t (zm-rw (zm+ ext 6)))
            (if (zm= t 0) ()
              (do
                (def n (zm-rb t))
                (def v (%zm-vec n))
                (def go (fn (self i) (if (zm< i n) (do (%zm-obj-set! v (zm+ i 1) (zm-rw (zm+ (zm+ t 1) (zm<< i 1)))) (self (zm+ i 1))))))
                (go 0)
                (set! %zm-utable v)))))))))

(def %zm-zscii->unicode
  (fn (_ c)
    (if (if (zm< c 32) #f (zm< c 127)) c
      (if (if (zm< c 155) #t (zm< (zm+ 154 (%zm-obj-ref %zm-utable 0)) c)) ()
        (%zm-obj-ref %zm-utable (zm- c 154))))))

(def %zm-out-spaces
  (fn (_)
    (def go (fn (self n) (if (zm< 0 n) (do (%zm-out-byte 32) (set! %zm-lower-row (pair 32 %zm-lower-row)) (self (zm- n 1))))))
    (go %zm-spaces)
    (set! %zm-col (zm+ %zm-col %zm-spaces))
    (set! %zm-spaces 0)))

(def %zm-commit
  (fn (_)
    (if (zm= %zm-wlen 0) ()
      (do
        (if (if (zm< 0 %zm-width)
              (if (zm< 0 %zm-col)
                (zm< %zm-width (zm+ %zm-col (zm+ %zm-spaces %zm-wlen)))
                #f)
              #f)
          (do (%zm-out-byte 10) (set! %zm-col 0) (set! %zm-lower-row ()) (set! %zm-spaces 0))
          (%zm-out-spaces))
        (def go (fn (self cs) (if (null? cs) () (do (%zm-glyph (first cs)) (self (rest cs))))))
        (go (%zm-rev %zm-word))
        (set! %zm-col (zm+ %zm-col %zm-wlen))
        (set! %zm-lower-row (List append %zm-word %zm-lower-row))
        (set! %zm-word ())
        (set! %zm-wlen 0)))))

; The lower window holds Unicode: a ZSCII character is translated first,
; and print_unicode's code point joins the same word.
(def %zm-screen-zscii
  (fn (_ c)
    (if (if (zm= c 13) #t (zm= c 10))
      (do (%zm-commit) (set! %zm-spaces 0) (%zm-out-byte 10) (set! %zm-col 0) (set! %zm-lower-row ()))
      (do
        (def u (%zm-zscii->unicode c))
        (if (null? u) () (%zm-screen-unicode u))))))

(def %zm-screen-unicode
  (fn (_ u)
    (match
      ((zm= u 32)
        (do (%zm-commit) (set! %zm-spaces (zm+ %zm-spaces 1))))
      ; a hyphen ends a piece of a word: the line may break after it
      ((zm= u 45)
        (do (set! %zm-word (pair u %zm-word)) (set! %zm-wlen (zm+ %zm-wlen 1)) (%zm-commit)))
      ; control characters print nothing: C0, DEL and C1
      ((if (zm< u 32) #t (if (zm< 126 u) (zm< u 160) #f)) ())
      (#t (do (set! %zm-word (pair u %zm-word)) (set! %zm-wlen (zm+ %zm-wlen 1)))))))

; Stream 3: a stack of (table . count); output lands in the innermost.
(def %zm-s3-zscii
  (fn (_ c)
    (def top (first %zm-stream3))
    (def n (rest top))
    (zm-wb! (zm+ (zm+ (first top) 2) n) (if (zm= c 10) 13 c))
    (set! %zm-stream3 (pair (pair (first top) (zm+ n 1)) (rest %zm-stream3)))))

; ZSCII 0 is no character at all, in any stream.  The screen's upper
; window is screen.x's to draw.
(def zm-out-zscii
  (fn (_ c)
    (if (zm= c 0) ()
      (if (null? %zm-stream3)
        (if %zm-stream1
          (if (zm= zm-window 0) (%zm-screen-zscii c) (zm-upper-zscii c)))
        (%zm-s3-zscii c)))))

(def zm-out-codes
  (fn (self cs)
    (if (null? cs) () (do (zm-out-zscii (first cs)) (self (rest cs))))))

; ASCII text from x, for the interpreter's own messages.
(def zm-out-ascii
  (fn (_ s)
    (def n (%zm-byte-len s))
    (def go
      (fn (self i)
        (if (zm< i n)
          (do (zm-out-zscii (%zm-char->int (%zm-byte-ref s i))) (self (zm+ i 1))))))
    (go 0)))

; A signed 16-bit value in decimal.
(def zm-out-num
  (fn (_ v)
    (def s (zm-signed v))
    (def digits
      (fn (self n acc)
        (if (zm< n 10) (pair (zm+ n 48) acc)
          (self (zm/ n 10) (pair (zm+ (zm% n 10) 48) acc)))))
    (if (zm< s 0)
      (do (zm-out-zscii 45) (zm-out-codes (digits (zm- 0 s) ())))
      (zm-out-codes (digits s ())))))

; output_stream: 1 the screen, 3 a table (nesting), 2 and 4 accepted and
; not kept.
(def zm-stream!
  (fn (_ n table)
    (def s (zm-signed n))
    (match
      ((zm= s 1) (set! %zm-stream1 #t))
      ((zm= s -1) (set! %zm-stream1 #f))
      ((zm= s 3) (set! %zm-stream3 (pair (pair table 0) %zm-stream3)))
      ((zm= s -3)
        (if (null? %zm-stream3) ()
          (do
            (zm-ww! (first (first %zm-stream3)) (rest (first %zm-stream3)))
            (set! %zm-stream3 (rest %zm-stream3)))))
      (#t ()))))

; print_unicode: a code point to the screen; stream 3 holds ZSCII only, so
; it gets a question mark.
(def zm-out-unicode
  (fn (_ u)
    (if (null? %zm-stream3)
      (if %zm-stream1
        (if (zm= zm-window 0) (%zm-screen-unicode u) (zm-upper-unicode u)))
      (%zm-s3-zscii 63))))
