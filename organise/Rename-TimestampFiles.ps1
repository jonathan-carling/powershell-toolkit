<#
.SYNOPSIS
    Renames a single file or all files in a directory based on EXIF "Date Taken"
    or LastWriteTime, producing ISO‑sortable filenames.

.DESCRIPTION
    This script accepts either:
        • A single file path - only that file is renamed
        • A directory path - all files in that directory are processed

    The script attempts to extract the "Date Taken" timestamp using Windows Shell
    COM metadata (works for most images and many videos). If unavailable, it
    falls back to LastWriteTime.

    Output filenames follow the pattern:
        yyyy-MM-dd_HHmmss.ext
    Collisions are resolved by appending _1, _2, etc.

.PARAMETER Path
    A file or directory path. If a file is provided, only that file is renamed.
    If a directory is provided, all files in that directory are processed.

.EXAMPLE
    PS> .\Rename-Media.ps1 -Path "C:\Photos"

.EXAMPLE
    PS> .\Rename-Media.ps1 -Path "C:\Photos\IMG_1234.JPG"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({
        if (Test-Path $_ -PathType Leaf -ErrorAction SilentlyContinue) { $true }
        elseif (Test-Path $_ -PathType Container -ErrorAction SilentlyContinue) { $true }
        else { throw "Path must be an existing file or directory." }
    })]
    [string]$Path
)

# --- Logging Setup ------------------------------------------------------------

$timestampForLog = (Get-Date).ToString("yyyyMMdd_HHmmss")

if (Test-Path $Path -PathType Leaf) {
    $logDir = Split-Path $Path
} else {
    $logDir = $Path
}

$logFile = Join-Path $logDir "RenameLog_$timestampForLog.txt"

function Write-Log {
    param([string]$Message)

    $entry = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -Path $logFile -Value $entry
}

Write-Log "=== Rename operation started ==="
Write-Log "Input Path: $Path"

# --- Helpers ------------------------------------------------------------------

function Remove-InvalidDateChars {
    param([string]$s)

    $bad = [char[]](
        0x200E, 0x200F, 0x202A, 0x202B, 0x202C,
        0x202D, 0x202E, 0x00A0, 0x200B
    )

    foreach ($c in $bad) {
        $s = $s.Replace([string]$c, '')
    }

    $s.Trim()
}

function Get-DateTaken {
    param([string]$Path)

    try {
        $shell  = New-Object -ComObject Shell.Application
        $folder = $shell.Namespace((Split-Path $Path))
        $file   = $folder.ParseName((Split-Path $Path -Leaf))

        $raw = $folder.GetDetailsOf($file, 12)
        Write-Log "Raw EXIF for '$Path': '$raw'"

        $clean = Remove-InvalidDateChars $raw

        if ([string]::IsNullOrWhiteSpace($clean)) {
            Write-Log "No EXIF date found for '$Path'"
            return $null
        }

        $formats = @(
            "dd/MM/yyyy HH:mm",
            "dd/MM/yyyy HH:mm:ss",
            "dd/MM/yyyy H:mm",
            "dd/MM/yyyy H:mm:ss"
        )

        foreach ($fmt in $formats) {
            try {
                $parsed = [DateTime]::ParseExact($clean, $fmt, $null)
                Write-Log "Parsed EXIF date '$parsed' using format '$fmt'"
                return $parsed
            } catch { }
        }

        Write-Log "Failed to parse EXIF date for '$Path'"
        return $null
    }
    catch {
        Write-Log "ERROR reading EXIF for '$Path': $_"
        return $null
    }
}

# --- Determine file set -------------------------------------------------------

if (Test-Path $Path -PathType Leaf) {
    $files = ,(Get-Item -LiteralPath $Path)
    $targetDir = Split-Path $Path
    Write-Log "Mode: Single file"
}
else {
    $files = Get-ChildItem -Path $Path -File
    $targetDir = $Path
    Write-Log "Mode: Directory with $($files.Count) files"
}

# --- Processing Loop ----------------------------------------------------------

foreach ($file in $files) {

    Write-Log "Processing: $($file.FullName)"

    $taken = Get-DateTaken -Path $file.FullName
    $timestamp = if ($taken) { $taken } else { $file.LastWriteTime }

    Write-Log "Using timestamp: $timestamp"

    $baseName = $timestamp.ToString("yyyy-MM-dd_HHmmss")
    $ext      = $file.Extension
    $newName  = "$baseName$ext"
    $counter  = 1

    while (Test-Path (Join-Path $targetDir $newName)) {
        $newName = "{0}_{1}{2}" -f $baseName, $counter, $ext
        $counter++
    }

    try {
        Rename-Item -LiteralPath $file.FullName -NewName $newName
        Write-Log "Renamed: $($file.Name) → $newName"
    }
    catch {
        Write-Log "ERROR renaming '$($file.FullName)': $_"
    }
}

Write-Log "=== Rename operation completed ==="