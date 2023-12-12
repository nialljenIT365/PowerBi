<#
.SYNOPSIS
This script retrieves Azure VM pricing information. It provides functions for fetching VM SKUs and their prices based on the specified parameters: SKU, currency, and region.

.DESCRIPTION
The script includes three main functionalities:
1. Get-AzureVMPrice: Fetches the price of a specific VM SKU in a given currency and region.
2. Get-AzureVMSKUs: Retrieves a list of VM SKUs available in a specified region.
3. Where-AzureVMSKU: Filters the list of VM SKUs based on a given string.

.PARAMETERS
- vmSku: The SKU of the VM for which prices are retrieved.
- currencyCode: The currency in which prices are reported.
- region: The Azure region for which VM prices are fetched.

.EXAMPLE
$Region = "uksouth"
$CurrencyCode = "GBP"
$Filter = "_D16"

Get-AzureVMSKUs -region $Region | Where-AzureVMSKU -Contains $Filter | Get-AzureVMPrice -currencyCode $CurrencyCode -region $Region

This example retrieves the prices of VMs in the 'uksouth' region that match the SKU pattern '_D16' and reports prices in GBP.

.NOTES
Version: 1.0
Author: Niall Jennings
Creation Date: 12/12/2023
Comments: Parent script to generate output from the Azure API and the filter function.
#>

# Function to get Azure VM prices
Function Get-AzureVMPrice {
    <#
    .NOTES
     Version: 1.1
     Author: Leee Jeffries
     Creation Date: 15/12/2023
     Comments: Original script from https://leeejeffries.com/checking-prices-for-azure-vms-with-powershell with addition of a process block to facilitate piping the output from Get-AzureVMSKUs and Where-AzureVMSKU. 
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline, HelpMessage='The VM Sku to get prices for', Mandatory=$true)]
        [string]$vmSku,

        [Parameter(HelpMessage='The currency to report back', Mandatory=$true)]
        [string]$currencyCode,

        [Parameter(HelpMessage='Azure region to get prices for', Mandatory=$true)]
        [string]$region
    )

    Process {
        # Setup request parameters
        $Parameters = @{
            currencyCode = $currencyCode
            '$filter' = "serviceName eq 'Virtual Machines' and armSkuName eq `'$vmSku`' and armRegionName eq `'$region`' and type eq 'Consumption'"
        }

        # Make a web request for the prices
        try {
            $request = Invoke-WebRequest -UseBasicParsing -Uri "https://prices.azure.com/api/retail/prices" -Body $Parameters -Method Get
            $result = $request.Content | ConvertFrom-Json | Select-Object -ExpandProperty Items | Sort-Object effectiveStartDate -Descending | Select -First 1

            # Creating the object to return
            $vmPrice = [PSCustomObject]@{
                SKUName = $($result.armSkuName)
                Region = $($result.armRegionName)
                Currency = $($result.currencyCode)
                Product_Name = $($result.productName)
                Price_Per_Minute = if ($($result.unitOfMeasure) -match 'Hour') {$($result.retailPrice)/60 } else { 0 }
                Price_Per_Hour = if ($($result.unitOfMeasure) -match 'Hour') { $($result.retailPrice) } else { 0 }
                Price_Per_Day = if ($($result.unitOfMeasure) -match 'Hour') { $($result.retailPrice) * 24 } else { 0 }
            }
            
            # Check if SKUName is available
            if ([string]::IsNullOrEmpty($vmPrice.SKUName)) {
                Throw
            } else {
                Return $vmPrice
            }

        } catch {
            Write-Error "Error processing request, check the SKU and region are valid"
            Write-Error $_
        }
    }
}

# Function to get Azure VM SKUs
Function Get-AzureVMSKUs {
    <#
    .NOTES
     Version: 1.0
     Author: Leee Jeffries
     Creation Date: 15/12/2023
     Comments: Original script as is from https://leeejeffries.com/checking-prices-for-azure-vms-with-powershell 
    #>
    [CmdletBinding()]

    Param
    (
        [Parameter(HelpMessage='Azure region to get prices for', Mandatory=$true)]
        [string]$region
    )

    # Setup parameters for the request
    $Parameters = @{
        currencyCode = $currencyCode
        '$filter' = "serviceName eq 'Virtual Machines' and armRegionName eq `'$region`' and type eq 'Consumption'"
    }

    # Make a web request for the VM SKUs
    try {
        $request = Invoke-WebRequest -UseBasicParsing -Uri "https://prices.azure.com/api/retail/prices" -Body $Parameters -Method Get
        $result = $request.Content | ConvertFrom-Json | Select-Object -ExpandProperty Items | Select-Object armSkuName

        # Collect and return unique SKUs
        $SKUs = foreach ($item in $result) {
            $item.armSkuName
        }

        Return $SKUs | Select-Object -Unique | Sort-Object
    } catch {
        Write-Error "Error processing request, check the region and currency are valid"
        Write-Error $_
    }
}

# Function to filter Azure VM SKUs
function Where-AzureVMSKU {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [array]$SKUList,

        [Parameter(Mandatory=$false)]
        [string]$Contains
    )

    begin {
        # Initialize an array to hold filtered SKUs
        $filteredSKUs = @()
    }

    process {
        # Check if filter is set to '*', if so, add all SKUs to the array without filtering
        if ($Contains -eq "*") {
            $filteredSKUs += $SKUList
        } else {
            # Add matching SKUs to the array based on the Contains filter
            $filteredSKUs += $SKUList | Where-Object {
                $_ -imatch $Contains
            }
        }
    }

    end {
        # Return the filtered list of SKUs
        return $filteredSKUs
    }
}

<#
.VARIABLES
#>
$Region = "uksouth"
$CurrencyCode = "GBP"
$Filter = "*"
<#
.SCRIPT BODY
#>
Get-AzureVMSKUs -region $Region | Where-AzureVMSKU -Contains $Filter | Get-AzureVMPrice -currencyCode $CurrencyCode -region $Region