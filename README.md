# x-infocom

An Infocom Z-machine on x-lang: an interpreter for story files, and the
tools around one, as a lang bundle.

    x -l infocom -- [--plain] zork1.z3

plays a story, reading commands from standard input.  On a terminal the
screen is drawn with ANSI sequences at the window's size: the status line
(before version 4) and the upper window held above a scroll region, text
styles as reverse, bold and italic.  Through a pipe, under `TERM=dumb` or
with `--plain`, it prints lines instead -- the lower window only, wrapped
at 80 columns -- which is what transcripts and the specs use; `--upper` adds
the status line and the upper window to them, as lines.

## The machine

Story files of versions 3, 4, 5 and 8 load; versions 1, 2, 6 and 7 are
refused at the start.  Zork I, II and III (version 3) run with output
identical to dfrotz's: Zork I from its opening through the house and into
the cellar, II and III through their first rooms.  Two
version-5 conformance stories pass: CZECH, all 406 of its checks, with a
transcript identical to its own reference outside the interpreter's
identity in the header; and Praxix, every test.

An instruction is read once.  The parser turns it into a record, and the
record into a closure that does the operation and answers the next
program counter; closures for code at or past the static base are kept in a
vector over the story, so a loop never decodes its body twice.  Strings in
static memory are decoded once and kept the same way.  The run loop is one
tail call an instruction.

Saving and restoring use Quetzal, the format interpreters share: a save
from this machine restores in dfrotz, and one from dfrotz restores here.
The file name is asked for as dfrotz asks it, offering the last name given.
The auxiliary forms (version 5 on) keep a table of the story's own as raw
bytes in a file of its own, named by the story or `<story>.aux`, and
asked for unless the story says not to.
Undo keeps eight levels: save_undo keeps dynamic memory (one block copy),
the stack and the frames, and restore_undo puts the newest back.

Not served yet:

- sound, fonts and colours; text styles on the plain screen.

## The command line

    x -l infocom -- [OPTIONS] STORY

`--help` prints the options; they are declared once, in `infocom/cli.x`,
and that declaration is both the help text and the parser.

Play:

| option | |
|---|---|
| `-p`, `--plain` | print lines, not a drawn screen |
| `-u`, `--upper` | on printed lines, the status line and upper window too: each changed row, as a line before the prompt it came with |
| `-w`, `--width N` | wrap printed lines at N columns (0: never) |
| `-s`, `--seed N` | seed the random numbers, for play that repeats (else the clock) |
| `-r`, `--restore FILE` | begin from a saved game |
| `-S`, `--save-dir DIR` | put save files in DIR |
| `-e`, `--echo` | echo each command read, as a transcript shows it |
| `-H`, `--history FILE` | keep the commands typed at a terminal in FILE; empty, nowhere |

Describe the story, then stop (in the spirit of infodump and txd):

| option | |
|---|---|
| `-i`, `--info` | the header: version, release, serial, checksum, the memory map |
| `-o`, `--objects` | the objects, their attributes and properties |
| `-t`, `--tree` | the object tree |
| `-d`, `--dict` | the dictionary |
| `-a`, `--abbrevs` | the abbreviations |
| `-D`, `--dis ADDR` | disassemble the routine at byte ADDR (hex; 0, the start) |

On a terminal a command is typed through x-lang's line editor: the arrows
move along it and back through the commands typed before, ctrl-r searches
them, ctrl-d on an empty line or ctrl-c ends the game.  The commands are
kept between games in `x/infocom-history` under `$XDG_STATE_HOME`
(`~/.local/state` when that is not set), or where `--history` says.

Reads with a timer (version 4 on: a time in tenths of a second and a
routine) call the routine each time that long passes without a key, and
stop when it returns true.  On a terminal that is while a command is being
typed too: the line is drawn again after the routine, with what was typed
so far.  Through a pipe no time passes between lines; a script for
`zm-play` says it does with the symbol `tick` among its commands.

A version 5 story can name keys besides Return that end a read -- the
arrows, function keys and keypad -- and `aread` stores which one did; a
key the story does not name is passed over.  On a terminal a key the
story names is taken ahead of the line editor's own use of it: an arrow
the story asks for ends the line rather than browsing the history.  A
script line for `zm-play` ended by a key is a pair, `(text . key)`, the
key by its ZSCII.

On a terminal, `read_char` takes a single key (the arrows, function keys
and keypad as ZSCII 129-154); elsewhere a line is the keys typed for it,
one a `read_char`, then Return, and what `read_char` leaves of a line the
next read takes.

## Tools

- `zm-dis`, `zm-dis-code`, `zm-dis-routine` and `zm-trace-run`
  (infocom/dis.x): a disassembler in the style of txd, over the parser the
  machine runs on, and a run that prints each instruction before it runs.
- `zm-info-header`, `-objects`, `-tree`, `-dict` and `-abbrevs`
  (infocom/info.x): the views behind the describing options.
- `tools/oracle.sh STORY COMMANDS`: the transcript dfrotz prints for a story
  and its commands, in the form the interpreter's script mode prints it.
  dfrotz runs in a Podman container built from `tools/Containerfile.oracle`.
- `tools/mkspec.sh STORY COMMANDS "heading"`: a spec case whose expected
  output is that transcript.
- `tools/sweep.sh DIR OUT [COMMANDS]`: every story under DIR against dfrotz,
  each verdict one of same, same but blank lines (dfrotz leaves those out at
  the top of a cleared screen), differs, or ERROR; the stories are read
  where they are, so a private collection can be swept without copying it.

## Tests

    make test

runs `tests/specs`; `make check` runs them against
`tests/contract/known-failures.txt`, which is what CI gates on.  A case
plays a story on a list of commands with `zm-play`, which echoes each
command after its prompt as a transcript shows it.  The command lists live
in `tests/walks`.

`tests/stories/zork1.z3`, `zork2.z3` and `zork3.z3` are Zork I (release
119), II (63) and III (25), from historicalsource
([zork1](https://github.com/historicalsource/zork1),
[zork2](https://github.com/historicalsource/zork2),
[zork3](https://github.com/historicalsource/zork3)), under the MIT licences
in `tests/stories/LICENSE.zork*`.  `czech.z5` is CZECH 0.8 (Amir
Karger; licence in `tests/stories/README.czech`) and `praxix.z5` is Praxix
(Zarf and Dannii, public domain; `tests/stories/README.praxix`), both from
the IF Archive.  `tests/saves` holds a save dfrotz wrote, restored by a spec.

## Licence

MIT No Attribution; see `LICENSE`.
