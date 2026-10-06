# @weight 2

What tools/sweep.sh found, playing every story in a folder of Infocom and
Inform games against dfrotz: the stories themselves are not in this
repository (most are not free to share), so each finding is pinned here
on what is.

## print_unicode

### joins the line it is printed in, in order

A code point from print_unicode is one more character of the word being
written, wrapped with it -- not bytes sent around the word in hand.

```infocom
(zm-start! (zm-story "zork1.z3"))
(zm-out-ascii "0040 : ")
(zm-out-unicode 64)
(zm-out-unicode 65)
(zm-out-unicode 233)
(zm-out-unicode 8364)
(zm-out-zscii 13)
(zm-flush)
()
```
---
    0040 : @Aé€

### control characters print nothing

DEL and the C1 controls are not characters to show, as the C0 ones are
not; dfrotz prints none of them either.

```infocom
(zm-start! (zm-story "zork1.z3"))
(zm-out-ascii "a")
(zm-out-unicode 127)
(zm-out-unicode 128)
(zm-out-unicode 159)
(zm-out-unicode 7)
(zm-out-ascii "b")
(zm-out-zscii 13)
(zm-flush)
()
```
---
    ab

## story files

### a file whose first byte is no version is refused, not run

Three files in the folder named .z3 and .z5 were not story files at all;
the machine ran their bytes until it met an opcode that does not exist.

```infocom
(File write-all "/tmp/x-infocom-not-a-story.z5" "]this is not a story")
(guard (e (display e)) (zm-start! "/tmp/x-infocom-not-a-story.z5"))
```
---
    #<err:infocom not a Z-machine story file (version byte 5d)>
