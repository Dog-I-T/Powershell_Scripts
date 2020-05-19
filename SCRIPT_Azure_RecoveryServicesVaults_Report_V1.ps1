<#
    .DESCRIPTION
        GET the following information from Azure Recovery Services Vaults and export to CSV files,
            - Azure Storage Accounts
            - AzureVM Backup Enabled (True/False)
            - AzureVM Backup Status

    .POWERSHELL MODULE
        Az 3.8.0

    .VARIABLES TO EDIT
        $Company
        $ReportFolder
        $DaysBack

    .EXAMPLE
        1. Save this script as "SCRIPT_AzureRecoveryServciesVaults_Report.ps1"
        2. Create folder C:\Temp\Reports
        3. Run script in Powershell
        4. Connect-AzAccount will prompt to authenticate to Azure
        5. Three CSV files are created in C:\Temp\Reports
            - 'CompanyName'_Azure_StorageAccount_Report_'CurrentDate'.csv
            - 'CompanyName'_AzureVM_BackupEnabled_Report_'CurrentDate'.csv
            - 'CompanyName'_AzureVM_BackupStatus_Report_'CurrentDate'.csv

    .COMMAND REFERENCES
        https://docs.microsoft.com/en-us/powershell/module/az.accounts/get-azsubscription?view=azps-3.8.0
        https://docs.microsoft.com/en-us/powershell/module/az.recoveryservices/get-azrecoveryservicesbackupstatus?view=azps-3.8.0
        https://docs.microsoft.com/en-us/powershell/module/az.recoveryservices/get-azrecoveryservicesvault?view=azps-3.8.0
        https://docs.microsoft.com/en-us/powershell/module/az.recoveryservices/get-azrecoveryservicesbackupcontainer?view=azps-3.8.0
        https://docs.microsoft.com/en-us/powershell/module/az.recoveryservices/get-azrecoveryservicesbackupitem?view=azps-3.8.0

    .FILE INFORMATION
        Date Created: 19 May 2020
        Version: 1.0
        Created By: Jye Keath
#>

#### START SCRIPT ####

# Connect to AzureAZ Module
Connect-AzAccount

# SET Variables
$Company = ""
$ReportFolder = "C:\Temp\Reports\"
$ReportFile1 = "$($Company)_AzureVM_BackupEnabled_Report_$(get-date -format dd_MM_yyyy).csv"
$ReportFile2 = "$($Company)_AzureVM_BackupStatus_Report_$(get-date -format dd_MM_yyyy).csv"
$ReportFile3 = "$($Company)_Azure_StorageAccount_Report_$(get-date -format dd_MM_yyyy).csv"
$ReportPath1 = $ReportFolder + $ReportFile1
$ReportPath2 = $ReportFolder + $ReportFile2
$ReportPath3 = $ReportFolder + $ReportFile3

# Remove Reports if already run today
Remove-Item $ReportPath1 -ErrorAction Ignore
Remove-Item $ReportPath2 -ErrorAction Ignore
Remove-Item $ReportPath3 -ErrorAction Ignore

# Cleanup old Report files
$CurrentDate = Get-Date
$DaysBack = "-60"
$DateToDelete = $CurrentDate.AddDays($DaysBack)
Get-ChildItem $ReportPath1  -ErrorAction Ignore | Where-Object {$_.LastWriteTime -lt $DateToDelete} | Remove-Item
Get-ChildItem $ReportPath2  -ErrorAction Ignore | Where-Object {$_.LastWriteTime -lt $DateToDelete} | Remove-Item
Get-ChildItem $ReportPath3  -ErrorAction Ignore | Where-Object {$_.LastWriteTime -lt $DateToDelete} | Remove-Item

#### LOAD Functions

# FUNCTION GetAzureStorageAccounts
function GetAzureStorageAccounts {

    $Report = @()

    $Subscriptions = Get-AzSubscription | Where-Object {($_.Name -notlike "*Azure Active Directory*") -and ($_.Name -notlike '*Microsoft Azure Enterprise*')}

    ForEach ($sub in $Subscriptions) {
        Get-AzSubscription -SubscriptionName $sub.Name | Set-AzContext | Out-Null
    
        $StorageAccounts = Get-AzStorageAccount
    
        ForEach ($account in $StorageAccounts) {
            $StorageAccountName = $account.StorageAccountName
            $ResourceGroupName = $account.ResourceGroupName
    
            $Key1 = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName)[0].Value
            $Key2 = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName)[1].Value
    
            $ConnectionString1 = 'DefaultEndpointsProtocol=https;AccountName=' + $StorageAccountName + ';AccountKey=' + $Key1 + ';EndpointSuffix=core.windows.net'
            $ConnectionString2 = 'DefaultEndpointsProtocol=https;AccountName=' + $StorageAccountName + ';AccountKey=' + $Key2 + ';EndpointSuffix=core.windows.net'
    
            $Object = [PSCustomObject] @{
                StorageAccount    = $StorageAccountName
                ResourceGroup     = $ResourceGroupName
                PrimaryLocation   = $account.PrimaryLocation
                Kind              = $account.Kind
                CreationTime      = $account.CreationTime
                ConnectionString1 = $ConnectionString1
                ConnectionString2 = $ConnectionString2
            }
    
            $Report += $Object
    
        }

    }

    $Report | Sort-Object StorageAccountName

}

# FUNCTION GetAzureVMBackupEnabled
function GetAzureVMBackupEnabled {

    $Report = @()

    $Subscriptions = Get-AzSubscription | Where-Object {($_.Name -notlike "*Azure Active Directory*") -and ($_.Name -notlike '*Microsoft Azure Enterprise*')}

    ForEach ($sub in $Subscriptions) {
        
        Get-AzSubscription -SubscriptionName $sub.Name | Set-AzContext | Out-Null

        $VMs = Get-AZVM -Status

        ForEach ($vm in $VMs) {

            $BackupStatus = Get-AzRecoveryServicesBackupStatus -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Type "AzureVM"

            ForEach ($backup in $BackupStatus) {

                If ($backup.VaultId) {
                    $RSV = $backup.VaultId.Split('/')[-1]
                }

                ElseIf ($backup.BackedUp -eq $false) {
                    $RSV = "NA"
                }

                $Object = [PSCustomObject] @{
                    VMName                = $vm.Name
                    VMPowerState          = $vm.PowerState
                    VMResourceGroupName   = $vm.ResourceGroupName
                    VMLocation            = $vm.Location
                    VMOsType              = $vm.OsType 
                    RecoveryServicesVault = $RSV
                    BackedUp              = $backup.BackedUp
                }

                $Report += $Object

            }
        
        }
    
    }

    $Report | Sort-Object VMName

}

# FUNCTION GetAzureVMBackupStatus
function GetAzureVMBackupStatus {

    $Report = @()

    $Subscriptions = Get-AzSubscription | Where-Object {($_.Name -notlike "*Azure Active Directory*") -and ($_.Name -notlike '*Microsoft Azure Enterprise*')}

    ForEach ($sub in $Subscriptions) {
        Get-AzSubscription -SubscriptionName $sub.Name | Set-AzContext | Out-Null

        $Vaults = Get-AZRecoveryServicesVault

        ForEach ($vault in $Vaults) {
            $Containers =  Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -Status Registered -VaultId $vault.ID

            ForEach ($container in $Containers) {
                $BackupItems = Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType AzureVM -VaultId $vault.ID

                $Object = [PSCustomObject] @{
                    VMNameShort          = $BackupItems.Name -replace ".*;"
                    VMNameLong           = $BackupItems.Name
                    HealthStatus         = $BackupItems.HealthStatus
                    LastBackupStatus     = $BackupItems.LastBackupStatus
                    LastBackupTime       = $BackupItems.LastBackupTime
                    WorkloadType         = $BackupItems.WorkloadType
                    ProtectionPolicyName = $BackupItems.ProtectionPolicyName
                    Container            = $container.Name
                }

                $Report += $Object

            }

        }

    }
    
    $Report | Sort-Object VMShortName

}

# Create Reports
$Report1 = GetAzureStorageAccounts
$Report2 = GetAzureVMBackupEnabled
$Report3 = GetAzureVMBackupStatus

# Export to CSV
$Report1 | Export-Csv $ReportPath1 -NoTypeInformation
$Report2 | Export-Csv $ReportPath2 -NoTypeInformation
$Report3 | Export-Csv $ReportPath3 -NoTypeInformation

#### END SCRIPT ####