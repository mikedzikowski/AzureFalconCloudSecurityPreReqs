# Azure Pre-Requirements Checker for Falcon Cloud Security

## Overview
This PowerShell script helps customers validate their Azure environment meets the necessary prerequisites before onboarding to CrowdStrike's Falcon Cloud Security solution. It performs comprehensive checks across Azure subscriptions and tenant root management group.

## What it Checks

### Tenant Root Level
- **[Owner Status](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner)**: Verifies required owner permissions at tenant level
- **[Global Administrator](https://learn.microsoft.com/en-us/azure/active-directory/roles/permissions-reference#global-administrator)**: Checks if the user has Global Administrator role
- **[User Access Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#user-access-administrator)**: Verifies if the user has User Access Administrator role or elevated access
- **[Policy Assignments](https://learn.microsoft.com/en-us/azure/governance/policy/overview)**: Identifies potential policy conflicts at tenant level

### Subscription Level
- **[Owner Status](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner)**: Verifies required owner permissions
- **[Provider Registration](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-services-resource-providers)**: Validates required Azure providers
  - Microsoft.Insights
  - Microsoft.Management
  - Microsoft.EventHub
  - Microsoft.PolicyInsights
- **[Diagnostic Settings](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/service-limits#diagnostic-settings)**: Checks activity log export configuration (optimal: < 5 logs)
- **[Policy Assignments](https://learn.microsoft.com/en-us/azure/governance/policy/overview)**: Identifies potential policy conflicts

### Checked Policies
- [Require a tag and its value on resources](https://www.azadvertizer.net/azpolicyadvertizer/1e30110a-5ceb-460c-a204-c1c3969c6d62.html)
- [Require a tag and its value on resource groups](https://www.azadvertizer.net/azpolicyadvertizer/8ce3da23-7156-49e4-b145-24f95f9dcb46.html)
- [Require a tag on resources](https://www.azadvertizer.net/azpolicyadvertizer/871b6d14-10aa-478d-b590-94f262ecfa99.html)
- [Require a tag on resource groups](https://www.azadvertizer.net/azpolicyadvertizer/96670d01-0a4d-4649-9c89-2d3abc0a5025.html)
- [Allowed locations](https://www.azadvertizer.net/azpolicyadvertizer/e56962a6-4747-49cd-b67b-bf8b01975c4c.html)
- [Allowed locations for resource groups](https://www.azadvertizer.net/azpolicyadvertizer/e765b5de-1225-4ba3-bd56-1ac6695af988.html)
- [Allowed resource types](https://www.azadvertizer.net/azpolicyadvertizer/a08ec900-254a-4555-9bf5-e42af04b5c5c.html)

## Visual Indicators

### ✓ Green checkmark - Ready for onboarding
- Owner: True (required for onboarding)
- Global Administrator: True (provides additional capabilities)
- User Access Administrator: True (provides necessary permissions)
- Provider: Registered (required for functionality)
- Diagnostic Settings: Count < 5 (optimal configuration)
- Policies: False (no conflicting policies)

### ✗ Red X - Needs attention
- Owner: False (insufficient permissions)
- Global Administrator: False (limited capabilities)
- User Access Administrator: False (limited permissions)
- Provider: Not Registered (missing requirements)
- Diagnostic Settings: Count >= 5 (potential issues)
- Policies: True (potential conflicts)

## Prerequisites
- Azure PowerShell module installed (for local execution)
- Sufficient permissions to read configurations
- Active Azure subscription

## Usage

### Local Execution
```powershell
# Run the script locally
./Get-PreReqs.ps1
```

### Azure Cloud Shell
```powershell
# Run in Azure Cloud Shell (PowerShell)
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/mikedzikowski/AzureFalconCloudSecurityPreReqs/main/Get-PreReqs.ps1" -OutFile "Get-PreReqs.ps1"
./Get-PreReqs.ps1
```

Note: Azure Cloud Shell comes with Azure PowerShell modules pre-installed, making it an ideal option for quick checks without local setup.

## Output Example
```
=== Checking Tenant Root Management Group ===
Scope: /providers/Microsoft.Management/managementGroups/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Owner Check:
  ✓ Is Owner: True

Global Administrator Check:
  ✓ Is Global Administrator: True

User Access Administrator Check:
  ✓ Is User Access Administrator: True

Policy Checks:
    ✓ Require a tag and its value on resources: False
    ✓ Allowed locations: False

=== Checking Subscription ===
Scope: /subscriptions/xxxx-xxxx-xxxx-xxxx

Provider Checks:
  ✓ Provider Microsoft.Insights is registered
  ✓ Provider Microsoft.Management is registered
  ✓ Provider Microsoft.EventHub is registered
  ✓ Provider Microsoft.PolicyInsights is registered

Owner Check:
  ✓ Is Owner: True

Diagnostic Settings Check:
  ✓ Activity Logs Exported: 2

Policy Checks:
    ✓ Require a tag and its value on resources: False
    ✓ Allowed locations: False
```

## Troubleshooting
- If you see "Is Global Administrator: False", you can manage Global Administrator roles at: https://portal.azure.com/#view/Microsoft_AAD_IAM/RolesManagementMenuBlade/~/AllRoles/adminUnitObjectId//resourceScope/%2F
- If you see "Is User Access Administrator: False", you can enable this at: https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/Properties
- If you see "Activity Logs Exported: 5" or higher, you can manage Activity Log settings at: https://portal.azure.com/#view/Microsoft_Azure_Monitoring/DiagnosticsLogsBlade/

## Note
This script is designed to help identify any potential blockers or configuration issues that need to be addressed before proceeding with Falcon Cloud Security onboarding. If you see any ✗ indicators, please review the requirements documentation or contact CrowdStrike Support for assistance.

## Additional Resources
- [Azure Resource Providers Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-services-resource-providers)
- [Azure Policy Documentation](https://learn.microsoft.com/en-us/azure/governance/policy/)
- [Azure RBAC Documentation](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview)
- [Azure Diagnostic Settings Documentation](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/diagnostic-settings)
- [Azure Cloud Shell Overview](https://learn.microsoft.com/en-us/azure/cloud-shell/overview)
- [Azure AD Roles Documentation](https://learn.microsoft.com/en-us/azure/active-directory/roles/permissions-reference)