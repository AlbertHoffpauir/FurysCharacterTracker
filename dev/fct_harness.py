"""Runs Fury's Character Tracker outside the game, in a Lua 5.1 runtime.

Two modes:

  game    the whole addon, with a stand-in for the ESO API (stub.lua). Proves the code loads, that
          every global it touches is a documented ESO API name (or a known ESO UI Lua helper), that
          every control method it calls exists, and that the windows draw what Core/Board.lua says.
  viewer  only the addon's shared files (first line "-- shared") with the offline viewer's small
          stand-in (shim.lua): what the offline viewer runs, minus the browser.

Both write the same kind of dump (dump.lua): every tab, cell, hover text and page for every account
in the saved file. Two dumps can be compared with diff.

    python3 fct_harness.py game   <addon folder> <saved file or -> <@account> <world> <out file> [scenario.lua]
    python3 fct_harness.py viewer <addon folder> <saved file> <out file>

Needs: pip install lupa, and the ESO API documentation text file (ESOUIDocumentation.txt) given in
the FCT_API_DOC environment variable.
"""
import os, re, sys
from lupa import lua51

HERE = os.path.dirname(os.path.abspath(__file__))
MODE, ADDON = sys.argv[1], sys.argv[2]
DOC = os.environ.get("FCT_API_DOC", os.path.join(HERE, "ref", "ESOUIDocumentation.txt"))
NOW = int(os.environ.get("FCT_NOW", "1795600000"))


def read(path):
    return open(path, encoding="utf-8").read()


def manifest_files():
    files = []
    for line in open(os.path.join(ADDON, "FurysCharacterTracker.txt"), encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#") and not line.startswith(";"):
            files.append(line)
    for rel in files:
        if not os.path.exists(os.path.join(ADDON, rel)):
            raise SystemExit("manifest lists a missing file: " + rel)
    return files


def shared_files():
    """The Lua files both the game and the offline viewer run, in manifest order."""
    return [f for f in manifest_files() if f.endswith(".lua") and read(os.path.join(ADDON, f)).startswith("-- shared")]


lua = lua51.LuaRuntime(unpack_returned_tuples=True)
G = lua.globals()
run_file = lua.eval("function(src, name) local f, err = loadstring(src, name); if not f then error(err) end; return f() end")


def write_out(path, text):
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


# ---- viewer mode ---------------------------------------------------------------------------------
if MODE == "viewer":
    SAVED, OUT = sys.argv[3], sys.argv[4]
    run_file(read(os.path.join(HERE, "shim.lua")), "@shim.lua")
    G.VIEWER_NOW = NOW
    # Anything the shared files reach for that is not there is a game call in the wrong file.
    lua.execute('''
        MISSING = {}
        setmetatable(_G, { __index = function(_, key)
            if type(key) == "string" and not key:match("^EVENT_") and key ~= "FuryCT_SV" and key ~= "setfenv" and key ~= "loadstring" then
                if not MISSING[key] then MISSING[key] = true; MISSING[#MISSING + 1] = key end
            end
        end })''')
    files = shared_files()
    for rel in files:
        run_file(read(os.path.join(ADDON, rel)), "@" + rel)
    for path in SAVED.split(","):
        if not lua.eval("FCT_AddSaved")(read(path)):
            raise SystemExit("could not read " + path)
    lua.execute("FurysCharacterTracker.UpgradeAll(); FurysCharacterTracker.view = FurysCharacterTracker.Accounts()[1]")
    run_file(read(os.path.join(HERE, "dump.lua")), "@dump.lua")
    write_out(OUT, lua.eval("FCT_Dump(true)"))
    missing = [x for x in G.MISSING.values() if isinstance(x, str)]
    print("shared files:", len(files))
    print("game names the shared files reached for:", len(missing), " ".join(missing))
    sys.exit(1 if missing else 0)

# ---- game mode -----------------------------------------------------------------------------------
SAVED, ACCOUNT, WORLD, OUT = sys.argv[3:7]
SCENARIO = sys.argv[7] if len(sys.argv) > 7 else None

if not os.path.exists(DOC):
    raise SystemExit("ESO API documentation not found: set FCT_API_DOC to ESOUIDocumentation.txt (it comes with each game update on the ESOUI wiki)")
funcs, consts, methods, events = set(), set(), set(), set()
section = None
for line in open(DOC, encoding="utf-8", errors="replace"):
    if line.startswith("h2. "):
        section = line[4:].strip()
        continue
    m = re.match(r"\* ([A-Za-z_][A-Za-z0-9_]*)", line)
    if not m:
        continue
    name = m.group(1)
    if section == "Global Variables":
        consts.add(name)
    elif section in ("Game API", "VM Functions"):
        funcs.add(name)
    elif section == "Object API":
        methods.add(name)
    elif section == "Events":
        events.add(name)

G.PY_IS_FUNC = lambda n: n in funcs or n in methods
G.PY_IS_CONST = lambda n: n in consts or n in events
G.PY_IS_METHOD = lambda n: n in methods
G.HOME_ACCOUNT = ACCOUNT
G.HOME_WORLD = WORLD
G.NOW = NOW
run_file(read(os.path.join(HERE, "stub.lua")).replace("NOW = 1795600000\n", "", 1), "@stub.lua")

if SAVED != "-":
    lua.execute(read(SAVED))

# The optional library Fury's Addons Menu (FurysAddonMenu), loaded before the addon as the game
# does (a copy in dev/vendor). FCT_NO_MENU_LIB=1 runs without it, as for a player who has not
# installed it.
if os.environ.get("FCT_NO_MENU_LIB") != "1":
    run_file(read(os.path.join(HERE, "vendor", "FurysAddonMenu.lua")), "@FurysAddonMenu.lua")
    lua.execute('Fire(EVENT_ADD_ON_LOADED, "FurysAddonMenu")')

files = manifest_files()
for rel in files:
    if rel.endswith(".lua"):
        run_file(read(os.path.join(ADDON, rel)), "@" + rel)
lua.execute('Fire(EVENT_ADD_ON_LOADED, "SomethingElse"); Fire(EVENT_ADD_ON_LOADED, "FurysCharacterTracker")')
run_file(read(os.path.join(HERE, "dump.lua")), "@dump.lua")
run_file(read(os.path.join(HERE, "uicheck.lua")), "@uicheck.lua")

lua.execute("CALLS = 0; Fire(EVENT_PLAYER_ACTIVATED, true)")
lua.execute("Advance(4000)")
login_calls = G.CALLS

if SCENARIO:
    run_file(read(SCENARIO), "@" + os.path.basename(SCENARIO))
else:
    lua.execute("UICheck()")

write_out(OUT, lua.eval("FCT_Dump(true)"))
write_out(OUT + ".sv.lua", lua.eval("SavedFileText()"))
write_out(OUT + ".board", lua.eval("FCT_BoardLines()"))
ui = [x for x in G.UI_OUT.values() if isinstance(x, str)]
write_out(OUT + ".ui", "\n".join(ui) + "\n")
print("files loaded:", len(files))
print("game calls for the login read:", login_calls)
log = [x for x in G.LOG.values() if isinstance(x, str)]
print("chat lines:", len(log))
for l in log[:14]:
    print("   ", l)
problems = [x for x in G.PROBLEMS.values() if isinstance(x, str)]
print("problems:", len(problems))
for x in problems[:60]:
    print("   ", x)
print("dump ->", OUT, "and", OUT + ".ui")
sys.exit(1 if problems else 0)
