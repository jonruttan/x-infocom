# @weight 2

Timed input: from version 4, read and read_char take a time in tenths of
a second and a routine; each time that long passes with nothing typed the
routine is called, and when it returns true the read stops.  A script
says that time passes with the symbol `tick` among its lines; a pipe has
no time between its lines; a terminal waits at the prompt.

None of the stories here use a timer, so these cases write small routines
into the end of Zork I's memory and hand their packed addresses over
(Zork I is version 3: a packed address is the byte address halved).  A
routine is its count of locals (0), then its code:

- at 86820 (packed 43410): print_char '*', rfalse -- `0 229 127 42 177`
- at 86826 (packed 43413): print_char '!', rtrue -- `0 229 127 33 176`
- at 86832 (packed 43416): rtrue -- `0 176`

## calling a routine in the middle of an instruction

### answers what the routine returns, with the frames as they were

```infocom
(def %tm-put!
  (fn (self a bs) (if (null? bs) () (do (zm-wb! a (first bs)) (self (zm+ a 1) (rest bs))))))
(zm-input-script! ())
(zm-start! (zm-story "zork1.z3"))
(%tm-put! 86820 (list 0 229 127 42 177))
(%tm-put! 86826 (list 0 229 127 33 176))
(%tm-put! 86832 (list 0 176))
(def %tm-depth (zm-frame-id))
(def %tm-r (list (zm-call-now 43410) (zm-call-now 43416) (zm-call-now 0) (zm= %tm-depth (zm-frame-id))))
(zm-out-zscii 13)
(zm-flush)
(write %tm-r)
```
---
```output
*
(0 1 0 #t)
```

## a timed line

### each tick calls the routine, until a line comes

```infocom
(zm-input-script! (list (lit tick) (lit tick) "Look"))
(def %tm-line (zm-read-line 10 (pair 10 43410)))
(zm-flush)
(write (rest %tm-line))
```
---
```output
**Look
(108 111 111 107)
```

### a routine returning true stops the read, and the line waits for the next

```infocom
(zm-input-script! (list (lit tick) "look"))
(def %tm-stop (zm-read-line 10 (pair 10 43413)))
(zm-out-zscii 13)
(def %tm-next (zm-read-line 10))
(zm-flush)
(write (list (eq? %tm-stop %zm-stopped) (rest %tm-next)))
```
---
```output
!
look
(#t (108 111 111 107))
```

### without a timer, ticks pass unseen

```infocom
(zm-input-script! (list (lit tick) "look"))
(def %tm-plain (zm-read-line 10))
(zm-flush)
(write (rest %tm-plain))
```
---
```output
look
(108 111 111 107)
```

## a timed read_char

### a tick calls the routine; true answers 0, and the key waits

```infocom
(zm-input-script! (list (lit tick) "a" (lit tick) "b"))
(def %tm-k1 (zm-read-char (pair 5 43410)))
(def %tm-k2 (zm-read-char (pair 5 43410)))
(def %tm-k3 (zm-read-char (pair 5 43413)))
(def %tm-k4 (zm-read-char (pair 5 43413)))
(zm-out-zscii 13)
(zm-flush)
(write (list %tm-k1 %tm-k2 %tm-k3 %tm-k4))
```
---
```output
*!
(97 13 0 98)
```
