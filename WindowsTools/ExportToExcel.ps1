# Fury's Character Tracker - Excel export
# Reads the "FCT|" export lines from the addon's saved data and writes a CSV that opens straight
# into Excel: one row per character, for every account that has logged out with the addon on.
# The addon writes those lines when you log out, /reloadui, or click Export to Excel.
# Plain text: open it in Notepad to see what it does. It never connects to the internet.

param(
    [string[]]$SavedVars,   # saved data files to read; default: the live (NA) and liveeu (EU) game folders
    [string]$OutFile,
    [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
$docs = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Elder Scrolls Online'
if (-not $SavedVars) {
    $SavedVars = foreach ($folder in 'live', 'liveeu') { Join-Path $docs "$folder\SavedVariables\FurysCharacterTracker.lua" }
}
if (-not $OutFile) { $OutFile = Join-Path $docs ("ESO Characters {0}.csv" -f (Get-Date -Format 'yyyy-MM-dd HHmm')) }

$found = @($SavedVars | Where-Object { Test-Path -LiteralPath $_ })
if ($found.Count -eq 0) {
    Write-Host "Can't find the addon's saved data. Looked for:" -ForegroundColor Red
    $SavedVars | ForEach-Object { Write-Host "  $_" }
    Write-Host "Log in with the addon enabled, then log out or /reloadui, and run this again."
    exit 1
}

# Text inside the saved file is written the Lua way: \t is a tab, \" a quote, \\ a backslash.
$unescape = [System.Text.RegularExpressions.MatchEvaluator]{
    param($m)
    switch -CaseSensitive ($m.Groups[1].Value) {
        't'     { "`t" }
        'n'     { ' ' }
        'r'     { ' ' }
        default { $m.Groups[1].Value }
    }
}

$utf8    = New-Object System.Text.UTF8Encoding($false)
$rows    = New-Object System.Collections.Generic.List[string]
$header  = $null    # the first header row found; every account's rows must have the same columns
$skip    = $false
$skipped = 0
foreach ($path in $found) {
    $text = [IO.File]::ReadAllText($path, $utf8)
    # Every "FCT|..." text in the file, however the game laid the file out.
    foreach ($m in [regex]::Matches($text, '"FCT\|((?:[^"\\]|\\.)*)"')) {
        $line   = [regex]::Replace($m.Groups[1].Value, '\\(.)', $unescape)
        $fields = $line -split "`t"
        if ($fields[0] -eq 'Account' -or $fields[0] -eq 'Name') {
            # A header row: the rows of one account follow it.
            if ($fields[0] -eq 'Name') { $skip = $true; $skipped++; continue }     # saved by an addon version before 1.5.0
            if ($header) {
                $skip = ($line -ne $header)                                        # other columns: another addon version
                if ($skip) { $skipped++ }
                continue
            }
            $header = $line
            $skip = $false
        }
        elseif ($skip) { continue }
        $quoted = foreach ($f in $fields) { '"' + ($f -replace '"', '""') + '"' }
        $rows.Add(($quoted -join ','))
    }
}

if ($rows.Count -le 1) {
    Write-Host "No characters to export yet. Log in on a character, then log out or /reloadui, and try again." -ForegroundColor Yellow
    exit 1
}

[System.IO.File]::WriteAllLines($OutFile, $rows, (New-Object System.Text.UTF8Encoding $true))
Write-Host ("Wrote {0} characters to {1}" -f ($rows.Count - 1), $OutFile) -ForegroundColor Green
if ($skipped -gt 0) {
    Write-Host ("Left out {0} account(s) whose rows were saved by another version of the addon. Log in on each once to add them." -f $skipped) -ForegroundColor Yellow
}

if (-not $NoOpen) { Invoke-Item -LiteralPath $OutFile }
