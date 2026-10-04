# @weight 2

The terminal screen, drawn with ANSI sequences: a scroll region under the
fixed rows, the status line written by position in reverse video before
each read, the cursor saved and put back around it.  zm-screen-ansi!'s
third argument writes ESC as ^[ so the sequences read here as text.  The
expectations were read through by hand, sequence by sequence; the plain
screen's specs are the ones compared with dfrotz.

## the status line

### Zork I at 60 columns, 24 rows

```infocom
(zm-screen-ansi! 60 24 #t)
(zm-play (zm-story "zork1.z3") (list "open mailbox"))
(zm-screen-plain! 80)
()
```
---
```output
^[[2J^[[2;1H^[7^[[2;24r^[8^[[2;1HZORK I: The Great Underground Empire
Infocom interactive fiction - a fantasy story
Copyright (c) 1981, 1982, 1983, 1984, 1985, 1986 Infocom,
Inc. All rights reserved.
ZORK is a registered trademark of Infocom, Inc.
Release 119 / Serial number 880429

West of House
You are standing in an open field west of a white house,
with a boarded front door.
There is a small mailbox here.

>^[7^[[1;1H^[[7m West of House                           Score: 0  Moves: 0 ^[[0m^[8open mailbox
Opening the small mailbox reveals a leaflet.

>^[7^[[1;1H^[[7m West of House                           Score: 0  Moves: 1 ^[[0m^[8^[[0m^[[r^[[24;1H
```

### its text at the first prompt: the room on the left, score and moves right

```infocom
(zm-play-grep "zork1.z3" () ())
(write (List map (fn (_ c) ((prim-ref (lit int) (lit ->char)) c)) (zm-status-codes 40)))
```
---
    (#\space #\W #\e #\s #\t #\space #\o #\f #\space #\H #\o #\u #\s #\e #\space #\space #\space #\space #\space #\space #\space #\S #\c #\o #\r #\e #\: #\space #\0 #\space #\space #\M #\o #\v #\e #\s #\: #\space #\0 #\space)
