Fury's Character Tracker - Windows Tools
=========================================

Optional helpers for the ESO addon Fury's Character Tracker. They run outside the game, on Windows,
and only read the addon's saved data file:
  Documents\Elder Scrolls Online\live\SavedVariables\FurysCharacterTracker.lua
The addon itself (from ESOUI / Minion) works fully in game without them.

Put this folder anywhere you like, for example Documents\Elder Scrolls Online. Every file here is plain
text: open it in Notepad to read exactly what it does. Nothing here connects to the internet, needs
admin rights, or changes the game or the addon.

Offline viewer
--------------
Open Offline Viewer.cmd   Runs OfflineViewer.ps1.
OfflineViewer.ps1         Reads the saved data file, puts it into a copy of Viewer\viewer.html and saves
                          that as Documents\Elder Scrolls Online\Fury's Character Tracker.html, then opens
                          it in your browser. Reads one file, writes one file.
Viewer\viewer.html        The page template: the same board as in game (tabs, account picker, brag card,
                          research timers, character details), written in plain HTML and JavaScript.
                          It loads nothing from the internet.
The game only saves when you log out or type /reloadui. Run the viewer again for newer data.

Export to Excel
---------------
ExportToExcel.cmd         Runs ExportToExcel.ps1 once.
ExportToExcel.ps1         Reads the "FCT|" export lines from the saved data file (written when you click
                          Export to Excel on the board, or /fct export) and saves them as a CSV in
                          Documents\Elder Scrolls Online, then opens it.
Turn On Auto Export.cmd   Runs AutoExport.ps1 -On: puts a one-line .vbs in your Windows Startup folder
                          ("Fury's Character Tracker Auto Export.vbs") that starts AutoExport.ps1 hidden at
                          every sign-in, and starts it now. No admin rights needed.
Turn Off Auto Export.cmd  Runs AutoExport.ps1 -Off: removes that .vbs and stops the helper.
AutoExport.ps1            The helper. Every 3 seconds it checks whether the saved data file changed. When
                          it holds a new export request, it runs ExportToExcel.ps1 to write
                          ESO Characters.csv in Documents\Elder Scrolls Online (a dated copy if Excel has
                          that file open). Keeps AutoExport.state (last export done) and AutoExport.log
                          (what it did) in this folder.

If you move this folder after turning Auto Export on, run Turn On Auto Export.cmd again from the new place.

AI disclosure: this code was written with the assistance of an AI coding assistant (Claude by Anthropic), working
from my designs and instructions. I test it on my own PC and maintain it.
