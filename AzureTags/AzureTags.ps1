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

function Out-AzTag{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $resources
        ,
        #[Parameter(ParameterSetName="Id")]
        $ResourceId
        ,
        #[Parameter(ParameterSetName="Type")]
        $ResourceType
    )

    $tagged = $resources.where{$_.tags}
    foreach ($t in $tagged) {
        foreach ($tagkey in $t.tags.keys) {
            $tag = [tag]::new()
            $tag.Name = $tagkey
            $tag.Value = $t.tags[$tagkey]
            If ($ResourceId){$tag.ResourceId = $ResourceId}else{$tag.ResourceId = $t.ResourceId}
            If ($ResourceType){$tag.ResourceType = $ResourceType}else{$tag.ResourceType = $t.ResourceType}
            $tag #| where-object {($_.Name -like $name) -and  ($_.Value -like $Value)}
        } 
    }
}

function Get-AzTagSubscription{
    [CmdletBinding()]
    param(
        $SubscriptionId
    )
    $ResourceType = 'Microsoft.Subscription'
    $resources = Get-AzSubscription @PSBoundParameters
    $resources | ForEach-Object {$_ | Add-Member -NotePropertyName ResourceId -NotePropertyValue "/susbscriptions/$($_.SubscriptionId)"}
    $resources | ForEach-Object {$_ | Add-Member -NotePropertyName ResourceType -NotePropertyValue $ResourceType}
    Out-AzTag -Resources $resources
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
        $ResourceId
        ,
        #[Parameter(ParameterSetName="Type")]
        $ResourceType
    )

    $PSBoundParameters.Remove('Name') | Out-Null
    $PSBoundParameters.Remove('Value') | Out-Null
    $splatSubscriptionId = @{}
    if ($ResourceId){
        $splittedResourceId = $ResourceId.Trim('/').Split('/')
        if (($splittedResourceId.count -eq 2) -and `
            ($splittedResourceId[0] -eq 'subscriptions') -and `
            ([guid]$splittedResourceId[1])){
                $splatSubscriptionId.SubscriptionId = $splittedResourceId[1]
                $ResourceType = 'Microsoft.Subscription'
        }
    }
    switch ($ResourceType){
        'Microsoft.Subscription' {
            $resources = Get-AzSubscription @splatSubscriptionId
            $resources | ForEach-Object {$_ | Add-Member -NotePropertyName ResourceId -NotePropertyValue "/susbscriptions/$($_.SubscriptionId)"}
            $resources | ForEach-Object {$_ | Add-Member -NotePropertyName ResourceType -NotePropertyValue $ResourceType}
            Out-AzTag -Resources $resources @PSBoundParameters
        }
        Default {
            $resources = Get-AzResource @PSBoundParameters
            Out-AzTag -Resources $resources
        }
    }
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
        #[Parameter(Mandatory,ParameterSetName="Name")]
        $Name
        ,
        #[Parameter(Mandatory,ParameterSetName="Name")]
        $Value
        ,
        #[Parameter(ParameterSetName="Id")]
        $ResourceId
        ,
        #[Parameter(ParameterSetName="Type")]
        $ResourceType
    )

    #$PSBoundParameters.Remove('Tag') | Out-Null
    $PSBoundParameters.Remove('Name') | Out-Null
    $PSBoundParameters.Remove('Value') | Out-Null
    $resources = Get-AzResource @PSBoundParameters
    $tags = @{$Name = $Value}
    #If ($PSCmdlet.ParameterSetName('tag')){}
    If ($PSBoundParameters.Keys -notin @('ResourceId','ResourceGroupName','ResourceType')){
        if($PSCmdlet.ShouldProcess("on $($resources.count) resources","setting tag $($name)" )){
            foreach ($resource in $resources) {
                Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge
            }
        }
    }else{
        foreach ($resource in $resources) {
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge
        }
    }
}

function Delete-AzTag{
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        $Name
        ,
        [Parameter(Mandatory)]
        $Value
        ,
        #[Parameter(ParameterSetName="Id")]
        $ResourceId
        ,
        #[Parameter(ParameterSetName="Type")]
        $ResourceType
    )

    $PSBoundParameters.Remove('Name') | Out-Null
    $PSBoundParameters.Remove('Value') | Out-Null
    $resources = Get-AzResource @PSBoundParameters
    $tags = @{$Name = $Value}
    
    If ($PSBoundParameters.Keys -notin @('ResourceId','ResourceGroupName','ResourceType')){
        if($PSCmdlet.ShouldProcess("Op $($resources.count) resources","zet tag $($name)" )){
            foreach ($resource in $resources) {
                Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Delete
            }
        }
    }else{
        foreach ($resource in $resources) {
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Delete
        }
    }
}