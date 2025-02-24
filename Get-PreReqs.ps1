# Suppress the output and warnings from Connect-AzAccount
Connect-AzAccount  -WarningAction SilentlyContinue | Out-Null

# Get the current user context
$currentUser = (Get-AzContext).Account.Id

# Get all subscriptions
$subscriptions = Get-AzSubscription

# Initialize result array
$results = @()

foreach ($subscription in $subscriptions) {
    # Set the active subscription
    Set-AzContext -SubscriptionId $subscription.Id | Out-Null

    # Check if the user has Owner role
    $roleAssignments = Get-AzRoleAssignment -SignInName $currentUser -Scope "/subscriptions/$($subscription.Id)" -ErrorAction SilentlyContinue
    $isOwner = $false  # Default to false

    # Only check for "Owner" role, output True or False
    if ($roleAssignments) {
        $isOwner = $roleAssignments | Where-Object { $_.RoleDefinitionName -eq "Owner" } | Select-Object -First 1
        if ($isOwner) {
            $isOwner = $true
        } else {
            $isOwner = $false
        }
    }

    # Get Activity Log Export Configurations
    $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId "/subscriptions/$($subscription.Id)" -ErrorAction SilentlyContinue
    $logCount = if ($diagnosticSettings) { ($diagnosticSettings | Measure-Object).Count } else { 0 }

    # Add results to array
    $results += [PSCustomObject]@{
        SubscriptionName      = $subscription.Name
        SubscriptionId        = $subscription.Id
        IsOwner              = $isOwner
        ActivityLogsExported = $logCount
    }
}

# Global Admin Check via Microsoft Graph API
$isGlobalAdmin = $false
$globalAdminRoleName = "Global Administrator"  # The display name of the Global Admin role

try {
    # Get an access token for Microsoft Graph API, suppressing warnings
    $token = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -WarningAction SilentlyContinue).Token

    # Set the request headers
    $headers = @{
        "Authorization" = "Bearer $token"
    }

    # Query Microsoft Graph API for user's group memberships
    $uri = "https://graph.microsoft.com/v1.0/me/memberOf"
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

    # Check if the user is a member of the Global Administrator role
    $globalAdminRole = $response.value | Where-Object { $_.displayName -eq $globalAdminRoleName }

    if ($globalAdminRole) {
        $isGlobalAdmin = $true
    }
} catch {
    Write-Host "Error checking Global Administrator status via Microsoft Graph: $_"
}

# Function to apply color to the 'True' isOwner values
function Get-ColoredOwner {
    param (
        [bool]$isOwner
    )

    if ($isOwner) {
        return "$($PSStyle::Foreground.Green)True$($PSStyle::Reset)"
    } else {
        return "False"
    }
}

# Output Results in Table Format with colored isOwner field inside the table
$results | ForEach-Object {
    $coloredOwner = Get-ColoredOwner -isOwner $_.IsOwner

    # Construct the final object with coloring logic
    [PSCustomObject]@{
        SubscriptionName      = $_.SubscriptionName
        SubscriptionId        = $_.SubscriptionId
        ActivityLogsExported  = $_.ActivityLogsExported
        isOwner               = $coloredOwner
    }
} | Format-Table -Property SubscriptionName, SubscriptionId, ActivityLogsExported, isOwner

# Output Global Admin status in color (green or red)
$globalAdminColor = if ($isGlobalAdmin) { "Green" } else { "Red" }
Write-Host "`nGlobal Administrator Status: $($isGlobalAdmin)" -ForegroundColor $globalAdminColor
