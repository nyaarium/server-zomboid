#!/bin/bash

set -e
cd /app

# The engine lowercases x_extends paths; provide lowercase aliases on case-sensitive filesystems.
find /app/steamapps/workshop/content/108600 -type d -name AnimSets 2>/dev/null | while read -r dir; do
	link="$(dirname "$dir")/animsets"
	[ -e "$link" ] || ln -s AnimSets "$link"
done

# Start the server and handle first-boot administration through stdin.
exec ./start-server.sh -servername servertest
