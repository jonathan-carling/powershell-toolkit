<#
.SYNOPSIS
    Removes empty directories from a specified root path.

.DESCRIPTION
    Scans the provided root directory recursively, identifies directories
    that contain no files or subdirectories, and deletes them. Directories
    are processed from the deepest level upward to ensure parent directories
    become eligible for removal once their children are deleted.
    If the root directory itself becomes empty, it will also be removed.

.PARAMETER Path
    The root directory to scan for empty subdirectories.

.EXAMPLE
    ./Remove-EmptyDirectories.ps1 -Path "C:\Projects\OldBuilds"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path
)

# Validate path
if (-not (Test-Path -Path $Path)) {
    throw "Path does not exist: $Path"
}

$root = Resolve-Path -Path $Path

# Get all directories, deepest first
$dirs = Get-ChildItem -Path $root -Directory -Recurse |
        Sort-Object { $_.FullName.Split([IO.Path]::DirectorySeparatorChar).Count } -Descending

foreach ($dir in $dirs) {
    $children = Get-ChildItem -Path $dir.FullName -Force
    if ($children.Count -eq 0) {
        Write-Host "Deleting empty directory: $($dir.FullName)"
        Remove-Item -Path $dir.FullName -Force
    }
}

# Check the root last
$rootChildren = Get-ChildItem -Path $root -Force
if ($rootChildren.Count -eq 0) {
    Write-Host "Deleting now-empty root directory: $root"
    Remove-Item -Path $root -Force
}