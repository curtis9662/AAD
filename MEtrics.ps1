<#
.SYNOPSIS
    Generates an Executive Leadership report for Microsoft 365 / Entra ID Identity metrics.

.DESCRIPTION
    This script connects to Microsoft Graph to retrieve:
    1. Total User Accounts
    2. Total Global Administrators (Privileged Accounts)
    3. Total Verified Domains
    4. Active Users (Logins in last 30 days) - Requires Entra ID P1/P2
    5. Total Enterprise Applications (Service Principals)
    6. MFA Registration Count

.NOTES
    Requires Modules: Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Reports, Microsoft.Graph.Applications
#>

# --- Configuration ---
$ExportPath = "$HOME\Desktop\Identity_Executive_Report_$(Get-Date -Format 'yyyyMMdd').csv"
$LookbackDays = 30

# --- Connect to Microsoft Graph ---
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
try {
    # Scopes required for Users, Roles, Domains, Reports, and Applications
    $Scopes = @(
        "User.Read.All", 
        "Directory.Read.All", 
        "RoleManagement.Read.Directory", 
        "Reports.Read.All", 
        "AuditLog.Read.All"
    )
    Connect-MgGraph -Scopes $Scopes -ErrorAction Stop
    Write-Host "Successfully connected." -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Error: $_"
    return
}

# --- Data Gathering ---

# 1. Total Number of Accounts
Write-Host "Gathering Total Account data..." -ForegroundColor Yellow
$AllUsers = Get-MgUser -All -Property Id, SignInActivity, UserPrincipalName, AccountEnabled -ErrorAction Stop
$TotalAccounts = $AllUsers.Count

# 2. Privileged Accounts (Global Administrators)
Write-Host "Counting Global Administrators..." -ForegroundColor Yellow
try {
    # Get the Global Administrator Role definition
    $GlobalAdminRole = Get-MgDirectoryRole -Filter "DisplayName eq 'Global Administrator'" -ErrorAction SilentlyContinue
    
    if (-not $GlobalAdminRole) {
        # If roles aren't activated/listed, we might need to fetch templates or activate the role first (rare in reporting)
        # Trying generic fetch for safety
        $GlobalAdminRole = Get-MgDirectoryRole | Where-Object { $_.DisplayName -eq "Global Administrator" }
    }

    if ($GlobalAdminRole) {
        $GlobalAdmins = Get-MgDirectoryRoleMember -DirectoryRoleId $GlobalAdminRole.Id -ErrorAction Stop
        $PrivilegedCount = $GlobalAdmins.Count
    }
    else {
        $PrivilegedCount = 0
        Write-Warning "Global Administrator role not found or no members active."
    }
}
catch {
    $PrivilegedCount = "Error Retrieving"
    Write-Warning "Could not retrieve privileged accounts: $_"
}

# 3. Total Active Directory Domains
Write-Host "Counting Verified Domains..." -ForegroundColor Yellow
$Domains = Get-MgDomain -All
$TotalDomains = $Domains.Count

# 4. Active Users (Last 30 Days)
Write-Host "Calculating Active Users (Last $LookbackDays Days)..." -ForegroundColor Yellow
$CutoffDate = (Get-Date).AddDays(-$LookbackDays)
$ActiveUserCount = 0

# Check if SignInActivity is populated (Requires P1 License)
if ($AllUsers[0].SignInActivity -eq $null -and $AllUsers.Count -gt 0) {
    $ActiveUserCount = "N/A (Requires Entra ID P1/P2)"
    Write-Warning "SignInActivity is null. This feature requires an Entra ID P1 or P2 license."
}
else {
    $ActiveUserCount = ($AllUsers | Where-Object { 
        $_.SignInActivity.LastSignInDateTime -ge $CutoffDate 
    }).Count
}

# 5. Total Enterprise Applications
Write-Host "Counting Enterprise Applications..." -ForegroundColor Yellow
# Using Get-MgServicePrincipal for "Enterprise Applications" (instances in your tenant)
# Get-MgApplication would return "App Registrations" (apps you developed)
$EntApps = Get-MgServicePrincipal -All -CountVariable EntAppCount -ConsistencyLevel eventual
$TotalEntApps = $EntApps.Count

# 6. MFA Enforcement Status (Users Registered)
Write-Host "Gathering MFA Registration Status..." -ForegroundColor Yellow
try {
    # Uses the Usage Reports API
    $MfaReport = Get-MgReportAuthenticationMethodUserRegistrationDetail -All -ErrorAction Stop
    $MfaRegisteredCount = ($MfaReport | Where-Object { $_.IsMfaRegistered -eq $true }).Count
    $MfaStatusString = "$MfaRegisteredCount Users Registered"
}
catch {
    $MfaStatusString = "Error/Insufficient Permissions"
    Write-Warning "Could not retrieve MFA report. Ensure you have Reports.Read.All."
}

# --- Compile Results ---
$ReportObject = [PSCustomObject]@{
    "Report Date"                  = (Get-Date).ToString("yyyy-MM-dd")
    "Total Accounts"               = $TotalAccounts
    "Privileged Accounts (Global Admin)" = $PrivilegedCount
    "Total Verified Domains"       = $TotalDomains
    "Active Users (Last 30 Days)"  = $ActiveUserCount
    "Enterprise Applications"      = $TotalEntApps
    "MFA Status"                   = $MfaStatusString
}

# --- Display and Export ---
Write-Host "`n--- Executive Leadership Identity Report ---" -ForegroundColor Cyan
$ReportObject | Format-List

# Add to a list for CSV export (Export-Csv expects a list/collection)
$ExportList = @($ReportObject)
$ExportList | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8

Write-Host "Report exported to: $ExportPath" -ForegroundColor Green