; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/mem.x -- the story file in memory, and its header
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The whole story is one byte region; the game writes only below the static
; base, and the rest is read in place.  A second, untouched copy of the file
; serves restart (the dynamic part is copied back) and verify (the checksum
; is taken over the file as it shipped).  Every value the machine handles is
; kept as an unsigned 16-bit number, 0..65535; the few signed operations
; convert at their own seat.

(provide infocom/mem
  zm-rb zm-rw zm-wb! zm-ww! zm-signed zm-unpack zm-load! zm-reset-memory!
  zm-checksum
  zm-version zm-size zm-hdr-dict zm-hdr-objects zm-hdr-globals
  zm-hdr-static zm-hdr-abbrev zm-hdr-pc zm-hdr-high)

(def %zm-mem ())
(def %zm-ptr ())
(def %zm-orig ())
(def %zm-orig-ptr ())
(def zm-size 0)
(def zm-version 0)
(def %zm-pack-shift 1)

(def zm-hdr-high 0)
(def zm-hdr-pc 0)
(def zm-hdr-dict 0)
(def zm-hdr-objects 0)
(def zm-hdr-globals 0)
(def zm-hdr-static 0)
(def zm-hdr-abbrev 0)

(def zm-rb (fn (_ a) (zm& (%zm-pref %zm-ptr a 1) 255)))
(def zm-rw
  (fn (_ a)
    (zm| (zm<< (zm& (%zm-pref %zm-ptr a 1) 255) 8)
         (zm& (%zm-pref %zm-ptr (zm+ a 1) 1) 255))))
(def zm-wb! (fn (_ a v) (%zm-pset! %zm-ptr a (zm& v 255) 1)))
(def zm-ww!
  (fn (_ a v)
    (%zm-pset! %zm-ptr a (zm& (zm>> v 8) 255) 1)
    (%zm-pset! %zm-ptr (zm+ a 1) (zm& v 255) 1)))

(def zm-signed (fn (_ v) (if (zm< v 32768) v (zm- v 65536))))

; A packed address: routines and strings sit on 2-, 4- or 8-byte boundaries
; by version.  Versions 6 and 7, which add offsets, are not served.
(def zm-unpack (fn (_ p) (zm<< p %zm-pack-shift)))

(def %zm-orig-rb (fn (_ a) (zm& (%zm-pref %zm-orig-ptr a 1) 255)))

; Load a story: two reads of the file, so the working copy and the pristine
; one never share storage.
(def zm-load!
  (fn (_ path)
    (set! zm-size (zm-file-size path))
    (set! %zm-mem (zm-file-read-all path))
    (set! %zm-ptr (%zm-str->ptr %zm-mem))
    (set! %zm-orig (zm-file-read-all path))
    (set! %zm-orig-ptr (%zm-str->ptr %zm-orig))
    (set! zm-version (zm-rb 0))
    ; the first byte of a story is its version, 1 to 8, and the header is 64
    ; bytes; anything else is not a story file, and is refused before the
    ; header is read or written
    (if (if (zm< zm-version 1) #t (zm< 8 zm-version))
      (Err raise (lit infocom)
        (Str8 append "not a Z-machine story file (version byte " (%zm-hex-str zm-version) ")")
        zm-version))
    (if (zm< zm-size 64)
      (Err raise (lit infocom) "not a Z-machine story file (shorter than its header)" zm-size))
    (set! %zm-pack-shift
      (if (zm< zm-version 4) 1 (if (zm< zm-version 8) 2 3)))
    (set! zm-hdr-high (zm-rw 4))
    (set! zm-hdr-pc (zm-rw 6))
    (set! zm-hdr-dict (zm-rw 8))
    (set! zm-hdr-objects (zm-rw 10))
    (set! zm-hdr-globals (zm-rw 12))
    (set! zm-hdr-static (zm-rw 14))
    (set! zm-hdr-abbrev (zm-rw 24))
    (%zm-header-set!)
    zm-version))

; What the interpreter says about itself in the header, by screen.  The
; plain screen: no status line or split, no styles, an unbounded height.
; The terminal: the status line and a split (before version 4); bold,
; italic and fixed pitch (from 4); the window's own size.
(def %zm-header-set!
  (fn (_)
    (def width (if (zm< 0 %zm-width) %zm-width 80))
    (def height (if zm-ansi? %zm-rows 255))
    (if (zm< zm-version 4)
      (zm-wb! 1 (zm| (zm& (zm-rb 1) (zm^ 255 (zm| 16 (zm| 32 64))))
                     (if zm-ansi? 32 0)))
      (do
        (zm-wb! 1 (if zm-ansi? 28 0))
        (zm-wb! 32 height)
        (zm-wb! 33 width)
        (if (zm< zm-version 5) ()
          (do (zm-ww! 34 width) (zm-ww! 36 height) (zm-wb! 38 1) (zm-wb! 39 1)
            ; the default colours: "default", there being no others
            (zm-wb! 44 1) (zm-wb! 45 1)))))
    ; flags 2: undo if the game asks; no pictures, mouse, colours or sound
    (zm-wb! 17 (zm& (zm-rb 17) 23))
    (zm-wb! 30 6)
    (zm-wb! 31 73)
    (zm-wb! 50 1)
    (zm-wb! 51 1)))

; Restart and restore put the dynamic part back as it shipped, keeping the
; two header bits the game owns across them (transcripting, fixed pitch).
(def zm-reset-memory!
  (fn (_)
    (def keep (zm& (zm-rb 17) 3))
    (%zm-mem-copy %zm-ptr %zm-orig-ptr zm-hdr-static)
    (%zm-header-set!)
    (zm-wb! 17 (zm| (zm& (zm-rb 17) 252) keep))))

; The checksum verify compares: the file's bytes from 64 to its stated
; length, summed modulo 65536, taken from the pristine copy.
(def zm-checksum
  (fn (_)
    (def mult (if (zm< zm-version 4) 2 (if (zm< zm-version 6) 4 8)))
    (def len (zm* (zm-rw 26) mult))
    (def end (if (zm< zm-size len) zm-size len))
    (def go
      (fn (self a sum)
        (if (zm< a end) (self (zm+ a 1) (zm& (zm+ sum (%zm-orig-rb a)) 65535)) sum)))
    (go 64 0)))
