#Requires -Version 5.1
<#
.SYNOPSIS
    Install or update Claude Code slash commands from this repo to ~/.claude/commands/

.EXAMPLE
    .\install.ps1                    # install/update all commands
    .\install.ps1 cam pr             # install/update specific commands
    .\install.ps1 -List              # show commands and install status
    .\install.ps1 -DryRun            # preview changes without applying
    .\install.ps1 -DryRun cam        # preview specific command
#>
[CmdletBinding()]
param(
    [switch]$List,
    [switch]$DryRun,
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Names
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoDir   = $PSScriptRoot
$SrcDir    = Join-Path $RepoDir 'commands'
$TargetDir = Join-Path (Join-Path $HOME '.claude') 'commands'

function Show-Usage {
    $script = Split-Path -Leaf $PSCommandPath
    Write-Host "Usage: $script [options] [command ...]"
    Write-Host ''
    Write-Host 'Install or update Claude Code slash commands from this repo to ~/.claude/commands/'
    Write-Host ''
    Write-Host 'Options:'
    Write-Host '  -List      Show all commands and their install status'
    Write-Host '  -DryRun    Preview changes without applying them'
    Write-Host '  -Help      Show this help message'
    Write-Host ''
    Write-Host 'Examples:'
    Write-Host "  $script                    # install/update all commands"
    Write-Host "  $script cam pr             # install/update specific commands"
    Write-Host "  $script -List              # show commands and install status"
    Write-Host "  $script -DryRun            # preview changes without applying"
    Write-Host "  $script -DryRun cam        # preview specific command"
}

function Get-CommandDescription {
    param([string]$FilePath)

    $lines = Get-Content -LiteralPath $FilePath -Encoding UTF8
    $inFrontmatter = $false
    $lineNum = 0

    foreach ($line in $lines) {
        $lineNum++
        if ($lineNum -eq 1 -and $line -eq '---') {
            $inFrontmatter = $true
            continue
        }
        if ($inFrontmatter) {
            if ($line -eq '---') {
                $inFrontmatter = $false
                continue
            }
            if ($line -match '^description:\s*(.+)$') {
                return $Matches[1].Trim()
            }
            continue
        }
        if ($line -match '^# (.+)$') {
            return $Matches[1].Trim()
        }
    }
    return '(no description)'
}

function Get-RelPath {
    param([string]$FilePath)
    # Return path relative to SrcDir using forward slashes
    $rel = $FilePath.Substring($SrcDir.Length + 1)
    return $rel -replace '\\', '/'
}

function Get-DisplayName {
    param([string]$RelPath)
    $name = $RelPath -replace '\.md$', ''
    return $name -replace '/', ':'
}

function Get-CommandFiles {
    param([string[]]$FilterNames)

    $files = Get-ChildItem -LiteralPath $SrcDir -Filter '*.md' -File -Recurse |
             Sort-Object FullName |
             Select-Object -ExpandProperty FullName

    if (-not $FilterNames -or $FilterNames.Count -eq 0) {
        return $files
    }

    $matched = @()
    foreach ($file in $files) {
        $rel  = Get-RelPath $file
        $name = Get-DisplayName $rel
        foreach ($filter in $FilterNames) {
            if ($name -eq $filter -or $rel -eq $filter -or $rel -eq "$filter.md") {
                $matched += $file
                break
            }
        }
    }
    return $matched
}

function Compare-Files {
    param([string]$Source, [string]$Target)
    $srcBytes = [System.IO.File]::ReadAllBytes($Source)
    $tgtBytes = [System.IO.File]::ReadAllBytes($Target)
    if ($srcBytes.Length -ne $tgtBytes.Length) { return $false }
    for ($i = 0; $i -lt $srcBytes.Length; $i++) {
        if ($srcBytes[$i] -ne $tgtBytes[$i]) { return $false }
    }
    return $true
}

function Show-FileDiff {
    param([string]$Target, [string]$Source)
    $targetLines = Get-Content -LiteralPath $Target -Encoding UTF8
    $sourceLines = Get-Content -LiteralPath $Source -Encoding UTF8
    $diff = Compare-Object -ReferenceObject $targetLines -DifferenceObject $sourceLines -IncludeEqual
    foreach ($entry in $diff) {
        switch ($entry.SideIndicator) {
            '<=' { Write-Host "- $($entry.InputObject)" -ForegroundColor Red }
            '=>' { Write-Host "+ $($entry.InputObject)" -ForegroundColor Green }
        }
    }
}

function Invoke-List {
    $header = '{0,-25} {1,-14} {2}' -f 'COMMAND', 'STATUS', 'DESCRIPTION'
    $sep    = '{0,-25} {1,-14} {2}' -f '-------', '------', '-----------'
    Write-Host $header
    Write-Host $sep

    $files = Get-ChildItem -LiteralPath $SrcDir -Filter '*.md' -File -Recurse |
             Sort-Object FullName |
             Select-Object -ExpandProperty FullName

    foreach ($file in $files) {
        $rel    = Get-RelPath $file
        $name   = Get-DisplayName $rel
        $target = Join-Path $TargetDir ($rel -replace '/', '\')
        $desc   = Get-CommandDescription $file

        if (-not (Test-Path -LiteralPath $target)) {
            $status = 'not installed'
        } elseif (Compare-Files $file $target) {
            $status = 'up to date'
        } else {
            $status = 'changed'
        }
        Write-Host ('{0,-25} {1,-14} {2}' -f "/$name", $status, $desc)
    }
}

function Invoke-Install {
    param(
        [bool]$IsDryRun,
        [string[]]$FilterNames
    )

    $installed  = 0
    $updated    = 0
    $upToDate   = 0

    $files = Get-CommandFiles -FilterNames $FilterNames

    foreach ($file in $files) {
        $rel       = Get-RelPath $file
        $name      = Get-DisplayName $rel
        $target    = Join-Path $TargetDir ($rel -replace '/', '\')
        $parentDir = Split-Path -Parent $target

        if (-not (Test-Path -LiteralPath $target)) {
            if ($IsDryRun) {
                Write-Host "would install: /$name"
            } else {
                if (-not (Test-Path -LiteralPath $parentDir)) {
                    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                }
                Copy-Item -LiteralPath $file -Destination $target -Force
                Write-Host "installed: /$name"
            }
            $installed++
        } elseif (Compare-Files $file $target) {
            Write-Host "up to date: /$name"
            $upToDate++
        } else {
            if ($IsDryRun) {
                Write-Host "would update: /$name"
                Show-FileDiff -Target $target -Source $file
                Write-Host ''
            } else {
                Copy-Item -LiteralPath $file -Destination $target -Force
                Write-Host "updated: /$name"
            }
            $updated++
        }
    }

    Write-Host ''
    Write-Host "$installed installed, $updated updated, $upToDate up to date"
}

# Main
if ($Help) {
    Show-Usage
    return
}

if ($List) {
    Invoke-List
} else {
    Invoke-Install -IsDryRun $DryRun.IsPresent -FilterNames $Names
}
