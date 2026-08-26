#!/bin/bash

set -e
cd "$(dirname "$0")"

TABLE="mod-table.md"
SERVER_NAME="servertest"
FORCE=0

while [ $# -gt 0 ]; do
	case "$1" in
		--force) FORCE=1; shift ;;
		--table) TABLE="$2"; shift 2 ;;
		--server) SERVER_NAME="$2"; shift 2 ;;
		*) echo "Unknown argument: $1" >&2; exit 2 ;;
	esac
done

INI="data/zomboid/Server/${SERVER_NAME}.ini"

if [ ! -f "$TABLE" ]; then
	echo "No such table: $TABLE" >&2
	exit 1
fi

PARSED=$(awk '
	BEGIN { FS = "|"; inTable = 0; done = 0 }

	!done && /^\| *Workshop ID *\|/ { inTable = 1; next }
	inTable && /^\|[ -]*-[ -]*\|/ { next }

	inTable {
		if ($0 !~ /^\|/) { inTable = 0; done = 1; next }

		id = $2; gsub(/^[ \t]+|[ \t]+$/, "", id)
		title = $4; gsub(/^[ \t]+|[ \t]+$/, "", title)
		if (id !~ /^[0-9]+$/) {
			printf "FAIL\tline %d: workshop id is not numeric: %s\n", NR, id
			next
		}

		if (id in seenId) printf "FAIL\tduplicate workshop id %s (lines %d and %d)\n", id, seenId[id], NR
		else seenId[id] = NR
		printf "ID\t%s\n", id

		rest = $3
		count = 0
		while (match(rest, /`[^`]+`/)) {
			key = substr(rest, RSTART + 1, RLENGTH - 2)
			gsub(/^[ \t]+|[ \t]+$/, "", key)
			rest = substr(rest, RSTART + RLENGTH)
			count++
			if (index(key, ";")) printf "FAIL\tkey contains a semicolon: %s (line %d)\n", key, NR
			if (key in seenKey) printf "FAIL\tduplicate key %s (lines %d and %d)\n", key, seenKey[key], NR
			else seenKey[key] = NR
			printf "KEY\t%s\n", key
		}
		if (count == 0) printf "WARN\tno enabled key, downloads but loads nothing: %s %s\n", id, title
	}
' "$TABLE")

FAILS=$(printf '%s\n' "$PARSED" | grep '^FAIL	' | cut -f2- || true)
WARNS=$(printf '%s\n' "$PARSED" | grep '^WARN	' | cut -f2- || true)
IDS=$(printf '%s\n' "$PARSED" | grep '^ID	' | cut -f2- || true)
KEYS=$(printf '%s\n' "$PARSED" | grep '^KEY	' | cut -f2- || true)

[ -n "$IDS" ] || { echo "No rows parsed out of $TABLE" >&2; exit 1; }

[ -z "$WARNS" ] || printf '%s\n' "$WARNS" | sed 's/^/warn:  /' >&2
[ -z "$FAILS" ] || printf '%s\n' "$FAILS" | sed 's/^/ERROR: /' >&2

id_count=$(printf '%s\n' "$IDS" | grep -c .)
key_count=$(printf '%s\n' "$KEYS" | grep -c . || true)
warn_count=$(printf '%s\n' "$WARNS" | grep -c . || true)
echo "$id_count items, $key_count keys, $warn_count items with nothing enabled." >&2

[ -z "$FAILS" ] || exit 1

join_semi() { printf '%s\n' "$1" | grep . | paste -sd ';' -; }
WORKSHOP_LINE="WorkshopItems=$(join_semi "$IDS")"
MODS_LINE="Mods=$(join_semi "$KEYS")"

echo "$WORKSHOP_LINE"
echo "$MODS_LINE"

if [ ! -f "$INI" ]; then
	echo "No such ini: $INI" >&2
	exit 1
fi

if [ "$FORCE" != "1" ] && docker exec app sh -c 'ps -eo comm= | grep -qE "^(java|ProjectZomboid)"' >/dev/null 2>&1; then
	echo "The game is running; stop it first or use --force." >&2
	exit 1
fi

STAGED="./.write-mod-config.tmp"
trap 'rm -f "$STAGED"' EXIT

awk -v workshop="$WORKSHOP_LINE" -v mods="$MODS_LINE" '
	/^WorkshopItems=/ { print workshop; seenWorkshop = 1; next }
	/^Mods=/ { print mods; seenMods = 1; next }
	{ print }
	END {
		if (!seenWorkshop) { print workshop; printf "warn:  WorkshopItems= was missing, appended\n" > "/dev/stderr" }
		if (!seenMods) { print mods; printf "warn:  Mods= was missing, appended\n" > "/dev/stderr" }
	}
' "$INI" > "$STAGED"

if [ -w "$INI" ]; then
	cp "$INI" "$INI.bak"
	cat "$STAGED" > "$INI"
else
	if ! docker image inspect zomboid-app >/dev/null 2>&1; then
		echo "$INI is not writable and the zomboid-app image is unavailable." >&2
		echo "Run 'docker compose build' or run this script as root." >&2
		exit 1
	fi
	docker run --rm \
		-v "$(cd "$(dirname "$INI")" && pwd):/target" \
		-v "$(pwd):/staging:ro" \
		zomboid-app \
		bash -c "cp /target/$(basename "$INI") /target/$(basename "$INI").bak && cat /staging/$(basename "$STAGED") > /target/$(basename "$INI")"
fi

echo "Updated $INI (previous kept as $INI.bak)" >&2
