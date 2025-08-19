# Azure Pre-Requirements Checker for Falcon Cloud Security

## Overview
This PowerShell script helps customers validate their Azure environment meets the necessary prerequisites before onboarding to CrowdStrike's Falcon Cloud Security solution. It performs comprehensive checks across Azure subscriptions and tenant root management group.

## What it Checks
- **Owner Status**: Verifies required owner permissions
- **Provider Registration**: Validates required Azure providers
  - Microsoft.Insights
  - Microsoft.Management
- **Diagnostic Settings**: Checks activity log export configuration (optimal: < 5 logs)
- **Policy Assignments**: Identifies potential policy conflicts with:
  - Tag requirements
  - Location restrictions
  - Resource type restrictions

## Visual Indicators
- <span style="color:green">✓</span> (Green Checkmark): Ready for onboarding
  - Owner: True (required for onboarding)
  - Provider: Registered (required for functionality)
  - Diagnostic Settings: Count < 5 (optimal configuration)
  - Policies: False (no conflicting policies)

- <span style="color:red">✗</span> (Red X): Needs attention
  - Owner: False (insufficient permissions)
  - Provider: Not Registered (missing requirements)
  - Diagnostic Settings: Count >= 5 (potential issues)
  - Policies: True (potential conflicts)

## Prerequisites
- Azure PowerShell module installed
- Sufficient permissions to read configurations
- Active Azure subscription

## Usage
```powershell
# Run the script
.\Get-PreReqs.ps1
```

## Output Example
```
=== Checking Subscription ===
Scope: /subscriptions/xxxx-xxxx-xxxx-xxxx

Provider Checks:
  <span style="color:green">✓</span> Provider Microsoft.Insights is registered
  <span style="color:green">✓</span> Provider Microsoft.Management is registered

Owner Check:
  <span style="color:green">✓</span> Is Owner: True

Diagnostic Settings Check:
  <span style="color:green">✓</span> Activity Logs Exported: 2

Policy Checks:
    <span style="color:green">✓</span> Require a tag and its value on resources: False
    <span style="color:green">✓</span> Allowed locations: False
```

## Note
This script is designed to help identify any potential blockers or configuration issues that need to be addressed before proceeding with Falcon Cloud Security onboarding. If you see any <span style="color:red">✗</span> indicators, please review the requirements documentation or contact CrowdStrike Support for assistance.

Note: If viewing this README in a plain text editor, the colored symbols may not appear. When running the script, you will see colored indicators in your PowerShell console.
