#!/bin/sh
# # x-infocom -- a Z-machine on x-lang
#
# ## tools/oracle.sh -- what dfrotz prints for a story and its commands
#
# @description Plays STORY under dfrotz (Debian's frotz package, in a
#   Podman container) on the lines of COMMANDS, and prints the transcript
#   as x-infocom's script mode prints it: no status lines, each command
#   echoed after its prompt.  The expected output of a spec comes from here.
# @author [Jon Ruttan](jonruttan@gmail.com)
# @copyright 2026 Jon Ruttan
# @license MIT No Attribution (MIT-0)
#
# Usage: oracle.sh STORY COMMANDS [SEED]
#
# dfrotz draws the status line as a line of its own (after the prompt,
# once a command is read) followed by an empty line; both go, and a
# prompt's line becomes the prompt and the command typed at it.
set -e

story="$1"
cmds="$2"
seed="${3:-1}"
image=x-infocom-oracle

[ -f "$story" ] && [ -f "$cmds" ] || {
	echo "usage: oracle.sh STORY COMMANDS [SEED]" >&2
	exit 2
}

podman image exists "$image" ||
	podman build -q -t "$image" -f "$(dirname "$0")/Containerfile.oracle" "$(dirname "$0")" >/dev/null

# The story runs from a scratch directory of its own, writable, so a save
# has somewhere to go; ORACLE_DIR names one to keep (and to seed with save
# files to restore).
work="${ORACLE_DIR:-$(mktemp -d)}"
cp "$story" "$work/"
name="$(basename "$story")"

podman run --rm -i -v "$work:/s" -w /s "$image" \
	/usr/games/dfrotz -m -w "${ORACLE_WIDTH:-80}" -s "$seed" "/s/$name" < "$cmds" 2>/dev/null |
awk -v cmds="$cmds" '
	BEGIN { n = 0; while ((getline line < cmds) > 0) c[++n] = line; k = 0 }
	# dfrotz reads a file name on the line it asks on, and shows nothing of
	# what was typed: put the name there, and what follows on a line of its own.
	function emit(s,   p, rest) {
		p = index(s, "Please enter a filename [")
		if (p == 0) { sub(/ +$/, "", s); if (s != "" || !drop) print s; return }
		p = index(s, "]: ")
		k++
		print substr(s, 1, p + 2) c[k]
		rest = substr(s, p + 3)
		sub(/ +$/, "", rest)
		if (rest != "") print rest
	}
	NR <= 2 { next }
	skip { skip = 0; if ($0 == "") next }
	/(Score: -?[0-9]+ +Moves: [0-9]+|Time: +[0-9]+:[0-9]+ [ap]m) *$/ {
		s = $0
		if (substr(s, 1, 1) == ">") { k++; print ">" c[k]; s = substr(s, 2) }
		# a file name read on a prompt line, the status drawn after it
		if (index(s, "Please enter a filename [") == 1) {
			k++
			print substr(s, 1, index(s, "]: ") + 2) c[k]
		}
		skip = 1
		next
	}
	# A prompt whose status line did not change, so dfrotz drew none: the
	# reply follows the prompt on its line.
	/^>/ && k < n {
		k++
		print ">" c[k]
		drop = 1
		emit(substr($0, 2))
		drop = 0
		next
	}
	{ emit($0) }
'
[ -n "$ORACLE_DIR" ] || rm -rf "$work"
