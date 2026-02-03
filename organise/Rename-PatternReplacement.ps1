<#
.SYNOPSIS
    Renames a file or all files in a directory using a user‑defined pattern.

.DESCRIPTION
    Accepts either a file path or a directory path.
    - If a file path is provided, only that file is renamed.
    - If a directory path is provided, all files in that directory (non‑recursive)
      are renamed.
    The user may specify both the regex pattern to replace and the replacement text.

.PARAMETER Path
    A file or directory path. Must exist.

.PARAMETER Pattern
    The regex pattern to search for in the file or directory names.
    Defaults to '\s+' (one or more whitespace characters).

.PARAMETER Replacement
    The replacement text for the matched pattern.
    Defaults to '-'.

.EXAMPLE
    Rename-Items.ps1 -Path "C:\Photos" -Pattern '\s+' -Replacement '_'

.EXAMPLE
    Rename-Items.ps1 -Path "C:\Photos\IMG 001.jpg"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [string]$Pattern = '\s+',

    [string]$Replacement = '-'
)

# Validate path
if (-not (Test-Path -LiteralPath $Path)) {
    throw "The path '$Path' does not exist."
}

# Determine whether path is a file or directory
$pathItem = Get-Item -LiteralPath $Path

# Build list of items to rename
if ($pathItem.PSIsContainer) {
    # Directory → rename files inside (non-recursive)
    $items = Get-ChildItem -LiteralPath $Path -File
} else {
    # Single file
    $items = ,$pathItem
}

foreach ($item in $items) {

    # Compute new name
    $newName = $item.Name -replace $Pattern, $Replacement

    # Skip if no change
    if ($newName -eq $item.Name) {
        Write-Host "No change needed for '$($item.FullName)'"
        continue
    }

    # Build new path
    $newPath = Join-Path $item.DirectoryName $newName

    # Safety check: avoid overwriting existing files
    if (Test-Path -LiteralPath $newPath) {
        Write-Warning "Skipping '$($item.FullName)' — target '$newPath' already exists."
        continue
    }

    Rename-Item -LiteralPath $item.FullName -NewName $newName
    Write-Host "Renamed '$($item.FullName)' → '$newPath'"
}