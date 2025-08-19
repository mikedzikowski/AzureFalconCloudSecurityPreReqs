# Define the symbols
$checkMark = [char]0x2713  # ✓
$xMark = [char]0x2717      # ✗

<#
Checkmark Logic:
Green checkmark (✓) conditions:
- Owner: True
- Global Administrator: True
- User Access Administrator: True
- Provider: Registered
- Diagnostic Settings: Count < 5
- All Policies: False

Red X (✗) conditions:
- Owner: False
- Global Administrator: False
- User Access Administrator: False
- Provider: Not Registered
- Diagnostic Settings: Count >= 5
- All Policies: True
#>

# Detect if running in Cloud Shell
$isCloudShell = $false
if ($env:AZUREPS_HOST_ENVIRONMENT -or $env:ACC_CLOUD -eq "AzureCloud") {
    $isCloudShell = $true
    Write-Host "Running in Azure Cloud Shell environment" -ForegroundColor Yellow
}

# Suppress the output and warnings from Connect-AzAccount
try {
    # Check if already connected
    $context = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $context) {
        Connect-AzAccount -WarningAction SilentlyContinue | Out-Null
    }
} catch {
    Write-Host "Error connecting to Azure: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# Get the current user context
$currentUser = (Get-AzContext).Account.Id

# Get all subscriptions
$subscriptions = Get-AzSubscription

# Get the tenant root management group
$tenantDetails = Get-AzTenant
$tenantRootId = "/providers/Microsoft.Management/managementGroups/$($tenantDetails.Id)"

# Define policy information
$policyIdsToCheck = @(
    # Tags
    @{
        Id = "/providers/Microsoft.Authorization/policyDefinitions/1e30110a-5ceb-460c-a204-c1c3969c6d62"
        Name = "Require a tag and its value on resources"
    },
    @{
        Id = "/providers/Microsoft.Authorization/policyDefinitions/8ce3da23-7156-49e4-b145-24f95f9dcb46"
        Name = "Require a tag and its value on resource groups"
    },
    @{
        Id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
        Name = "Require a tag on resources"
    },
    @{
        Id = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
        Name = "Require a tag on resource groups"
    },
    # Location
    @{
        Id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
        Name = "Allowed locations"
    },
    @{
        Id = "/providers/Microsoft.Authorization/policyDefinitions/e765b5de-1225-4ba3-bd56-1ac6695af988"
        Name = "Allowed locations for resource groups"
    },
    # Resource Types
    @{
        Id = "/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c"
        Name = "Allowed resource types"
    }
)

# First check Tenant Root Management Group
Write-Host "`n=== Checking Tenant Root Management Group ===" -ForegroundColor Cyan
Write-Host "Scope: $tenantRootId"

# Owner Check at Tenant Root
Write-Host "`nOwner Check:"
if ($isCloudShell) {
    # In Cloud Shell, we'll check if the user can perform an Owner action
    # instead of directly checking the role assignment
    try {
        # Try to get a management group that requires Owner permissions
        $canManageRoot = Get-AzManagementGroup -GroupId $tenantDetails.Id -ErrorAction SilentlyContinue
        if ($canManageRoot) {
            Write-Host "  " -NoNewline
            Write-Host $checkMark -ForegroundColor Green -NoNewline
            Write-Host " Is Owner: True (based on permissions test)"
        } else {
            Write-Host "  " -NoNewline
            Write-Host $xMark -ForegroundColor Red -NoNewline
            Write-Host " Is Owner: False (based on permissions test)"
        }
    } catch {
        Write-Host "  " -NoNewline
        Write-Host $xMark -ForegroundColor Red -NoNewline
        Write-Host " Is Owner: False (based on permissions test)"
    }
} else {
    # Regular check for non-Cloud Shell environments
    $tenantOwnerAssignment = Get-AzRoleAssignment -Scope '/' -RoleDefinitionName 'Owner' -SignInName $currentUser -ErrorAction SilentlyContinue
    if ($tenantOwnerAssignment) {
        Write-Host "  " -NoNewline
        Write-Host $checkMark -ForegroundColor Green -NoNewline
        Write-Host " Is Owner: True"
    } else {
        Write-Host "  " -NoNewline
        Write-Host $xMark -ForegroundColor Red -NoNewline
        Write-Host " Is Owner: False"
    }
}

# Global Administrator Check
Write-Host "`nGlobal Administrator Check:"
if ($isCloudShell) {
    # In Cloud Shell, we can't reliably check for Global Admin
    Write-Host "  " -NoNewline
    Write-Host "?" -ForegroundColor Yellow -NoNewline
    Write-Host " Global Administrator status cannot be determined in Cloud Shell"
    Write-Host "      To verify, please check in Azure Portal: https://portal.azure.com/#view/Microsoft_AAD_IAM/RolesManagementMenuBlade/~/AllRoles/adminUnitObjectId//resourceScope/%2F"
} else {
    $isGlobalAdmin = $false
    $globalAdminRoleName = "Global Administrator"  # The display name of the Global Admin role

    try {
        # Get an access token for Microsoft Graph API, suppressing warnings
        $token = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -WarningAction SilentlyContinue).Token

        # Set the request headers
        $headers = @{
            "Authorization" = "Bearer $token"
        }

        # Query Microsoft Graph API for user's directory roles
        $uri = "https://graph.microsoft.com/v1.0/me/memberOf"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

        # Check if the user is a member of the Global Administrator role
        $globalAdminRole = $response.value | Where-Object { $_.displayName -eq $globalAdminRoleName }

        if ($globalAdminRole) {
            $isGlobalAdmin = $true
            Write-Host "  " -NoNewline
            Write-Host $checkMark -ForegroundColor Green -NoNewline
            Write-Host " Is Global Administrator: True"
        } else {
            Write-Host "  " -NoNewline
            Write-Host $xMark -ForegroundColor Red -NoNewline
            Write-Host " Is Global Administrator: False"
            Write-Host "      To manage Global Administrators, visit: https://portal.azure.com/#view/Microsoft_AAD_IAM/RolesManagementMenuBlade/~/AllRoles/adminUnitObjectId//resourceScope/%2F"
        }
    } catch {
        Write-Host "  " -NoNewline
        Write-Host $xMark -ForegroundColor Red -NoNewline
        Write-Host " Is Global Administrator: Error checking ($($_.Exception.Message))"
        Write-Host "      To manage Global Administrators, visit: https://portal.azure.com/#view/Microsoft_AAD_IAM/RolesManagementMenuBlade/~/AllRoles/adminUnitObjectId//resourceScope/%2F"
    }
}

# User Access Administrator Check
Write-Host "`nUser Access Administrator Check:"
try {
    # Check if the user has User Access Administrator role at tenant root
    # This should work in both environments
    $userAccessAdminRole = Get-AzRoleAssignment -Scope '/' -RoleDefinitionName 'User Access Administrator' -SignInName $currentUser -ErrorAction SilentlyContinue
    $hasUserAccessAdmin = $false
    
    if ($userAccessAdminRole) {
        $hasUserAccessAdmin = $true
        Write-Host "  " -NoNewline
        Write-Host $checkMark -ForegroundColor Green -NoNewline
        Write-Host " Is User Access Administrator: True"
    } else {
        Write-Host "  " -NoNewline
        Write-Host $xMark -ForegroundColor Red -NoNewline
        Write-Host " Is User Access Administrator: False"
        Write-Host "      To enable, visit: https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/Properties"
    }
} catch {
    Write-Host "  " -NoNewline
    Write-Host $xMark -ForegroundColor Red -NoNewline
    Write-Host " Is User Access Administrator: Error checking ($($_.Exception.Message))"
    Write-Host "      To enable, visit: https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/Properties"
}

# Policy Checks at Tenant Root
Write-Host "`nPolicy Checks:"
foreach ($policyInfo in $policyIdsToCheck) {
    try {
        $policy = Get-AzPolicyDefinition -Id $policyInfo.Id -ErrorAction Stop
        if ($policy) {
            $assignments = Get-AzPolicyAssignment -Scope $tenantRootId -ErrorAction SilentlyContinue
            $isPolicyEnabled = $false
            
            foreach ($assignment in $assignments) {
                if ($assignment.PolicyDefinitionId -eq $policyInfo.Id) {
                    $isPolicyEnabled = $true
                    break
                }
            }
            
            if ($isPolicyEnabled) {
                # Red X for any policy when True
                Write-Host "    " -NoNewline
                Write-Host $xMark -ForegroundColor Red -NoNewline
                Write-Host " $($policyInfo.Name): True"
            } else {
                # Green checkmark for any policy when False
                Write-Host "    " -NoNewline
                Write-Host $checkMark -ForegroundColor Green -NoNewline
                Write-Host " $($policyInfo.Name): False"
            }
        }
    } catch {
        Write-Host "Error checking policy definition $($policyInfo.Id)`: $($_.Exception.Message)"
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
    if ($isCloudShell) {
        # In Cloud Shell, check if the user can perform an Owner action
        try {
            # Try to get a resource group (requires Owner or Contributor)
            $canManageSubscription = Get-AzResourceGroup -ErrorAction SilentlyContinue
            if ($canManageSubscription) {
                # Additional check to distinguish between Owner and Contributor
                # Try to assign a role (requires Owner)
                $testGuid = [guid]::NewGuid().ToString()
                $canAssignRoles = $false
                try {
                    # Just check if the command would work, don't actually execute it
                    $roleDefId = (Get-AzRoleDefinition -Name "Reader").Id
                    $testCommand = "New-AzRoleAssignment -ObjectId $testGuid -RoleDefinitionId $roleDefId -Scope /subscriptions/$($subscription.Id) -WhatIf"
                    Invoke-Expression $testCommand -ErrorAction Stop
                    $canAssignRoles = $true
                } catch {
                    # If this fails, user likely doesn't have Owner permissions
                }
                
                if ($canAssignRoles) {
                    Write-Host "  " -NoNewline
                    Write-Host $checkMark -ForegroundColor Green -NoNewline
                    Write-Host " Is Owner: True (based on permissions test)"
                } else {
                    Write-Host "  " -NoNewline
                    Write-Host $xMark -ForegroundColor Red -NoNewline
                    Write-Host " Is Owner: False (based on permissions test)"
                }
            } else {
                Write-Host "  " -NoNewline
                Write-Host $xMark -ForegroundColor Red -NoNewline
                Write-Host " Is Owner: False (based on permissions test)"
            }
        } catch {
            Write-Host "  " -NoNewline
            Write-Host $xMark -ForegroundColor Red -NoNewline
            Write-Host " Is Owner: False (based on permissions test)"
        }
    } else {
        # Regular check for non-Cloud Shell environments
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
    foreach ($policyInfo in $policyIdsToCheck) {
        try {
            $policy = Get-AzPolicyDefinition -Id $policyInfo.Id -ErrorAction Stop
            if ($policy) {
                $assignments = Get-AzPolicyAssignment -Scope "/subscriptions/$($subscription.Id)" -ErrorAction SilentlyContinue
                $isPolicyEnabled = $false
                
                foreach ($assignment in $assignments) {
                    if ($assignment.PolicyDefinitionId -eq $policyInfo.Id) {
                        $isPolicyEnabled = $true
                        break
                    }
                }
                
                if ($isPolicyEnabled) {
                    # Red X for any policy when True
                    Write-Host "    " -NoNewline
                    Write-Host $xMark -ForegroundColor Red -NoNewline
                    Write-Host " $($policyInfo.Name): True"
                } else {
                    # Green checkmark for any policy when False
                    Write-Host "    " -NoNewline
                    Write-Host $checkMark -ForegroundColor Green -NoNewline
                    Write-Host " $($policyInfo.Name): False"
                }
            }
        } catch {
            Write-Host "Error checking policy definition $($policyInfo.Id)`: $($_.Exception.Message)"
        }
    }
}
