function Get-CustomerSettings {
    <#
    .SYNOPSIS
    Get a set of customer parameters to be used to prepare CDParameters

    .DESCRIPTION
    In Cloud Suite Environments there is a CustomerSettings resource group, which has multiple tags with the needed customer settings. 

    .PARAMETER NoConfirm
    When using this switch, there will be no popup form confirmation of the settings.
    
    .Example
    $CustomerSettings = Get-CsCustomerSettings

    .Example
    $CustomerSettings = Get-CsCustomerSettings -NoConfirm
    #>

    Param(
        [String]$CustomerName
        ,
        [String]$CustomerShort

    )

    $AzContext = Get-AzContext -ErrorAction Stop
    Write-Verbose "Using subscription $()"

    $subscriptionFilter = "/subscriptions/$($AzContext.Subscription.Id)*"
    #$tags = Get-AzTag -Name 'Deployment' -ResourceType 'Microsoft.Subscription'
    #$Deployment = $tags.Where{$_.Name -eq 'Deployment' -and $_.ResourceType -eq 'Microsoft.Subscription'}
    Try{
        $DeploymentTag = Get-AzTag -Name 'Deployment' -ResourceType 'Microsoft.Subscription' -ResourceId $subscriptionFilter -ErrorAction Stop
        $DeploymentDetails = $null
        #If ($DeploymentTag){
            $Deployment = $DeploymentTag.Value | ConvertFrom-Json
    
            If ($CustomerShort -and ($CustomerShort -in $Deployment)){
                $DeploymentDetails = $tags.Where{$_.Name -eq "Deployment_$($CustomerShort)" -and $_.ResourceType -eq 'Microsoft.Subscription'}
            }
            If ($CustomerName){
                #later
            }
            $DeploymentChoice = $Deployment | Out-Gridview -PassThru -Title "Kies deployment" 
            $DeploymentDetails = $tags.Where{$_.Name -eq "Deployment_$($DeploymentChoice)" -and $_.ResourceType -eq 'Microsoft.Subscription'}
            $DeploymentDetailsTag = Get-AzTag -Name "Deployment_$($DeploymentChoice)" -ResourceType 'Microsoft.Subscription' -ResourceId $subscriptionFilter
            $Parameters = $DeploymentDetailsTag.Value | ConvertFrom-Json
        #}Else{
            
        #}

            #find tagged resources
    $tags = get-aztag -ResourceId $subscriptionFilter
    $relatedTags = Get-AzTag -Name 'Deployment' -Value $Parameters.CustomerShort -ResourceId $subscriptionFilter
    $tags.where{$_.ResourceId -in $relatedTags.ResourceId -and $_.Name -ne 'Deployment'}


    If ($NoConfirm){$Confirm = $False} Else {$Confirm = $True}

    $Tags = (Get-AzResourceGroup -Tag @{'Settings'='CustomerSettings'}).Tags
    
    $CustomerSettings = @{}
    $CustomerSettings.CustomerName = $Tags['CustomerName']
    $CustomerSettings.vnetCIDR = $tags['VnetCIDR']
    $CustomerSettings.CustomerShort = $tags['CustomerShort']
    $CustomerSettings.PublicFQDN = $tags['PublicFQDN']
    $CustomerSettings.InternalFQDN = $tags['InternalFQDN']
    $CustomerSettings.NetbiosName = $tags['NetbiosName']
    $CustomerSettings.CloudSuiteVersion = $tags['CloudSuiteVersion']
    $CustomerSettings.wvddefaultbaseimage = $tags['wvddefaultbaseimage']
    If ($tags.Contains('Prefix')) {$CustomerSettings.Prefix = $tags['Prefix']} Else {$CustomerSettings.Prefix = "cs"} 

    #check if tags exist
    If ($Confirm -eq $true){
        If ($tags -eq $null)  {   
            [System.Windows.Forms.MessageBox]::Show("Customer settings not found in tenant $tenant`n`nMake sure the Resource Group CustomerSettings exists`nwith the following tags:  `n -CustomerName`n -CustomerShort`n -PublicFQDN`n -vnetCIDR`n`nExiting procedure" , "ERROR" , 1)
            return
        }
    }
    }Catch{
        #Try to get value the old way
        $CustomerSettings = Get-CustomerSettingsOld

        If ($CustomerSettings){
            Write-Warning -Message "Old type customersettings found, please migrate to new type!"
        }
    }
    


    return $CustomerSettings
}


function Get-CustomerSettingsOld {
    $CustomerSettings = @(Get-AzResourceGroup | Where-Object -Property ResourceGroupName -like '*-customersettings-rg')
    If ($null -eq $CustomerSettings){
        Write-Warning -Message "Geen bestaande CustomerSettings gevonden"
    }
    If ($CustomerSettings.Count -gt 1){
        Throw "Meerdere ResourceGroepen met de (deel)naam CustomerSettings gevonden!"
    }
    $CustomerSettings = $CustomerSettings[0]
    return $CustomerSettings.Tags
}


function Get-SettingsVirtualNetwork{
    param(
        # Parameter help description
        [Parameter(Mandatory)]
        [String]
        $Deployment
    )
    $AzVirtualNetwork = Get-AzVirtualNetwork
    foreach ($net in $AzVirtualNetwork){
        $tags = Get-AzTag -ResourceId $net.id -Name 'Deployment' -Value $Deployment
        $DeploymentTag = $tags.where{$_.Name -eq 'Deployment'}
        if ($DeploymentTag.Value -eq $Deployment){
            $vnet = [PSCustomObject]@{
                Name = $net.Name
                ResourceGroupName = $net.ResourceGroupName
                AddressPrefixes = ($net.AddressSpaceText | ConvertFrom-Json).AddressPrefixes
            }          
            $SubnetTags = $tags.where{$_.Name -like '*Subnet'}
            $SubnetTags
            #$UniqueSubnets = $SubnetTags.Value | Select-Object -Unique 
            $Subnets = $net | Get-AzVirtualNetworkSubnetConfig
            $SubnetReport = @()
            foreach ($snt in $SubnetTags){
                if ($snt.Value -in $Subnets.Name){
                    $SubnetReport += @{
                        ServiceName = $snt.Name
                        Name = $snt.Value
                        AddressPrefix = $sn.AddressPrefix
                    }
                }
            }
        }
    }
    return [PSCustomObject]@{
        Vnet = $vnet
        Subnets = $SubnetReport
    }
}



function Get-SettingsVirtualNetworkSubnet{
    param(
        # Parameter help description
        [Parameter(Mandatory,ValueFromPipeline=$true)]
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]
        $VirtualNetwork
    )

    $Subnets = $VirtualNetwork | Get-AzVirtualNetworkSubnetConfig
    $Tags = Get-AzTag -ResourceId $VirtualNetwork.id -Name '*Subnet'          
    foreach ($t in $Tags){
        $sn = $Subnets.Where{$_.Name -eq $t.Value}
        if ($sn){
            [PSCustomObject]@{
                ServiceName = $t.Name
                Name = $t.Value
                AddressPrefix = $sn.AddressPrefix
            }
        }
    }
}

function Get-SettingsVirtualNetworkSubnet{
    param(
        # Parameter help description
        [Parameter(Mandatory,ValueFromPipeline=$true)]
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]
        $VirtualNetwork
    )

    $Subnets = $VirtualNetwork | Get-AzVirtualNetworkSubnetConfig
    $Tags = Get-AzTag -ResourceId $VirtualNetwork.id -Name '*Subnet'          
    foreach ($t in $Tags){
        $sn = $Subnets.Where{$_.Name -eq $t.Value}
        if ($sn){
            [PSCustomObject]@{
                ServiceName = $t.Name
                Name = $t.Value
                AddressPrefix = $sn.AddressPrefix
            }
        }
    }
}


<#

VNet                     : @{Name=cs-jnllmn-net-vnet; RGName=cs-jnllmn-net-rg; AddressPrefix=10.97.0.0/16}
    Subnets                  : {@{AddressPrefix=10.97.0.0/27; Name=gatewaysubnet; ShortName=gatewaysubnet}, @{AddressPrefix=10.97.1.0/28;
                            Name=cs-jnllmn-net-mgt-sn; ShortName=mgt}, @{AddressPrefix=10.97.1.16/28; Name=cs-jnllmn-net-ngfw-sn;
                            ShortName=ngfw}, @{AddressPrefix=10.97.1.32/28; Name=cs-jnllmn-net-appgw-sn; ShortName=appgw}...}

#>