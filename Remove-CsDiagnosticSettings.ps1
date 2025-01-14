<#
.SYNOPSIS
This script logs into Azure, retrieves all subscriptions for a given tenant, and processes Azure Activity Log Diagnostic Settings based on specified criteria.

.DESCRIPTION
The script performs the following actions:
1. Logs into Azure using the specified environment.
2. Retrieves all subscriptions for the provided tenant ID.
3. For each subscription, it selects the subscription and retrieves all Azure Activity Log Diagnostic Settings.
4. Filters the diagnostic settings based on specified names and either outputs or removes them based on the DeleteSettings parameter.
5. Uses the Azure REST API to retrieve and process additional diagnostic settings for the subscription.

.PARAMETER DeleteSettings
A boolean parameter that determines whether to remove the matching diagnostic settings. If set to $true, the settings will be removed; otherwise, they will only be listed.

.EXAMPLE
# Example 1: Remove matching diagnostic settings
.\Remove-FcsDiagnosticSettings.ps1 -DeleteSettings $false
#>

param (
    [bool]$DeleteSettings = $true
)

# Login to Azure
Connect-AzAccount -InformationAction SilentlyContinue
# Get all subscriptions in the tenant
$subscriptions = Get-AzSubscription

$null = $diagnosticSettings

foreach ($subscription in $subscriptions) {

    $subscriptionId = $subscription.Id
    Write-Output "Processing subscription: $($subscription.Name)"
    Select-AzSubscription -SubscriptionId $subscriptionId

    # Get all Azure Activity Log Diagnostic Settings for the subscription
    $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId "/subscriptions/$subscriptionId"

    # Filter and output the diagnostic settings that match the criteria
    foreach ($setting in $diagnosticSettings) {
        if ($setting.Name -like "cs-monitor-activity-to-eventhub") {
            try {
                if ($DeleteSettings) {
                    Write-Host "Removing diagnostic setting: $($setting.Name)" -ForegroundColor Blue
                    Remove-AzDiagnosticSetting -Name $setting.Name -ResourceId "/subscriptions/$subscriptionId"
                }
                else {
                    Write-Output "If Delete Diagnostics Settings True: $($setting.Name) would be removed"
                }
            }
            catch {
                Write-Error "Failed to remove diagnostic setting: $($setting.Name). Error: $_"
            }
        }
        else {
            Write-Host "Skipping Diagnostic Setting: $($setting.name)" -ForegroundColor Yellow
        }
    }

    # Use REST API to get all diagnostic settings for the subscription

    # Set the API endpoint and headers
    $token = (Get-AzAccessToken -WarningAction SilentlyContinue).Token
    $uri = "https://management.azure.com/providers/microsoft.aadiam/diagnosticSettings?api-version=2017-04-01-preview"
    $headers = @{
        'Authorization' = "Bearer $token"
        'Content-Type'  = 'application/json'
    }

    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

    #Output the diagnostic settings retrieved via REST API that match "cs-aad-to-eventhub"
    foreach ($setting in $response.value) {
        if ($setting.name -like "cs-aad-to-eventhub") {
            if ($DeleteSettings) {
                Write-Host "Removing diagnostic setting via REST API: $($setting.name)" -ForegroundColor Blue
                $deleteUri = "https://management.azure.com/providers/microsoft.aadiam/diagnosticSettings/$($setting.name)?api-version=2017-04-01-preview"
                Invoke-RestMethod -Uri $deleteUri -Method Delete -Headers $headers
            }
            else {
                Write-Output "If Delete Diagnostics Settings True: $($setting.name) would be removed via REST API"
            }
        }
        else {
            Write-Host "Skipping Diagnostic Setting: $($setting.name)" -ForegroundColor Yellow
        }
    }
    Write-Output "Completed processing subscription: $($subscription.Name)"
}
Write-Output "Completed processing all subscriptions"
Disconnect-AzAccount -InformationAction SilentlyContinue
