<#
.SYNOPSIS
    Copies files and directories from a source to a destination using Robocopy.

.DESCRIPTION
    This script wraps Robocopy with standard PowerShell parameter handling.
    It preserves file attributes, timestamps, ACLs, and owner information.
    Auditing (SACL) is intentionally excluded to avoid privilege requirements.

.PARAMETER Source
    The source directory to copy from.

.PARAMETER Destination
    The destination directory to copy to.

.PARAMETER ExcludeFiles
    One or more file names or patterns to exclude from the backup.

.PARAMETER ExcludeDirs
    One or more directory names or patterns to exclude from the backup.

.PARAMETER LogPath
    Optional path to a log file. If not provided, a timestamped log file
    will be created in the user's TEMP directory.

.EXAMPLE
    ./Invoke-Backup.ps1 -Source "C:\Data" -Destination "D:\Backup" -ExcludeFiles "*.tmp"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Source,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Destination,

    [Parameter()]
    [string[]]$ExcludeFiles,
    
    [Parameter()]
    [string[]]$ExcludeDirs,

    [Parameter()]
    [string]$LogPath = "$(Join-Path $env:TEMP "Backup-$(Get-Date -Format yyyyMMdd_HHmmss).log")"
)

# Validate source
if (-not (Test-Path -Path $Source)) {
    throw "Source path does not exist: $Source"
}

# Ensure destination exists
if (-not (Test-Path -Path $Destination)) {
    Write-Verbose "Destination does not exist. Creating: $Destination"
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

# Robocopy arguments
$robocopyArgs = @(
    "`"$Source`""
    "`"$Destination`""
    "/E"                # Copy subdirectories including empty ones
    "/COPY:DATSO"       # Copy everything except auditing info (avoids privilege issues)
    "/R:3"              # Retry 3 times
    "/W:2"              # Wait 2 seconds between retries
    "/LOG:`"$LogPath`"" # Log file path
    "/TEE"              # Output to console + log
)

# Add file exclusions
if ($ExcludeFiles) {
    foreach ($file in $ExcludeFiles) {
        $robocopyArgs += "/XF"
        $robocopyArgs += "`"$file`""
    }
}

# Add directory exclusions
if ($ExcludeDirs) {
    foreach ($dir in $ExcludeDirs) {
        $robocopyArgs += "/XD"
        $robocopyArgs += "`"$dir`""
    }
}

Write-Verbose "Running Robocopy with arguments: $($robocopyArgs -join ' ')"

# Invoke Robocopy
$process = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs `
    -NoNewWindow -Wait -PassThru

# Normalise Robocopy exit codes
if ($process.ExitCode -le 7) {
    Write-Host "Backup completed successfully. Robocopy exit code: $($process.ExitCode)"
}
else {
    throw "Robocopy reported a failure. Exit code: $($process.ExitCode)"
}