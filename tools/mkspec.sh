#!/bin/sh
# # x-infocom -- a Z-machine on x-lang
#
# ## tools/mkspec.sh -- a spec case whose expectation is dfrotz's transcript
#
# @description Prints one spec case: a heading, the zm-play call on
#   COMMANDS, and the transcript tools/oracle.sh takes from dfrotz for the
#   same story and commands, at the same 80-column width.
# @author [Jon Ruttan](jonruttan@gmail.com)
# @copyright 2026 Jon Ruttan
# @license MIT No Attribution (MIT-0)
#
# Usage: mkspec.sh STORY COMMANDS "case heading"
#
# STORY is a file under tests/stories; COMMANDS holds one command a line,
# none containing a double quote or a backslash.  MKSPEC_PRELUDE, when set,
# is x placed before the zm-play call; ORACLE_DIR is passed to oracle.sh.
set -e

story="$1"
cmds="$2"
title="$3"
here="$(dirname "$0")"

[ -f "$story" ] && [ -f "$cmds" ] && [ -n "$title" ] || {
	echo "usage: mkspec.sh STORY COMMANDS \"case heading\"" >&2
	exit 2
}
if grep -q '["\\]' "$cmds"; then
	echo "mkspec.sh: a command holds a double quote or a backslash" >&2
	exit 2
fi

printf '### %s\n\n```infocom\n' "$title"
[ -z "$MKSPEC_PRELUDE" ] || printf '%s\n' "$MKSPEC_PRELUDE"
printf '(zm-play (zm-story "%s")\n  (list' "$(basename "$story")"
awk '{ printf "\n    \"%s\"", $0 }' "$cmds"
printf '))\n```\n---\n```output\n'
sh "$here/oracle.sh" "$story" "$cmds"
printf '```\n'
