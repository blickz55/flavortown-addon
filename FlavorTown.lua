-- Flavor Town
-- Records your WoW: Forever milestones so you can bring them to flavortown.beer.
--
-- An addon cannot reach the internet, and this one does not try. Everything it
-- notices is kept in memory and written by the game client to
--   _forever_\WTF\Account\<account>\SavedVariables\FlavorTown.lua
-- when you log out, quit, or type /reload (or /ft save). You decide if and when
-- that file reaches the website.
--
-- It records facts, not judgments. Who was first, who can see what, and what any
-- of it is worth is decided on the website, so this file rarely needs to change.
--
-- Nothing here is minified or obfuscated. Read it.

local ADDON_NAME = ...
local VERSION = "0.1.0"
local SCHEMA = 1          -- bump when the shape of FlavorTownDB changes
local FACTS_CAP = 4000    -- the file stays small; nothing here grows without bound

-- Midnight-era clients hand addons "secret" values inside instances and combat.
-- Comparing one raises an error, so every value from outside goes through clean().
local issecret = issecretvalue or function() return false end
local function clean(v)
  if v == nil or issecret(v) then return nil end
  return v
end

local db          -- FlavorTownDB, once the client has loaded it
local me          -- db.chars[guid] for the character logged in
local guid        -- UnitGUID("player")
local index = {}  -- "guid|kind|key" -> true, so a fact is recorded once
local session = { facts = 0, errors = 0, greeted = false }

-- Server time is the one clock a player cannot move. The PC clock rides along in
-- each fact so the website can spot a machine whose clock is off.
local function now()
  local ok, t = pcall(GetServerTime)
  if ok and type(t) == "number" and t > 0 then return t end
  return time()
end

local function say(text)
  print("|cffff7a00Flavor Town|r " .. tostring(text))
end

-- Every handler runs inside guard(). A bug in one tracker never stops the others
-- and never throws a Lua error at a dad mid-pull.
local function guard(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then
      session.errors = session.errors + 1
      if db then
        db.errors = (db.errors or 0) + 1
        db.last_error = tostring(err)
      end
      if session.errors == 1 then
        say("hit a snag and kept recording. /ft debug shows it.")
      end
    end
  end
end

-- Which ruleset this character plays on. GetRealmName() is not used: in the beta
-- it returned a label like "Classic Beta PvE", and Forever has no realms.
local function ruleset()
  local rules = Enum and Enum.GameRule
  if not (rules and C_GameRules and C_GameRules.IsGameRuleActive) then return nil end
  local function active(rule)
    if rule == nil then return nil end
    local ok, on = pcall(C_GameRules.IsGameRuleActive, rule)
    if ok then return on == true end
    return nil
  end
  local hc, pvp, rp = active(rules.HardcoreRuleset), active(rules.PvPRuleset), active(rules.RPRuleset)
  if hc == nil and pvp == nil and rp == nil then return nil end
  if hc then return "hardcore" end
  if pvp and rp then return "rppvp" end
  if pvp then return "pvp" end
  if rp then return "rp" end
  return "normal"
end

local function noteGuild()
  if not me then return end
  local ok, name = pcall(GetGuildInfo, "player")
  if ok and name ~= nil then me.guild = clean(name) end
end

-- The character is keyed by GUID, which survives a rename. The name is kept for
-- display. In Forever the second value from UnitNameUnmodified is the surname.
local function identify()
  local ok, g = pcall(UnitGUID, "player")
  g = ok and clean(g) or nil
  if type(g) ~= "string" then return false end
  guid = g
  db.chars[guid] = db.chars[guid] or { first_seen = now() }
  me = db.chars[guid]

  local _, name, surname = pcall(UnitNameUnmodified, "player")
  me.name = clean(name) or me.name
  me.surname = clean(surname) or me.surname

  local _, classFile, classID = pcall(UnitClassBase, "player")
  me.class = clean(classFile) or me.class
  me.class_id = clean(classID) or me.class_id

  local _, _, raceFile, raceID = pcall(UnitRace, "player")
  me.race = clean(raceID) or me.race
  me.race_file = clean(raceFile) or me.race_file

  local _, faction = pcall(UnitFactionGroup, "player")
  me.faction = clean(faction) or me.faction

  local _, level = pcall(UnitLevel, "player")
  level = clean(level)
  if type(level) == "number" then
    -- Levels reached before the addon was installed have no timestamp and are
    -- never invented. The website shows them as before tracking.
    if not me.level_at_install then me.level_at_install = level end
    me.level = level
  end

  me.ruleset = ruleset() or me.ruleset
  me.last_seen = now()
  me.addon = VERSION
  noteGuild()
  return true
end

local function factKey(c, kind, key)
  return c .. "|" .. kind .. "|" .. key
end

-- record() stores one fact once. kind is what happened (level, ach, loot, craft,
-- kill, skill, rank, legacy, dead); key makes it unique for this character (the
-- level, the achievement id, the item id, the encounter); extra carries details.
local function record(kind, key, extra)
  if not db or db.off or not guid then return nil end
  key = tostring(key)
  local id = factKey(guid, kind, key)
  if index[id] then return nil end
  if #db.facts >= FACTS_CAP then return nil end
  local fact = { c = guid, k = kind, key = key, at = now(), lt = time() }
  if extra then
    for name, value in pairs(extra) do
      if not issecret(value) then fact[name] = value end
    end
  end
  db.facts[#db.facts + 1] = fact
  index[id] = true
  db.n = #db.facts
  session.facts = session.facts + 1
  return fact
end

-- Levels

local function onLevelUp(level)
  level = clean(level)
  if type(level) ~= "number" then return end
  if not me and not identify() then return end
  me.level = level
  record("level", level)
end

-- Achievements. In Forever these are the Legacy Challenges and the Explore
-- achievements. Statistics also fire this event and are skipped.

local function onAchievement(id, alreadyEarned)
  id = clean(id)
  if type(id) ~= "number" then return end
  if not me and not identify() then return end
  -- GetAchievementInfo: id, name, points, completed, month, day, year, description,
  -- flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy, isStatistic
  local a = { pcall(GetAchievementInfo, id) }
  if a[1] and a[16] then return end
  record("ach", id, { name = a[1] and clean(a[3]) or nil, again = alreadyEarned and true or nil })
end

-- Challenges earned before the addon was installed carry Blizzard's own completion
-- date (month, day and year, with no time). They are stored with that date and
-- marked pre = true, so the website treats them as before tracking.
local function backfill()
  if not me or me.backfilled then return end
  if not (GetCategoryList and GetCategoryNumAchievements and GetAchievementInfo) then return end
  local ok, cats = pcall(GetCategoryList)
  if not ok or type(cats) ~= "table" then return end
  for _, cat in ipairs(cats) do
    local okN, total = pcall(GetCategoryNumAchievements, cat, true)
    for i = 1, (okN and tonumber(total) or 0) do
      local a = { pcall(GetAchievementInfo, cat, i) }
      if a[1] and type(a[2]) == "number" and a[5] and not a[16] then
        record("ach", a[2], {
          name = clean(a[3]), pre = true, mine = a[14] and true or false,
          m = clean(a[6]), d = clean(a[7]), y = clean(a[8]),
        })
      end
    end
  end
  me.backfilled = now()
end

-- Loot. Lines are matched against the client's own localized strings, never
-- against English, and only epics and better are kept, with their binding, so the
-- website can tell a world drop from a crafted or bought piece.

local lootPatterns  -- { { pattern, kind }, ... }
local pending = {}  -- itemID -> kind, while the client fetches item data

local function toPattern(s)
  s = s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")  -- escape pattern magic
  s = s:gsub("%%%%%d%%%$s", "(.-)")                   -- %1$s
  s = s:gsub("%%%%s", "(.-)")                         -- %s
  s = s:gsub("%%%%%d%%%$d", "%%d+")                   -- %1$d
  s = s:gsub("%%%%d", "%%d+")                         -- %d
  return "^" .. s .. "$"
end

local function buildLootPatterns()
  lootPatterns = {}
  local function add(global, kind)
    local s = _G[global]
    if type(s) == "string" and s ~= "" then
      lootPatterns[#lootPatterns + 1] = { toPattern(s), kind }
    end
  end
  add("LOOT_ITEM_SELF_MULTIPLE", "loot")          -- You receive loot: %sx%d.
  add("LOOT_ITEM_SELF", "loot")                   -- You receive loot: %s.
  add("LOOT_ITEM_CREATED_SELF_MULTIPLE", "craft")
  add("LOOT_ITEM_CREATED_SELF", "craft")          -- You create: %s.
end

local function judgeItem(itemID, kind)
  local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not getInfo then return end
  -- GetItemInfo: name, link, quality, itemLevel, minLevel, type, subType, stackCount,
  -- equipLoc, texture, sellPrice, classID, subclassID, bindType, ...
  local r = { pcall(getInfo, itemID) }
  local quality = r[1] and clean(r[4]) or nil
  if type(quality) ~= "number" then
    pending[itemID] = kind   -- not cached yet; GET_ITEM_INFO_RECEIVED finishes this
    return
  end
  pending[itemID] = nil
  if quality < 4 then return end
  record(kind, itemID, { name = clean(r[2]), q = quality, il = clean(r[5]), b = clean(r[15]) })
end

local function onLoot(text)
  text = clean(text)
  if type(text) ~= "string" or not lootPatterns then return end
  if not me and not identify() then return end
  for _, p in ipairs(lootPatterns) do
    if text:match(p[1]) then
      local itemID = tonumber(text:match("|Hitem:(%d+)"))
      if itemID then judgeItem(itemID, p[2]) end
      return
    end
  end
end

local function onItemInfo(itemID, success)
  itemID = clean(itemID)
  local kind = itemID and pending[itemID]
  if not kind then return end
  if clean(success) == false then
    pending[itemID] = nil
    return
  end
  judgeItem(itemID, kind)
end

-- Boss kills. The encounter id is kept with its name, because the client does not
-- yet carry ids for every new dungeon or raid, and the guildmates present are
-- recorded so the website has witnesses.

local function onEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
  success = clean(success)
  if not (success == 1 or success == true) then return end
  if not me and not identify() then return end
  encounterID, encounterName = clean(encounterID), clean(encounterName)
  local key = encounterID and tostring(encounterID) or (encounterName or "unknown")
  me.kills = me.kills or {}
  me.kills[key] = (me.kills[key] or 0) + 1

  local who = {}
  local _, count = pcall(GetNumGroupMembers)
  local _, inRaid = pcall(IsInRaid)
  for i = 1, (clean(count) or 0) do
    local ok, g = pcall(UnitGUID, (inRaid and "raid" or "party") .. i)
    g = ok and clean(g) or nil
    if type(g) == "string" and g ~= guid then who[#who + 1] = g end
  end
  record("kill", key, { name = encounterName, diff = clean(difficultyID), size = clean(groupSize), who = who })
end

-- Deaths are counted, and only the first one is a fact. Whether anyone sees them
-- is the website's call.

local function onDeath()
  if not me and not identify() then return end
  me.deaths = (me.deaths or 0) + 1
  if me.deaths == 1 then record("dead", 1, { level = me.level }) end
end

-- Forever's PvP rank (faction 2800) and the Legacy reward track (faction 2802) are
-- renown-style tracks and announce each new level.

local function onRenown(factionID, newLevel)
  factionID, newLevel = clean(factionID), clean(newLevel)
  if type(factionID) ~= "number" or type(newLevel) ~= "number" then return end
  if not me and not identify() then return end
  if factionID == 2800 then
    me.pvp_rank = newLevel
    record("rank", newLevel)
  elseif factionID == 2802 then
    me.legacy_track = newLevel
    record("legacy", newLevel)
  end
end

-- Professions. Each skill line's level is kept, and crossing 75, 150, 225 or 300
-- is a fact. A line already past a mark when first seen gets no fact, because its
-- time is unknown.

local SKILL_LINES = {
  [129] = "First Aid", [164] = "Blacksmithing", [165] = "Leatherworking", [171] = "Alchemy",
  [182] = "Herbalism", [185] = "Cooking", [186] = "Mining", [197] = "Tailoring",
  [202] = "Engineering", [333] = "Enchanting", [356] = "Fishing", [393] = "Skinning",
  [762] = "Riding",
}
local SKILL_MARKS = { 75, 150, 225, 300 }

local function noteSkill(line, level, max, name)
  line, level = clean(line), clean(level)
  if type(line) ~= "number" or type(level) ~= "number" then return end
  me.skills = me.skills or {}
  local prev = me.skills[line]
  me.skills[line] = { lvl = level, max = clean(max), name = SKILL_LINES[line] or clean(name) }
  if not prev then return end
  for _, mark in ipairs(SKILL_MARKS) do
    if level >= mark and prev.lvl < mark then
      record("skill", line .. ":" .. mark, { name = SKILL_LINES[line] or clean(name), lvl = level })
    end
  end
end

local function snapshotSkills()
  if not me and not identify() then return end
  local found = false
  if GetProfessions and GetProfessionInfo then
    local r = { pcall(GetProfessions) }
    if r[1] then
      for i = 2, 7 do
        if r[i] then
          -- GetProfessionInfo: name, icon, skillLevel, maxSkillLevel, numAbilities,
          -- spellOffset, skillLine
          local p = { pcall(GetProfessionInfo, r[i]) }
          if p[1] and type(clean(p[8])) == "number" and type(clean(p[4])) == "number" then
            found = true
            noteSkill(p[8], p[4], p[5], p[2])
          end
        end
      end
    end
  end
  if not found and C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID then
    for line in pairs(SKILL_LINES) do
      local ok, info = pcall(C_SkillInfo.GetSkillLineInfoByID, line)
      if ok and type(info) == "table" then
        local level = clean(info.skillLevel) or clean(info.currentLevel) or clean(info.rank)
        local max = clean(info.maxSkillLevel) or clean(info.maxLevel) or clean(info.maxRank)
        if type(level) == "number" and level > 0 then
          noteSkill(line, level, max, info.name or info.skillLineName)
        end
      end
    end
  end
end

local skillTimer
local function scheduleSkills()
  if skillTimer then return end
  if not (C_Timer and C_Timer.After) then
    snapshotSkills()
    return
  end
  skillTimer = true
  C_Timer.After(2, guard(function()
    skillTimer = nil
    snapshotSkills()
  end))
end

-- Chat

local function greet()
  if session.greeted or not db or db.quiet then return end
  session.greeted = true
  say(string.format("v%s is recording%s. %d on file. /ft for status, /ft save to write to disk.",
    VERSION, db.off and " nothing: it is switched off (/ft on)" or "", db.n or 0))
end

local function status()
  if not db then
    say("is not loaded yet.")
    return
  end
  local who = me and ((me.name or "?") .. " " .. (me.surname or "")) or "?"
  say(string.format(
    "v%s. %s, level %s, %s. %d milestones on file, %d new since login (written at logout or /ft save). Recording is %s.",
    VERSION, who, tostring(me and me.level or "?"), (me and me.ruleset) or "ruleset unknown",
    db.n or 0, session.facts, db.off and "OFF" or "on"))
end

SLASH_FLAVORTOWN1 = "/ft"
SLASH_FLAVORTOWN2 = "/flavortown"
SlashCmdList.FLAVORTOWN = guard(function(msg)
  msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, rest = msg:match("^(%S*)%s*(.*)$")
  cmd = (cmd or ""):lower()
  if not db then
    say("is not loaded yet.")
  elseif cmd == "" or cmd == "status" then
    status()
  elseif cmd == "save" then
    say("writing to disk by reloading the interface.")
    if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
  elseif cmd == "off" then
    db.off = true
    say("switched off. Nothing is recorded until /ft on.")
  elseif cmd == "on" then
    db.off = false
    say("recording again.")
  elseif cmd == "quiet" then
    db.quiet = not db.quiet
    say(db.quiet and "login line hidden. /ft quiet brings it back." or "login line is back.")
  elseif cmd == "link" then
    local code = (rest or ""):upper():gsub("[^A-Z]", "")
    if #code < 6 then
      say("usage: /ft link CODE, with the code from flavortown.beer/me.")
    elseif me then
      me.link = code
      me.linked_at = now()
      say(string.format("code %s stored for %s. It takes effect at your next upload.", code, me.name or "this character"))
    end
  elseif cmd == "debug" then
    say(string.format("schema %d, addon %s, client %s build %s, interface %s. %d errors ever. Last: %s",
      db.v or 0, db.addon or "?", (db.client and db.client.version) or "?", (db.client and db.client.build) or "?",
      tostring(db.client and db.client.interface or "?"), db.errors or 0, db.last_error or "none"))
  elseif cmd == "wipe" then
    if rest == "yes" then
      db.chars, db.facts, db.n, index, me = {}, {}, 0, {}, nil
      identify()
      say("wiped. Everything recorded on this PC is gone. The website keeps what you already uploaded.")
    else
      say("/ft wipe yes erases everything recorded on this PC.")
    end
  else
    say("commands: /ft, /ft save, /ft link CODE, /ft off, /ft on, /ft quiet, /ft debug, /ft wipe yes")
  end
end)

-- Loading

local function init()
  if type(FlavorTownDB) ~= "table" then FlavorTownDB = {} end
  db = FlavorTownDB
  db.v = SCHEMA
  db.addon = VERSION
  db.chars = type(db.chars) == "table" and db.chars or {}
  db.facts = type(db.facts) == "table" and db.facts or {}
  db.installed = db.installed or now()
  index = {}
  for _, fact in ipairs(db.facts) do
    if type(fact) == "table" and fact.c and fact.k and fact.key then
      index[factKey(fact.c, fact.k, fact.key)] = true
    end
  end
  db.n = #db.facts
  local ok, version, build, _, interface = pcall(GetBuildInfo)
  if ok then db.client = { version = clean(version), build = clean(build), interface = clean(interface) } end
  db.project = WOW_PROJECT_ID
  buildLootPatterns()
end

local frame = CreateFrame("Frame")
local handlers = {
  ADDON_LOADED = function(name)
    if name == ADDON_NAME then init() end
  end,
  PLAYER_ENTERING_WORLD = function()
    if not db then return end
    identify()
    scheduleSkills()
    if C_Timer and C_Timer.After then C_Timer.After(8, guard(backfill)) else backfill() end
    greet()
  end,
  PLAYER_LEVEL_UP = onLevelUp,
  ACHIEVEMENT_EARNED = onAchievement,
  CHAT_MSG_LOOT = onLoot,
  GET_ITEM_INFO_RECEIVED = onItemInfo,
  ENCOUNTER_END = onEncounterEnd,
  PLAYER_DEAD = onDeath,
  SKILL_LINES_CHANGED = scheduleSkills,
  MAJOR_FACTION_RENOWN_LEVEL_CHANGED = onRenown,
  PLAYER_GUILD_UPDATE = noteGuild,
  PLAYER_LOGOUT = function()
    -- The last moment before the client writes the file.
    if me then me.last_seen = now() end
    if db then db.saved_at = now() end
  end,
}
for event, handler in pairs(handlers) do
  handlers[event] = guard(handler)
  pcall(frame.RegisterEvent, frame, event)  -- an event this client lacks is skipped, not fatal
end
frame:SetScript("OnEvent", function(_, event, ...)
  local handler = handlers[event]
  if handler then handler(...) end
end)
