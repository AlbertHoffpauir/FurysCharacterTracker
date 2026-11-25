Fury's Character Tracker - Windows Tools 1.5.5
===============================================

Optional helpers for the ESO addon Fury's Character Tracker. They run outside the game, on Windows,
and only read the addon's saved data file:
  Documents\Elder Scrolls Online\live\SavedVariables\FurysCharacterTracker.lua      (NA megaserver)
  Documents\Elder Scrolls Online\liveeu\SavedVariables\FurysCharacterTracker.lua    (EU megaserver)
The addon itself (from ESOUI / Minion) works fully in game without them.

Use these tools with addon version 1.5.0 or newer. Put this folder anywhere you like, for example
Documents\Elder Scrolls Online. Nothing here connects to the internet, needs admin rights, or changes
the game, the addon or its saved data. The .ps1 and .cmd files are plain text: open one in Notepad
to read exactly what it does.

The game only writes the saved data when you log out or type /reloadui. Do one of those first, then
run a tool, to see what you just did in game.

Offline viewer
--------------
Open Offline Viewer.cmd   Double-click this. It runs OfflineViewer.ps1.
OfflineViewer.ps1         Reads the saved data (both megaserver folders, if you play on both), puts it
                          into a copy of Viewer\viewer.html, saves that as
                          Documents\Elder Scrolls Online\Fury's Character Tracker.html and opens it in
                          your browser. It reads the saved data and writes that one file.
Viewer\viewer.html        The page: the same board as in game, with every tab, the account picker,
                          Start here, the Todo List, research timers, the brag card, character details,
                          Copy for Discord and Save for Excel. No game needed.

The viewer shows exactly what the addon shows, because it runs the addon's own files. The page holds
a copy of the addon's board files and a small Lua engine (Fengari) to run them in your browser. When
the addon gets a new tab or column, the next Windows Tools has it too.

Characters you have not logged in on since updating to 1.5.0 show "-" in the new columns. Log in on
each one once to fill them.

Export to Excel
---------------
The quick way: open the offline viewer, pick the account, click Save for Excel. That saves a CSV of
the account on screen, and needs no export in game.

For every account in one file, or to have the file written for you:
ExportToExcel.cmd         Double-click this. It runs ExportToExcel.ps1 once.
ExportToExcel.ps1         Reads the export rows the addon saves when you log out (and when you click
                          Export to Excel on the board, or type /fct export), from both megaserver
                          folders, and saves them as one CSV in Documents\Elder Scrolls Online, then
                          opens it. One row per character, with its account and megaserver in the
                          first two columns. An account that last logged out on an addon version
                          before 1.5.0 is left out until you log in on it once; the tool tells you.
Turn On Auto Export.cmd   Runs AutoExport.ps1 -On: puts a one-line .vbs in your Windows Startup folder
                          ("Fury's Character Tracker Auto Export.vbs") that starts AutoExport.ps1
                          hidden at every sign-in, and starts it now. No admin rights needed.
Turn Off Auto Export.cmd  Runs AutoExport.ps1 -Off: removes that .vbs and stops the helper.
AutoExport.ps1            The helper. Every 3 seconds it checks whether the saved data changed. When
                          it holds a new export request (you clicked Export to Excel in game), it runs
                          ExportToExcel.ps1 to write ESO Characters.csv in
                          Documents\Elder Scrolls Online (a dated copy if Excel has that file open).
                          It keeps AutoExport.state (the last export done) and AutoExport.log (what
                          it did) in this folder.

If you move this folder after turning Auto Export on, run Turn On Auto Export.cmd again from the new
place.

Credits
-------
The offline viewer includes Fengari (https://fengari.io), a Lua engine written in JavaScript by
Benoit Giannangeli and Daurnimator, used under the MIT license. The license text is in
Viewer\Fengari LICENSE.txt. Fengari is only in the viewer page; the addon itself does not use it.

AI disclosure: this code was written with the assistance of an AI coding assistant (Claude by
Anthropic), working from my designs and instructions. I test it on my own PC and maintain it.
