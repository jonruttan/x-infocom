# @weight 3

Zork I (release 119, serial 880429; MIT-licensed by Microsoft, see
tests/stories/LICENSE.zork1).  Every expectation is the transcript dfrotz
prints for the same commands at 80 columns, taken by tools/mkspec.sh from
the command lists in tests/walks.

## Zork I

### the opening, then the end of input at the first prompt

```infocom
(zm-play (zm-story "zork1.z3")
  (list))
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

>
```

### the mailbox and the leaflet

```infocom
(zm-play (zm-story "zork1.z3")
  (list
    "open mailbox"
    "read leaflet"
    "drop leaflet"
    "inventory"))
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

>open mailbox
Opening the small mailbox reveals a leaflet.

>read leaflet
(Taken)
"WELCOME TO ZORK!

ZORK is a game of adventure, danger, and low cunning. In it you will explore
some of the most amazing territory ever seen by mortals. No computer should be
without one!"

>drop leaflet
Dropped.

>inventory
You are empty-handed.

>
```

### into the house and down to the cellar

```infocom
(zm-play (zm-story "zork1.z3")
  (list
    "north"
    "east"
    "open window"
    "west"
    "examine table"
    "take sack"
    "open it"
    "west"
    "take lamp"
    "move rug"
    "open trap door"
    "turn on lamp"
    "down"
    "score"))
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

>north
North of House
You are facing the north side of a white house. There is no door here, and all
the windows are boarded up. To the north a narrow path winds through the trees.

>east
Behind House
You are behind the white house. A path leads into the forest to the east. In one
corner of the house there is a small window which is slightly ajar.

>open window
With great effort, you open the window far enough to allow entry.

>west
Kitchen
You are in the kitchen of the white house. A table seems to have been used
recently for the preparation of food. A passage leads to the west and a dark
staircase can be seen leading upward. A dark chimney leads down and to the east
is a small window which is open.
A bottle is sitting on the table.
The glass bottle contains:
  A quantity of water
On the table is an elongated brown sack, smelling of hot peppers.

>examine table
A bottle is sitting on the table.
The glass bottle contains:
  A quantity of water
On the table is an elongated brown sack, smelling of hot peppers.

>take sack
Taken.

>open it
Opening the brown sack reveals a clove of garlic, and a lunch.

>west
Living Room
You are in the living room. There is a doorway to the east, a wooden door with
strange gothic lettering to the west, which appears to be nailed shut, a trophy
case, and a large oriental rug in the center of the room.
Above the trophy case hangs an elvish sword of great antiquity.
A battery-powered brass lantern is on the trophy case.

>take lamp
Taken.

>move rug
With a great effort, the rug is moved to one side of the room, revealing the
dusty cover of a closed trap door.

>open trap door
The door reluctantly opens to reveal a rickety staircase descending into
darkness.

>turn on lamp
The brass lantern is now on.

>down
The trap door crashes shut, and you hear someone barring it.

Cellar
You are in a dark and damp cellar with a narrow passageway leading north, and a
crawlway to the south. On the west is the bottom of a steep metal ramp which is
unclimbable.

>score
Your score is 35 (total of 350 points), in 13 moves.
This gives you the rank of Amateur Adventurer.

>
```
