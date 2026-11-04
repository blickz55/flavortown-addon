# Flavor Town

The guild addon for Flavor Town on WoW: Forever. It records your dings, Legacy Challenges, epic loot, boss kills and a few other milestones, stamped with the server's clock, so they can go on [flavortown.beer](https://flavortown.beer).

Addons cannot use the internet, and this one does not try. Everything it notices is written by the game to one file on your PC when you log out, quit or type `/reload`:

```
World of Warcraft\_forever_\WTF\Account\<your account>\SavedVariables\FlavorTown.lua
```

Nothing leaves your PC until you upload that file to flavortown.beer yourself. The upload page is being built. Install now so your dings from launch night are on the record when it opens.

## Install

1. Download `FlavorTown-0.1.0.zip` from [Releases](../../releases).
2. Unzip it. You get one folder named `FlavorTown`.
3. Move that folder into `World of Warcraft\_forever_\Interface\AddOns\`, so that `AddOns\FlavorTown\FlavorTown.toc` exists. Do not nest it inside another folder.
4. If the game is open, log out to the character screen and back in. New addons are picked up at the character screen, where the AddOns button should list Flavor Town.

WowUp users can add this repository's address under Get Addons, Install from URL. The CurseForge listing is waiting on CurseForge's review.

## What it records

| Milestone | When | What is kept |
|---|---|---|
| Level | Every ding | The level and the server time |
| Legacy Challenge or Explore achievement | When it is earned | The achievement id and name. Ones earned before you installed are kept with Blizzard's date and marked as before tracking |
| Epic loot | When you loot an epic or better | The item id, quality, item level and binding. Crafted epics are kept separately. Nothing below epic is recorded |
| Boss kill | When an encounter ends in a kill | The encounter, difficulty, group size, and which guildmates were there |
| Profession | Crossing 75, 150, 225 or 300 | The skill line and level |
| PvP rank and Legacy track | Each new rank | The level reached |
| Deaths | Counted | Only the first one is a dated fact |

Each character is keyed by its game id and carries its name, class, race, faction, guild and ruleset. Your level when you installed is stored, so nothing before that is ever guessed.

It does not record your zone, who is online, guild notes, chat, gold, your bags or anything about other players beyond who stood in a boss kill with you.

## Commands

| Command | Does |
|---|---|
| `/ft` | Status: who you are, what is on file, what is not yet written to disk |
| `/ft save` | Writes to disk now by reloading the interface |
| `/ft link CODE` | Stores the code from flavortown.beer/me so your next upload claims this character |
| `/ft off`, `/ft on` | Stops and resumes recording |
| `/ft quiet` | Hides the one line it prints at login |
| `/ft debug` | Versions and any error it swallowed |
| `/ft wipe yes` | Erases everything recorded on this PC |

## Saving

The game writes addon data only when you log out, quit cleanly or reload the interface. A crash or a disconnect loses whatever happened since the last write. `/ft save` writes now, and `/ft` tells you how much is waiting. On a night with a big ding, type `/ft save` before you walk away.

## Launch night checklist

For whoever tests the first build on the live client. Ten minutes.

1. Before launch, install as above. At the character screen, open AddOns and confirm Flavor Town is listed, ticked, and not marked out of date.
2. Enter the world. One orange line should appear: `Flavor Town v0.1.0 is recording. 0 on file.`
3. Type `/ft`. It should show your first name and surname, your level and `pvp`.
4. Gain a level. `/ft` should now say `1 new since login`.
5. Type `/ft save`. After the reload, `/ft` should say `1 milestones on file, 0 new since login`.
6. Alt-tab and open `_forever_\WTF\Account\<account>\SavedVariables\FlavorTown.lua` in Notepad. Look for `["facts"]` with a `["k"] = "level"` entry whose `["at"]` is close to the current Unix time. Note the account folder's name.
7. Type `/dump select(4, GetBuildInfo())`. Expected: `16001`. Then `/dump UnitNameUnmodified("player")`, `/dump GetRealmName()` and `/dump UnitGUID("player")`, and keep the output.
8. Loot something, then type `/ft debug`. It should report `0 errors ever`.
9. Later, with a guildmate who also runs it, kill a dungeon boss and check that both of you gained a kill in `/ft`.

If step 2 shows a Lua error, or `/ft debug` shows errors, type `/ft off` and report what it said.

## For the website

`FlavorTownDB` is schema 1. `chars` is keyed by player GUID and holds `name`, `surname`, `class`, `class_id`, `race`, `race_file`, `faction`, `guild`, `ruleset`, `level`, `level_at_install`, `first_seen`, `last_seen`, `deaths`, `kills`, `skills`, `pvp_rank`, `legacy_track`, `link` and `linked_at`. `facts` is an array of `{ c = guid, k = kind, key = key, at = serverTime, lt = pcTime, ... }` with kinds `level`, `ach`, `loot`, `craft`, `kill`, `skill`, `rank`, `legacy` and `dead`; a fact exists once per character, kind and key. `client` holds the game version, build and interface number; `installed` and `saved_at` are server times. An `ach` with `pre = true` was earned before tracking and carries Blizzard's `m`, `d`, `y`.

## License

MIT. The code is plain Lua and is meant to be read.
