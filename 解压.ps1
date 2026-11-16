<#
.SYNOPSIS
    Restore user folder backups from F: drive zip archives.
.DESCRIPTION
    Scans F:\ for zip files matching the pattern "xxxx_yyyymmdd.zip"
    (e.g. docu_20250101.zip, my_20250101.zip) and extracts each one
    back to its original location under the current user profile.
.NOTES
    Run PowerShell as Administrator to avoid access denied errors.
    Requires PowerShell 5.1+ (Expand-Archive available).
#>

# ===================== Configuration =====================
$Source        = "F:\"
$UserProfile   = $env:USERPROFILE        # e.g. C:\Users\username
$DatePattern   = '\d{8}'                 # yyyymmdd

# Map: archive base name -> target restore folder
# For normal folders the archive content is extracted directly into the folder.
# For "my" the archive contains the filtered profile items (no extra nesting).
$RestoreMap = [ordered]@{
    "docu"     = Join-Path $UserProfile "Documents"
    "desktop"  = Join-Path $UserProfile "Desktop"
    "download" = Join-Path $UserProfile "Downloads"
    "image"    = Join-Path $UserProfile "Pictures"
    "my"       = $UserProfile            # restore items into profile root
}

# ===================== Helper functions =====================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts] [$Level] $Message"
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Log "Created directory: $Path"
    }
}

# ===================== Main =====================
Write-Log "Starting restore from $Source"
Write-Log "Target user profile: $UserProfile"

if (-not (Test-Path -LiteralPath $Source)) {
    Write-Log "Source drive $Source not available. Aborting." "ERROR"
    exit 1
}

# Match files like: docu_20250101.zip  (underscore separator)
$Regex = '^(?<name>[A-Za-z]+)_(?<date>' + $DatePattern + ')\.zip$'

$zipFiles = Get-ChildItem -LiteralPath $Source -Filter "*.zip" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match $Regex }

if (-not $zipFiles) {
    Write-Log "No matching archives found in $Source (pattern: xxxx_yyyymmdd.zip)." "WARN"
    exit 0
}

Write-Log ("Found {0} matching archive(s)." -f $zipFiles.Count)

foreach ($zip in $zipFiles) {

    $null = $zip.Name -match $Regex
    $baseName = $matches['name'].ToLower()
    $dateStr  = $matches['date']

    Write-Log "Processing: $($zip.Name)  (name='$baseName', date='$dateStr')"

    if (-not $RestoreMap.Contains($baseName)) {
        Write-Log "Unknown archive prefix '$baseName', skipped." "WARN"
        continue
    }

    $targetPath = $RestoreMap[$baseName]

    try {
        Ensure-Directory $targetPath

        if ($baseName -eq "my") {
            # "my" archive already contains items relative to profile root,
            # so extract directly into $UserProfile (merge, no subfolder).
            Write-Log "Restoring '$($zip.Name)' -> '$targetPath' (merge into profile root)"
            Expand-Archive -LiteralPath $zip.FullName -DestinationPath $targetPath -Force
        } else {
            # Normal folders: extract contents into the target folder.
            Write-Log "Restoring '$($zip.Name)' -> '$targetPath'"
            Expand-Archive -LiteralPath $zip.FullName -DestinationPath $targetPath -Force
        }

        Write-Log "Restored: $($zip.Name)"

    } catch {
        Write-Log "Failed to restore '$($zip.Name)': $($_.Exception.Message)" "ERROR"
    }
}

Write-Log "Restore completed."