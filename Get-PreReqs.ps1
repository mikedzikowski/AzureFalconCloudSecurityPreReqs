# Define the symbols
$checkMark = [char]0x2713  # ✓
$xMark = [char]0x2717      # ✗

<#
Checkmark Logic:
Green checkmark (✓) conditions:
- Owner: True
- Provider: Registered
- Diagnostic Settings: Count < 5
- All Policies: False

Red X (✗) conditions:
- Owner: False
- Provider: Not Registered
- Diagnostic Settings: Count >= 5
- All Policies: True
#>

# Suppress the output and warnings from Connect-AzAccount
Connect-AzAccount -WarningAction SilentlyContinue | Out-Null

# Get the current user context
$currentUser = (Get-AzContext).Account.Id

# Get all subscriptions
$subscriptions = Get-AzSubscription

# Get the tenant root management group
$tenantDetails = Get-AzTenant
$tenantRootId = "/providers/Microsoft.Management/managementGroups/$($tenantDetails.Id)"

# First check Tenant Root Management Group
Write-Host "`n=== Checking Tenant Root Management Group ===" -ForegroundColor Cyan
Write-Host "Scope: $tenantRootId"

# Owner Check at Tenant Root
Write-Host "`nOwner Check:"
$roleAssignments = Get-AzRoleAssignment -SignInName $currentUser -Scope $tenantRootId -ErrorAction SilentlyContinue
$isOwner = $false
if ($roleAssignments) {
    $isOwner = $roleAssignments | Where-Object { $_.RoleDefinitionName -eq "Owner" } | Select-Object -First 1
    if ($isOwner) {
        Write-Host "  " -NoNewline
        Write-Host $checkMark -ForegroundColor Green -NoNewline
        Write-Host " Is Owner: True"
    } else {
        Write-Host "  " -NoNewline
        Write-Host $xMark -ForegroundColor Red -NoNewline
        Write-Host " Is Owner: False"
    }
}

# Policy Checks at Tenant Root
Write-Host "`nPolicy Checks:"
$policyIdsToCheck = @(
    # Tags
    "/providers/Microsoft.Authorization/policyDefinitions/1e30110a-5ceb-460c-a204-c1c3969c6d62", # Require a tag and its value on resources
    "/providers/Microsoft.Authorization/policyDefinitions/8ce3da23-7156-49e4-b145-24f95f9dcb46", # Require a tag and its value on resource groups
    "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99", # Require a tag on resources
    "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025", # Require a tag on resource groups
    # Location
    "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c", # Allowed locations
    "/providers/Microsoft.Authorization/policyDefinitions/e765b5de-1225-4ba3-bd56-1ac6695af988", # Allowed locations for resource groups
    # Resource Types
    "/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c"  # Allowed resource types
)

foreach ($policyId in $policyIdsToCheck) {
    try {
        $policy = Get-AzPolicyDefinition -Id $policyId -ErrorAction Stop
        if ($policy) {
            $assignments = Get-AzPolicyAssignment -Scope $tenantRootId -ErrorAction SilentlyContinue
            $isPolicyEnabled = $false
            foreach ($assignment in $assignments) {
                if ($assignment.PolicyDefinitionId -eq $policyId) {
                    $isPolicyEnabled = $true
                    break
                }
            }
            
            if ($isPolicyEnabled) {
                # Red X for any policy when True
                Write-Host "    " -NoNewline
                Write-Host $xMark -ForegroundColor Red -NoNewline
                Write-Host " $($policy.DisplayName): True"
            } else {
                # Green checkmark for any policy when False
                Write-Host "    " -NoNewline
                Write-Host $checkMark -ForegroundColor Green -NoNewline
                Write-Host " $($policy.DisplayName): False"
            }
        }
    } catch {
        Write-Host "Error checking policy definition $policyId`: $($_.Exception.Message)"
    }
}

# Then check each subscription
foreach ($subscription in $subscriptions) {
    Write-Host "`n=== Checking Subscription ===" -ForegroundColor Cyan
    Write-Host "Scope: /subscriptions/$($subscription.Id)"
    
    # Set the active subscription
    Set-AzContext -SubscriptionId $subscription.Id | Out-Null

    # Provider Checks
    Write-Host "`nProvider Checks:"
    $requiredProviders = @(
        "Microsoft.Insights"
        "Microsoft.Management"
        "Microsoft.EventHub"
        "Microsoft.PolicyInsights"
    )

    foreach ($provider in $requiredProviders) {
        $providerRegistration = Get-AzResourceProvider -ProviderNamespace $provider
        if ($providerRegistration.RegistrationState -eq "Registered") {
            # Green checkmark for registered providers
            Write-Host "  " -NoNewline
            Write-Host $checkMark -ForegroundColor Green -NoNewline
            Write-Host " Provider $provider is registered"
        } else {
            # Red X for unregistered providers
            Write-Host "  " -NoNewline
            Write-Host $xMark -ForegroundColor Red -NoNewline
            Write-Host " Provider $provider is not registered"
        }
    }

    # Owner Check
    Write-Host "`nOwner Check:"
    $roleAssignments = Get-AzRoleAssignment -SignInName $currentUser -Scope "/subscriptions/$($subscription.Id)" -ErrorAction SilentlyContinue
    $isOwner = $false

    if ($roleAssignments) {
        $isOwner = $roleAssignments | Where-Object { $_.RoleDefinitionName -eq "Owner" } | Select-Object -First 1
        if ($isOwner) {
            Write-Host "  " -NoNewline
            Write-Host $checkMark -ForegroundColor Green -NoNewline
            Write-Host " Is Owner: True"
        } else {
            Write-Host "  " -NoNewline
            Write-Host $xMark -ForegroundColor Red -NoNewline
            Write-Host " Is Owner: False"
        }
    }

    # Diagnostic Settings Check
    Write-Host "`nDiagnostic Settings Check:"
    $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId "/subscriptions/$($subscription.Id)" -ErrorAction SilentlyContinue
    $logCount = if ($diagnosticSettings) { ($diagnosticSettings | Measure-Object).Count } else { 0 }
    if ($logCount -lt 5) {
        # Green checkmark for log count less than 5
        Write-Host "  " -NoNewline
        Write-Host $checkMark -ForegroundColor Green -NoNewline
        Write-Host " Activity Logs Exported: $($logCount)"
    } else {
        # Red X for log count 5 or greater
        Write-Host "  " -NoNewline
        Write-Host $xMark -ForegroundColor Red -NoNewline
        Write-Host " Activity Logs Exported: $($logCount)"
    }

    # Policy Checks
    Write-Host "`nPolicy Checks:"
    foreach ($policyId in $policyIdsToCheck) {
        try {
            $policy = Get-AzPolicyDefinition -Id $policyId -ErrorAction Stop
            if ($policy) {
                $assignments = Get-AzPolicyAssignment -Scope "/subscriptions/$($subscription.Id)" -ErrorAction SilentlyContinue
                $isPolicyEnabled = $false
                foreach ($assignment in $assignments) {
                    if ($assignment.PolicyDefinitionId -eq $policyId) {
                        $isPolicyEnabled = $true
                        break
                    }
                }
                
                if ($isPolicyEnabled) {
                    # Red X for any policy when True
                    Write-Host "    " -NoNewline
                    Write-Host $xMark -ForegroundColor Red -NoNewline
                    Write-Host " $($policy.DisplayName): True"
                } else {
                    # Green checkmark for any policy when False
                    Write-Host "    " -NoNewline
                    Write-Host $checkMark -ForegroundColor Green -NoNewline
                    Write-Host " $($policy.DisplayName): False"
                }
            }
        } catch {
            Write-Host "Error checking policy definition $policyId`: $($_.Exception.Message)"
        }
    }
}
