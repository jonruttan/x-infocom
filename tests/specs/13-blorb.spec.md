# @weight 2

Blorb: a story is often shipped inside a Blorb file -- an IFF FORM of type
IFRS -- as its Exec 0 resource, a ZCOD chunk, beside cover art and
metadata.  The index chunk (RIdx) says where the story starts; a file
without one is searched for the chunk.  This case builds Blorbs around
Praxix (31744 bytes) and loads them; the story's own checksum, held in its
header, verifies when every byte came through.

## the story inside

### found through the index, found by searching, and refused when absent

The three files:

- FORM, IFRS; an RIdx chunk of 16 bytes holding one entry, Exec 0 at 36;
  the ZCOD chunk there.
- FORM, IFRS; an AUTH chunk of 3 bytes and its pad byte, which the search
  steps over; then the ZCOD chunk.
- FORM, IFRS; a GLUL chunk -- a Glulx game -- and no Z-code at all.

```infocom
(def %bl-story (zm-file-read-all (zm-story "praxix.z5")))
(def %bl-n (zm-file-size (zm-story "praxix.z5")))
(def %bl-id (fn (_ s) (List map (fn (_ i) (%zm-char->int (%zm-byte-ref s i))) (list 0 1 2 3))))
(def %bl-long (fn (_ n) (list (zm& (zm>> n 24) 255) (zm& (zm>> n 16) 255) (zm& (zm>> n 8) 255) (zm& n 255))))
(def %bl-write
  (fn (_ path head)
    (def hn (%zm-length head))
    (def total (zm+ hn %bl-n))
    (def s (%zm-str-make (zm+ total 1)))
    (def p (%zm-str->ptr s))
    (def put (fn (self bs i) (if (null? bs) () (do (%zm-pset! p i (first bs) 1) (self (rest bs) (zm+ i 1))))))
    (put head 0)
    (%zm-mem-copy (%zm-int->ptr (zm+ (%zm-ptr->int p) hn)) (%zm-str->ptr %bl-story) %bl-n)
    (def fd (File open path (list (lit wronly) (lit creat) (lit trunc)) 420))
    (zm-file-write fd s total)
    (File close fd)))
(%bl-write "/tmp/x-infocom-indexed.zblorb"
  (List append (%bl-id "FORM") (%bl-long (zm+ 36 %bl-n)) (%bl-id "IFRS")
               (%bl-id "RIdx") (%bl-long 16) (%bl-long 1) (%bl-id "Exec") (%bl-long 0) (%bl-long 36)
               (%bl-id "ZCOD") (%bl-long %bl-n)))
(%bl-write "/tmp/x-infocom-searched.zblorb"
  (List append (%bl-id "FORM") (%bl-long (zm+ 24 %bl-n)) (%bl-id "IFRS")
               (%bl-id "AUTH") (%bl-long 3) (list 74 111 110 0)
               (%bl-id "ZCOD") (%bl-long %bl-n)))
(%bl-write "/tmp/x-infocom-glulx.gblorb"
  (List append (%bl-id "FORM") (%bl-long (zm+ 12 %bl-n)) (%bl-id "IFRS")
               (%bl-id "GLUL") (%bl-long %bl-n)))
(zm-start! "/tmp/x-infocom-indexed.zblorb")
(def %bl-1 (list zm-version zm-size (zm= (zm-checksum) (zm-rw 28))))
(zm-start! "/tmp/x-infocom-searched.zblorb")
(def %bl-2 (list zm-version zm-size (zm= (zm-checksum) (zm-rw 28))))
(write (list %bl-1 %bl-2))
(newline)
(guard (e (display e)) (zm-start! "/tmp/x-infocom-glulx.gblorb"))
```
---
```output
((5 31744 #t) (5 31744 #t))
#<err:infocom a Blorb file with no Z-code in it (a Glulx game's?)>
```
