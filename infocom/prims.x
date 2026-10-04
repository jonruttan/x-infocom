; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/prims.x -- the platform layer, under the names the machine is
; written against
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The machine's hot path is integer arithmetic on 16-bit values and byte
; access into the story, so both go through the catalogue's raw doors: the
; INT prims (C's truncating / and %, which is what the Z-machine's div and
; mod are) and the pointer prims over a (str make) region, which carry a
; zero byte like any other.  Fetched once here; nothing hot dispatches
; through a class.

(import x/sys/file)

(provide infocom/prims
  zm+ zm- zm* zm/ zm% zm& zm| zm^ zm<< zm>> zm< zm=
  %zm-pref %zm-pset! %zm-mem-copy %zm-str->ptr %zm-str-make
  %zm-obj-make %zm-obj-ref %zm-obj-set! %zm-vector-type %zm-vec
  %zm-char->int %zm-byte-ref %zm-byte-len
  %zm-rev %zm-rev-onto %zm-length %zm-assq %zm-hex-str
  zm-file-size zm-file-read-all zm-file-write zm-file-read
  zm-sys-exit zm-sys-dup2 zm-sys-close)

(def zm+ (prim-ref (lit int) (lit +)))
(def zm- (prim-ref (lit int) (lit -)))
(def zm* (prim-ref (lit int) (lit *)))
(def zm/ (prim-ref (lit int) (lit /)))
(def zm% (prim-ref (lit int) (lit %)))
(def zm& (prim-ref (lit int) (lit &)))
(def zm| (prim-ref (lit int) (lit |)))
(def zm^ (prim-ref (lit int) (lit ^)))
(def zm<< (prim-ref (lit int) (lit <<)))
(def zm>> (prim-ref (lit int) (lit >>)))
(def zm< (prim-ref (lit int) (lit <)))
(def zm= (prim-ref (lit int) (lit =)))

; Story memory: a GC-owned (str make) region and its raw pointer.  The
; pointer prims take a byte offset and a width; a width-1 read is signed.
(def %zm-pref (prim-ref (lit ptr) (lit ref)))
(def %zm-pset! (prim-ref (lit ptr) (lit set!)))
; (mem copy DST SRC N): a block copy between pointers, memcpy itself.
(def %zm-mem-copy (prim-ref (lit mem) (lit copy)))
(def %zm-str->ptr (prim-ref (lit str) (lit ->ptr)))
(def %zm-str-make (prim-ref (lit str) (lit make)))

; Vectors through the raw slot prims: slot 0 is the length, slots 1..N the
; elements, so a vector of 15 holds locals 1..15 at their own numbers.
(def %zm-obj-make (prim-ref (lit obj) (lit make)))
(def %zm-obj-ref (prim-ref (lit obj) (lit ref)))
(def %zm-obj-set! (prim-ref (lit obj) (lit set!)))
(def %zm-vector-type ((prim-ref (lit type) (lit of)) (Vector make 0 0)))

(def %zm-char->int (prim-ref (lit char) (lit ->int)))
(def %zm-byte-ref (prim-ref (lit str) (lit byte-ref)))
(def %zm-byte-len (prim-ref (lit str) (lit byte-len)))

(def %zm-rev-onto
  (fn (self l acc)
    (if (null? l) acc (self (rest l) (pair (first l) acc)))))
(def %zm-rev (fn (_ l) (%zm-rev-onto l ())))
(def %zm-length
  (fn (_ l)
    (def go (fn (self l n) (if (null? l) n (self (rest l) (zm+ n 1)))))
    (go l 0)))
(def %zm-assq
  (fn (self k al)
    (if (null? al) ()
      (if (eq? (first (first al)) k) (first al) (self k (rest al))))))

(def zm-file-size (fn (_ path) (rest (%zm-assq (lit size) (File stat path)))))
(def zm-file-read-all (fn (_ path) (File read-all path)))
(def zm-file-write (fn (_ fd buf n) (File write fd buf n)))
(def zm-file-read (fn (_ fd buf n) (File read fd buf n)))
(def zm-sys-exit (fn (_ n) (Sys exit n)))
(def zm-sys-dup2 (fn (_ a b) (Sys dup2 a b)))
(def zm-sys-close (fn (_ fd) (Sys close fd)))

; A vector of n nil slots, made in one step.
(def %zm-vec
  (fn (_ n)
    (def v (%zm-obj-make %zm-vector-type (zm+ n 1)))
    (%zm-obj-set! v 0 n)
    v))

; A non-negative integer as hexadecimal text, for messages.
(def %zm-cvt (prim-ref (lit convert) (lit to)))
(def %zm-string-type (Type named STRING))
(def %zm-hex-str
  (fn (_ v)
    (def digit (fn (_ d) ((prim-ref (lit int) (lit ->char)) (if (zm< d 10) (zm+ d 48) (zm+ d 87)))))
    (def go (fn (self v acc) (if (zm< v 16) (pair (digit v) acc) (self (zm>> v 4) (pair (digit (zm& v 15)) acc)))))
    (%zm-cvt (go v ()) %zm-string-type)))
