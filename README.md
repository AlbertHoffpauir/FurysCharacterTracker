# Fury's Character Tracker

**AI disclosure:** This addon's code was written with the assistance of an AI coding assistant (Claude by Anthropic), working from my designs and instructions. I test every release in game on my own characters before it goes up, and I maintain it.

An Elder Scrolls Online addon: every character on your account, on one board. Skill and class lines, crafting, research, daily writs, skill points still to earn, wallet, worn gear, companions and progress over time, read from the game. One list of who needs you, a brag card, copy for Discord, export to Excel. Everything that can be turned off starts turned off.

## Downloads

- **The addon:** get it from ESOUI or Minion. The same files are in [`FurysCharacterTracker/`](FurysCharacterTracker/) here, and as [FurysCharacterTracker-1.5.7.zip](https://github.com/AlbertHoffpauir/FurysCharacterTracker/raw/main/downloads/FurysCharacterTracker-1.5.7.zip).
- **Windows Tools** (optional): offline viewer and Excel export. **[Download FurysCharacterTracker-WindowsTools-1.5.5.zip](https://github.com/AlbertHoffpauir/FurysCharacterTracker/raw/main/downloads/FurysCharacterTracker-WindowsTools-1.5.5.zip)**. Unzip it into any folder, for example Documents\Elder Scrolls Online. Source: [`WindowsTools/`](WindowsTools/), and [README.txt](WindowsTools/README.txt) says what every file does. Use tools 1.5.0 or newer with addon 1.5.0 or newer; older tools cannot read what 1.5.0 saves.

The tools are plain-text scripts (batch, PowerShell) and one HTML page. They only read the addon's saved data file on your PC and never connect to the internet.

## Repository layout

| Folder | What |
|---|---|
| `FurysCharacterTracker/` | The addon, exactly as it goes into `Documents\Elder Scrolls Online\live\AddOns`. See its [README](FurysCharacterTracker/README.md) and [CHANGELOG](FurysCharacterTracker/CHANGELOG.md). |
| `WindowsTools/` | Offline viewer (`Open Offline Viewer.cmd`) and Excel export (`Turn On Auto Export.cmd`, `ExportToExcel.cmd`). |
| `dev/` | Not part of the addon: the build of the offline viewer and the tests that run the addon outside the game. See its [README](dev/README.md). |
| `downloads/` | Ready-made zips of the addon and the tools for each release. |
| `docs/` | The text of the addon's ESOUI page. |

## More from Fury

- [Fury's Guild Management Toolset](https://www.esoui.com/downloads/info5063.html): an officer's toolkit: bank alerts, member and inactivity reports, trader week totals, raffles, event sign-ups and recruiting.
- [Fury's Inventory Ledger](https://www.esoui.com/downloads/info5099.html): every item you own in one list, across all your characters, the bank and your houses, with export to Excel.
- [Fury's Account Sync](https://www.esoui.com/downloads/info5106.html): make your other accounts on this PC match your main one: settings, keybinds, addon settings and builds.

All free on ESOUI and in Minion.

## Credits

- Settings page uses **LibAddonMenu-2.0** by Seerah and sirinsidiator.
- Game API details from the ESOUI wiki and ZeniMax's ESO UI source code.
- The offline viewer includes **Fengari** ([fengari.io](https://fengari.io)), a Lua engine in JavaScript by Benoit Giannangeli and Daurnimator, MIT license ([license text](WindowsTools/Viewer/Fengari%20LICENSE.txt)).

License: MIT (see [LICENSE](LICENSE)).
