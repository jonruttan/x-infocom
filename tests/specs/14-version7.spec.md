Version 7: version 5's machine with routines and strings packed from bases
the header gives, in units of 8 bytes -- the routine offset at 0x28, the
string offset at 0x2A -- and a file length counted in units of 8.  No
version 7 story is shipped, so this case writes one: 1,024 bytes whose
main routine calls a routine that prints a string, both packed against
nonzero bases.

## a story of 1,024 bytes

### routines and strings unpack from their bases

The header: version 7; high memory and the first instruction at 0x300; an
empty dictionary at 0x40; objects at 0x60, globals at 0x100, static memory
from 0x2E0, abbreviations at 0x50; the length 1,024 / 8; the checksum;
the routine base 0x20 (0x100 bytes) and the string base 0x30 (0x180).

- 0x300: call_vs routine 0x88 -> sp; quit.  0x88 * 4 + 0x100 = 0x320.
- 0x320: no locals; print_paddr 0x70; new_line; rtrue.  0x70 * 4 + 0x180
  = 0x340.
- 0x340: "seven".

Without the bases the call would land on 0x220, zeros, and the string on
0x1C0.  The story's checksum is its bytes from 0x40 on, read to the
length the header gives.

```infocom
(def %v7-size 1024)
(def %v7-s (%zm-str-make %v7-size))
(def %v7-p (%zm-str->ptr %v7-s))
(def %v7-zero (fn (self i) (if (zm< i %v7-size) (do (%zm-pset! %v7-p i 0 1) (self (zm+ i 1))))))
(%v7-zero 0)
(def %v7-put (fn (self a bs) (if (null? bs) () (do (%zm-pset! %v7-p a (first bs) 1) (self (zm+ a 1) (rest bs))))))
(def %v7-word (fn (_ a w) (%v7-put a (list (zm>> w 8) (zm& w 255)))))
(%v7-put 0 (list 7))
(%v7-word 4 768)
(%v7-word 6 768)
(%v7-word 8 64)
(%v7-word 10 96)
(%v7-word 12 256)
(%v7-word 14 736)
(%v7-word 24 80)
(%v7-word 26 (zm>> %v7-size 3))
(%v7-word 40 32)
(%v7-word 42 48)
(%v7-put 64 (list 0 9 0 0))
(%v7-put 768 (list 224 63 0 136 0 186))
(%v7-put 800 (list 0 141 0 112 187 176))
(%v7-put 832 (list 97 91 170 101))
(def %v7-sum
  (fn (self i s)
    (if (zm< i %v7-size) (self (zm+ i 1) (zm& (zm+ s (zm& (%zm-pref %v7-p i 1) 255)) 65535)) s)))
(%v7-word 28 (%v7-sum 64 0))
(def %v7-write
  (fn (_ path)
    (def fd (File open path (list (lit wronly) (lit creat) (lit trunc)) 420))
    (zm-file-write fd %v7-s %v7-size)
    (File close fd)))
(%v7-write "/tmp/x-infocom-seven.z7")
(zm-play "/tmp/x-infocom-seven.z7" ())
(write (list (%base-ref (lit zm-version)) (zm-unpack-routine 136) (zm-unpack-string 112) (zm= (zm-checksum) (zm-rw 28))))
(newline)
(%v7-put 0 (list 6))
(%v7-write "/tmp/x-infocom-six.z6")
(guard (e (display e)) (zm-start! "/tmp/x-infocom-six.z6"))
```
---
```output
seven
(7 800 832 #t)
#<err:infocom story version 6 not served (3, 4, 5, 7 and 8 are)>
```
