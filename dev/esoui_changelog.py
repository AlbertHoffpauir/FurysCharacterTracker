"""Writes the newest entry of the addon's CHANGELOG.md as BBCode for the ESOUI change log box,
followed by the older entries from the last release's file.

    python3 dev/esoui_changelog.py <previous ESOUI-changelog file> <out file>
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def inline(text):
    text = re.sub(r"\*\*(.+?)\*\*", r"[B]\1[/B]", text)
    text = re.sub(r"`(.+?)`", r'[FONT="Courier New"][B]\1[/B][/FONT]', text)
    return re.sub(r"(?<![\w\]])(/fct(?: [a-z]+)?)", r'[FONT="Courier New"][B]\1[/B][/FONT]', text)


def newest_entry():
    source = open(os.path.join(ROOT, "FurysCharacterTracker", "CHANGELOG.md"), encoding="utf-8").read()
    lines = source.split("\n## ")[1].split("\n")
    out, in_list = ["[B]%s[/B]" % lines[0].strip()], False
    for line in lines[1:]:
        if not line.strip():
            continue
        if line.startswith("- "):
            if not in_list:
                out.append("[LIST]")
                in_list = True
            out.append("[*]" + inline(line[2:]))
            continue
        if in_list:
            out.append("[/LIST]")
            in_list = False
        # A short line on its own is the title of the list under it.
        out.append(inline(line) if len(line) > 60 else '[COLOR="#A08CFF"][B]%s[/B][/COLOR]' % line)
    if in_list:
        out.append("[/LIST]")
    return lines[0].strip(), "\n".join(out) + "\n"


if __name__ == "__main__":
    previous, target = sys.argv[1], sys.argv[2]
    version, block = newest_entry()
    older = open(previous, encoding="utf-8").read()
    if older.startswith("[B]%s[/B]" % version):
        raise SystemExit("the previous file already starts with " + version)
    with open(target, "w", encoding="utf-8", newline="\n") as f:
        f.write(block + "\n" + older)
    print("wrote", target)
