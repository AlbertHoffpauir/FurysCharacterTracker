"""Builds what ships from this repository.

    python3 dev/build.py viewer              the offline viewer template (WindowsTools/Viewer/viewer.html)
    python3 dev/build.py fill <out.html> <saved file> [...]
                                             what OfflineViewer.ps1 does on Windows: puts saved files into the template
    python3 dev/build.py release <out dir>   checks, then the ESOUI zip and the Windows Tools zip

The viewer template holds Fengari (dev/vendor, MIT), the viewer's small stand-in for the game
(dev/shim.lua), the addon's shared Lua files (the ones whose first line is "-- shared", in manifest
order) and the page (dev/viewer/). Build it again after any change to a shared file.
"""
import json, os, re, sys, zipfile

DEV = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(DEV)
ADDON = os.path.join(ROOT, "FurysCharacterTracker")
TOOLS = os.path.join(ROOT, "WindowsTools")
TEMPLATE = os.path.join(TOOLS, "Viewer", "viewer.html")


def read(path):
    return open(path, encoding="utf-8").read()


def manifest():
    lines = read(os.path.join(ADDON, "FurysCharacterTracker.txt")).splitlines()
    files = [l.strip() for l in lines if l.strip() and not l.startswith("#") and not l.startswith(";")]
    version = next(l.split(":", 1)[1].strip() for l in lines if l.startswith("## Version:"))
    return lines, files, version


def shared_files():
    _, files, _ = manifest()
    return [f for f in files if f.endswith(".lua") and read(os.path.join(ADDON, f)).startswith("-- shared")]


def script_json(value):
    """JSON that is safe inside a <script> block."""
    return json.dumps(value, ensure_ascii=False).replace("</", "<\\/").replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")


def build_viewer():
    fengari = read(os.path.join(DEV, "vendor", "fengari-web.js"))
    assert "</script" not in fengari.lower()
    lua = [{"name": "shim.lua", "text": read(os.path.join(DEV, "shim.lua"))}]
    lua += [{"name": f, "text": read(os.path.join(ADDON, f))} for f in shared_files()]
    lua.append({"name": "viewer.lua", "text": read(os.path.join(DEV, "viewer", "viewer.lua"))})
    page = read(os.path.join(DEV, "viewer", "page.html"))
    assert page.count("/*FENGARI*/") == 1 and page.count("/*LUA*/[]") == 1 and page.count('"__FCT_FILES__"') == 1
    notice = "/* Fengari, a Lua engine in JavaScript. MIT license, (c) 2017 Benoit Giannangeli, 2017-2018 Daurnimator. https://fengari.io */\n"
    page = page.replace("/*FENGARI*/", notice + fengari).replace("/*LUA*/[]", script_json(lua))
    os.makedirs(os.path.dirname(TEMPLATE), exist_ok=True)
    with open(TEMPLATE, "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    print("viewer template: %d KB, %d Lua files" % (len(page.encode("utf-8")) // 1024, len(lua)))


def fill(out, saved):
    files = [{"folder": "live", "time": int(os.path.getmtime(p)), "text": read(p)} for p in saved]
    page = read(TEMPLATE).replace('"__FCT_FILES__"', script_json(files))
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(page)


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "viewer":
        build_viewer()
    elif command == "fill":
        fill(sys.argv[2], sys.argv[3:])
    elif command == "release":
        from release import release
        build_viewer()
        release(sys.argv[2])
    else:
        print(__doc__)
