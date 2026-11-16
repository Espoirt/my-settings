<#
.SYNOPSIS
    Backup user folders to F: drive as zip archives.
.DESCRIPTION
    Compresses Documents, Desktop, Downloads, Pictures and "My Profile"
    (user folder minus AppData, known library folders, and other hidden files)
    into separate zip files on drive F:, named like: docu_20250101.zip
.NOTES
    Run PowerShell as Administrator if you encounter access denied errors.
    Requires PowerShell 5.1+ (Compress-Archive available).
#>

# ===================== Configuration =====================
$UserProfile = $env:USERPROFILE          # e.g. C:\Users\username
$Destination = "F:\"                     # target drive
$DateStr     = (Get-Date).ToString("yyyyMMdd")

# Map: archive base name -> source folder
$BackupMap = [ordered]@{
    "docu"      = Join-Path $UserProfile "Documents"
    "desktop"   = Join-Path $UserProfile "Desktop"
    "download"  = Join-Path $UserProfile "Downloads"
    "image"     = Join-Path $UserProfile "Pictures"
    "my"        = $UserProfile            # special handling below
}

# Known library / system folders excluded from "my" profile backup
$ExcludeFolders = @(
    "AppData",
    "Documents",
    "Desktop",
    "Downloads",
    "Pictures",
    "Music",
    "Videos",
    "Favorites",
    "Links",
    "Saved Games",
    "Searches",
    "Contacts",
    "OneDrive",
    "3D Objects"
)

# ===================== Helper functions =====================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts] [$Level] $Message"
}

function Test-SourceFolder {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Container) { return $true }
    Write-Log "Source folder not found, skipped: $Path" "WARN"
    return $false
}

# ===================== Main =====================
Write-Log "Starting user folder backup to $Destination"
Write-Log "User profile: $UserProfile"

if (-not (Test-Path -LiteralPath $Destination)) {
    Write-Log "Destination drive $Destination not available. Aborting." "ERROR"
    exit 1
}

foreach ($name in $BackupMap.Keys) {

    $srcPath = $BackupMap[$name]
    $zipPath = Join-Path $Destination ("{0}_{1}.zip" -f $name, $DateStr)

    # ---------- Special case: "my" profile ----------
    if ($name -eq "my") {
        Write-Log "Building filtered profile backup for '$name' ..."
        $tempRoot = Join-Path $env:TEMP ("backup_my_" + [guid]::NewGuid().ToString("N"))
        $tempCopy = Join-Path $tempRoot "my"

        if (Test-Path -LiteralPath $tempCopy) {
            Remove-Item -LiteralPath $tempCopy -Recurse -Force
        }
        New-Item -ItemType Directory -Path $tempCopy -Force | Out-Null

        try {
            # Enumerate top-level items in user profile, filtering hidden/system/excluded
            $items = Get-ChildItem -LiteralPath $UserProfile -Force -ErrorAction SilentlyContinue

            foreach ($item in $items) {
                # Skip excluded folder names (case-insensitive)
                if ($ExcludeFolders -contains $item.Name) {
                    Write-Log "  Excluded folder: $($item.Name)"
                    continue
                }

                # Skip hidden or system items
                if ($item.Attributes -band [IO.FileAttributes]::Hidden) {
                    Write-Log "  Skipped hidden item: $($item.Name)"
                    continue
                }
                if ($item.Attributes -band [IO.FileAttributes]::System) {
                    Write-Log "  Skipped system item: $($item.Name)"
                    continue
                }

                # Copy item to temp staging area
                $destItem = Join-Path $tempCopy $item.Name
                try {
                    if ($item.PSIsContainer) {
                        Copy-Item -LiteralPath $item.FullName -Destination $destItem -Recurse -Force -ErrorAction Stop
                    } else {
                        Copy-Item -LiteralPath $item.FullName -Destination $destItem -Force -ErrorAction Stop
                    }
                    Write-Log "  Copied: $($item.Name)"
                } catch {
                    Write-Log "  Failed to copy '$($item.Name)': $($_.Exception.Message)" "WARN"
                }
            }

            # Create zip
            if (Test-Path -LiteralPath $zipPath) {
                Remove-Item -LiteralPath $zipPath -Force
            }
            Compress-Archive -LiteralPath $tempCopy -DestinationPath $zipPath -CompressionLevel Optimal -Force
            Write-Log "Created archive: $zipPath"

        } catch {
            Write-Log "Error creating '$name' archive: $($_.Exception.Message)" "ERROR"
        } finally {
            # Cleanup temp folder
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        continue
    }

    # ---------- Normal folders ----------
    if (-not (Test-SourceFolder $srcPath)) { continue }

    Write-Log "Compressing '$srcPath' -> '$zipPath'"

    try {
        if (Test-Path -LiteralPath $zipPath) {
            Remove-Item -LiteralPath $zipPath -Force
        }
        Compress-Archive -Path (Join-Path $srcPath "*") -DestinationPath $zipPath -CompressionLevel Optimal -Force
        Write-Log "Created archive: $zipPath"
    } catch {
        Write-Log "Error compressing '$srcPath': $($_.Exception.Message)" "ERROR"
    }
}

Write-Log "Backup completed."