; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/info.x -- what a story file holds, in the spirit of infodump
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Four views of a loaded story, each printed through the machine's own
; output: the header (zm-info-header), the objects with their attributes
; and properties (zm-info-objects), the object tree (zm-info-tree), the
; dictionary (zm-info-dict) and the abbreviations (zm-info-abbrevs).
; Addresses and data bytes are hexadecimal, counts decimal.

(provide infocom/info
  zm-info-header zm-info-objects zm-info-tree zm-info-dict zm-info-abbrevs
  zm-object-count)

(def %zm-say (fn (_ s) (zm-out-ascii s)))
(def %zm-nl (fn (_) (zm-out-zscii 13)))
(def %zm-hex4 (fn (_ v) (zm-out-codes (%zm-hex v 4))))
(def %zm-hex2 (fn (_ v) (zm-out-codes (%zm-hex v 2))))
(def %zm-dec (fn (_ v) (zm-out-num v)))

; Right-aligned in n columns.
(def %zm-dec-pad
  (fn (_ v n)
    (def len (fn (self v k) (if (zm< v 10) k (self (zm/ v 10) (zm+ k 1)))))
    (def pad (fn (self k) (if (zm< k n) (do (zm-out-zscii 32) (self (zm+ k 1))))))
    (pad (len v 1))
    (zm-out-num v)))

(def %zm-row
  (fn (_ label)
    (%zm-say label)
    (def pad (fn (self k) (if (zm< k 22) (do (zm-out-zscii 32) (self (zm+ k 1))))))
    (pad (%zm-byte-len label))))

; --- the header --------------------------------------------------------------

(def zm-info-header
  (fn (_)
    (%zm-row "Story file version") (%zm-dec zm-version) (%zm-nl)
    (%zm-row "Release") (%zm-dec (zm-rw 2)) (%zm-nl)
    (%zm-row "Serial number")
    (def serial (fn (self i) (if (zm< i 6) (do (zm-out-zscii (zm-rb (zm+ 18 i))) (self (zm+ i 1))))))
    (serial 0) (%zm-nl)
    (%zm-row "Checksum") (%zm-hex4 (zm-rw 28))
    (%zm-say (if (zm= (zm-checksum) (zm-rw 28)) " (verifies)" " (does not verify)")) (%zm-nl)
    (%zm-row "File size") (%zm-dec-wide zm-size) (%zm-say " bytes") (%zm-nl)
    (%zm-row "Initial pc") (%zm-hex4 zm-hdr-pc) (%zm-nl)
    (%zm-row "Dynamic memory") (%zm-say "0000-") (%zm-hex4 (zm- zm-hdr-static 1)) (%zm-nl)
    (%zm-row "Static memory") (%zm-hex4 zm-hdr-static) (%zm-nl)
    (%zm-row "High memory") (%zm-hex4 zm-hdr-high) (%zm-nl)
    (%zm-row "Dictionary") (%zm-hex4 zm-hdr-dict) (%zm-nl)
    (%zm-row "Object table") (%zm-hex4 zm-hdr-objects) (%zm-nl)
    (%zm-row "Global variables") (%zm-hex4 zm-hdr-globals) (%zm-nl)
    (%zm-row "Abbreviations") (%zm-hex4 zm-hdr-abbrev) (%zm-nl)
    (%zm-row "Objects") (%zm-dec (zm-object-count)) (%zm-nl)
    (%zm-row "Dictionary words") (%zm-dec (%zm-dict-count)) (%zm-nl)
    (if (zm< zm-version 4)
      (do (%zm-row "Status line")
          (%zm-say (if (zm= (zm& (zm-rb 1) 2) 0) "score and moves" "time")) (%zm-nl)))
    (zm-flush)))

; --- objects -----------------------------------------------------------------

; How many objects: the table ends where the lowest property table begins.
(def zm-object-count
  (fn (_)
    (def size (if (zm< zm-version 4) 9 14))
    (def first-obj (zm+ zm-hdr-objects (if (zm< zm-version 4) 62 126)))
    (def go
      (fn (self o lowest)
        (def a (zm+ first-obj (zm* (zm- o 1) size)))
        (if (zm< a lowest)
          (do
            (def p (%zm-props o))
            (self (zm+ o 1) (if (zm< p lowest) p lowest)))
          (zm- o 1))))
    (go 1 65535)))

(def %zm-name-q
  (fn (_ o)
    (zm-out-zscii 34) (zm-out-codes (zm-obj-name o)) (zm-out-zscii 34)))

(def %zm-attrs
  (fn (_ o)
    (def n (if (zm< zm-version 4) 32 48))
    (def go
      (fn (self a any)
        (if (zm< a n)
          (if (zm-attr? o a)
            (do (if any (zm-out-zscii 32)) (%zm-dec a) (self (zm+ a 1) #t))
            (self (zm+ a 1) any))
          any)))
    (if (go 0 #f) () (%zm-say "none"))))

(def %zm-props-list
  (fn (_ o)
    (def go
      (fn (self e)
        (def h (%zm-prop-head e))
        (if (null? h) ()
          (do
            (def size (first (rest h)))
            (def data (zm+ e (first (rest (rest h)))))
            (%zm-say "    [") (%zm-dec-pad (first h) 2) (%zm-say "] ")
            (def bytes
              (fn (self i)
                (if (zm< i size)
                  (do (%zm-hex2 (zm-rb (zm+ data i))) (zm-out-zscii 32) (self (zm+ i 1))))))
            (bytes 0)
            (%zm-nl)
            (self (zm+ data size))))))
    (go (%zm-prop-first o))))

(def zm-info-objects
  (fn (_)
    (def n (zm-object-count))
    (def go
      (fn (self o)
        (if (zm< n o) ()
          (do
            (%zm-dec-pad o 3) (%zm-say ". ") (%zm-name-q o) (%zm-nl)
            (%zm-say "    Attributes: ") (%zm-attrs o) (%zm-nl)
            (%zm-say "    Parent ") (%zm-dec (zm-obj-parent o))
            (%zm-say "  Sibling ") (%zm-dec (zm-obj-sibling o))
            (%zm-say "  Child ") (%zm-dec (zm-obj-child o)) (%zm-nl)
            (%zm-say "    Properties at ") (%zm-hex4 (%zm-props o)) (%zm-nl)
            (%zm-props-list o)
            (self (zm+ o 1))))))
    (go 1)
    (zm-flush)))

; The tree: every object without a parent, its children beneath it.
(def zm-info-tree
  (fn (_)
    (def n (zm-object-count))
    (def dots (fn (self d) (if (zm< 0 d) (do (%zm-say ". ") (self (zm- d 1))))))
    (def show
      (fn (self o depth)
        (if (zm= o 0) ()
          (do
            (dots depth)
            (%zm-say "[") (%zm-dec-pad o 3) (%zm-say "] ") (%zm-name-q o) (%zm-nl)
            (self (zm-obj-child o) (zm+ depth 1))
            (self (zm-obj-sibling o) depth)))))
    (def roots
      (fn (self o)
        (if (zm< n o) ()
          (do
            (if (zm= (zm-obj-parent o) 0)
              (do
                (dots 0)
                (%zm-say "[") (%zm-dec-pad o 3) (%zm-say "] ") (%zm-name-q o) (%zm-nl)
                (show (zm-obj-child o) 1)))
            (self (zm+ o 1))))))
    (roots 1)
    (zm-flush)))

; --- the dictionary and abbreviations ---------------------------------------

(def %zm-dict-count
  (fn (_)
    (def n (zm-rb zm-hdr-dict))
    (def c (zm-signed (zm-rw (zm+ (zm+ zm-hdr-dict 2) n))))
    (if (zm< c 0) (zm- 0 c) c)))

(def zm-info-dict
  (fn (_)
    (def d zm-hdr-dict)
    (def n (zm-rb d))
    (%zm-say "Word separators: ")
    (def seps (fn (self i) (if (zm< i n) (do (zm-out-zscii (zm-rb (zm+ (zm+ d 1) i))) (zm-out-zscii 32) (self (zm+ i 1))))))
    (seps 0) (%zm-nl)
    (def elen (zm-rb (zm+ (zm+ d 1) n)))
    (def count (%zm-dict-count))
    (def start (zm+ (zm+ d 4) n))
    (%zm-say "Entry length ") (%zm-dec elen) (%zm-say ", ") (%zm-dec count) (%zm-say " words") (%zm-nl)
    (def go
      (fn (self i)
        (if (zm< i count)
          (do
            (def e (zm+ start (zm* i elen)))
            (%zm-say "[") (%zm-dec-pad (zm+ i 1) 4) (%zm-say "] ") (%zm-hex4 e) (%zm-say " ")
            (zm-out-codes (first (zm-zstring-at e))) (%zm-nl)
            (self (zm+ i 1))))))
    (go 0)
    (zm-flush)))

(def zm-info-abbrevs
  (fn (_)
    (def go
      (fn (self i)
        (if (zm< i 96)
          (do
            (%zm-say "[") (%zm-dec-pad i 2) (%zm-say "] ")
            (zm-out-zscii 34) (zm-out-codes (%zm-abbrev i)) (zm-out-zscii 34) (%zm-nl)
            (self (zm+ i 1))))))
    (go 0)
    (zm-flush)))

; Any non-negative integer in decimal, not only a 16-bit value.
(def %zm-dec-wide
  (fn (_ v)
    (def go (fn (self n acc) (if (zm< n 10) (pair (zm+ n 48) acc) (self (zm/ n 10) (pair (zm+ (zm% n 10) 48) acc)))))
    (zm-out-codes (go v ()))))
