#!/bin/bash

if [ -z "$STEAM_APP_ID" ]; then
	echo "STEAM_APP_ID is not set"
	exit 1;
fi

if [ -z "$STEAM_BRANCH" ]; then
	echo "STEAM_BRANCH is not set"
	exit 1;
fi

mkdir -p /app

if [ "$STEAM_VALIDATE" = "1" ]; then
	VALIDATE="validate"
else
	VALIDATE=""
fi

/root/steamcmd/steamcmd.sh \
	+force_install_dir /app \
	+login anonymous \
	+app_update "$STEAM_APP_ID" -beta "$STEAM_BRANCH" $VALIDATE \
	+quit \
	|| echo "WARNING: steamcmd exited nonzero." >&2

if [ ! -x /app/start-server.sh ]; then
	echo "No game install at /app and steamcmd could not provide one." >&2
	exit 1
fi

grep '"buildid"' /app/steamapps/appmanifest_"$STEAM_APP_ID".acf
