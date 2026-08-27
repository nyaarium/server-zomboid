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
setaccesslevel "username" "admin"
```

Available levels: Admin, Moderator, Overseer, GM, Observer. Access persists in the user database;
players must relog for a changed level to apply.

## Workshop mods

The server downloads mods to `/app/steamapps/workshop/content/108600/<workshop id>/`.
`compose.yml` mounts `./data/workshop` at `/app/steamapps/workshop` so mods survive rebuilds.

Mount only `workshop`; `appmanifest_380870.acf` is stored in the parent `steamapps/` directory,
and mounting that parent would hide the game manifest.

## Map load order

- `Map=` folder order. Earlier entries win. Vanilla `Muldraugh, KY` stays last.
- Map rows at the bottom of `mod-table.md`. Workshop ID and enabled-key validation in `write-mod-config.sh`.
- Map-cell files: `*.lotheader`, `*.lotpack`, `chunkdata_*.bin`. Spawn-location mods use `servertest_spawnregions.lua` instead.
- Changes to `Map=` breaks the save. Wipe `Saves/`.

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

`start.sh game` uses the Docker cache. Update these variables in `docker/Dockerfile`:

- `STEAM_BRANCH` is passed to steamcmd as `-beta`; it defaults to `public`. List branches with:
  `steamcmd +login anonymous +app_info_update 1 +app_info_print 380870`.
- `GAME_BUILD` invalidates the install layer. It records the installed build but does not pin it;
  steamcmd installs the branch's newest build. `docker/install.sh` prints the installed ID.

Changing `GAME_BUILD` can trigger a full game download because the install is a Docker layer, not a
mounted volume. Rebuild when clients report a version mismatch.
