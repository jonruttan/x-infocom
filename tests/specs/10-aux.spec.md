# @weight 2

The auxiliary save and restore: from version 5, save and restore with
operands keep a table of the story's own -- table, bytes, name, prompt --
as raw bytes in a file of their own.  save stores 1 when the table is
written, else 0; restore stores how many bytes it read (the file's
length, up to bytes), 0 when there is no file.  name is a string in
memory, a length byte and its characters; prompt 0 takes it as it is.

Praxix uses neither, so each case writes into the end of its memory
(31744 bytes; past its static base, where nothing runs):

- the table at 31680, six bytes, a zero among them;
- the name `TESTAUX` at 31700: `7 84 69 83 84 65 85 88`;
- at 31600 (packed 7900) a routine of one EXT save -- `190 0`, types
  `17` (large, small, large, small), table `123 192`, bytes `6`, name
  `123 212`, prompt `0`, result to the stack `0` -- then ret_popped `184`;
- at 31616 (packed 7904) the same with restore, `190 1`.

## through the instructions

### save writes the table and restore reads it back

```infocom
(def %ax-put!
  (fn (self a bs) (if (null? bs) () (do (zm-wb! a (first bs)) (self (zm+ a 1) (rest bs))))))
(def %ax-get
  (fn (self a n) (if (zm= n 0) () (pair (zm-rb a) (self (zm+ a 1) (zm- n 1))))))
(zm-input-script! ())
(zm-start! (zm-story "praxix.z5"))
(zm-save-dir! "/tmp")
(%ax-put! 31680 (list 1 2 3 0 255 9))
(%ax-put! 31700 (list 7 84 69 83 84 65 85 88))
(%ax-put! 31600 (list 0 190 0 17 123 192 6 123 212 0 0 184))
(%ax-put! 31616 (list 0 190 1 17 123 192 6 123 212 0 0 184))
(def %ax-saved (zm-call-now 7900))
(%ax-put! 31680 (list 0 0 0 0 0 0))
(def %ax-read (zm-call-now 7904))
(write (list %ax-saved %ax-read (%ax-get 31680 6)))
```
---
    (1 6 (1 2 3 0 255 9))

## the table

### restore reads no more than bytes, and no more than the file holds

```infocom
(def %ax-put!
  (fn (self a bs) (if (null? bs) () (do (zm-wb! a (first bs)) (self (zm+ a 1) (rest bs))))))
(def %ax-get
  (fn (self a n) (if (zm= n 0) () (pair (zm-rb a) (self (zm+ a 1) (zm- n 1))))))
(zm-input-script! ())
(zm-start! (zm-story "praxix.z5"))
(zm-save-dir! "/tmp")
(%ax-put! 31680 (list 1 2 3 0 255 9))
(%ax-put! 31700 (list 7 84 69 83 84 65 85 88))
(def %ax-saved (zm-save-table 31680 6 31700 #f))
(%ax-put! 31680 (list 0 0 0 0 0 0 7 7))
(def %ax-3 (zm-restore-table 31680 3 31700 #f))
(def %ax-3-bytes (%ax-get 31680 6))
(%ax-put! 31680 (list 0 0 0 0 0 0 7 7))
(def %ax-8 (zm-restore-table 31680 8 31700 #f))
(write (list %ax-saved %ax-3 %ax-3-bytes %ax-8 (%ax-get 31680 8)))
```
---
    (1 3 (1 2 3 0 0 0) 6 (1 2 3 0 255 9 7 7))

### restore from a file that is not there stores 0 and leaves the table

```infocom
(def %ax-put!
  (fn (self a bs) (if (null? bs) () (do (zm-wb! a (first bs)) (self (zm+ a 1) (rest bs))))))
(def %ax-get
  (fn (self a n) (if (zm= n 0) () (pair (zm-rb a) (self (zm+ a 1) (zm- n 1))))))
(zm-input-script! ())
(zm-start! (zm-story "praxix.z5"))
(zm-save-dir! "/tmp/x-infocom-no-such-directory")
(%ax-put! 31680 (list 1 2 3 0 255 9))
(%ax-put! 31700 (list 7 84 69 83 84 65 85 88))
(def %ax-none (zm-restore-table 31680 6 31700 #f))
(write (list %ax-none (%ax-get 31680 6)))
```
---
    (0 (1 2 3 0 255 9))

## asking for the name

### with no name and prompt not 0, the story's name in .aux is offered

```infocom
(def %ax-put!
  (fn (self a bs) (if (null? bs) () (do (zm-wb! a (first bs)) (self (zm+ a 1) (rest bs))))))
(def %ax-get
  (fn (self a n) (if (zm= n 0) () (pair (zm-rb a) (self (zm+ a 1) (zm- n 1))))))
(zm-input-script! (list "" ""))
(zm-start! (zm-story "praxix.z5"))
(zm-save-dir! "/tmp")
(%ax-put! 31680 (list 1 2 3 0 255 9))
(def %ax-asked-save (zm-save-table 31680 6 0 #t))
(%ax-put! 31680 (list 0 0 0 0 0 0))
(def %ax-asked-read (zm-restore-table 31680 6 0 #t))
(zm-flush)
(write (list %ax-asked-save %ax-asked-read (%ax-get 31680 6)))
```
---
```output
Please enter a filename [praxix.aux]: 
Please enter a filename [praxix.aux]: 
(1 6 (1 2 3 0 255 9))
```
