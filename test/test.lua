-- Drives FlavorTown.lua through a session: install, dings, loot, kills, deaths,
-- professions, ranks, achievements, the slash commands, logout, a reload and a wipe.
-- A check that fails is printed and counted; the run exits non-zero at the end.

local function check(cond, msg)
  if cond then
    print("PASS " .. msg)
  else
    print("FAIL " .. msg)
    STUB.failed = STUB.failed + 1
  end
end
local function lastLine() return STUB.printed[#STUB.printed] or "" end
local function DB() return FlavorTownDB end
local GUID = "Player-1234-0000ABCD"

-- First login ever.
STUB.loadAddon()
STUB.fire("ADDON_LOADED", "SomeOtherAddon")
check(FlavorTownDB == nil, "another addon loading does nothing")
STUB.fire("ADDON_LOADED", "FlavorTown")
check(type(DB()) == "table" and DB().v == 1 and DB().n == 0, "db initialised at schema 1")
check(DB().client and DB().client.interface == 16001 and DB().project == 18, "client and project recorded")
STUB.fire("PLAYER_ENTERING_WORLD", true, false)
local greeting = lastLine()
local me = DB().chars[GUID]
check(me ~= nil, "character keyed by GUID")
check(me.name == "Biscuit" and me.surname == "Flavortown" and me.class == "WARRIOR" and me.race == 2 and me.faction == "Horde", "identity recorded")
check(me.level_at_install == 7 and me.level == 7, "level at install is 7")
check(me.ruleset == "pvp", "ruleset read from game rules")
check(me.guild == "Flavor Town", "guild recorded")
check(greeting:find("is recording") ~= nil and greeting:find("0 on file") ~= nil, "one greeting line")
local printed = #STUB.printed
STUB.fire("PLAYER_ENTERING_WORLD", false, false)
check(#STUB.printed == printed, "zoning does not greet again")

STUB.runTimers() -- the skills snapshot and the Legacy back-fill
check(me.skills and me.skills[185] and me.skills[185].lvl == 148 and me.skills[129].lvl == 75, "profession snapshot")
check(DB().n == 1, "back-fill keeps the one completed, non-statistic achievement")
local f1 = DB().facts[1]
check(f1.k == "ach" and f1.key == "61499" and f1.pre == true and f1.m == 11 and f1.d == 4 and f1.y == 26 and f1.mine == true, "back-filled challenge carries Blizzard's date")
check(me.backfilled ~= nil, "back-fill runs once")

-- Dings.
STUB.server = STUB.server + 600
STUB.player.level = 8
STUB.fire("PLAYER_LEVEL_UP", 8, 20, 10, 0, 0, 1, 1, 1, 1)
local f2 = DB().facts[2]
check(DB().n == 2 and f2.k == "level" and f2.key == "8" and f2.at == STUB.server and f2.c == GUID, "level 8 recorded with server time")
check(f2.lt ~= nil, "pc clock rides along")
STUB.fire("PLAYER_LEVEL_UP", 8)
check(DB().n == 2, "duplicate ding ignored")
STUB.fire("PLAYER_LEVEL_UP", "SECRET")
check(DB().n == 2, "secret level ignored without error")

-- Loot.
STUB.fire("CHAT_MSG_LOOT", "You receive loot: |cffa335ee|Hitem:14152::::::::8:::::|h[Robe of the Archmage]|h|r.", "Biscuit")
local f3 = DB().facts[3]
check(DB().n == 3 and f3.k == "loot" and f3.key == "14152" and f3.q == 4 and f3.b == 2 and f3.il == 62, "epic BoE loot recorded with binding 2")
STUB.fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:2589::::::::8:::::|h[Linen Cloth]|h|rx3.", "Biscuit")
check(DB().n == 3, "white loot ignored")
STUB.fire("CHAT_MSG_LOOT", "You create: |cffa335ee|Hitem:14152::::::::8:::::|h[Robe of the Archmage]|h|r.", "Biscuit")
check(DB().n == 4 and DB().facts[4].k == "craft", "crafted epic recorded as craft")
STUB.fire("CHAT_MSG_LOOT", "Biscuit receives loot: |cffa335ee|Hitem:19019::::::::8:::::|h[Thunderfury]|h|r.", "Other")
check(DB().n == 4, "another player's loot line ignored")
STUB.fire("CHAT_MSG_LOOT", "SECRET", "Biscuit")
check(DB().n == 4, "secret loot line ignored without error")
STUB.fire("CHAT_MSG_LOOT", "You receive loot: |cffa335ee|Hitem:99999::::::::8:::::|h[Mystery]|h|r.", "Biscuit")
check(DB().n == 4, "uncached item waits for item data")
STUB.items[99999] = { name = "Mystery Epic", quality = 4, ilvl = 65, bind = 2 }
STUB.fire("GET_ITEM_INFO_RECEIVED", 99999, true)
check(DB().n == 5 and DB().facts[5].key == "99999" and DB().facts[5].name == "Mystery Epic", "uncached epic recorded once item data arrives")
STUB.fire("GET_ITEM_INFO_RECEIVED", 99999, true)
check(DB().n == 5, "late item data does not duplicate")

-- Boss kills.
STUB.groupCount = 3
STUB.group = { party1 = "Player-1234-00000002", party2 = "Player-1234-00000003" }
STUB.fire("ENCOUNTER_END", 3001, "Deathulus", 1, 5, 1)
local k = DB().facts[6]
check(DB().n == 6 and k.k == "kill" and k.key == "3001" and k.name == "Deathulus" and k.size == 5 and #k.who == 2, "kill recorded with two witnesses")
STUB.fire("ENCOUNTER_END", 3001, "Deathulus", 1, 5, 0)
check(DB().n == 6 and me.kills["3001"] == 1, "wipe ignored and kill count stays 1")
STUB.fire("ENCOUNTER_END", 3001, "Deathulus", 1, 5, 1)
check(DB().n == 6 and me.kills["3001"] == 2, "second kill counted, not a second fact")
STUB.fire("ENCOUNTER_END", nil, "Nameless Boss", 1, 5, 1)
check(DB().n == 7 and DB().facts[7].key == "Nameless Boss", "kill without an id is keyed by name")

-- Deaths.
STUB.fire("PLAYER_DEAD")
STUB.fire("PLAYER_DEAD")
check(me.deaths == 2 and DB().n == 8 and DB().facts[8].k == "dead", "deaths counted and only the first is a fact")

-- Professions crossing a mark.
STUB.profs[1][3] = 151
STUB.fire("SKILL_LINES_CHANGED")
STUB.fire("SKILL_LINES_CHANGED")
check(#STUB.timers == 1, "skill updates are debounced to one timer")
STUB.runTimers()
check(DB().n == 9 and DB().facts[9].k == "skill" and DB().facts[9].key == "185:150" and DB().facts[9].lvl == 151, "cooking 150 recorded")
check(me.skills[185].lvl == 151, "skill snapshot updated")

-- Renown tracks.
STUB.fire("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", 2800, 3, 2)
check(DB().n == 10 and DB().facts[10].k == "rank" and DB().facts[10].key == "3" and me.pvp_rank == 3, "pvp rank recorded")
STUB.fire("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", 2802, 2, 1)
check(DB().n == 11 and DB().facts[11].k == "legacy", "legacy track recorded")
STUB.fire("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", 2587, 3, 2)
check(DB().n == 11, "other factions ignored")

-- A live achievement.
STUB.fire("ACHIEVEMENT_EARNED", 61500, false)
check(DB().n == 12 and DB().facts[12].k == "ach" and DB().facts[12].name == "Experienced Warrior" and DB().facts[12].pre == nil, "live achievement recorded")
STUB.fire("ACHIEVEMENT_EARNED", 900, false)
check(DB().n == 12, "statistic ignored")
STUB.fire("ACHIEVEMENT_EARNED", 61499, true)
check(DB().n == 12, "already back-filled challenge not duplicated")

-- Slash commands.
SlashCmdList.FLAVORTOWN("")
check(lastLine():find("12 milestones on file") ~= nil and lastLine():find("Biscuit Flavortown") ~= nil, "status shows count and name")
SlashCmdList.FLAVORTOWN("link wdjb-mjht")
check(me.link == "WDJBMJHT" and me.linked_at ~= nil, "link code stored as letters only")
SlashCmdList.FLAVORTOWN("link ab")
check(me.link == "WDJBMJHT" and lastLine():find("usage") ~= nil, "short code refused")
SlashCmdList.FLAVORTOWN("off")
STUB.fire("PLAYER_LEVEL_UP", 9)
check(DB().n == 12 and DB().off == true, "off stops recording")
SlashCmdList.FLAVORTOWN("on")
STUB.fire("PLAYER_LEVEL_UP", 9)
check(DB().n == 13 and DB().off == false, "on resumes recording")
SlashCmdList.FLAVORTOWN("quiet")
check(DB().quiet == true, "quiet toggles")
SlashCmdList.FLAVORTOWN("quiet")
SlashCmdList.FLAVORTOWN("save")
check(STUB.reloads == 1, "save reloads the interface")
SlashCmdList.FLAVORTOWN("nonsense")
check(lastLine():find("commands:") ~= nil, "unknown command lists commands")
SlashCmdList.FLAVORTOWN("debug")
check(lastLine():find("0 errors ever") ~= nil, "no handler errored")

-- Logout.
STUB.fire("PLAYER_LOGOUT")
check(DB().saved_at == STUB.server and me.last_seen == STUB.server, "saved_at and last_seen set at logout")

-- /reload with the same file: a fresh frame, the index rebuilt, no duplicates.
STUB.unknownEvents = { MAJOR_FACTION_RENOWN_LEVEL_CHANGED = true }
STUB.loadAddon()
STUB.fire("ADDON_LOADED", "FlavorTown")
STUB.fire("PLAYER_ENTERING_WORLD", false, true)
check(DB().n == 13 and DB().chars[GUID].level_at_install == 7, "reload keeps data and level at install")
STUB.fire("PLAYER_LEVEL_UP", 9)
check(DB().n == 13, "index rebuilt from the file, so an old ding is not duplicated")
STUB.fire("PLAYER_LEVEL_UP", 10)
check(DB().n == 14, "new ding still recorded after reload")
STUB.fire("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", 2800, 4, 3)
check(DB().n == 14, "an event the client lacks is skipped at load, not fatal")
SlashCmdList.FLAVORTOWN("debug")
check(lastLine():find("0 errors ever") ~= nil, "still no swallowed errors")

-- Wipe.
SlashCmdList.FLAVORTOWN("wipe")
check(DB().n == 14, "wipe without yes does nothing")
SlashCmdList.FLAVORTOWN("wipe yes")
check(DB().n == 0 and DB().chars[GUID] ~= nil and DB().chars[GUID].level_at_install == 8, "wipe clears facts and re-identifies")

-- Show the shape the website will read.
local function dump(t, indent, seen)
  indent = indent or ""
  seen = seen or {}
  if type(t) ~= "table" then return tostring(t) end
  if seen[t] then return "<cycle>" end
  seen[t] = true
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local out = { "{" }
  for _, k in ipairs(keys) do
    local v = t[k]
    if type(v) == "table" then
      out[#out + 1] = indent .. "  " .. tostring(k) .. " = " .. dump(v, indent .. "  ", seen)
    else
      out[#out + 1] = indent .. "  " .. tostring(k) .. " = " .. (type(v) == "string" and string.format("%q", v) or tostring(v))
    end
  end
  out[#out + 1] = indent .. "}"
  return table.concat(out, "\n")
end
print("DB after wipe:")
print(dump(DB()))

if STUB.failed > 0 then error("FAILED " .. STUB.failed .. " checks", 0) end
print("ALL CHECKS PASSED")
