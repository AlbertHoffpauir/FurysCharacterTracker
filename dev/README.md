# Developer tools

Nothing in this folder ships with the addon. It builds the offline viewer and tests the addon outside the game.

**AI disclosure:** this code was written with the assistance of an AI coding assistant (Claude by Anthropic), working from my designs and instructions.

## How the addon is laid out

- Files whose first line is `-- shared` make no game calls when they load. The game runs them, and so does the offline viewer. They hold the rules of the board: what the tabs are, what every cell shows, every hover text.
- `Trackers/` has one file per tracked thing (skills, research, writs, wallet and so on). Each says how to read it from the game, which events mean it changed, its columns, and what it adds to the details page, the Excel export and the Who needs me list.
- `Data/Views.lua` lists the tabs and names the columns on each. `Data/Text.lua` holds the words on the windows.
- `Game/` and `UI/` are game only: reading, alerts, startup, and the windows.

To add a column: add it to the tracker's file, name it on a tab in `Data/Views.lua`, raise `CT.READ_VERSION` if it needs a new read, then run the checks below and rebuild the viewer.

## Building

    python3 dev/build.py viewer               builds WindowsTools/Viewer/viewer.html from the shared files
    python3 dev/build.py fill out.html <saved file> [...]    what OfflineViewer.ps1 does on Windows
    python3 dev/build.py release <out dir>    checks everything, then writes the two zips

The viewer page is `dev/viewer/page.html`, its Lua side `dev/viewer/viewer.lua`, the game functions it stands in for `dev/shim.lua`. `dev/vendor/` holds Fengari (fengari-web 0.1.4, MIT), the Lua engine the page runs the shared files with.

## Testing outside the game

Needs Python with `lupa`, Node with Playwright for the browser checks, and the ESO API documentation text file (ESOUIDocumentation.txt) named in the `FCT_API_DOC` environment variable.

    python3 dev/fct_harness.py game FurysCharacterTracker <saved file or -> <@account> "<megaserver>" out/game.txt
    python3 dev/fct_harness.py game FurysCharacterTracker <saved file> <@account> "<megaserver>" out/play.txt dev/scenario.lua
    python3 dev/fct_harness.py game FurysCharacterTracker - @Someone "NA Megaserver" out/new.txt dev/newinstall.lua
    python3 dev/fct_harness.py viewer FurysCharacterTracker out/game.txt.sv.lua out/viewer51.txt
    node dev/viewer_dump.js out/viewer.html dev/dump.lua <time> out/viewer53.txt
    node dev/shots.js out/viewer.html out/shots

- `game` loads the whole addon against a stand-in for the game (`stub.lua`). It fails on any global that is not in the API documentation, any control method that does not exist, a tab wider than the window, a button without hover text, or a window that does not draw what `Core/Board.lua` says. The megaserver name must be the one in the saved file ("NA Megaserver", "EU Megaserver").
- `scenario.lua` plays through a session: rank up, recipes, combat, writs on a German client, companions, gear, logout, export. `newinstall.lua` checks a first run.
- `viewer` runs only the shared files, the way the offline viewer does, and fails if one of them reaches for a game function.
- Every mode writes the same kind of dump (every tab, cell and hover text for every account). The dump from `viewer` and the one from the browser must be identical; the one from `game` differs only where the words are meant to differ.
- `compare.py` compares the board of two versions cell by cell.

Never put a real saved variables file in the repository.
