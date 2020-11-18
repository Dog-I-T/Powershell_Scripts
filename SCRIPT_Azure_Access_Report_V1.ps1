<#
    .DESCRIPTION
        GET the following information for an Azure tenant and export to CSV files,
            - AzureAD Directory Role assignments
            - Azure Subscription Access (All Subscriptions)

    .POWERSHELL MODULES
        Az 3.8.0
        AzureAD 2.0.2.76

    .VARIABLES TO EDIT
        $Company
        $ReportFolder
        $DaysBack

    .EXAMPLE
        1. Save this script as "SCRIPT_Azure_Access_Report.ps1"
        2. Create folder C:\Temp\Reports
        3. Run script in Powershell
        4. Connect-AzAccount and Connect-AzureAD will prompt to authenticate to Azure
        5. Two CSV files are created in C:\Temp\Reports
            - 'CompanyName'_AzureAD_DirectoryRoles_Report_'CurrentDate'.csv
            - 'CompanyName'_Azure_SubscriptionAccess_Report_'CurrentDate'.csv

    .COMMAND REFERENCES
        https://docs.microsoft.com/en-us/powershell/azure/new-azureps-module-az?view=azps-3.8.0
        https://www.powershellgallery.com/packages/AzureAD/2.0.2.4
        https://docs.microsoft.com/en-us/powershell/module/azuread/get-azureaddirectoryrole?view=azureadps-2.0
        https://docs.microsoft.com/en-us/powershell/module/azuread/get-azureaddirectoryrolemember?view=azureadps-2.0
        https://docs.microsoft.com/en-us/powershell/module/az.accounts/get-azsubscription?view=azps-3.8.0
        https://docs.microsoft.com/en-us/powershell/module/az.resources/get-azroleassignment?view=azps-3.8.0

    .FILE INFORMATION
        Date Created: 19 Nov 2020
        Version: 1.0
        Created By: Jye Keath
#>

#### START SCRIPT ####

# Connect to AzureAZ Module
Connect-AzAccount

# Connect to AzureAD Module
Connect-AzureAD

# SET Variables
$Company = "SV"
$ReportFolder = "C:\Temp\Reports\"
$ReportFile1 = "$($Company)_AzureAD_DirectoryRoles_Report_$(get-date -format yyyy_MM_dd).csv"
$ReportFile2 = "$($Company)_Azure_SubscriptionAccess_Report_$(get-date -format yyyy_MM_dd).csv"
$ReportPath1 = $ReportFolder + $ReportFile1
$ReportPath2 = $ReportFolder + $ReportFile2

# REMOVE THE REPORTS IF ALREADY BEEN RUN TODAY
Remove-Item $ReportPath1 -ErrorAction Ignore
Remove-Item $ReportPath2 -ErrorAction Ignore

# CLEANUP OLD REPORT FILES
$CurrentDate = Get-Date
$DaysBack = "-60"
$DateToDelete = $CurrentDate.AddDays($DaysBack)
Get-ChildItem $ReportPath1 -ErrorAction Ignore | Where-Object {$_.LastWriteTime -lt $DateToDelete} | Remove-Item
Get-ChildItem $ReportPath2 -ErrorAction Ignore | Where-Object {$_.LastWriteTime -lt $DateToDelete} | Remove-Item

#### LOAD Functions

# FUNCTION: GetAzureADDirectoryRoles
function GetAzureADAdminRoles {
    
    $Report = @()
    
    $AzureADDirectoryRoles = Get-AzureADDirectoryRole

    ForEach ($role in $AzureADDirectoryRoles) {

        $RoleMembers = Get-AzureADDirectoryRoleMember -ObjectId $role.ObjectId | Select-Object DisplayName,ObjectType,RoleDisabled,UserPrincipalName,UserType,AccountEnabled

        ForEach ($member in $RoleMembers) {

            $ServicePrincipal = $true | Where-Object {$member.ObjectType -eq 'ServicePrincipal'}

            $Object = [PSCustomObject] @{
                RoleDisplayName   = $role.DisplayName
                RoleObjectType    = $role.ObjectType
                RoleDisabled      = $role.RoleDisabled
                MemberDisplayName = $member.DisplayName
                MemberEnabled     = $member.AccountEnabled
                MemberType        = $member.ObjectType
                MemberUPN         = If ($ServicePrincipal -eq $true) {'NotApplicable'} Else {$member.UserPrincipalName}
            }

            $Report += $Object

        }
        
    }

    $Report | Sort-Object RoleDisplayName,MemberDisplayName

}

# FUNCTION: GetAzureSubscriptionAccess
function GetAzureSubscriptionAccess {

    $Report = @()

    $Subscriptions = Get-AzSubscription

    ForEach ($sub in $Subscriptions) {
        
        Get-AzSubscription -SubscriptionName $sub.Name | Set-AzContext | Out-Null

        $AssignedRoles = Get-AzRoleAssignment | Select-Object RoleDefinitionName | Sort-Object RoleDefinitionName | Get-Unique -AsString

        ForEach ($role in $AssignedRoles) {

            $RoleMembers = Get-AzRoleAssignment -RoleDefinitionName $role.RoleDefinitionName -IncludeClassicAdministrators | Select-Object DisplayName,SignInName,RoleDefinitionName,ObjectType,CanDelegate,Scope

            ForEach ($member in $RoleMembers) {

                $Object = [PSCustomObject] @{
                    SubscriptionName         = $sub.Name
                    SubscriptionRole         = $role.RoleDefinitionName
                    MemberDisplayName        = $member.DisplayName
                    MemberSignInName         = $member.SignInName
                    MemberRoleDefinitionName = $member.RoleDefinitionName
                    MemberObjectType         = $member.ObjectType
                    MemberCanDelegate        = $member.CanDelegate
                    MemberScope              = $member.Scope
                }

                $Report += $Object

            }

        }

    }

    $Report | Sort-Object SubscriptionName,SubscriptionRole,MemberDisplayName

}

# Create Reports
$Report1 = GetAzureADAdminRoles
$Report2 = GetAzureSubscriptionAccess

# Export to CSV
$Report1 | Export-Csv $ReportPath1 -NoTypeInformation
$Report2 | Export-Csv $ReportPath2 -NoTypeInformation
