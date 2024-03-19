#https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-services-resource-providers


class tag {
    # Properties
        $Name
        $Value
        $ResourceId
        $ResourceType

    # Constructors
    tag()
    {}
}

function ConvertTo-AzTag{
    [CmdletBinding()]
    param(
        #enable pipelining
        [Parameter(Mandatory,ValueFromPipeline=$true)]
        $resources
    )

    $tagged = $resources.where{$_.tags}
    foreach ($t in $tagged) {
        foreach ($tagkey in $t.tags.keys) {
            $tag = [tag]::new()
            $tag.Name = $tagkey
            $tag.Value = $t.tags[$tagkey]
            $tag.ResourceId = $t.ResourceId
            $tag.ResourceType = $t.ResourceType
            $tag #| where-object {($_.Name -like $name) -and  ($_.Value -like $Value)}
        } 
    }
}

function Get-AzTagResource{
    [CmdletBinding()]
    param()
    $resources = Get-AzResource @PSBoundParameters
    ConvertTo-AzTag -resources $resources
}

function Get-AzTagSubscription{
    [CmdletBinding()]
    param(
        $SubscriptionId
    )
    $ResourceType = 'Microsoft.Subscription'
    $resources = Get-AzSubscription @PSBoundParameters
    $resources | ForEach-Object {$_ | Add-Member -NotePropertyName ResourceId -NotePropertyValue "/subscriptions/$($_.SubscriptionId)"}
    $resources | ForEach-Object {$_ | Add-Member -NotePropertyName ResourceType -NotePropertyValue $ResourceType}
    ConvertTo-AzTag -Resources $resources
}


function Get-AzTagResourceGroup{
    [CmdletBinding()]
    param(
        $Name
    )
    $ResourceType = 'Microsoft.Resources/resourcegroups'
    $resources = Get-AzResourceGroup @PSBoundParameters
    $resources | ForEach-Object {$_ | Add-Member -NotePropertyName ResourceType -NotePropertyValue $ResourceType}
    ConvertTo-AzTag -Resources $resources
}

function Select-AzTag{
    [CmdletBinding(DefaultParameterSetName='none')]
    param(
        [Parameter(Mandatory,ValueFromPipeline=$true)]
        [tag[]]$InputObject
        ,
        #[Parameter(ParameterSetName="Name")]
        $Name = '*'
        ,
        #[Parameter(ParameterSetName="Name")]
        $Value = '*'
        ,
        #[Parameter(ParameterSetName="Id")]
        $ResourceId = '*'
        ,
        #[Parameter(ParameterSetName="Type")]
        $ResourceType = '*'
    )
    
    <#
    if ($ResourceId){
        $splittedResourceId = $ResourceId.Trim('/').Split('/')
        if (($splittedResourceId.count -eq 2) -and `
            ($splittedResourceId[0] -eq 'subscriptions') -and `
            ([guid]$splittedResourceId[1])){
                $splatSubscriptionId.SubscriptionId = $splittedResourceId[1]
                $ResourceType = 'Microsoft.Subscription'
        }
    }
    #>
    process{
        foreach ($item in $InputObject) {
            $item | where-object {($_.Name -like $name) -and  ($_.Value -like $Value) -and  ($_.ResourceId -like $ResourceId) -and ($_.ResourceType -like $ResourceType)}
        }
    }
}

#proxy/wrapper function for Get-AzTag
#based on: https://devblogs.microsoft.com/scripting/proxy-functions-spice-up-your-powershell-core-cmdlets/
#$MetaData = New-Object System.Management.Automation.CommandMetaData (Get-Command  Get-AzTag)
#[System.Management.Automation.ProxyCommand]::Create($MetaData)
function Get-AzTag{
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName='GetPredefinedTagParameterSet', Position=0, ValueFromPipelineByPropertyName=$true, HelpMessage='Name of the tag. If not specified, return all the predefined and used tags under the subscription.')]
        [Parameter(ParameterSetName='ExtendedFunctionality')]
        #[ValidateNotNullOrEmpty()]
        [string]
        ${Name},
    
        [Parameter(ParameterSetName='ExtendedFunctionality')]
        $Value = '*',

        [Parameter(ParameterSetName='GetPredefinedTagParameterSet', ValueFromPipelineByPropertyName=$true, HelpMessage='Whether should get the tag values information as well.')]
        [switch]
        ${Detailed},
    
        [Parameter(ParameterSetName='GetByResourceIdParameterSet', Mandatory=$true, ValueFromPipelineByPropertyName=$true, HelpMessage='The resource identifier for the tagged entity. A resource, a resource group or a subscription may be tagged.')]
        [Parameter(ParameterSetName='ExtendedFunctionality')]
        [ValidateNotNullOrEmpty()]
        [string]
        ${ResourceId},
   
        [Parameter(ParameterSetName='ExtendedFunctionality')]
        [string]
        $ResourceType = '*'

        [Parameter(HelpMessage='The credentials, account, tenant, and subscription used for communication with Azure.')]
        [Alias('AzContext','AzureRmContext','AzureCredential')]
        [Microsoft.Azure.Commands.Common.Authentication.Abstractions.Core.IAzureContextContainer]
        ${DefaultProfile}
    )
    
    
    dynamicparam
    {
        try {
            $targetCmd = $ExecutionContext.InvokeCommand.GetCommand('Az.Resources\Get-AzTag', [System.Management.Automation.CommandTypes]::Cmdlet, $PSBoundParameters)
            $dynamicParams = @($targetCmd.Parameters.GetEnumerator() | Microsoft.PowerShell.Core\Where-Object { $_.Value.IsDynamic })
            if ($dynamicParams.Length -gt 0)
            {
                $paramDictionary = [Management.Automation.RuntimeDefinedParameterDictionary]::new()
                foreach ($param in $dynamicParams)
                {
                    $param = $param.Value
    
                    if(-not $MyInvocation.MyCommand.Parameters.ContainsKey($param.Name))
                    {
                        $dynParam = [Management.Automation.RuntimeDefinedParameter]::new($param.Name, $param.ParameterType, $param.Attributes)
                        $paramDictionary.Add($param.Name, $dynParam)
                    }
                }
    
                return $paramDictionary
            }
        } catch {
            throw
        }
    }
    
    begin
    {
        try {
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }
    
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Az.Resources\Get-AzTag', [System.Management.Automation.CommandTypes]::Cmdlet)
            $scriptCmd = {& $wrappedCmd @PSBoundParameters }
    
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            throw
        }
    }
    
    process
    {
        try {
            $steppablePipeline.Process($_)
        } catch {
            throw
        }
    }
    
    end
    {
        try {
            $steppablePipeline.End()
        } catch {
            throw
        }
    }
    
    clean
    {
        if ($null -ne $steppablePipeline) {
            $steppablePipeline.Clean()
        }
    }
    <#
    
    .ForwardHelpTargetName Az.Resources\Get-AzTag
    .ForwardHelpCategory Cmdlet
    
    #>


}
function Get-AzTag{
    [CmdletBinding(DefaultParameterSetName='none')]
    param(
        #[Parameter(ParameterSetName="Name")]
        $Name = '*'
        ,
        #[Parameter(ParameterSetName="Name")]
        $Value = '*'
        ,
        #[Parameter(ParameterSetName="Id")]
        $ResourceId = '*'
        ,
        #[Parameter(ParameterSetName="Type")]
        $ResourceType = '*'
    )

    #$PSBoundParameters.Remove('Name') | Out-Null
    #$PSBoundParameters.Remove('Value') | Out-Null

    if (($ResourceType -eq 'Microsoft.Subscription') -or ($ResourceType -eq '*')){
        Get-AzTagSubscription | Select-AzTag @PSBoundParameters
    }
    if (($ResourceType -eq 'Microsoft.Resources/resourcegroups') -or ($ResourceType -eq '*')){
        Get-AzTagResourceGroup | Select-AzTag @PSBoundParameters
    }
    if ((!($ResourceType -eq 'Microsoft.Subscription')) -or ($ResourceType -eq '*')){
        Get-AzTagResource | Select-AzTag @PSBoundParameters
    }
    
    <#
    switch ($ResourceType){
        'Microsoft.Subscription' {
            Get-AzTagSubscription | Select-AzTag @PSBoundParameters
        }
        Default {
            Get-AzTagResource | Select-AzTag @PSBoundParameters
        }
    }
    #>
}

function Set-AzTag{
    [CmdletBinding(DefaultParameterSetName='none',SupportsShouldProcess,ConfirmImpact = 'High')]
    param(
        <#
        maybe put in inputobject parameter for pipeline with a tag object
        [Parameter(ParameterSetName="tag")]
        [tag[]]$tag
        ,
        #>
        [Parameter(Mandatory)]
        $Name
        ,
        [Parameter(Mandatory)]
        $Value
        ,
        #[Parameter(ParameterSetName="Id")]
        $ResourceId = '*'
        ,
        #[Parameter(ParameterSetName="Type")]
        $ResourceType = '*'
    )

    #$PSBoundParameters.Remove('Tag') | Out-Null
    $PSBoundParameters.Remove('Name') | Out-Null
    $PSBoundParameters.Remove('Value') | Out-Null
    $resources = @(Get-AzTag @PSBoundParameters)
    $resourceUnique = @($resources | Select-Object -Property ResourceId -Unique)
    $tags = @{$Name = $Value}
    #If ($PSCmdlet.ParameterSetName('tag')){}
    #If ($PSBoundParameters.Keys -notin @('ResourceId','ResourceType')){
        if(($resourceUnique.count -gt 1) -and ($PSCmdlet.ShouldProcess("on $($resourceUnique.count) resources","setting tag $($name)"))){
            foreach ($item in $resourceUnique) {
                Update-AzTag -ResourceId $item.ResourceId -Tag $tags -Operation Merge
            }
        
    }else{
        Update-AzTag -ResourceId $resourceUnique[0].ResourceId -Tag $tags -Operation Merge
    }
    #    foreach ($resource in $resources) {
    #        Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge
    #    }
    #}
}

function Remove-AzTag{
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        $Name
        ,
        $Value = '*'
        ,
        #[Parameter(ParameterSetName="Id")]
        $ResourceId = '*'
        ,
        #[Parameter(ParameterSetName="Type")]
        $ResourceType = '*'
    )

    #$PSBoundParameters.Remove('Name') | Out-Null
    #$PSBoundParameters.Remove('Value') | Out-Null
    $resources = @(Get-AzTag @PSBoundParameters)  
    #If ($PSBoundParameters.Keys -notin @('ResourceId','ResourceType')){
        if(($resources.count -gt 1) -and ($PSCmdlet.ShouldProcess("on $($resources.count) resources","setting tag $($name)"))){
            foreach ($item in $resources) {
                $tags = @{$item.Name = $item.Value}
                Update-AzTag -ResourceId $item.ResourceId -Tag $tags -Operation Delete
            }
        #}
    }else{
        foreach ($item in $resources) {
            $tags = @{$item.Name = $item.Value}
            Update-AzTag -ResourceId $item.ResourceId -Tag $tags -Operation Delete
        }
    }
}



$info = @{
    CloudSuiteVersion = 3.1
    CustomerName = "iton"
    CustomerShort = "iton"
    Armprefix = "iton-"
    Date = (get-date -f s)
}

