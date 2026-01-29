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

.PARAMETER LogPath
    Optional path to a log file. If not provided, a timestamped log file
    will be created in the user's TEMP directory.

.EXAMPLE
    ./Remove-EmptyDirectories.ps1 -Path "C:\Projects\OldBuilds"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter()]
    [string]$LogPath = "$(Join-Path $env:TEMP "Remove-EmptyDirectories-$(Get-Date -Format yyyyMMdd_HHmmss).log")"
)

# Helper: write to log + console
function Write-Log {
    param([string]$Message)
    $Message | Out-File -FilePath $LogPath -Append -Encoding utf8
    Write-Host $Message
}

# Validate path
if (-not (Test-Path -Path $Path)) {
    throw "Path does not exist: $Path"
}

$root = Resolve-Path -Path $Path

# Start log
Write-Log "Started at $(Get-Date)"

# Get all directories, deepest first
$dirs = Get-ChildItem -Path $root -Directory -Recurse |
        Sort-Object { $_.FullName.Split([IO.Path]::DirectorySeparatorChar).Count } -Descending

foreach ($dir in $dirs) {
    $children = Get-ChildItem -Path $dir.FullName -Force
    if ($children.Count -eq 0) {
        Write-Log "Deleting empty directory: $($dir.FullName)"
        Remove-Item -Path $dir.FullName -Force
    }
}

# Check the root last
$rootChildren = Get-ChildItem -Path $root -Force
if ($rootChildren.Count -eq 0) {
    Write-Log "Deleting now-empty root directory: $root"
    Remove-Item -Path $root -Force
}

# Finish log
Write-Log "Finished at $(Get-Date)"
