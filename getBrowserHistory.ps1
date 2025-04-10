<#
.SYNOPSIS
    Retrieves browsing history URLs from a specified user's default Microsoft Edge profile.
    REQUIRES ADMINISTRATIVE PRIVILEGES.

.DESCRIPTION
    This script reads the Microsoft Edge history SQLite database for a specified username
    on the local machine. It targets the 'Default' Edge profile within that user's folder
    unless another profile name is specified.

    It requires:
    - Running PowerShell As Administrator.
    - The PSSQLite module (will prompt for installation if not found).
    - The target user's Microsoft Edge instance must be COMPLETELY CLOSED.

.PARAMETER UserName
    [Mandatory] The login username of the target user whose Edge history you want to check.

.PARAMETER ProfileName
    Specifies the Edge profile directory name within the target user's data folder
    (e.g., "Default", "Profile 1"). Defaults to "Default".

.PARAMETER MaxEntries
    Specifies the maximum number of the most recent history entries to retrieve.
    If not specified (or 0), retrieves all entries (which could be very large).

.EXAMPLE
    .\Get-TargetUserEdgeHistory.ps1 -UserName jdoe

    Retrieves all history from the 'Default' Edge profile for user 'jdoe'. (Run as Admin)

.EXAMPLE
    .\Get-TargetUserEdgeHistory.ps1 -UserName sarahm -ProfileName "Profile 2" -MaxEntries 100

    Retrieves the latest 100 history entries from 'Profile 2' for user 'sarahm'. (Run as Admin)

.NOTES
    Requires:
        - PowerShell 5.1 or later.
        - Administrator privileges.
        - The PSSQLite module.
        - Target user's Edge instance must be completely closed.
#>
param(
    [Parameter(Mandatory = $true, HelpMessage = "Enter the login username of the target user.")]
    [string]$UserName,

    [Parameter(Mandatory = $false, HelpMessage = "Specify the Edge profile name ('Default', 'Profile 1', etc.).")]
    [string]$ProfileName = "Default",

    [Parameter(Mandatory = $false, HelpMessage = "Maximum number of recent entries to retrieve (0 for all).")]
    [int]$MaxEntries = 0
)

# --- Check for Administrator Privileges ---
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$currentUser
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script requires administrative privileges to access other user profiles. Please re-run PowerShell as an Administrator."
    # Optional: Attempt to relaunch as admin (uncomment if desired)
    # Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`" {1}" -f $MyInvocation.MyCommand.Path, $MyInvocation.BoundParameters.GetEnumerator().ForEach({"'-{0} {1}'" -f $_.Key, $_.Value})) -Verb RunAs
    Exit 1 # Exit if not admin
}
Write-Verbose "Running with Administrator privileges."

# --- Configuration ---
# Construct path to the target user's profile
$TargetUserProfileBasePath = Join-Path -Path $env:SystemDrive -ChildPath "Users\$UserName"
$EdgeDataPath = Join-Path -Path $TargetUserProfileBasePath -ChildPath 'AppData\Local\Microsoft\Edge\User Data' # Note: AppData is usually hidden
$HistoryDbPath = Join-Path -Path $EdgeDataPath -ChildPath "$ProfileName\History"

# --- Prerequisite Checks ---

# 1. Check if target user profile base path exists
if (-not (Test-Path -Path $TargetUserProfileBasePath -PathType Container)) {
    Write-Error "Target user profile path not found: '$TargetUserProfileBasePath'. Did the user '$UserName' log into this machine?"
    Exit 1
}
Write-Verbose "Target user profile base path found: $TargetUserProfileBasePath"

# 2. Check if PSSQLite module is installed (install for AllUsers as Admin)
if (-not (Get-Module -Name PSSQLite -ListAvailable)) {
    Write-Warning "The 'PSSQLite' module is required to read the Edge history database."
    try {
        $confirm = Read-Host "Do you want to attempt to install it now system-wide (AllUsers)? (Requires internet connection) [Y/N]"
        if ($confirm -match '^[Yy]') {
            Write-Host "Attempting to install PSSQLite for AllUsers..." -ForegroundColor Cyan
             # Ensure PowerShellGet is available and updated if possible
            if (-not (Get-Module -Name PowerShellGet -ListAvailable)) {
                Write-Error "PowerShellGet module not found. Cannot install PSSQLite automatically."
                Exit 1
            }
             # Set TLS 1.2 if needed for older systems
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Install-Module -Name PSSQLite -Scope AllUsers -Repository PSGallery -Force -AllowClobber -SkipPublisherCheck
            Import-Module PSSQLite
        } else {
            Write-Error "PSSQLite module not installed. Script cannot continue."
            Exit 1
        }
    } catch {
        Write-Error "Failed to install or import PSSQLite module. Please install it manually (`Install-Module PSSQLite -Scope AllUsers`) and try again. Error: $($_.Exception.Message)"
        Exit 1
    }
} else {
     # Ensure it's loaded if available but not imported
    if (-not (Get-Module -Name PSSQLite)) {
         Import-Module PSSQLite -ErrorAction Stop
    }
    Write-Verbose "PSSQLite module found."
}

# 3. Check if the specific History file exists for the target user/profile
#    Use -Force because AppData is often hidden
if (-not (Test-Path -Path $HistoryDbPath -PathType Leaf)) {
    Write-Error "Microsoft Edge history database not found for user '$UserName' at '$HistoryDbPath'."
    Write-Error "Possible reasons: User hasn't used Edge, '$ProfileName' is incorrect, or Edge data is stored elsewhere."
    Exit 1
}
Write-Verbose "Target history database file found: $HistoryDbPath"

# 4. Check if Edge is running (basic check - may not catch target user's instance specifically if they aren't logged in actively)
#    The most reliable check is the database lock error later.
$edgeProcesses = Get-Process -Name "msedge" -ErrorAction SilentlyContinue
if ($edgeProcesses) {
     Write-Warning "An 'msedge.exe' process is running on this machine. If it belongs to the target user '$UserName', the history file might be locked. Ensure the target user has completely closed Edge."
} else {
    Write-Verbose "No active 'msedge.exe' process detected."
}

# --- Read History ---
Write-Host "Attempting to read Edge history for user '$UserName' (Profile: '$ProfileName')..." -ForegroundColor Green

# Construct the SQL Query
$sql = "SELECT url, title, last_visit_time FROM urls ORDER BY last_visit_time DESC"
if ($MaxEntries -gt 0) {
    $sql += " LIMIT $MaxEntries"
    Write-Host "Retrieving the latest $MaxEntries entries."
} else {
     Write-Host "Retrieving all entries (this could take a while)..."
}

try {
    # Query the database using the full path
    # Use -Force in Get-Item just in case containing folders have odd permissions/attributes
    $historyData = Invoke-SqliteQuery -DataSource (Get-Item -Path $HistoryDbPath -Force).FullName -Query $sql -ErrorAction Stop

    if ($historyData) {
        Write-Host "Successfully queried history data. Processing entries..." -ForegroundColor Green

        # Process the results, converting the timestamp
        $output = $historyData | Select-Object -Property @(
            'URL',
            'Title',
            @{Name = 'LastVisitTime'; Expression = {
                    # Timestamp is microseconds since 1601-01-01 00:00:00 UTC (WebKit/Chrome format)
                    $fileTimeTicks = $_.last_visit_time * 10 # Convert microseconds to 100-nanosecond intervals (FileTime ticks)
                    $dateTime = [DateTime]::FromFileTimeUtc($fileTimeTicks) # Create UTC DateTime
                    $dateTime.ToLocalTime() # Convert from UTC to Local Time for display
                }
            }
        )

        # Display the results
        Write-Host "`n--- Edge Browsing History (User: $UserName, Profile: $ProfileName) ---"
        $output | Format-Table -AutoSize -Wrap

        Write-Host "`nFound $($output.Count) history entries for '$UserName'."

    } else {
        Write-Host "No history data found in the database for user '$UserName', profile '$ProfileName'."
    }

} catch [System.Data.SQLite.SQLiteException] {
     if ($_.Exception.Message -like '*database is locked*') {
         Write-Error "Failed to query history: The database file '$HistoryDbPath' is locked. Please ensure the target user '$UserName' has COMPLETELY closed Microsoft Edge and try again."
     } else {
        Write-Error "An SQLite error occurred querying '$HistoryDbPath': $($_.Exception.Message)"
        Write-Error "Ensure the PSSQLite module is working correctly and the file is accessible."
     }
} catch {
    Write-Error "An unexpected error occurred while processing history for '$UserName': $($_.Exception.Message)"
    Write-Error "Script execution halted."
}

Write-Host "`nScript finished."