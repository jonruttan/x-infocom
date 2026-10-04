# x-infocom

An Infocom Z-machine on x-lang: an interpreter for story files, and the
tools around one, as a lang bundle.

    x -l infocom -- [--plain] zork1.z3

plays a story, reading commands from standard input.  On a terminal the
screen is drawn with ANSI sequences at the window's size: the status line
(before version 4) and the upper window held above a scroll region, text
styles as reverse, bold and italic.  Through a pipe, under `TERM=dumb` or
with `--plain`, it prints lines instead -- the lower window only, wrapped
at 80 columns -- which is what transcripts and the specs use.

## The machine

Story files of versions 3, 4, 5 and 8 load; versions 1, 2, 6 and 7 are
refused at the start.  Zork I (version 3) runs from its opening through
the house and into the cellar with output identical to dfrotz's.  Two
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

Not served yet:

- undo (`save_undo` reports it unavailable), and the auxiliary saves of a
  table;
- sound, fonts and colours; on the plain screen, the upper window and text
  styles (output to the upper window is not printed);
- the timed and terminating-character forms of input.

## The command line

    x -l infocom -- [OPTIONS] STORY

`--help` prints the options; they are declared once, in `infocom/cli.x`,
and that declaration is both the help text and the parser.

Play:

| option | |
|---|---|
| `-p`, `--plain` | print lines, not a drawn screen |
| `-w`, `--width N` | wrap printed lines at N columns (0: never) |
| `-s`, `--seed N` | seed the random numbers, for play that repeats (else the clock) |
| `-r`, `--restore FILE` | begin from a saved game |
| `-S`, `--save-dir DIR` | put save files in DIR |
| `-e`, `--echo` | echo each command read, as a transcript shows it |

Describe the story, then stop (in the spirit of infodump and txd):

| option | |
|---|---|
| `-i`, `--info` | the header: version, release, serial, checksum, the memory map |
| `-o`, `--objects` | the objects, their attributes and properties |
| `-t`, `--tree` | the object tree |
| `-d`, `--dict` | the dictionary |
| `-a`, `--abbrevs` | the abbreviations |
| `-D`, `--dis ADDR` | disassemble the routine at byte ADDR (hex; 0, the start) |

On a terminal, `read_char` takes a single key (the arrows as ZSCII
129-132); elsewhere it takes the next line's first character.

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

## Tests

    make test

runs `tests/specs`; `make check` runs them against
`tests/contract/known-failures.txt`, which is what CI gates on.  A case
plays a story on a list of commands with `zm-play`, which echoes each
command after its prompt as a transcript shows it.  The command lists live
in `tests/walks`.

`tests/stories/zork1.z3` is Zork I, release 119, from
[historicalsource/zork1](https://github.com/historicalsource/zork1), under
the MIT licence in `tests/stories/LICENSE.zork1`.  `czech.z5` is CZECH 0.8 (Amir
Karger; licence in `tests/stories/README.czech`) and `praxix.z5` is Praxix
(Zarf and Dannii, public domain; `tests/stories/README.praxix`), both from
the IF Archive.  `tests/saves` holds a save dfrotz wrote, restored by a spec.

## Licence

MIT No Attribution; see `LICENSE`.
