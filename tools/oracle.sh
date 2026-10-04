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

dir="$(cd "$(dirname "$story")" && pwd)"
name="$(basename "$story")"

podman run --rm -i -v "$dir:/s:ro" "$image" \
	/usr/games/dfrotz -m -w "${ORACLE_WIDTH:-80}" -s "$seed" "/s/$name" < "$cmds" 2>/dev/null |
awk -v cmds="$cmds" '
	BEGIN { n = 0; while ((getline line < cmds) > 0) c[++n] = line; k = 0 }
	NR <= 2 { next }
	skip { skip = 0; if ($0 == "") next }
	/Score: -?[0-9]+ +Moves: [0-9]+ *$/ {
		if (substr($0, 1, 1) == ">") { k++; print ">" c[k] }
		skip = 1
		next
	}
	# A prompt whose status line did not change, so dfrotz drew none: the
	# reply follows the prompt on its line.
	/^>/ && k < n {
		k++
		print ">" c[k]
		rest = substr($0, 2)
		sub(/ +$/, "", rest)
		if (rest != "") print rest
		next
	}
	{ sub(/ +$/, ""); print }
'
