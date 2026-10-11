# @weight 2

The debugger (`-g`): the story stops before an instruction and the (zdb)
prompt takes a command.  Commands are read as the story's own lines are,
so one script carries both -- here, the debugger's commands, then the
story's when it runs on to a read.  Each stop shows the next instruction
as the disassembler does.

## stepping and looking

### step, then the locals, the stack, the frames, a global and memory

```infocom
(zm-input-script! (list "s" "s 2" "l" "sp" "bt" "g 0" "x 0 8" "o 1" "pc" "help" "q"))
(zm-start! (zm-story "zork1.z3"))
(zm-debug zm-hdr-pc)
```
---
```output
50d5: call #2afd #83a4 #ffff -> sp
(zdb) s
5601: call #2b07 l01 -> l03
(zdb) s 2
5619: add g1f #b4 -> l03
561d: add g1f g42 -> l04
(zdb) l
  l01 83a4
  l02 0000
  l03 2462
  l04 0000
  l05 0000
(zdb) sp
  empty
(zdb) bt
  561d
  5607
  50de
(zdb) g 0
  g00 0000
(zdb) x 0 8
0000: 03 00 00 77 4b 54 50 d5
(zdb) o 1
  1. "forest"
    Attributes: 14
    Parent 48  Sibling 65  Child 0
    Properties at 0cee
    [18] 3e c7 49 8d 44 7e 40 09
    [17] 50 60
(zdb) pc
561d: add g1f g42 -> l04
(zdb) help
  ? s n fin c b d bt l sp g x o pc q
(zdb) q
```

## running

### n steps over a call; c stops at a breakpoint; d deletes it

```infocom
(zm-input-script! (list "n" "b 50f5" "b 50ec" "b" "c" "bt" "c" "d 50ec" "d 50f5" "b" "q"))
(zm-start! (zm-story "zork1.z3"))
(zm-debug zm-hdr-pc)
```
---
```output
50d5: call #2afd #83a4 #ffff -> sp
(zdb) n
50de: storew sp #00 #01
(zdb) b 50f5
(zdb) b 50ec
(zdb) b
  50f5
  50ec
(zdb) c
50ec: call #2afd #8481 #ffff -> sp
(zdb) bt
  50ec
(zdb) c
50f5: storew sp #00 #01
(zdb) d 50ec
(zdb) d 50f5
(zdb) b
  no breakpoints
(zdb) q
```

### c runs the story on, reading its own lines, until it ends

```infocom
(zm-input-script! (list "c" "quit" "y"))
(zm-start! (zm-story "zork1.z3"))
(zm-debug zm-hdr-pc)
```
---
```output
50d5: call #2afd #83a4 #ffff -> sp
(zdb) c
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

>quit
Your score is 0 (total of 350 points), in 0 moves.
This gives you the rank of Beginner.
Do you wish to leave the game? (Y is affirmative): >y
the story has ended
```
