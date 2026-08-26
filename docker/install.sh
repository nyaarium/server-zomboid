#!/bin/bash

# See Dockerfile for the app id, branch, and build
if [ -z "$STEAM_APP_ID" ]; then
	echo "STEAM_APP_ID is not set"
	exit 1;
fi

if [ -z "$STEAM_BRANCH" ]; then
	echo "STEAM_BRANCH is not set"
	exit 1;
fi

# Not passed to steamcmd. Its only job is to invalidate this layer on a bump.
if [ -z "$GAME_BUILD" ]; then
	echo "GAME_BUILD is not set"
	exit 1;
fi

mkdir -p /app

/root/steamcmd/steamcmd.sh \
	+force_install_dir /app \
	+login anonymous \
	+app_update "$STEAM_APP_ID" -beta "$STEAM_BRANCH" validate \
	+quit

# What actually landed. Copy it into the Dockerfile's GAME_BUILD.
grep '"buildid"' /app/steamapps/appmanifest_"$STEAM_APP_ID".acf
