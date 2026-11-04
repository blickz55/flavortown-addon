// Runs FlavorTown.lua under fengari (Lua in JavaScript) with the stand-in WoW API
// in prelude.lua, then the scenario in test.lua.
// Usage: node run.cjs [path to FlavorTown.lua]
const fs = require("fs");
const path = require("path");
const fengari = require("fengari");
const { lua, lauxlib, lualib, to_luastring } = fengari;

const addonPath = process.argv[2] || path.join(__dirname, "..", "FlavorTown.lua");

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

function fail(stage) {
  console.error(`[${stage}] ${lua.lua_tojsstring(L, -1)}`);
  process.exit(1);
}

function run(stage, src) {
  if (lauxlib.luaL_loadstring(L, to_luastring(src)) !== lua.LUA_OK) fail(stage + " load");
  if (lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) fail(stage + " run");
}

const addonSrc = fs.readFileSync(addonPath, "utf8");
lua.lua_pushstring(L, to_luastring(addonSrc));
lua.lua_setglobal(L, to_luastring("ADDON_SOURCE"));

run("prelude", fs.readFileSync(path.join(__dirname, "prelude.lua"), "utf8"));
run("test", fs.readFileSync(path.join(__dirname, "test.lua"), "utf8"));
