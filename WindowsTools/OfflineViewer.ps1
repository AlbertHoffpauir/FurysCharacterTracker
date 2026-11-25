# Fury's Character Tracker - offline viewer
# Reads the addon's saved data (every account and megaserver that plays on this PC), builds
# "Fury's Character Tracker.html" in Documents\Elder Scrolls Online and opens it in your browser.
# No game needed. ESO writes the saved data when you log out or /reloadui.
# Plain text: open it in Notepad to see what it does. It reads the saved data files, writes one
# file, and never connects to the internet.

param(
    [string[]]$SavedVars,   # saved data files to show; default: the live (NA) and liveeu (EU) game folders
    [string]$OutFile,
    [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
$docs = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Elder Scrolls Online'
if (-not $SavedVars) {
    $SavedVars = foreach ($folder in 'live', 'liveeu') { Join-Path $docs "$folder\SavedVariables\FurysCharacterTracker.lua" }
}
if (-not $OutFile) { $OutFile = Join-Path $docs "Fury's Character Tracker.html" }
$template = Join-Path $PSScriptRoot 'Viewer\viewer.html'

$found = @($SavedVars | Where-Object { Test-Path -LiteralPath $_ })
if ($found.Count -eq 0) {
    Write-Host "Can't find the addon's saved data. Looked for:" -ForegroundColor Red
    $SavedVars | ForEach-Object { Write-Host "  $_" }
    Write-Host "Log in with the addon enabled, then log out or /reloadui, and run this again."
    exit 1
}
if (-not (Test-Path -LiteralPath $template)) {
    Write-Host "Can't find $template - download Fury's Character Tracker Windows Tools again." -ForegroundColor Red
    exit 1
}

# Each saved file goes into the page as one JavaScript string, with the folder it came from and
# the time the game wrote it. The page itself reads the Lua inside.
$utf8 = New-Object System.Text.UTF8Encoding($false)
$files = foreach ($path in $found) {
    $text   = [IO.File]::ReadAllText($path, $utf8)
    $time   = [DateTimeOffset]::new((Get-Item -LiteralPath $path).LastWriteTimeUtc).ToUnixTimeSeconds()
    $folder = Split-Path -Leaf (Split-Path -Parent (Split-Path -Parent $path))
    '{"folder":' + (ConvertTo-Json -InputObject ([string]$folder) -Compress) + ',"time":' + $time +
        ',"text":' + (ConvertTo-Json -InputObject $text -Compress) + '}'
}
$json = ('[' + ($files -join ',') + ']').Replace('</', '<\/')

$html = [IO.File]::ReadAllText($template, $utf8)
$html = $html.Replace('"__FCT_FILES__"', $json)
[IO.File]::WriteAllText($OutFile, $html, $utf8)

Write-Host "Wrote $OutFile"
$found | ForEach-Object { Write-Host "  from $_" }
if (-not $NoOpen) { Start-Process -FilePath $OutFile }
