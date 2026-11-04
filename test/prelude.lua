-- Stand-in WoW API for running FlavorTown.lua offline under fengari (Lua 5.3).
-- This is not the game. It covers only what the addon touches, so a green run
-- means the logic holds, not that the live client behaves this way.

time = os.time
date = os.date
WOW_PROJECT_ID = 18
WOW_PROJECT_CAMELOT = 18

STUB = { timers = {}, printed = {}, frames = {}, reloads = 0, failed = 0 }

local realprint = print
print = function(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  local line = table.concat(parts, " ")
  STUB.printed[#STUB.printed + 1] = line
  realprint(line)
end

-- Midnight's secret values: anything equal to "SECRET" counts as one here.
issecretvalue = function(v) return v == "SECRET" end

STUB.server = 1793840000
function GetServerTime() return STUB.server end
function GetBuildInfo() return "1.60.1", "70755", "Nov 3 2026", 16001 end

STUB.player = {
  guid = "Player-1234-0000ABCD", name = "Biscuit", surname = "Flavortown",
  classFile = "WARRIOR", classID = 1, raceName = "Orc", raceFile = "Orc", raceID = 2,
  faction = "Horde", level = 7, guild = "Flavor Town",
}
STUB.group = {}
function UnitGUID(unit)
  if unit == "player" then return STUB.player.guid end
  return STUB.group[unit]
end
function UnitNameUnmodified(unit) return STUB.player.name, STUB.player.surname end
function UnitClassBase(unit) return STUB.player.classFile, STUB.player.classID end
function UnitRace(unit) return STUB.player.raceName, STUB.player.raceFile, STUB.player.raceID end
function UnitFactionGroup(unit) return STUB.player.faction, STUB.player.faction end
function UnitLevel(unit) return STUB.player.level end
function GetGuildInfo(unit) return STUB.player.guild, "Dad", 3 end
function GetNumGroupMembers() return STUB.groupCount or 0 end
function IsInRaid() return STUB.inRaid or false end

Enum = { GameRule = { PvPRuleset = 1, RPRuleset = 2, HardcoreRuleset = 3 } }
C_GameRules = { IsGameRuleActive = function(rule) return rule == 1 end }

function CreateFrame(kind)
  local f = { events = {}, scripts = {} }
  function f:RegisterEvent(e)
    if STUB.unknownEvents and STUB.unknownEvents[e] then
      error("Attempt to register unknown event \"" .. e .. "\"")
    end
    self.events[e] = true
  end
  function f:SetScript(name, fn) self.scripts[name] = fn end
  STUB.frames[#STUB.frames + 1] = f
  return f
end
function STUB.fire(event, ...)
  for _, f in ipairs(STUB.frames) do
    if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
  end
end

C_Timer = { After = function(delay, fn) STUB.timers[#STUB.timers + 1] = fn end }
function STUB.runTimers()
  local t = STUB.timers
  STUB.timers = {}
  for _, fn in ipairs(t) do fn() end
end

C_UI = { Reload = function() STUB.reloads = STUB.reloads + 1 end }
ReloadUI = C_UI.Reload
SlashCmdList = {}

LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
LOOT_ITEM_CREATED_SELF = "You create: %s."
LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %sx%d."

STUB.items = {
  [19019] = { name = "Thunderfury, Blessed Blade of the Windseeker", quality = 5, ilvl = 80, bind = 1 },
  [14152] = { name = "Robe of the Archmage", quality = 4, ilvl = 62, bind = 2 },
  [2589] = { name = "Linen Cloth", quality = 1, ilvl = 5, bind = 0 },
}
C_Item = {
  GetItemInfo = function(id)
    local it = STUB.items[id]
    if not it then return nil end
    return it.name, "|Hitem:" .. id .. "::|h[" .. it.name .. "]|h", it.quality, it.ilvl, 1,
      "Armor", "Cloth", 1, "INVTYPE_ROBE", 123, 1, 4, 1, it.bind, 0, 0, false
  end,
}

STUB.achievements = {
  [61499] = { name = "Novice Warrior", completed = true, m = 11, d = 4, y = 26, mine = true, stat = false },
  [61500] = { name = "Experienced Warrior", completed = false },
  [62382] = { name = "Explorer", completed = false },
  [900] = { name = "Deaths from falling", completed = true, stat = true },
}
local catIndex = { [1] = { 61499, 61500 }, [2] = { 62382, 900 } }
function GetCategoryList() return { 1, 2 } end
function GetCategoryNumAchievements(cat)
  local n = #(catIndex[cat] or {})
  return n, 0, n
end
function GetAchievementInfo(a, b)
  local id = a
  if b then id = (catIndex[a] or {})[b] end
  local x = STUB.achievements[id]
  if not x then return nil end
  return id, x.name, 10, x.completed, x.m, x.d, x.y, "desc", 0, 123, "", false, x.mine, "", x.stat or false
end

-- name, icon, skillLevel, maxSkillLevel, numAbilities, spellOffset, skillLine
STUB.profs = { [1] = { "Cooking", 1, 148, 150, 1, 0, 185 }, [2] = { "First Aid", 1, 75, 150, 1, 0, 129 } }
function GetProfessions() return 1, 2 end
function GetProfessionInfo(i)
  local p = STUB.profs[i]
  if p then return p[1], p[2], p[3], p[4], p[5], p[6], p[7] end
end

-- Loads the addon the way a /reload would: a fresh frame, the same saved data.
function STUB.loadAddon()
  STUB.frames = {}
  STUB.timers = {}
  local fn = assert(load(ADDON_SOURCE, "=FlavorTown.lua"))
  fn("FlavorTown")
end
