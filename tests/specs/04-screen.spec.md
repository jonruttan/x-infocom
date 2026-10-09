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
^[[0m^[[2J^[[2;1H^[7^[[2;24r^[8^[[2;1HZORK I: The Great Underground Empire
Infocom interactive fiction - a fantasy story
Copyright (c) 1981, 1982, 1983, 1984, 1985, 1986 Infocom,
Inc. All rights reserved.
ZORK is a registered trademark of Infocom, Inc.
Release 119 / Serial number 880429

West of House
You are standing in an open field west of a white house,
with a boarded front door.
There is a small mailbox here.

>^[7^[[1;1H^[[0;7m West of House                           Score: 0  Moves: 0 ^[[0m^[8open mailbox
Opening the small mailbox reveals a leaflet.

>^[7^[[1;1H^[[0;7m West of House                           Score: 0  Moves: 1 ^[[0m^[8^[[0m^[[r^[[24;1H
```

### its text at the first prompt: the room on the left, score and moves right

```infocom
(zm-play-grep "zork1.z3" () ())
(write (List map (fn (_ c) ((prim-ref (lit int) (lit ->char)) c)) (zm-status-codes 40)))
```
---
    (#\space #\W #\e #\s #\t #\space #\o #\f #\space #\H #\o #\u #\s #\e #\space #\space #\space #\space #\space #\space #\space #\S #\c #\o #\r #\e #\: #\space #\0 #\space #\space #\M #\o #\v #\e #\s #\: #\space #\0 #\space)

## the plain screen's fixed rows

With zm-plain-upper! on (the command line's --upper), the plain screen
prints the status line and the upper window as lines: each before the read
it came with, ahead of the prompt, and only once changed.

### Zork I's status line, before each prompt, as moves are made

```infocom
(zm-plain-upper! #t)
(zm-play (zm-story "zork1.z3") (list "open mailbox" "north"))
(zm-plain-upper! #f)
()
```
---
```output
ZORK I: The Great Underground Empire
Infocom interactive fiction - a fantasy story
Copyright (c) 1981, 1982, 1983, 1984, 1985, 1986 Infocom, Inc. All rights
reserved.
ZORK is a registered trademark of Infocom, Inc.
Release 119 / Serial number 880429

West of House
You are standing in an open field west of a white house, with a boarded front
door.
There is a small mailbox here.

 West of House                                               Score: 0  Moves: 0
>open mailbox
Opening the small mailbox reveals a leaflet.

 West of House                                               Score: 0  Moves: 1
>north
North of House
You are facing the north side of a white house. There is no door here, and all
the windows are boarded up. To the north a narrow path winds through the trees.

 North of House                                              Score: 0  Moves: 2
>
```

### upper-window rows, printed when the lower window takes over, changed rows only

The upper window is kept as rows, as a terminal holds it; going back to the
lower window prints the rows that changed and are not blank, so the second
time only the score row prints.

```infocom
(zm-plain-upper! #t)
(zm-input-script! ())
(zm-start! (zm-story "praxix.z5"))
(zm-out-ascii "lower one")
(zm-out-zscii 13)
(zm-split! 2)
(zm-set-window! 1)
(zm-set-cursor! 1 30)
(zm-out-ascii "* PART I *")
(zm-set-cursor! 2 1)
(zm-out-ascii "Score: 5")
(zm-set-window! 0)
(zm-out-ascii "lower two")
(zm-out-zscii 13)
(zm-set-window! 1)
(zm-set-cursor! 2 1)
(zm-out-ascii "Score: 6")
(zm-set-window! 0)
(zm-out-ascii ">")
(zm-before-read!)
(zm-flush)
(zm-plain-upper! #f)
()
```
---
```output
lower one
                             * PART I *
Score: 5
lower two
Score: 6
>
```

## the row a line editor redraws

### is the lower window's row in progress, as it was printed

At a terminal a command is read through x-lang's line editor, whose
redraw starts the row over: the row the story printed -- its prompt -- is
what it draws ahead of the command.  A newline or a wrap starts the row
again; spaces between words are part of it.

```infocom
(zm-screen-plain! 20)
(zm-start! (zm-story "zork1.z3"))
(zm-out-ascii "West of House")
(zm-out-zscii 13)
(zm-out-ascii "You are standing in an open field. ")
(zm-out-unicode 233)
(zm-out-ascii " >")
(zm-flush)
(def %rs-row (zm-row-str))
(zm-out-zscii 13)
(zm-flush)
(write %rs-row)
(zm-screen-plain! 80)
()
```
---
```output
West of House
You are standing in
an open field. é >
"an open field. é >"
```

## styles and colours

The look is one SGR sequence -- reset, the style, the foreground, the
background -- sent whole on every change, so a style of 0 keeps the
colours.  set_colour's 2 to 9 are ANSI's 30-37 and 40-47, 1 the
terminal's own, 0 no change; set_true_colour sends 24-bit colour from
fifteen bits, -1 (65535) the terminal's own and -2 (65534) no change.

### styles add to each other, and set_colour builds on them

```infocom
(zm-screen-ansi! 80 24 #t)
(zm-input-script! ())
(zm-start! (zm-story "praxix.z5"))
(zm-flush)
(zm-out-zscii 13)
(zm-set-colour! 4 1)
(zm-out-ascii "green ")
(zm-text-style! 2)
(zm-out-ascii "bold ")
(zm-text-style! 4)
(zm-out-ascii "italic too ")
(zm-set-colour! 0 7)
(zm-out-ascii "on magenta ")
(zm-text-style! 0)
(zm-out-ascii "roman ")
(zm-set-colour! 1 1)
(zm-out-ascii "own")
(zm-out-zscii 13)
(zm-flush)
(zm-screen-plain! 80)
()
```
---
```output
^[[0m^[[2J^[[1;1H^[7^[[1;24r^[8^[[1;1H
^[[0;32mgreen ^[[0;1;32mbold ^[[0;1;3;32mitalic too ^[[0;1;3;32;45mon magenta ^[[0;32;45mroman ^[[0mown
```

### set_true_colour: fifteen bits as 24-bit colour, -2 keeps, -1 resets

```infocom
(zm-screen-ansi! 80 24 #t)
(zm-input-script! ())
(zm-start! (zm-story "praxix.z5"))
(zm-flush)
(zm-out-zscii 13)
(zm-set-true-colour! 31 32767)
(zm-out-ascii "red on white ")
(zm-set-true-colour! 65534 992)
(zm-out-ascii "on green ")
(zm-set-true-colour! 65535 65535)
(zm-out-ascii "own")
(zm-out-zscii 13)
(zm-flush)
(zm-screen-plain! 80)
()
```
---
```output
^[[0m^[[2J^[[1;1H^[7^[[1;24r^[8^[[1;1H
^[[0;38;2;255;0;0;48;2;255;255;255mred on white ^[[0;38;2;255;0;0;48;2;0;255;0mon green ^[[0mown
```

### the header claims colours on a terminal from version 5, not on the plain screen through a pipe

```infocom
(zm-screen-ansi! 80 24 #t)
(zm-start! (zm-story "praxix.z5"))
(def %co-ansi (zm& (zm-rb 1) 1))
(zm-flush)
(zm-screen-plain! 80)
(zm-start! (zm-story "praxix.z5"))
(def %co-plain (zm& (zm-rb 1) 1))
(zm-flush)
(write (list %co-ansi %co-plain))
```
---
```output
^[[0m^[[2J^[[1;1H^[7^[[1;24r^[8^[[1;1H(1 0)
```
