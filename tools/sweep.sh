#!/bin/sh
# # x-infocom -- a Z-machine on x-lang
#
# ## tools/sweep.sh -- every story in a directory, against dfrotz
#
# @description Plays each story file under DIR (versions 3, 4, 5 and 8;
#   version 6 is not served) on COMMANDS -- nothing, by default: the opening
#   to the first prompt -- under this bundle and under dfrotz, and reports
#   for each whether the transcripts are the same, differ, or whether this
#   machine stopped with an error.  The stories are read where they are and
#   copied nowhere; the transcripts and diffs go to OUT.
# @author [Jon Ruttan](jonruttan@gmail.com)
# @copyright 2026 Jon Ruttan
# @license MIT No Attribution (MIT-0)
#
# Usage: sweep.sh DIR OUT [COMMANDS]
#
# X names the x to run (default: x on PATH).  The bundle is copied into a
# fresh langs directory under OUT first, because x keys its state image by
# the bundle's path: a reused path can serve an image of older code.
# Each run is held to SWEEP_SECS seconds (default 60) and SWEEP_MB of
# memory (default 2000) by ~/.cache/x-claude/guard.sh when it is there.
set -e

dir="$1"
out="$2"
cmds="${3:-}"
here="$(cd "$(dirname "$0")/.." && pwd)"
X="${X:-x}"

[ -d "$dir" ] && [ -n "$out" ] || {
	echo "usage: sweep.sh DIR OUT [COMMANDS]" >&2
	exit 2
}

mkdir -p "$out"
out="$(cd "$out" && pwd)"
if [ -z "$cmds" ]; then
	cmds="$out/no-commands.txt"
	: > "$cmds"
fi

langs="$out/langs.$$"
mkdir -p "$langs/infocom"
cp -R "$here/lang.xon" "$here/run.x" "$here/infocom" "$langs/infocom/"

guard="$HOME/.cache/x-claude/guard.sh"
run_ours() {
	if [ -f "$guard" ]; then
		GUARD_START="${GUARD_START:-30}" X_LANG_DIR="$langs/" \
			sh "$guard" "${SWEEP_MB:-2000}" "${SWEEP_SECS:-60}" -- \
			"$X" -l infocom -- --plain --echo "$1" < "$cmds" 2>&1
	else
		X_LANG_DIR="$langs/" "$X" -l infocom -- --plain --echo "$1" < "$cmds" 2>&1
	fi
}

printf '%-40s %s\n' story verdict > "$out/summary.txt"
find -L "$dir" -type f \( -iname '*.z3' -o -iname '*.z4' -o -iname '*.z5' -o -iname '*.z8' \) |
	sort | while IFS= read -r story; do
	name="$(basename "$story")"
	key="$(printf '%s' "$story" | cksum | cut -d' ' -f1)-$name"
	# the guard's report can land on the last line, after a prompt
	run_ours "$story" | sed 's/GUARD: peak.*$//; s/ *$//' |
		grep -v '^x: no current state image' > "$out/$key.ours" || true
	sh "$here/tools/oracle.sh" "$story" "$cmds" > "$out/$key.frotz" 2>/dev/null || true
	if grep -q 'Error:\|GUARD: stopped\|Segmentation' "$out/$key.ours"; then
		verdict="ERROR $(grep -m1 'Error:\|GUARD: stopped\|Segmentation' "$out/$key.ours" | cut -c1-80)"
	elif diff -q "$out/$key.frotz" "$out/$key.ours" > /dev/null; then
		verdict="same"
	elif diff -q -B "$out/$key.frotz" "$out/$key.ours" > /dev/null; then
		# dfrotz leaves out blank lines at the top of a cleared screen
		verdict="same but blank lines"
	else
		diff -B "$out/$key.frotz" "$out/$key.ours" > "$out/$key.diff" || true
		verdict="differs ($(grep -c '^[<>]' "$out/$key.diff") lines)"
	fi
	printf '%-40s %s\n' "$name" "$verdict" | tee -a "$out/summary.txt"
done
rm -rf "$langs"
