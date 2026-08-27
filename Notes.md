# Operator Notes

## First boot: admin password

If the `admin` account does not exist, `start-server.sh` prompts on stdin:

```
User 'admin' not found, creating it
Command line admin password: null
Enter new administrator password:
```

`docker-entrypoint.sh` omits `-adminpassword`. Use the app server manager to respond to the prompt:

1. Start the server.
2. Watch the logs for `Enter new administrator password:`.
3. Send the password through the server console.

The account persists in the user database, so this is required only once per world. The manager
holds the stdin FIFO open with `O_RDWR`; a raw `docker exec -i` does not and can cause EOF instead
of waiting for the password.

## Granting admin

From the server console, run:

```
setaccesslevel "Nyaa" "admin"
```

Available levels: Admin, Moderator, Overseer, GM, Observer. Access persists in the user database;
players must relog for a changed level to apply.

## Workshop mods

- Mod path: `/app/steamapps/workshop/content/108600/<workshop id>/`.
- Mount: `./data/workshop`, nested inside the `./data/game` install volume.
- Separate cache mount. Survives game revalidation and reinstall.

## Map load order

- `Map=` folder order. Earlier entries win. Vanilla `Muldraugh, KY` last.
- Map rows at the bottom of `mod-table.md`. Workshop ID and enabled-key validation in `write-mod-config.sh`.
- Map-cell files: `*.lotheader`, `*.lotpack`, `chunkdata_*.bin`. Spawn-location mods use `servertest_spawnregions.lua` instead.
- Map changes: save reset required. Wipe `Saves/`.

## Spawn regions

- Labels and descriptions: `<Map>.json` under `media/lua/shared/Translate/EN/`; not `map.info`.
- B41 `title.txt` layouts display the raw placeholder. McCoy Estate uses this layout.
- Client-side ordering: `MapsOrder.lua` places `Muldraugh, KY` first; `SpawnRegions()` orders the rest.
- Sandbox-only maps: Echo Creek, Fallas Lake, March Ridge, and Valley Station. Omitted from
  `servertest_spawnregions.lua`.
- Restart after region-list changes.

## AnimSets case workaround

The engine lowercases paths while resolving `x_extends`. On Linux, that does not match mods'
`AnimSets` directories and causes `PZXmlParserException` errors.

On every boot, `docker-entrypoint.sh` creates an `animsets` symlink beside each `AnimSets` directory
under the workshop content. The patch runs at startup because workshop content is mounted and empty
when the image is built. On a fresh host, mods download after the entrypoint runs, so the first boot
may still log these errors; the next boot applies the links.

## Mod sandbox options

- `media/sandbox-options.txt` defaults merged into `servertest_SandboxVars.lua` on next boot.
- Existing table values preserved.
- File growth after boot expected.

## Updating the game

- `docker-entrypoint.sh` runs `steamcmd` at startup.
- Game install: `./data/game`; persistent and separate from the image.
- `STEAM_BRANCH`: `-beta` value. Default: `public`. List branches with:
  `steamcmd +login anonymous +app_info_update 1 +app_info_print 380870`.
- `STEAM_VALIDATE=1`: integrity validation for partial or damaged installs.
- Steam unavailable: warning and boot from the installed files. An empty install still fails.
- Superseded install: remove `data/game/steamapps/appmanifest_380870.acf`, then run once with
  `STEAM_VALIDATE=1`.

## Client kicked for a Lua checksum mismatch

- `File doesn't match the one on the server`: build mismatch on a **vanilla** path. Not a mod error.
- Build comparison: `grep '"buildid"' data/game/steamapps/appmanifest_380870.acf` with
  `branches.public.buildid` from `app_info_print 380870`.
- Restart after updating. Server app `380870` and client app `108600` use separate build IDs.
