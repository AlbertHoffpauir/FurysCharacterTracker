"""Checks the addon and the Windows Tools, then writes the two release zips.

Called by `python3 dev/build.py release <out dir>`, after the viewer template has been built.

    FurysCharacterTracker-<version>.zip                the addon, as it goes to ESOUI
    FurysCharacterTracker-WindowsTools-<version>.zip   the Windows Tools, as they go to GitHub

Every check below is a rule that has bitten before (ESOUI's addon check, the game's manifest
reader) or a promise the read-me makes. A failed check stops the release.
"""
import os, re, zipfile

DEV = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(DEV)
ADDON = os.path.join(ROOT, "FurysCharacterTracker")
TOOLS = os.path.join(ROOT, "WindowsTools")

ADDON_EXTRAS = ["README.md", "CHANGELOG.md"]            # in the zip, not in the manifest
ADDON_TYPES = (".lua", ".xml", ".txt", ".md")           # ESOUI: addon files only, no scripts or pages
CRLF_TYPES = (".ps1", ".cmd", ".txt")                   # Windows Tools text opens in Notepad


def read(path):
    with open(path, encoding="utf-8", newline="") as f:
        return f.read()


def walk(folder):
    for base, _, names in os.walk(folder):
        for name in names:
            yield os.path.relpath(os.path.join(base, name), folder).replace(os.sep, "/")


def check_addon(problems):
    manifest = read(os.path.join(ADDON, "FurysCharacterTracker.txt"))
    lines = manifest.splitlines()
    for number, line in enumerate(lines, 1):
        if len(line.encode("utf-8")) > 301:
            problems.append("manifest line %d is %d bytes; the game reads 301" % (number, len(line.encode("utf-8"))))
    field = lambda name: next((l.split(":", 1)[1].strip() for l in lines if l.startswith("## " + name + ":")), None)
    version = field("Version")
    major, minor, patch = (int(x) for x in version.split("."))
    if field("AddOnVersion") != str(major * 100 + minor * 10 + patch):
        problems.append("AddOnVersion %s does not match version %s" % (field("AddOnVersion"), version))
    if ("v" + version) not in (field("Title") or ""):
        problems.append("the manifest title does not show v" + version)
    main = read(os.path.join(ADDON, "FurysCharacterTracker.lua"))
    if 'CT.version = "%s"' % version not in main:
        problems.append("CT.version in FurysCharacterTracker.lua is not " + version)
    if ("## " + version) not in read(os.path.join(ADDON, "CHANGELOG.md")):
        problems.append("CHANGELOG.md has no entry for " + version)

    listed = [l.strip() for l in lines if l.strip() and not l.startswith("#") and not l.startswith(";")]
    for rel in listed:
        if not os.path.exists(os.path.join(ADDON, rel)):
            problems.append("manifest lists a missing file: " + rel)
    ship = ["FurysCharacterTracker.txt"] + listed + ADDON_EXTRAS
    for rel in walk(ADDON):
        if rel not in ship:
            problems.append("file in the addon folder that the manifest does not load: " + rel)
        if not rel.endswith(ADDON_TYPES):
            problems.append("not an addon file type: " + rel)

    for rel in ship:
        path = os.path.join(ADDON, rel)
        if not os.path.exists(path):
            continue
        text = read(path)
        if re.search(r"\bstarts? off\b", text, re.I):
            problems.append(rel + ': says "starts off"; the wording is "starts turned off"')
        if not rel.endswith(".lua"):
            continue
        code = re.sub(r"--[^\n]*", "", text)
        if re.search(r"\bx?pcall\s*\(", code):
            problems.append(rel + ": uses pcall or xpcall")
        if "%f[" in code:
            problems.append(rel + ": uses a %f pattern")
        if re.search(r"\band\s+true\s+or\s+false\b", code):
            problems.append(rel + ": uses 'x and true or false'")
        # ESOUI's check reads a multi-line `Name = function(` inside a table as a new global.
        for match in re.finditer(r"^[ \t]+([A-Z]\w*)\s*=\s*function\s*\([^)]*\)[ \t]*$", code, re.M):
            problems.append("%s: multi-line function field %s in a table" % (rel, match.group(1)))
        if rel != "FurysCharacterTracker.lua" and not rel.startswith("UI/") and re.search(r"^(?!local\b)[A-Za-z_]\w*\s*=[^=]", code, re.M):
            for match in re.finditer(r"^(?!local\b)([A-Za-z_]\w*)\s*=[^=]", code, re.M):
                problems.append("%s: sets a global, %s" % (rel, match.group(1)))
    return version, ship


def check_tools(problems, version):
    import build
    for rel in walk(TOOLS):
        if rel.endswith((".log", ".state")) or "SavedVariables" in rel:
            problems.append("Windows Tools holds a file that must not ship: " + rel)
        if rel.endswith((".ps1", ".cmd")):
            raw = open(os.path.join(TOOLS, rel), "rb").read()
            if any(byte > 127 for byte in raw):
                problems.append(rel + ": not plain ASCII (Windows PowerShell would misread it)")
    if ("Windows Tools " + version) not in read(os.path.join(TOOLS, "README.txt")):
        problems.append("the Windows Tools read-me does not say " + version)
    if re.search(r"\bstarts? off\b", read(os.path.join(TOOLS, "README.txt")), re.I):
        problems.append('the Windows Tools read-me says "starts off"')
    # The viewer holds a copy of the addon's shared files: it must be the copy of these files.
    template = read(build.TEMPLATE)
    if template.count('"__FCT_FILES__"') != 1:
        problems.append("the viewer template does not have exactly one place for the saved files")
    for rel in build.shared_files():
        if build.script_json(read(os.path.join(ADDON, rel)).replace("\r\n", "\n"))[1:-1] not in template:
            problems.append("the viewer was built from an older " + rel + ": run build.py viewer")
    if not os.path.exists(os.path.join(TOOLS, "Viewer", "Fengari LICENSE.txt")):
        problems.append("the Fengari license text is missing from the Windows Tools")


def write_zip(path, top, folder, files, crlf=()):
    if os.path.exists(path):
        os.remove(path)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in sorted(files):
            data = open(os.path.join(folder, rel), "rb").read()
            if rel.endswith(tuple(crlf)):
                data = data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
            z.writestr(top + "/" + rel, data)
    return os.path.getsize(path)


def release(out):
    problems = []
    version, ship = check_addon(problems)
    check_tools(problems, version)
    if problems:
        print("NOT released, %d problem(s):" % len(problems))
        for problem in problems:
            print("   ", problem)
        raise SystemExit(1)
    os.makedirs(out, exist_ok=True)
    addon_zip = os.path.join(out, "FurysCharacterTracker-%s.zip" % version)
    tools_zip = os.path.join(out, "FurysCharacterTracker-WindowsTools-%s.zip" % version)
    size = write_zip(addon_zip, "FurysCharacterTracker", ADDON, ship)
    print("%s: %d files, %d KB" % (os.path.basename(addon_zip), len(ship), size // 1024))
    tools = list(walk(TOOLS))
    size = write_zip(tools_zip, "FurysCharacterTracker-WindowsTools", TOOLS, tools, CRLF_TYPES)
    print("%s: %d files, %d KB" % (os.path.basename(tools_zip), len(tools), size // 1024))
    print("checks passed for " + version)
