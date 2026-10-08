# @weight 2

Terminating characters: from version 5, a read can end on a key other than
Return -- an arrow, a function key, a keypad key -- when the story names
it in the zero-ended table at the header's word 0x2E (255 there standing
for every function key).  The read keeps what was typed, and aread stores
the key as its terminator.

A script line that ends with a key instead of Return is a pair, (text .
key), the key by its ZSCII: 129-132 the arrows, 133-144 F1 to F12, 145-154
the keypad.  Praxix names no keys, so these cases write a table into the
end of its memory and point the header at it.

## the table

### with no table, a key ends nothing: the typing stays and the line goes on

```infocom
(zm-input-script! (list (pair "north" 129) "east"))
(zm-start! (zm-story "praxix.z5"))
(def %tc-line (zm-read-line 20))
(zm-flush)
(write %tc-line)
```
---
```output
northeast
(13 110 111 114 116 104 101 97 115 116)
```

### a key the table names ends the read, keeping what was typed

```infocom
(zm-input-script! (list (pair "north" 129) (pair "up" 133) "!"))
(zm-start! (zm-story "praxix.z5"))
(def %tc-at (zm- zm-size 8))
(zm-wb! %tc-at 129)
(zm-wb! (zm+ %tc-at 1) 0)
(zm-ww! 46 %tc-at)
(def %tc-1 (zm-read-line 20))
(def %tc-2 (zm-read-line 20))
(zm-flush)
(write (list %tc-1 %tc-2))
```
---
```output
north
up!
((129 110 111 114 116 104) (13 117 112 33))
```

### 255 in the table stands for every function key

```infocom
(zm-input-script! (list (pair "go" 140) (pair "" 254)))
(zm-start! (zm-story "praxix.z5"))
(def %tc-at (zm- zm-size 8))
(zm-wb! %tc-at 255)
(zm-wb! (zm+ %tc-at 1) 0)
(zm-ww! 46 %tc-at)
(def %tc-1 (zm-read-line 20))
(def %tc-2 (zm-read-line 20))
(zm-flush)
(write (list %tc-1 %tc-2))
```
---
```output
go

((140 103 111) (254))
```

## aread

### stores the key as its terminator, and the text as typed

```infocom
(zm-input-script! (list (pair "Look" 131)))
(zm-start! (zm-story "praxix.z5"))
(def %tc-at (zm- zm-size 8))
(zm-wb! %tc-at 255)
(zm-wb! (zm+ %tc-at 1) 0)
(zm-ww! 46 %tc-at)
(def %tc-buf (zm- zm-size 40))
(zm-wb! %tc-buf 20)
(def %tc-term (zm-aread %tc-buf 0 (pair 0 0)))
(zm-flush)
(write (list %tc-term (zm-rb (zm+ %tc-buf 1)) (zm-rb (zm+ %tc-buf 2)) (zm-rb (zm+ %tc-buf 5))))
```
---
```output
Look
(131 4 108 107)
```

## read_char

### a line ended by a key gives its characters, then the key

```infocom
(zm-input-script! (list (pair "ab" 131) "c"))
(zm-start! (zm-story "praxix.z5"))
(def %tc-k (list (zm-read-char) (zm-read-char) (zm-read-char) (zm-read-char) (zm-read-char)))
(zm-flush)
(write %tc-k)
```
---
```output
(97 98 131 99 13)
```
