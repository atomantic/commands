#Requires -Version 5.1
<#
.SYNOPSIS
    Remove old root-level commands that have been replaced by slashdo (/do:* namespace)

.EXAMPLE
    .\uninstall.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TargetDir = Join-Path (Join-Path $HOME '.claude') 'commands'
$LibDir    = Join-Path (Join-Path $HOME '.claude') 'lib'

$Commands = @('cam', 'fpr', 'makegoals', 'makegood', 'pr', 'release', 'replan', 'rpr', 'review')
$Subdirs  = @('claude/optimize-md')
$Libs     = @('code-review-checklist', 'copilot-review-loop', 'graphql-escaping')

$removed = 0

foreach ($cmd in $Commands) {
    $f = Join-Path $TargetDir "$cmd.md"
    if (Test-Path -LiteralPath $f) {
        Remove-Item -LiteralPath $f -Force
        Write-Host "removed: /$cmd"
        $removed++
    }
}

foreach ($cmd in $Subdirs) {
    $f = Join-Path $TargetDir (($cmd -replace '/', '\') + '.md')
    if (Test-Path -LiteralPath $f) {
        Remove-Item -LiteralPath $f -Force
        $displayName = $cmd -replace '/', ':'
        Write-Host "removed: /$displayName"
        $removed++
        # remove parent dir if empty
        $dir = Split-Path -Parent $f
        $children = Get-ChildItem -LiteralPath $dir -ErrorAction SilentlyContinue
        if ($null -eq $children -or $children.Count -eq 0) {
            Remove-Item -LiteralPath $dir -Force
            Write-Host "removed empty dir: $dir"
        }
    }
}

foreach ($lib in $Libs) {
    $f = Join-Path $LibDir "$lib.md"
    if (Test-Path -LiteralPath $f) {
        Remove-Item -LiteralPath $f -Force
        Write-Host "removed: lib/$lib.md"
        $removed++
    }
}

if ($removed -eq 0) {
    Write-Host 'Nothing to remove -- old commands already cleaned up.'
} else {
    Write-Host ''
    Write-Host "$removed files removed."
    Write-Host 'Migrate to slashdo: npx slash-do@latest'
}
