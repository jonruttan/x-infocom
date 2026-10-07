# @weight 2

The command line.  zm-options is one declaration: what --help prints and
what a line is parsed against.  zm-cli-plan turns a line into what to do
without doing it; the inspecting views are shown on Zork I, release 119,
and their numbers checked against the file's own bytes (the header) and
the known count of Zork I's objects (250).

## options

### --help prints the declaration

```infocom
(display (zm-usage))
```
---
```output
Usage: infocom [OPTIONS] STORY

Play a Z-machine story (versions 3, 4, 5 and 8), or describe it

Play:
	-p,--plain		Print lines, not a drawn screen
	-u,--upper		On printed lines, the status line and upper window too
	-w,--width N		Wrap printed lines at N columns (0: never)
	-s,--seed N		Seed the random numbers, for play that repeats
	-r,--restore FILE	Begin from a saved game
	-S,--save-dir DIR	Put save files in DIR
	-e,--echo		Echo each command read, as a transcript shows it
Describe, then stop:
	-i,--info		The header
	-o,--objects		The objects, attributes and properties
	-t,--tree		The object tree
	-d,--dict		The dictionary
	-a,--abbrevs		The abbreviations
	-D,--dis ADDR		Disassemble the routine at byte ADDR (hex; 0, the start)
```

### lines and their plans

```infocom
(write (zm-cli-plan (list "z.z3")))
(newline)
(write (zm-cli-plan (list "-p" "-w" "60" "-s" "7" "--restore" "a.qzl" "-S" "/tmp" "-e" "z.z3")))
(newline)
(write (zm-cli-plan (list "-i" "--tree" "-D" "0x4f05" "z.z3")))
(newline)
(write (list (zm-cli-plan ()) (zm-cli-plan (list "-z" "z")) (zm-cli-plan (list "a" "b")) (zm-cli-plan (list "-w" "x" "z")) (zm-cli-plan (list "--help")) (zm-cli-plan (list "-h"))))
```
---
```output
('play "z.z3" (('plain . #f) ('width . 80) ('seed) ('restore) ('save-dir) ('echo . #f) ('upper . #f)))
('play "z.z3" (('plain . #t) ('width . 60) ('seed . 7) ('restore . "a.qzl") ('save-dir . "/tmp") ('echo . #t) ('upper . #f)))
('describe "z.z3" ('info 'tree ('dis . 20229)))
(('refuse ()) ('refuse "unrecognized option '-z'") ('refuse "one story at a time") ('refuse "--width takes a number") ('help) ('help))
```

## describing a story

### the header, then the code from the start

```infocom
(zm-screen-plain! 0)
(zm-start! (zm-story "zork1.z3"))
(zm-info-header)
(zm-first-lines 6 (fn (_) (zm-dis-code zm-hdr-pc)))
(zm-screen-plain! 80)
()
```
---
```output
Story file version    3
Release               119
Serial number         880429
Checksum              bf44 (verifies)
File size             86838 bytes
Initial pc            50d5
Dynamic memory        0000-2c11
Static memory         2c12
High memory           4b54
Dictionary            3899
Object table          03e6
Global variables      02b0
Abbreviations         01f0
Objects               250
Dictionary words      684
Status line           score and moves
50d5: call #2afd #83a4 #ffff -> sp
50de: storew sp #00 #01
50e3: call #2afd #840f #ffff -> sp
50ec: call #2afd #8481 #ffff -> sp
50f5: storew sp #00 #01
50fa: call #2afd #732b #28 -> sp
```

### the objects, the tree, the dictionary and the abbreviations

```infocom
(zm-screen-plain! 0)
(zm-start! (zm-story "zork1.z3"))
(zm-first-lines 12 zm-info-objects)
(zm-first-lines 14 zm-info-tree)
(zm-first-lines 8 zm-info-dict)
(zm-first-lines 6 zm-info-abbrevs)
(zm-screen-plain! 80)
()
```
---
```output
  1. "forest"
    Attributes: 14
    Parent 48  Sibling 65  Child 0
    Properties at 0cee
    [18] 3e c7 49 8d 44 7e 40 09
    [17] 50 60
  2. "Temple"
    Attributes: 6 9 19
    Parent 39  Sibling 18  Child 71
    Properties at 0d00
    [31] 12
    [30] f1
[ 39] ""
. [ 31] "Slide Room"
. [  3] "Coal Mine"
. [112] "Coal Mine"
. [ 90] "Coal Mine"
. [173] "Coal Mine"
. [ 89] "Machine Room"
. . [101] "switch"
. . [207] "machine"
. [249] "Drafty Room"
. . [203] "basket"
. [  8] "Timber Room"
. . [181] "broken timber"
. [156] "Dead End"
Word separators: . , "
Entry length 7, 684 words
[   1] 38a0 $ve
[   2] 38a7 .
[   3] 38ae ,
[   4] 38b5 #comm
[   5] 38bc #rand
[   6] 38c3 #reco
[ 0] "the "
[ 1] "The "
[ 2] "You "
[ 3] ", "
[ 4] "your "
[ 5] "is "
```

## beginning from a save

### the restore -r makes, as dfrotz -L makes it

```infocom
(zm-input-script! (list "look"))
(zm-start! (zm-story "zork1.z3"))
(zm-run (zm-restore-file (Str8 append (zm-test-dir "saves") "/zork1-north.qzl")))
(zm-screen-end!)
```
---
```output
Ok.

>look
North of House
You are facing the north side of a white house. There is no door here, and all
the windows are boarded up. To the north a narrow path winds through the trees.

>
```
