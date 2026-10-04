# x-infocom

An Infocom Z-machine on x-lang: an interpreter for story files, and the
tools around one, as a lang bundle.

    x -l infocom -- zork1.z3

plays a story on the terminal, reading commands from standard input and
writing at 80 columns, wrapped at word boundaries.

## The machine

Story files of versions 3, 4, 5 and 8 load; versions 1, 2, 6 and 7 are
refused at the start.  Version 3, the format of most Infocom games, is the
one exercised: Zork I runs from its opening through the house and into the
cellar with output identical to dfrotz's.

An instruction is read once.  The parser turns it into a record, and the
record into a closure that does the operation and answers the next
program counter; closures for code at or past the static base are kept in a
vector over the story, so a loop never decodes its body twice.  Strings in
static memory are decoded once and kept the same way.  The run loop is one
tail call an instruction.

Not served yet:

- saving and restoring (`save` and `restore` report failure, which every
  story handles);
- the status line and the upper window (output to either is not drawn);
- undo, sound, fonts, colours and text styles;
- the timed and terminating-character forms of input.

## Tools

- `zm-dis`, `zm-dis-routine` and `zm-trace-run` (infocom/dis.x): a
  disassembler in the style of txd, over the parser the machine runs on,
  and a run that prints each instruction before it runs.
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
the MIT licence in `tests/stories/LICENSE.zork1`.

## Licence

MIT No Attribution; see `LICENSE`.
