# @weight 2

The transcript, recording commands, and playing them back.  Output stream
2 is the transcript: the lower window's text and the commands, while the
header's flags 2 bit 0 is set -- by output_stream 2, or by a version 3
story itself, as Zork's SCRIPT does.  Output stream 4 records each
command typed; input stream 1 plays a file of commands back, echoing
each, and the keyboard takes over at its end.

## the transcript

### Zork I's SCRIPT and UNSCRIPT write what passed between them

The screen goes to /dev/null; the transcript file is what is shown.

```infocom
(def %st-null (File open "/dev/null" (lit wronly)))
(zm-output-fd! %st-null)
(zm-transcript-file! "/tmp/x-infocom-zork1.scr")
(zm-play (zm-story "zork1.z3") (list "look" "script" "open mailbox" "unscript" "north"))
(zm-output-fd! 1)
(File close %st-null)
(zm-transcript-file! ())
(display (File read-all "/tmp/x-infocom-zork1.scr"))
```
---
```output
Here begins a transcript of interaction with
ZORK I: The Great Underground Empire
Infocom interactive fiction - a fantasy story
Copyright (c) 1981, 1982, 1983, 1984, 1985, 1986 Infocom, Inc. All rights reserved.
ZORK is a registered trademark of Infocom, Inc.
Release 119 / Serial number 880429

>open mailbox
Opening the small mailbox reveals a leaflet.

>unscript
Here ends a transcript of interaction with
ZORK I: The Great Underground Empire
Infocom interactive fiction - a fantasy story
Copyright (c) 1981, 1982, 1983, 1984, 1985, 1986 Infocom, Inc. All rights reserved.
ZORK is a registered trademark of Infocom, Inc.
Release 119 / Serial number 880429
```

## recording commands

### each command typed, one a line

```infocom
(def %st-null (File open "/dev/null" (lit wronly)))
(zm-output-fd! %st-null)
(zm-record-file! "/tmp/x-infocom-zork1.rec")
(zm-input-script! (list "open mailbox" "north"))
(zm-start! (zm-story "zork1.z3"))
(zm-record-start!)
(zm-run zm-hdr-pc)
(zm-screen-end!)
(zm-output-fd! 1)
(File close %st-null)
(zm-record-file! ())
(display (File read-all "/tmp/x-infocom-zork1.rec"))
```
---
```output
open mailbox
north
```

## playing commands back

### the file's lines come first, echoed, then the source it took over from

```infocom
(def %st-fd (File open "/tmp/x-infocom-replay.rec" (list (lit wronly) (lit creat) (lit trunc)) 420))
(File write %st-fd "a\nB\n" 4)
(File close %st-fd)
(zm-input-script! (list "c"))
(zm-start! (zm-story "zork1.z3"))
(zm-echo! #f)
(def %st-ok (zm-replay-file! "/tmp/x-infocom-replay.rec"))
(def %st-1 (zm-read-line 10))
(def %st-2 (zm-read-line 10))
(def %st-3 (zm-read-line 10))
(zm-flush)
(write (list %st-ok %st-1 %st-2 %st-3))
```
---
```output
a
B
(#t (13 97) (13 98) (13 99))
```
