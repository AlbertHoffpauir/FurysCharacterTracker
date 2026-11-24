# Fury's Character Tracker

**AI disclosure:** This addon's code was written with the assistance of an AI coding assistant (Claude by Anthropic), working from my designs and instructions. I test every release in game on my own characters before it goes up, and I maintain it.

An Elder Scrolls Online addon: your whole roster on one board. Skill lines, guild ranks, crafting, research, scribing, motifs, recipes, companions, riding and time played for every character, read from the game.

## Downloads

- **The addon:** get it from ESOUI or Minion. The same files are in [`FurysCharacterTracker/`](FurysCharacterTracker/) here, and as [FurysCharacterTracker-1.3.2.zip](https://github.com/AlbertHoffpauir/FurysCharacterTracker/raw/main/downloads/FurysCharacterTracker-1.3.2.zip).
- **Windows Tools** (optional): offline viewer and Excel export. **[Download FurysCharacterTracker-WindowsTools-1.3.0.zip](https://github.com/AlbertHoffpauir/FurysCharacterTracker/raw/main/downloads/FurysCharacterTracker-WindowsTools-1.3.0.zip)**. Unzip it into any folder, for example Documents\Elder Scrolls Online. Source: [`WindowsTools/`](WindowsTools/), and [README.txt](WindowsTools/README.txt) says what every file does.

The tools are plain-text scripts (batch, PowerShell) and one HTML page. They only read the addon's saved data file on your PC and never connect to the internet.

## Repository layout

| Folder | What |
|---|---|
| `FurysCharacterTracker/` | The addon, exactly as it goes into `Documents\Elder Scrolls Online\live\AddOns`. See its [README](FurysCharacterTracker/README.md) and [CHANGELOG](FurysCharacterTracker/CHANGELOG.md). |
| `WindowsTools/` | Offline viewer (`Open Offline Viewer.cmd`) and Excel export (`Turn On Auto Export.cmd`, `ExportToExcel.cmd`). |
| `downloads/` | Ready-made zips of both for each release. |

## Credits

- Settings page uses **LibAddonMenu-2.0** by Seerah and sirinsidiator.
- Game API details from the ESOUI wiki and ZeniMax's ESO UI source code.

License: MIT (see [LICENSE](LICENSE)).
