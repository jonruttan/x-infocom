# @weight 3

Saving and restoring in Quetzal, the format interpreters share.  The
dialogue is dfrotz's -- it asks for a file name, offering the last one
given -- and every expectation is dfrotz's transcript for the same
commands.

## Zork I

### a save, a change, and a restore that undoes it

```infocom
(zm-play (zm-story "zork1.z3")
  (list
    "open mailbox"
    "save"
    "x-infocom-zork1.qzl"
    "take leaflet"
    "restore"
    "x-infocom-zork1.qzl"
    "look"
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

>save
Please enter a filename [zork1.qzl]: x-infocom-zork1.qzl
Ok.

>take leaflet
Taken.

>restore
Please enter a filename [x-infocom-zork1.qzl]: x-infocom-zork1.qzl
Ok.

>look
West of House
You are standing in an open field west of a white house, with a boarded front
door.
There is a small mailbox here.
The small mailbox contains:
  A leaflet

>inventory
You are empty-handed.

>
```

### restoring a save dfrotz wrote, north of the house with the leaflet

```infocom
(zm-save-dir! (zm-test-dir "saves"))
(zm-play (zm-story "zork1.z3")
  (list
    "restore"
    "zork1-north.qzl"
    "look"
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

>restore
Please enter a filename [zork1.qzl]: zork1-north.qzl
Ok.

>look
North of House
You are facing the north side of a white house. There is no door here, and all
the windows are boarded up. To the north a narrow path winds through the trees.

>inventory
You are carrying:
  A leaflet

>
```
