; # x-infocom -- a Z-machine on x-lang
;
; ## infocom/obj.x -- the object tree, attributes and properties
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Before version 4 an object is 9 bytes (32 attributes, byte-sized parent,
; sibling and child, a property pointer) behind 31 default property words;
; from version 4 it is 14 bytes (48 attributes, word-sized links) behind 63.
; Object 0 is "nothing": reading its links answers 0, and the operations
; that would move or mark it do nothing.

(provide infocom/obj
  zm-obj-parent zm-obj-sibling zm-obj-child
  zm-attr? zm-attr-set! zm-attr-clear!
  zm-obj-insert! zm-obj-remove! zm-obj-name
  zm-prop zm-prop-addr zm-prop-len zm-prop-next zm-prop-put!)

(def %zm-small? (fn (_) (zm< zm-version 4)))

(def %zm-obj-addr
  (fn (_ o)
    (if (zm< zm-version 4)
      (zm+ (zm+ zm-hdr-objects 53) (zm* o 9))
      (zm+ (zm+ zm-hdr-objects 112) (zm* o 14)))))

; link k: 0 parent, 1 sibling, 2 child
(def %zm-link
  (fn (_ o k)
    (if (zm= o 0) 0
      (if (zm< zm-version 4)
        (zm-rb (zm+ (zm+ (%zm-obj-addr o) 4) k))
        (zm-rw (zm+ (zm+ (%zm-obj-addr o) 6) (zm<< k 1)))))))

(def %zm-link-set!
  (fn (_ o k v)
    (if (zm= o 0) ()
      (if (zm< zm-version 4)
        (zm-wb! (zm+ (zm+ (%zm-obj-addr o) 4) k) v)
        (zm-ww! (zm+ (zm+ (%zm-obj-addr o) 6) (zm<< k 1)) v)))))

(def zm-obj-parent (fn (_ o) (%zm-link o 0)))
(def zm-obj-sibling (fn (_ o) (%zm-link o 1)))
(def zm-obj-child (fn (_ o) (%zm-link o 2)))

(def %zm-props
  (fn (_ o)
    (zm-rw (zm+ (%zm-obj-addr o) (if (zm< zm-version 4) 7 12)))))

; Attribute a lives in byte a/8, bit 7 - a%8.
(def zm-attr?
  (fn (_ o a)
    (if (zm= o 0) #f
      (not (zm= 0 (zm& (zm-rb (zm+ (%zm-obj-addr o) (zm>> a 3)))
                       (zm>> 128 (zm& a 7))))))))

(def zm-attr-set!
  (fn (_ o a)
    (if (zm= o 0) ()
      (do
        (def b (zm+ (%zm-obj-addr o) (zm>> a 3)))
        (zm-wb! b (zm| (zm-rb b) (zm>> 128 (zm& a 7))))))))

(def zm-attr-clear!
  (fn (_ o a)
    (if (zm= o 0) ()
      (do
        (def b (zm+ (%zm-obj-addr o) (zm>> a 3)))
        (zm-wb! b (zm& (zm-rb b) (zm^ 255 (zm>> 128 (zm& a 7)))))))))

; Detach o from its parent's child chain.
(def zm-obj-remove!
  (fn (_ o)
    (def p (zm-obj-parent o))
    (if (zm= p 0) ()
      (do
        (if (zm= (zm-obj-child p) o)
          (%zm-link-set! p 2 (zm-obj-sibling o))
          (do
            (def walk
              (fn (self s)
                (def nx (zm-obj-sibling s))
                (if (zm= nx 0) ()
                  (if (zm= nx o)
                    (%zm-link-set! s 1 (zm-obj-sibling o))
                    (self nx)))))
            (walk (zm-obj-child p))))
        (%zm-link-set! o 0 0)
        (%zm-link-set! o 1 0)))))

; Make o the first child of d.
(def zm-obj-insert!
  (fn (_ o d)
    (if (zm= o 0) ()
      (do
        (zm-obj-remove! o)
        (%zm-link-set! o 0 d)
        (%zm-link-set! o 1 (zm-obj-child d))
        (%zm-link-set! d 2 o)))))

; The short name: a Z-string after the property table's length byte.
(def zm-obj-name
  (fn (_ o)
    (def t (%zm-props o))
    (if (zm= (zm-rb t) 0) () (zm-zstring (zm+ t 1)))))

; The first property entry: past the name.
(def %zm-prop-first
  (fn (_ o)
    (def t (%zm-props o))
    (zm+ (zm+ t 1) (zm<< (zm-rb t) 1))))

; An entry's (number size header-length), or () at the list's end.
(def %zm-prop-head
  (fn (_ e)
    (def b (zm-rb e))
    (if (zm= b 0) ()
      (if (zm< zm-version 4)
        (list (zm& b 31) (zm+ (zm>> b 5) 1) 1)
        (if (zm= (zm& b 128) 0)
          (list (zm& b 63) (if (zm= (zm& b 64) 0) 1 2) 1)
          (do
            (def s (zm& (zm-rb (zm+ e 1)) 63))
            (list (zm& b 63) (if (zm= s 0) 64 s) 2)))))))

; The entry for property p of o, as (data-address size), or ().
(def %zm-prop-find
  (fn (_ o p)
    (def go
      (fn (self e)
        (def h (%zm-prop-head e))
        (if (null? h) ()
          (do
            (def n (first h))
            (def size (first (rest h)))
            (def data (zm+ e (first (rest (rest h)))))
            (if (zm= n p) (list data size)
              (if (zm< n p) () (self (zm+ data size))))))))
    (go (%zm-prop-first o))))

(def zm-prop
  (fn (_ o p)
    (def hit (%zm-prop-find o p))
    (if (null? hit)
      (zm-rw (zm+ zm-hdr-objects (zm<< (zm- p 1) 1)))
      (if (zm= (first (rest hit)) 1)
        (zm-rb (first hit))
        (zm-rw (first hit))))))

(def zm-prop-addr
  (fn (_ o p)
    (def hit (%zm-prop-find o p))
    (if (null? hit) 0 (first hit))))

; The size of the property whose data starts at a (0 for address 0).
(def zm-prop-len
  (fn (_ a)
    (if (zm= a 0) 0
      (do
        (def b (zm-rb (zm- a 1)))
        (if (zm< zm-version 4)
          (zm+ (zm>> b 5) 1)
          (if (zm= (zm& b 128) 0)
            (if (zm= (zm& b 64) 0) 1 2)
            (if (zm= (zm& b 63) 0) 64 (zm& b 63))))))))

; The property after p (p 0: the first), 0 after the last.
(def zm-prop-next
  (fn (_ o p)
    (if (zm= p 0)
      (do
        (def h (%zm-prop-head (%zm-prop-first o)))
        (if (null? h) 0 (first h)))
      (do
        (def hit (%zm-prop-find o p))
        (if (null? hit)
          (Err raise (lit infocom) "get_next_prop: no such property" p)
          (do
            (def h (%zm-prop-head (zm+ (first hit) (first (rest hit)))))
            (if (null? h) 0 (first h))))))))

(def zm-prop-put!
  (fn (_ o p v)
    (def hit (%zm-prop-find o p))
    (if (null? hit)
      (Err raise (lit infocom) "put_prop: no such property" p)
      (if (zm= (first (rest hit)) 1)
        (zm-wb! (first hit) v)
        (zm-ww! (first hit) v)))))
