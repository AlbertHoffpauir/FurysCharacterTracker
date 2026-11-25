"""Compares two board dumps (the ".board" file of fct_harness.py, or a 1.4.1 dump) cell by cell:
same account, same tab, same character, same column title. Prints what differs and what is new."""
import sys, collections

def parse(path):
    data, account, view, head = {}, None, None, []
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if line.startswith("=== account "):
            account = line[12:]
        elif line.startswith("--- view "):
            view = line[9:].split(" ")[0]
        elif line.startswith("  head: "):
            head = [h.replace(" v", "").replace(" ^", "") for h in line[8:].split(" | ")]
        elif line.startswith("  row ") and view:
            cells = line.split(": ", 1)[1].split(" | ")
            for title, cell in zip(head[1:], cells[1:]):
                data[(account, view, cells[0], title)] = cell
        elif line.startswith("  totals: ") and view:
            cells = line[10:].split(" | ")
            for title, cell in zip(head[1:], cells[1:]):
                data[(account, view, "(totals)", title)] = cell
        elif line.startswith("  [") or line.startswith("    "):
            view = None if line.startswith("  [") else view
    return data

old, new = parse(sys.argv[1]), parse(sys.argv[2])
same, diff = 0, collections.Counter()
shown = collections.Counter()
for key, cell in old.items():
    if key not in new:
        diff[("gone", key[1], key[3])] += 1
    elif new[key] == cell:
        same += 1
    else:
        diff[("changed", key[1], key[3])] += 1
        if shown[(key[1], key[3])] < 3:
            shown[(key[1], key[3])] += 1
            print("  %s / %s / %s / %s: [%s] -> [%s]" % (key + (cell, new[key])))
added = collections.Counter((k[1], k[3]) for k in new if k not in old)
print("same cells:", same)
for (kind, view, title), n in sorted(diff.items()):
    print("%s: %s / %s (%d cells)" % (kind, view, title, n))
print("new columns:", ", ".join(sorted("%s/%s" % k for k in added)))
