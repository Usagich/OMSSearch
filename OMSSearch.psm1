﻿Function Get-AADToken {
<# 
    .SYNOPSIS
        Get token from Azure AD so you can use the other cmdlets.

    .DESCRIPTION
        Get token from Azure AD so you can use the other cmdlets.
    
    .PARAMETER OMSConnection
        Object that contains all needed parameters for working
        with OMSSearch Module. You can create such object in 
        OMS Automation as connection asset.

    .PARAMETER TenantADName
        Valid Azure AD Tenant name. 
        Example: stanoutlook.onmicrosoft.com

    .PARAMETER TenantID
        Valid Azure Tenant ID. 
        Example: eeb91fce-4be2-4a30-aad8-39e05fefde0

    .PARAMETER Credential
        Valid user credentials to Azure AD. The Azure AD user must
        have at least user rights in OMS and administrator and 
        Contributor rights on the Azure resource group where
        the OMS workspace is located.

    .EXAMPLE
        $creds = Get-Credetnial
        $token = Get-AADToken -TenantADName 'stanoutlook.onmicrosoft.com' -Credential $creds

    .EXAMPLE
        $creds = Get-Credetnial
        $token = Get-AADToken -TenantID 'eeb91fce-4be2-4a30-aad8-39e05fefde0' -Credential $creds

    .EXAMPLE
        $OMSCon = Get-AutomationConnection -Name 'stasoutlook'
        $Token = Get-AADToken -OMSConnection $OMSCon

    .OUTPUTS
        System.String. Returns token from Azure AD.

#>        
[CmdletBinding(DefaultParameterSetName='LoginbyTenantADName')]
[OutputType([string])]
PARAM (
        [Parameter(ParameterSetName='OMSConnection',Position=0,Mandatory=$true)]
        [Alias('Connection','c')]
        [Object]$OMSConnection,

        [Parameter(ParameterSetName='LoginbyTenantADName',Position=0,Mandatory=$true)]
        
        [Alias('t')]
        [String]$TenantADName,

        [Parameter(ParameterSetName='LoginByTenantID',Position=0,Mandatory=$true)]
        [ValidateScript({
            try 
            {
                [System.Guid]::Parse($_) | Out-Null
                $true
            } 
            catch 
            {
                $false
            }
        })]
        [Alias('tID')]
        [String]$TenantID,

        [Parameter(ParameterSetName='LoginbyTenantADName',Position=1,Mandatory=$true)]
        [Parameter(ParameterSetName='LoginByTenantID',Position=1,Mandatory=$true)]
        [Alias('cred')]
        [pscredential]
        [System.Management.Automation.CredentialAttribute()]
        $Credential
        )
    Try
    {
        If ($OMSConnection)
	    {
		    $Username       = $OMSConnection.Username
		    $Password       = $OMSConnection.Password
            If ($OMSConnection.TenantID)
            {
                $TenantID   = $OMSConnection.TenantID
            }
            Else
            {
                $TenantADName   = $OMSConnection.TenantADName
            }
	    }
        Else 
        {
            $Username       = $Credential.Username
		    $Password       = $Credential.Password
	    }
        # Set well-known client ID for Azure PowerShell
        $clientId = '1950a258-227b-4e31-a9cf-717495945fc2'

        # Set Resource URI to Azure Service Management API
        $resourceAppIdURI = 'https://management.azure.com/'

        # Set Authority to Azure AD Tenant
        If ($TenantID)
        {
            $authority = 'https://login.microsoftonline.com/common/' + $TenantID
        }
        Else
        {
            $authority = 'https://login.microsoftonline.com/' + $TenantADName
        }
    

	    $AADcredential = New-Object `
                            -TypeName 'Microsoft.IdentityModel.Clients.ActiveDirectory.UserCredential' `
                            -ArgumentList $Username,$Password
    
        # Create AuthenticationContext tied to Azure AD Tenant
        $authContext = New-Object `
                            -TypeName 'Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext' `
                            -ArgumentList $authority

        $authResult = $authContext.AcquireToken($resourceAppIdURI,$clientId,$AADcredential)
        $Token = $authResult.CreateAuthorizationHeader()
    }
    Catch
    {
       $ErrorMessage = 'Failed to aquire Azure AD token.'
       $ErrorMessage += " `n"
       $ErrorMessage += 'Error: '
       $ErrorMessage += $_
       Write-Error -Message $ErrorMessage `
                   -ErrorAction Stop
    }

	Return $Token
}
Function Get-OMSWorkspace {
<# 
    .SYNOPSIS
        Get OMS Workspaces from Azure Subscription.

    .DESCRIPTION
        Get OMS Workspaces from Azure Subscription.

    .PARAMETER Token
        Token aquired from Get-AADToken cmdlet.

    .PARAMETER SubscriptionID
        Azure Subscription ID where the OMS workspace
        is located.

    .PARAMETER OMSConnection
        Object that contains all needed parameters for working
        with OMSSearch Module. You can create such object in 
        OMS Automation as connection asset.

    .PARAMETER APIVersion
        Api version for microsoft.operationalinsights
        Azure Resource provider.

    .EXAMPLE
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $SubscriptionId = "3c1d68a5-4064-4522-94e4-e0378165555e"
        $Token = Get-AADToken -OMSConnection $OMSCon
        Get-OMSWorkspace -SubscriptionId $Subscriptionid -Token $Token

    .EXAMPLE
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $SubscriptionId = "3c1d68a5-4064-4522-94e4-e0378165555e"
        $Token = Get-AADToken -OMSConnection $OMSCon
        Get-OMSWorkspace -SubscriptionId $Subscriptionid -Token $Token -APIVersion '2015-03-20'

    .EXAMPLE
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        Get-OMSWorkspace -OMSConnection $OMSCon -Token $Token

    .EXAMPLE
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        Get-OMSWorkspace -OMSConnection $OMSCon -Token $Token -APIVersion '2015-03-20'

    .OUTPUTS
        System.Object. Returns array of objects. Each object
        is OMS workspace information.

#>
[CmdletBinding(DefaultParameterSetName='DefaultParameterSet')]
[OutputType([object])]
PARAM (
        [Parameter(ParameterSetName='DefaultParameterSet',Position=0,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection',Position=0,Mandatory=$true)]
        [String]$Token,
        
        [Parameter(ParameterSetName='DefaultParameterSet',Position=1,Mandatory=$true)]
        [ValidateScript({
            try 
            {
                [System.Guid]::Parse($_) | Out-Null
                $true
            } 
            catch 
            {
                $false
            }
        })]
        [string]$SubscriptionID,

        [Parameter(ParameterSetName='OMSConnection',Position=1,Mandatory=$true)]
        [Alias('Connection','c')]
        [Object]$OMSConnection,

        [Parameter(ParameterSetName='DefaultParameterSet',Position=2,Mandatory=$false)]
        [Parameter(ParameterSetName='OMSConnection',Position=2,Mandatory=$false)]
        [String]$APIVersion='2015-03-20'
    )
    
    Try
    {
        If ($OMSConnection)
	    {
	        $SubscriptionID    = $OMSConnection.SubscriptionID
        }

        $URIManagement = 'https://management.azure.com'
        $UriProvider = 'providers/microsoft.operationalinsights'
        $OMSApiAction = 'workspaces'  
         
        $uri = '{0}/subscriptions/{1}/{2}/{3}?api-version={4}' `
               -f $URIManagement,$SubscriptionID,$UriProvider,$OMSApiAction,$APIVersion
        
        $headers = @{'Authorization'=$Token;'Accept'='application/json'}
        $headers.Add('Content-Type','application/json')
        
        $result = Invoke-WebRequest `
                        -Method Get `
                        -Uri $uri `
                        -Headers $headers `
                        -UseBasicParsing `
                        -ErrorAction Stop
    }
    Catch
    {
        $ErrorMessage = 'Failed to query OMS API. Check parameters.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Error: '
        $ErrorMessage += $_
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
    }
    
    #region Verbose
    $VerboseMessage = (Get-Date -Format HH:mm:ss).ToString() + ' - Web Request Status code: ' + $result.StatusCode
        Write-Verbose `
             -Message $VerboseMessage 
    #endergion

    if($result.StatusCode -ge 200 -and $result.StatusCode -le 399)
    {
        if($null -ne $result.Content)
        {
            $json = ConvertFrom-Json `
                        -InputObject $result.Content `
                        -ErrorAction Stop

            if($null -ne $json)
            {
                $return = $json
                if($null -ne $json.value)
                {
                    $return = $json.value
                }
                Else
                {
                    $return = $null
                }
            }
            Else
            {
                $return = $null
            }
        }
    }
    Else
    {
        $ErrorMessage = 'Failed to get OMS Workspace. Check parameters.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Web request Error: '
        $ErrorMessage += $result
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
    }
    
    return $return
}
Function Get-OMSResourceGroup {
<# 
    .SYNOPSIS
        Get Azure Resource Group where there is OMS
        workspace resource.
        The cmdlet assumes that your OMS resource Groups
        has 'OI-Default-' in its name.

    .DESCRIPTION
        Get Azure Resource Group where there is OMS
        workspace resource. The cmdlet assumes that your OMS resource Groups
        has 'OI-Default-' in its name.

    .PARAMETER Token
        Token aquired from Get-AADToken cmdlet.
        Token must be aquired with account that has
        access to all resource groups in the Azure
        subscription.

    .PARAMETER SubscriptionID
        Azure Subscription ID where the OMS workspace
        is located.

    .PARAMETER OMSConnection
        Object that contains all needed parameters for working
        with OMSSearch Module. You can create such object in 
        OMS Automation as connection asset.

    .PARAMETER APIVersion
        Api version for Azure subscriptions provider.

    .EXAMPLE
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $SubscriptionId = "3c1d68a5-4064-4522-94e4-e0378165555e"
        $Token = Get-AADToken -OMSConnection $OMSCon
        Get-OMSResourceGroup -SubscriptionId $Subscriptionid -Token $Token
    
    .EXAMPLE
        $SubscriptionId = "3c1d68a5-4064-4522-94e4-e0378165555e"
        $Token = Get-AADToken -OMSConnection $OMSCon
        Get-OMSResourceGroup -SubscriptionId $Subscriptionid -Token $Token -APIVersion '2014-04-01'

    .EXAMPLE
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        Get-OMSResourceGroup -OMSConnection $OMSCon -Token $Token
    
    .EXAMPLE
        $Token = Get-AADToken -OMSConnection $OMSCon
        Get-OMSResourceGroup -OMSConnection $OMSCon -Token $Token -APIVersion '2014-04-01'

    .OUTPUTS
        System.Object. Returns array of objects. Each object
        is OMS resoure group information.

#>
[CmdletBinding(DefaultParameterSetName='DefaultParameterSet')]
[OutputType([object[]])]
PARAM (
        [Parameter(ParameterSetName='DefaultParameterSet',Position=0,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection',Position=0,Mandatory=$true)]
        [String]$Token,
        
        [Parameter(ParameterSetName='DefaultParameterSet',Position=1,Mandatory=$true)]
        [ValidateScript({
            try 
            {
                [System.Guid]::Parse($_) | Out-Null
                $true
            } 
            catch 
            {
                $false
            }
        })]
        [string]$SubscriptionID,

        [Parameter(ParameterSetName='OMSConnection',Position=1,Mandatory=$true)]
        [Alias('Connection','c')]
        [Object]$OMSConnection,

        [Parameter(ParameterSetName='DefaultParameterSet',Position=2,Mandatory=$false)]
        [Parameter(ParameterSetName='OMSConnection',Position=2,Mandatory=$false)]
        [String]$APIVersion='2014-04-01'

    )
    
    Try
    {
        If ($OMSConnection)
	    {
	        $SubscriptionID    = $OMSConnection.SubscriptionID
        }

        #region Warning
        $WarningMessage = 'This cmdlet returns OMS resource groups that have OI-Default- in its name.'
        Write-Warning `
            -Message $WarningMessage
        #endregion
        
        $URIManagement = 'https://management.azure.com'
        $OMSApiAction = 'resourceGroups'  
     
        $uri = '{0}/subscriptions/{1}/{2}?api-version={3}' `
               -f $URIManagement,$SubscriptionID,$OMSApiAction,$APIVersion
    
        $headers = @{'Authorization'=$Token;'Accept'='application/json'}
        $headers.Add('Content-Type','application/json')
    
        $result = Invoke-WebRequest `
                        -Method Get `
                        -Uri $uri `
                        -Headers $headers `
                        -UseBasicParsing `
                        -ErrorAction Stop
    }
    Catch
    {
        $ErrorMessage = 'Failed to query Azure Resource Manager API. Check parameters.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Error: '
        $ErrorMessage += $_
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
    }
    
    #region Verbose
    $VerboseMessage = (Get-Date -Format HH:mm:ss).ToString() + ' - Web Request Status code: ' + $result.StatusCode
        Write-Verbose `
             -Message $VerboseMessage 
    #endergion
    
    if($result.StatusCode -ge 200 -and $result.StatusCode -le 399)
    {
        if($null -ne $result.Content)
        {
            $json = ConvertFrom-Json `
                    -InputObject $result.Content `
                    -ErrorAction Stop

            if($null -ne $json)
            {
                $return = $json
            
                if($null -ne $json.value)
                {
                    $return = $json.value
                }
                Else
                {
                    $return = $null
                }
            }
            Else
            {
                $return = $null
            }
        }
    }
    Else
    {
        $ErrorMessage = 'Failed to get OMS Resource Group. Check parameters.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Web request Error: '
        $ErrorMessage += $result
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
    }
    
    #Filter out all none OMS resource groups
    $arrOMSResourceGroups = @()
    If ($null -ne $return)
    {
        Foreach ($resourceGroup in $return)
        {
            if ($resourceGroup.name -imatch '^OI-Default-')
            {
                $arrOMSResourceGroups += $resourceGroup
            }
        }
    }
    
    
    #region Verbose
    $VerboseMessage = (Get-Date -Format HH:mm:ss).ToString() + 'Total OMS resource groups found: ' + $arrOMSResourceGroups.count
    Write-Verbose `
        -Message $VerboseMessage 
    #endergion

    return $arrOMSResourceGroups
}
Function Get-OMSSavedSearch {
<# 
    .SYNOPSIS
        Gets Saved Searches from OMS workspace

    .DESCRIPTION
        Gets Saved Searches from OMS workspace
    
    .PARAMETER Token
        Token aquired from Get-AADToken cmdlet.

    .PARAMETER SubscriptionID
        Azure Subscription ID where the OMS workspace
        is located.

    .PARAMETER ResourceGroupName
        Azure Resource Group Name where the OMS 
        workspace is located.

    .PARAMETER OMSWorkspaceName
        Name of the OMS workspace.

    .PARAMETER OMSConnection
        Object that contains all needed parameters for working
        with OMSSearch Module. You can create such object in 
        OMS Automation as connection asset.
    
    .PARAMETER QueryName
        Specify the full name of OMS Saved Search to get
        only specific query. Array of saved search names
        can be specified as well.

    .PARAMETER APIVersion
        Api version for microsoft.operationalinsights
        Azure Resource provider.

    .EXAMPLE
        # Gets Saved Searches from OMS. Returns results.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        $subscriptionId = "3c1d68a5-4064-4522-94e4-e0378165555e"
        $ResourceGroupName = "oi-default-east-us"
        $OMSWorkspace = "Test"	
        $OMSSS=Get-OMSSavedSearch -SubscriptionID $subscriptionId -ResourceGroupName $ResourceGroupName  -OMSWorkspaceName $OMSWorkspace -Token $Token
        $OMSSS[0].ID
        $OMSSS[0].etag
        $OMSSS[0].properties
        $OMSSS[0].properties.Category
        $OMSSS[0].properties.DisplayName
        $OMSSS[0].properties.Query
        $OMSSS[0].properties.Version

    .EXAMPLE
        # Gets Saved Searches from OMS. Returns results.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        $subscriptionId = "3c1d68a5-4064-4522-94e4-e0378165555e"
        $ResourceGroupName = "oi-default-east-us"
        $OMSWorkspace = "Test"	
        $OMSSS=Get-OMSSavedSearch -SubscriptionID $subscriptionId -ResourceGroupName $ResourceGroupName  -OMSWorkspaceName $OMSWorkspace -Token $Token -APIVersion '2015-03-20'
        $OMSSS[0].ID
        $OMSSS[0].etag
        $OMSSS[0].properties
        $OMSSS[0].properties.Category
        $OMSSS[0].properties.DisplayName
        $OMSSS[0].properties.Query
        $OMSSS[0].properties.Version

    .EXAMPLE
        # Gets Saved Searches from OMS. Returns results.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon	
        $OMSSS = Get-OMSSavedSearch -OMSConnection $OMSCon -Token $Token
        $OMSSS[0].ID
        $OMSSS[0].etag
        $OMSSS[0].properties
        $OMSSS[0].properties.Category
        $OMSSS[0].properties.DisplayName
        $OMSSS[0].properties.Query
        $OMSSS[0].properties.Version

    .OUTPUTS
        System.Object. Returns array of objects. Each object
        is saved search query. If no saved searches are found
        error is returned.


#>
[CmdletBinding(DefaultParameterSetName='DefaultParameterSet')]
[OutputType([object])]
PARAM (
        [Parameter(ParameterSetName='OMSConnection',Position=0,Mandatory=$true)]
        [Parameter(ParameterSetName='DefaultParameterSet',Position=0,Mandatory=$true)]
        [String]$Token,

        [Parameter(ParameterSetName='DefaultParameterSet',Position=1,Mandatory=$true)]
        [ValidateScript({
            try 
            {
                [System.Guid]::Parse($_) | Out-Null
                $true
            } 
            catch 
            {
                $false
            }
        })]
        [string]$SubscriptionID,

        [Parameter(ParameterSetName='DefaultParameterSet',Position=2,Mandatory=$true)]
        [String]$ResourceGroupName,

        [Parameter(ParameterSetName='DefaultParameterSet',Position=3,Mandatory=$true)]
        [String]$OMSWorkspaceName,

        [Parameter(ParameterSetName='OMSConnection',Position=2,Mandatory=$true)]
        [Alias('Connection','c')]
        [Object]$OMSConnection,

        [Parameter(ParameterSetName='DefaultParameterSet',Position=4,Mandatory=$false)]
        [Parameter(ParameterSetName='OMSConnection',Position=4,Mandatory=$false)]
        [String[]]$QueryName=$null,

        [Parameter(ParameterSetName='DefaultParameterSet',Position=4,Mandatory=$false)]
        [Parameter(ParameterSetName='OMSConnection',Position=4,Mandatory=$false)]
        [String]$APIVersion='2015-03-20'
    )
    
    Try
    {
        If ($OMSConnection)
	    {
	        $SubscriptionID    = $OMSConnection.SubscriptionID
	        $ResourceGroupName = $OMSConnection.ResourceGroupName
            $OMSWorkspaceName  = $OMSConnection.WorkSpaceName
        }

        $URIManagement = 'https://management.azure.com'
        $UriProvider = 'providers/microsoft.operationalinsights'
        $OMSApiAction = 'savedSearches'
        $uri = '{0}/subscriptions/{1}/resourcegroups/{2}/{3}/workspaces/{4}/{5}?api-version={6}' `
                -f $URIManagement,$SubscriptionID, $ResourceGroupName, $UriProvider, $OMSWorkspaceName,$OMSApiAction, $APIVersion
        
        $headers = @{'Authorization'=$Token;'Accept'='application/json'}
        
        $headers.Add('Content-Type','application/json')
        
        $result = Invoke-WebRequest `
                        -Method Get `
                        -Uri $uri `
                        -Headers $headers `
                        -UseBasicParsing `
                        -ErrorAction Stop
        
    }
    Catch
    {
        $ErrorMessage = 'Failed to query OMS API.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Error: '
        $ErrorMessage += $_
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
    }
    
    #region Verbose
    $VerboseMessage = (Get-Date -Format HH:mm:ss).ToString() + ' - Web Request Status code: ' + $result.StatusCode
        Write-Verbose `
             -Message $VerboseMessage 
    #endergion

    if ($result.StatusCode -ge 200 -and $result.StatusCode -le 399)
    {
        if ($null -ne $result.Content)
        {
            $json = ConvertFrom-Json `
                        -InputObject $result.Content `
                        -ErrorAction Stop
            
            if ($null -ne $json)
            {
                $OMSSavedSearches = $json
                $return = $json
                
                
                if ($null -ne $json.value)
                {
                    $OMSSavedSearches = $json.value
                    $return = $json.value
                    
                }
                Else
                {
                    $ErrorMessage = 'There are no OMS Saved Searches.'
                    $ErrorMessage += " `n"
                    $ErrorMessage += 'Returned results: '
                    $ErrorMessage += $json
                    Write-Error -Message $ErrorMessage `
                                -ErrorAction Stop
                }
            }
            Else
            {
                $ErrorMessage = 'There are no OMS Saved Searches.'
                $ErrorMessage += " `n"
                $ErrorMessage += 'Returned results: '
                $ErrorMessage += $json
                Write-Error -Message $ErrorMessage `
                            -ErrorAction Stop
            }
            
        }
    }
    Else
    {
        $ErrorMessage = 'Failed to get OMS Saved Searches.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Web request Error: '
        $ErrorMessage += $result
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
        
    }

    # If Name parameter specified
    If ($QueryName)
    {
        $match = $false
        $QueriesArray = @()
        foreach ($qName in $QueryName)
        {
            foreach($q in $OMSSavedSearches) 
            {
                if ($q.properties.displayname.Tostring() -eq $qName) 
                {
                    $QueriesArray += $q
                    $match=$true;break;
                }
	        }
	        
            if(! $match) 
            {
                $ErrorMessage = 'Failed to find query with Name: ' + $qName
                $ErrorMessage += " `n"
                $ErrorMessage += 'Error: '
                $ErrorMessage += $_
                Write-Error -Message $ErrorMessage `
                            -ErrorAction Stop	    	
	        	return $null
	        }
            else 
            {
                $return = $QueriesArray
            }
        }
    }
    
    return $return
}
Function Remove-OMSSavedSearch {
<# 
    .SYNOPSIS
        Deletes OMS Saved Search.

    .DESCRIPTION
        Deletes OMS Saved Search.

    .PARAMETER Token
        Token aquired from Get-AADToken cmdlet.

    .PARAMETER SubscriptionID
        Azure Subscription ID where the OMS workspace
        is located.

    .PARAMETER ResourceGroupName
        Azure Resource Group Name where the OMS 
        workspace is located.

    .PARAMETER OMSWorkspaceName
        Name of the OMS workspace.

    .PARAMETER OMSConnection
        Object that contains all needed parameters for working
        with OMSSearch Module. You can create such object in 
        OMS Automation as connection asset.
    
    .PARAMETER QueryName
        Specify the full name of OMS Saved Search to get
        only specific query.

    .PARAMETER APIVersion
        Api version for microsoft.operationalinsights
        Azure Resource provider.

    .EXAMPLE
        # Gets Saved Searches from OMS. Returns results.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        $subscriptionId = "3c1d68a5-4064-4522-94e4-e0378165555e"
        $ResourceGroupName = "oi-default-east-us"
        $OMSWorkspace = "Test"	
        Remove-OMSSavedSearch -SubscriptionID $subscriptionId -ResourceGroupName $ResourceGroupName  -OMSWorkspaceName $OMSWorkspace -Token $Token -QueryName 'SavedQueryName'
        
    .EXAMPLE
        # Gets Saved Searches from OMS. Returns results.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        $subscriptionId = "3c1d68a5-4064-4522-94e4-e0378165555e"
        $ResourceGroupName = "oi-default-east-us"
        $OMSWorkspace = "Test"
        Remove-OMSSavedSearch -SubscriptionID $subscriptionId -ResourceGroupName $ResourceGroupName  -OMSWorkspaceName $OMSWorkspace -Token $Token -QueryName 'SavedQueryName' -APIVersion '2015-03-20'
         

    .EXAMPLE
        # Gets Saved Searches from OMS. Returns results.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon	
        Remove-OMSSavedSearch -OMSConnection $OMSCon -Token $Token -QueryName 'SavedQueryName'
        
    .EXAMPLE
        # Gets Saved Searches from OMS. Returns results.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        Remove-OMSSavedSearch -OMSConnection $OMSCon -Token $Token -QueryName 'SavedQueryName' -APIVersion '2015-03-20'
         
        
    .OUTPUTS
        No Output.
       

#>
[CmdletBinding(DefaultParameterSetName='DefaultParameterSet')]
[OutputType([object])]
PARAM (
		[Parameter(ParameterSetName='DefaultParameterSet',Position=0,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection',Position=0,Mandatory=$true)]
        [String]$Token,

        [Parameter(ParameterSetName='OMSConnection',Position=1,Mandatory=$true)]
        [Alias('Connection','c')]
        [Object]$OMSConnection,

        [Parameter(ParameterSetName='DefaultParameterSet',Position=1,Mandatory=$true)]
        [ValidateScript({
            try 
            {
                [System.Guid]::Parse($_) | Out-Null
                $true
            } 
            catch 
            {
                $false
            }
        })]
        [string]$SubscriptionID,

		[Parameter(ParameterSetName='DefaultParameterSet',Position=2,Mandatory=$true)]
        [String]$ResourceGroupName,

		[Parameter(ParameterSetName='DefaultParameterSet',Position=3,Mandatory=$true)]
        [String]$OMSWorkspaceName,

		[Parameter(ParameterSetName='DefaultParameterSet',Position=4,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection',Position=4,Mandatory=$true)]
        [String]$QueryName,

        [Parameter(ParameterSetName='DefaultParameterSet',Position=5,Mandatory=$false)]
        [Parameter(ParameterSetName='OMSConnection',Position=5,Mandatory=$false)]
        [String]$APIVersion='2015-03-20'
	)
    
    Try
    {
        If ($OMSConnection)
	    {
	        $SubscriptionID    = $OMSConnection.SubscriptionID
	        $ResourceGroupName = $OMSConnection.ResourceGroupName
            $OMSWorkspaceName  = $OMSConnection.WorkSpaceName
        }
	
        $savedSearch = Get-OMSSavedSearch `
                        -SubscriptionID $SubscriptionID `
                        -ResourceGroupName $ResourceGroupName `
                        -OMSWorkspaceName $OMSWorkspaceName `
                        -QueryName $QueryName `
                        -Token $token `
                        -APIVersion $APIVersion `
                        -ErrorAction Stop
    }
    Catch
    {
        $ErrorMessage = 'Failed to find Saved Search. Check parameters.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Details:  '
        $ErrorMessage += $_
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
    }

    Try
    {
        If ($OMSConnection)
	    {
	        $SubscriptionID    = $OMSConnection.SubscriptionID
	        $ResourceGroupName = $OMSConnection.ResourceGroupName
            $OMSWorkspaceName  = $OMSConnection.WorkSpaceName
        }

        $URIManagement = 'https://management.azure.com'
        $UriProvider = 'providers/microsoft.operationalinsights'
        $OMSApiAction = 'savedSearches'
        $SavedSearchID = $savedSearch[0].id.Split('/')[-1]
        $uri = '{0}/subscriptions/{1}/resourcegroups/{2}/{3}/workspaces/{4}/{5}/{6}?api-version={7}' `
                -f $URIManagement,$SubscriptionID, $ResourceGroupName, $UriProvider, $OMSWorkspaceName,$OMSApiAction, $SavedSearchID, $APIVersion
        
        $headers = @{'Authorization'=$Token;'Accept'='application/json'}
        
        $headers.Add('Content-Type','application/json')
        
        $result = Invoke-WebRequest `
                        -Method Delete `
                        -Uri $uri `
                        -Headers $headers `
                        -UseBasicParsing `
                        -ErrorAction Stop
        
    }
    Catch
    {
        $ErrorMessage = 'Failed to query OMS API.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Error: '
        $ErrorMessage += $_
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
    }
    
    #region Verbose
    $VerboseMessage = (Get-Date -Format HH:mm:ss).ToString() + ' - Web Request Status code: ' + $result.StatusCode
        Write-Verbose `
             -Message $VerboseMessage 
    Write-Verbose $result
    #endergion

    if ($result.StatusCode -ge 200 -and $result.StatusCode -le 399)
    {
        if ($null -ne $result.Content)
        {
            $return = $null
        }
    }
    Else
    {
        $ErrorMessage = 'Failed to deleted OMS Saved Searches.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Web request Error: '
        $ErrorMessage += $result
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
        
    }

    return $return
}
Function New-OMSSavedSearch {
<# 
    .SYNOPSIS
        Creates new saved search in OMS workspace.

    .DESCRIPTION
        Creates new saved search in OMS workspace.

    .PARAMETER Token
        Token aquired from Get-AADToken cmdlet.

    .PARAMETER SubscriptionID
        Azure Subscription ID where the OMS workspace
        is located.

    .PARAMETER ResourceGroupName
        Azure Resource Group Name where the OMS 
        workspace is located.

    .PARAMETER OMSWorkspaceName
        Name of the OMS workspace.

    .PARAMETER OMSConnection
        Object that contains all needed parameters for working
        with OMSSearch Module. You can create such object in 
        OMS Automation as connection asset.
    
    .PARAMETER Query
        Query to be saved in OMS.
        Example: * EventID=406

    .PARAMETER QueryName
        Query name for the saved search.

    .PARAMETER Category
        Category of the saved search.

    .PARAMETER APIVersion
        Api version for microsoft.operationalinsights
        Azure Resource provider.

    .EXAMPLE
        # Executes Search Query against OMS. Returns results from query.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        $subscriptionId = "3c1d68a5-4064-4522-94e4-e0378165555e"
        $ResourceGroupName = "oi-default-east-us"
        $OMSWorkspace = "Test"	
        $Query = "shutdown Type=Event EventLog=System Source=User32 EventID=1074 | Select TimeGenerated,Computer"
        New-OMSSavedSearch -SubscriptionID $subscriptionId -ResourceGroupName $ResourceGroupName  -OMSWorkspaceName $OMSWorkspace -Query $Query -QueryName 'Restarted Servers' -Category 'Windows Server' -Token $Token  -APIVersion '2015-03-20'

     .EXAMPLE
        # Executes Search Query against OMS. Returns results from query.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        $Query = "shutdown Type=Event EventLog=System Source=User32 EventID=1074 | Select TimeGenerated,Computer"
        New-OMSSavedSearch -OMSConnection $OMSCon -Query $Query -QueryName 'Restarted Servers' -Category 'Windows Server' -Token $Token

    .OUTPUTS
        No Output.

#>
[CmdletBinding(
    DefaultParameterSetName='DefaultParameterSet',
    SupportsShouldProcess=$true,
    ConfirmImpact='Low')]
[OutputType([object])]
PARAM (
        [Parameter(ParameterSetName='DefaultParameterSet',Position=0,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection',Position=0,Mandatory=$true)]
        [String]$Token,

        [Parameter(ParameterSetName='OMSConnection',Position=1,Mandatory=$true)]
        [Alias('Connection','c')]
        [Object]$OMSConnection,

        [Parameter(ParameterSetName='DefaultParameterSet',Position=1,Mandatory=$true)]
        [ValidateScript({
            try 
            {
                [System.Guid]::Parse($_) | Out-Null
                $true
            } 
            catch 
            {
                $false
            }
        })]
        [string]$SubscriptionID,

        [Parameter(ParameterSetName='DefaultParameterSet',Position=2,Mandatory=$true)]
        [String]$ResourceGroupName,

        [Parameter(ParameterSetName='DefaultParameterSet',Position=3,Mandatory=$true)]
        [String]$OMSWorkspaceName,

        [Parameter(ParameterSetName='OMSConnection',Position=4,Mandatory=$true)]
        [Parameter(ParameterSetName='DefaultParameterSet',Position=4,Mandatory=$true)]
        [String]$QueryName,

        [Parameter(ParameterSetName='DefaultParameterSet',Position=5,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection',Position=5,Mandatory=$true)]
        [String]$Query,

        [Parameter(ParameterSetName='DefaultParameterSet',Position=6,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection',Position=6,Mandatory=$true)]
        [string]$Category,

        [Parameter(ParameterSetName='DefaultParameterSet',Position=7,Mandatory=$false)]
        [Parameter(ParameterSetName='OMSConnection',Position=7,Mandatory=$false)]
        [String]$APIVersion='2015-03-20'

    )

    Try
    {
        If ($OMSConnection)
	    {
	        $SubscriptionID    = $OMSConnection.SubscriptionID
	        $ResourceGroupName = $OMSConnection.ResourceGroupName
            $OMSWorkspaceName  = $OMSConnection.WorkSpaceName
        }

        $URIManagement = 'https://management.azure.com'
        $UriProvider = 'providers/microsoft.operationalinsights'
        $OMSApiAction = 'savedSearches'
        $SavedSearchID = $Category + '|' + $QueryName
        $uri = '{0}/subscriptions/{1}/resourcegroups/{2}/{3}/workspaces/{4}/{5}/{6}?api-version={7}' `
                -f $URIManagement,$SubscriptionID, $ResourceGroupName, $UriProvider, $OMSWorkspaceName,$OMSApiAction,$SavedSearchID, $APIVersion
        
        $headers = @{'Authorization'=$Token;'Accept'='application/json'}
        
        $headers.Add('Content-Type','application/json')

        
                     
        $QueryVersion = 1
        $QProperties = `
             [pscustomobject]@{'Category'    = $Category ;
                               'DisplayName' = $QueryName;
                               'Query'       = $Query;
                               'Version'     = $QueryVersion;
                               }

        $QDate = (get-date -Format 'yyyy-MM-ddTHH mm ss.fffffffZ').Replace(' ','%3A')
        $etag = "W/`"datetime`'" + $QDate + "`'`""
        $QObj = `
              [pscustomobject]@{'etag'        = $etag;
                                'properties'  = $QProperties}
        
        $body = $QObj | Convertto-Json `
                            -ErrorAction Stop
        #Write-verbose $body
        If ($PSCmdlet.ShouldProcess("Query: $QueryName")) 
        {
            $result = Invoke-WebRequest `
                            -Method Put `
                            -Uri $uri `
                            -Headers $headers `
                            -Body $body `
                            -UseBasicParsing `
                            -ErrorAction Stop
        }
        
    }
    Catch
    {
        $ErrorMessage = 'Failed to query OMS API.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Error: '
        $ErrorMessage += $_
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
    }
    
    #region Verbose
    $VerboseMessage = (Get-Date -Format HH:mm:ss).ToString() + ' - Web Request Status code: ' + $result.StatusCode
        Write-Verbose `
             -Message $VerboseMessage 
    #endergion

    if ($result.StatusCode -ge 200 -and $result.StatusCode -le 399)
    {
        if ($null -ne $result.Content)
        {
            $json = ConvertFrom-Json `
                        -InputObject $result.Content `
                        -ErrorAction Stop
            
            if ($null -ne $json)
            {
                $return = $json
                
                
                if ($null -ne $json.value)
                {
                    $return = $json.value
                    
                }
            }
            
        }
    }
    Else
    {
        $ErrorMessage = 'Failed to save OMS search query.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Web request Error: '
        $ErrorMessage += $result
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
        
    }

}
Function Invoke-OMSSavedSearch {
<# 
    .SYNOPSIS
        Return the results from a named saved search.

    .DESCRIPTION
        Gets results from Saved Search.

    .PARAMETER Token
        Token aquired from Get-AADToken cmdlet.

    .PARAMETER SubscriptionID
        Azure Subscription ID where the OMS workspace
        is located.

    .PARAMETER ResourceGroupName
        Azure Resource Group Name where the OMS 
        workspace is located.

    .PARAMETER OMSWorkspaceName
        Name of the OMS workspace.

    .PARAMETER OMSConnection
        Object that contains all needed parameters for working
        with OMSSearch Module. You can create such object in 
        OMS Automation as connection asset.
    
    .PARAMETER QueryName
        Specify the full name of OMS Saved Search to get
        only specific query.

    .PARAMETER Top
        Maximum number of restults to be returned 
        from the query. If not specified 10 results
        will be returned.
        Example: 200

    .PARAMETER Start
        Date/Time string in format yyyy-MM-ddTHH:mm:ss.fffZ
        Start and End paramteres specify the interval for
        which the query should return results.
        Example: 2016-01-17T08:33:55.864Z

    .PARAMETER End
        Date/Time string in format yyyy-MM-ddTHH:mm:ss.fffZ
        Start and End paramteres specify the interval for
        which the query should return results.
        Example: 2016-01-17T14:34:16.953Z

    .PARAMETER APIVersion
        Api version for microsoft.operationalinsights
        Azure Resource provider.

    .EXAMPLE
        # Gets Saved Searches from OMS. Returns results.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        $subscriptionId = "3c1d68a5-4064-4522-94e4-e0378165555e"
        $ResourceGroupName = "oi-default-east-us"
        $OMSWorkspace = "Test"	
        Invoke-OMSSavedSearch -SubscriptionID $subscriptionId -ResourceGroupName $ResourceGroupName  -OMSWorkspaceName $OMSWorkspace -Token $Token -QueryName 'SavedQueryName'
        
    .EXAMPLE
        # Gets Saved Searches from OMS. Returns results.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        $subscriptionId = "3c1d68a5-4064-4522-94e4-e0378165555e"
        $ResourceGroupName = "oi-default-east-us"
        $OMSWorkspace = "Test"
        $NumberOfResults = 150
        $StartTime = (((get-date)).AddHours(-6).ToUniversalTime()).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $EndTime = ((get-date).ToUniversalTime()).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")	
        Invoke-OMSSearchQuery -SubscriptionID $subscriptionId -ResourceGroupName $ResourceGroupName  -OMSWorkspaceName $OMSWorkspace -Token $Token -QueryName 'SavedQueryName' -Top $NumberOfResults -Start $StartTime -End $EndTime
         
    .EXAMPLE
        # Gets Saved Searches from OMS. Returns results.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        $subscriptionId = "3c1d68a5-4064-4522-94e4-e0378165555e"
        $ResourceGroupName = "oi-default-east-us"
        $OMSWorkspace = "Test"
        Invoke-OMSSavedSearch -SubscriptionID $subscriptionId -ResourceGroupName $ResourceGroupName  -OMSWorkspaceName $OMSWorkspace -Token $Token -QueryName 'SavedQueryName' -APIVersion '2015-03-20'
         

    .EXAMPLE
        # Gets Saved Searches from OMS. Returns results.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon	
        Invoke-OMSSavedSearch -OMSConnection $OMSCon -Token $Token -QueryName 'SavedQueryName'
        
    .EXAMPLE
        # Gets Saved Searches from OMS. Returns results.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        $NumberOfResults = 150
        $StartTime = (((get-date)).AddHours(-6).ToUniversalTime()).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $EndTime = ((get-date).ToUniversalTime()).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")	
        Invoke-OMSSearchQuery -OMSConnection $OMSCon -Token $Token -QueryName 'SavedQueryName' -Top $NumberOfResults -Start $StartTime -End $EndTime
         
    .EXAMPLE
        # Gets Saved Searches from OMS. Returns results.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        Invoke-OMSSavedSearch -OMSConnection $OMSCon -Token $Token -QueryName 'SavedQueryName' -APIVersion '2015-03-20'
         
        
    .OUTPUTS
        System.Object. Returns array of objects. Each object
        is result from the query executed. Properties of each
        object depend on the type of data returned.
        For example result from Perf Type can look like this:
        Key               Value
        ---               -----
        Computer          CENTOS7
        ObjectName        Processor
        CounterName       % Processor Time
        InstanceName      _Total
        Min               0,0
        Max               1,0
        SampleCount       45
        TimeGenerated     2016-01-11T21:13:52Z
        BucketStartTime   2016-01-11T21:05:39Z
        BucketEndTime     2016-01-11T21:13:52Z
        SourceSystem      OpsManager
        CounterPath       \\CENTOS7\Processor(_Total)\% Processor Time
        StandardDeviation 0,339934634239519
        MG                00000000-0000-0000-0000-000000000002
        id                8530a411-23bd-e980-04ae-b5dc6fffa365
        Type              Perf
        CounterValue      0,866666666666667
        __metadata        {[Type, Perf], [TimeGenerated, 2016-01-11T21:13:52Z]}

#>
[CmdletBinding(DefaultParameterSetName='NoDateTime')]
[OutputType([object])]
PARAM (
		[Parameter(ParameterSetName='OMSConnection-NoDateTime',Position=0,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection-DateTime',Position=0,Mandatory=$true)]
        [Parameter(ParameterSetName='NoDateTime',Position=0,Mandatory=$true)]
        [Parameter(ParameterSetName='DateTime',Position=0,Mandatory=$true)]
        [String]$Token,

        [Parameter(ParameterSetName='OMSConnection-NoDateTime',Position=1,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection-DateTime',Position=1,Mandatory=$true)]
        [Alias('Connection','c')]
        [Object]$OMSConnection,

        [Parameter(ParameterSetName='NoDateTime',Position=1,Mandatory=$true)]
        [Parameter(ParameterSetName='DateTime',Position=1,Mandatory=$true)]
        [ValidateScript({
            try 
            {
                [System.Guid]::Parse($_) | Out-Null
                $true
            } 
            catch 
            {
                $false
            }
        })]
        [string]$SubscriptionID,

		[Parameter(ParameterSetName='NoDateTime',Position=2,Mandatory=$true)]
        [Parameter(ParameterSetName='DateTime',Position=2,Mandatory=$true)]
        [String]$ResourceGroupName,

		[Parameter(ParameterSetName='NoDateTime',Position=3,Mandatory=$true)]
        [Parameter(ParameterSetName='DateTime',Position=3,Mandatory=$true)]
        [String]$OMSWorkspaceName,

		[Parameter(ParameterSetName='OMSConnection-NoDateTime',Position=4,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection-DateTime',Position=4,Mandatory=$true)]
        [Parameter(ParameterSetName='NoDateTime',Position=4,Mandatory=$true)]
        [Parameter(ParameterSetName='DateTime',Position=4,Mandatory=$true)]
        [String]$QueryName,

		[Parameter(ParameterSetName='OMSConnection-NoDateTime',Position=5,Mandatory=$false)]
        [Parameter(ParameterSetName='OMSConnection-DateTime',Position=5,Mandatory=$false)]
        [Parameter(ParameterSetName='NoDateTime',Position=5,Mandatory=$false)]
        [Parameter(ParameterSetName='DateTime',Position=5,Mandatory=$false)]
        [int]$Top=10,

		[Parameter(ParameterSetName='OMSConnection-DateTime',Position=6,Mandatory=$true)]
        [Parameter(ParameterSetName='DateTime',Position=6,Mandatory=$true)]
        [ValidatePattern('\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}Z')]
        [string]$Start,

		[Parameter(ParameterSetName='OMSConnection-DateTime',Position=7,Mandatory=$true)]
        [Parameter(ParameterSetName='DateTime',Position=7,Mandatory=$true)]
        [ValidatePattern('\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}Z')]
        [string]$End,

        [Parameter(ParameterSetName='OMSConnection-NoDateTime',Position=8,Mandatory=$false)]
        [Parameter(ParameterSetName='OMSConnection-DateTime',Position=8,Mandatory=$false)]
        [Parameter(ParameterSetName='NoDateTime',Position=8,Mandatory=$false)]
        [Parameter(ParameterSetName='DateTime',Position=8,Mandatory=$false)]
        [String]$APIVersion='2015-03-20'
	)
    
    Try
    {
        If ($OMSConnection)
	    {
	        $SubscriptionID    = $OMSConnection.SubscriptionID
	        $ResourceGroupName = $OMSConnection.ResourceGroupName
            $OMSWorkspaceName  = $OMSConnection.WorkSpaceName
        }
	
        $savedSearch = Get-OMSSavedSearch `
                        -SubscriptionID $SubscriptionID `
                        -ResourceGroupName $ResourceGroupName `
                        -OMSWorkspaceName $OMSWorkspaceName `
                        -QueryName $QueryName `
                        -Token $token `
                        -APIVersion $APIVersion `
                        -ErrorAction Stop
    }
    Catch
    {
        $ErrorMessage = 'Failed to find Saved Search. Check parameters.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Details:  '
        $ErrorMessage += $_
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
    }
    
    If ($savedSearch[0].properties.Query.Count -eq 1)
    {
        $OMSParams = @{            
        SubscriptionID = $SubscriptionID
        ResourceGroupName = $ResourceGroupName
        OMSWorkspaceName = $OMSWorkspaceName 
        Token = $token 
        Query =  $savedSearch[0].properties.Query
        APIVersion = $APIVersion       
        } 
        if($top)            
        {            
            $OMSParams.add('Top', $top)         
        }
        if($start)            
        {            
            $OMSParams.add('Start', $start)         
        } 
        if($End)            
        {            
            $OMSParams.add('End', $End)         
        }
    
        $results =  Invoke-OMSSearchQuery @OMSParams
    }
    Else
    {
        $ErrorMessage = 'Failed to find Saved Search. Check parameters.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Details:  '
        $ErrorMessage += $savedSearch
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
    }

    return $results
}
Function Invoke-OMSSearchQuery {
<# 
    .SYNOPSIS
        Executes Search Query against OMS

    .DESCRIPTION
        Executes Search Query against OMS

    .PARAMETER Token
        Token aquired from Get-AADToken cmdlet.

    .PARAMETER SubscriptionID
        Azure Subscription ID where the OMS workspace
        is located.

    .PARAMETER ResourceGroupName
        Azure Resource Group Name where the OMS 
        workspace is located.

    .PARAMETER OMSWorkspaceName
        Name of the OMS workspace.

    .PARAMETER OMSConnection
        Object that contains all needed parameters for working
        with OMSSearch Module. You can create such object in 
        OMS Automation as connection asset.
    
    .PARAMETER Query
        Query to be executed against OMS API.
        Example: * EventID=406

    .PARAMETER Top
        Maximum number of restults to be returned 
        from the query. If not specified 10 results
        will be returned.
        Example: 200

    .PARAMETER Start
        Date/Time string in format yyyy-MM-ddTHH:mm:ss.fffZ
        Start and End paramteres specify the interval for
        which the query should return results.
        Example: 2016-01-17T08:33:55.864Z

    .PARAMETER End
        Date/Time string in format yyyy-MM-ddTHH:mm:ss.fffZ
        Start and End paramteres specify the interval for
        which the query should return results.
        Example: 2016-01-17T14:34:16.953Z

    .PARAMETER APIVersion
        Api version for microsoft.operationalinsights
        Azure Resource provider.

    .EXAMPLE
        # Executes Search Query against OMS. Returns results from query.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        $subscriptionId = "3c1d68a5-4064-4522-94e4-e0378165555e"
        $ResourceGroupName = "oi-default-east-us"
        $OMSWorkspace = "Test"	
        $Query = "shutdown Type=Event EventLog=System Source=User32 EventID=1074 | Select TimeGenerated,Computer"
        $NumberOfResults = 150
        $StartTime = (((get-date)).AddHours(-6).ToUniversalTime()).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $EndTime = ((get-date).ToUniversalTime()).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        Invoke-OMSSearchQuery -SubscriptionID $subscriptionId -ResourceGroupName $ResourceGroupName  -OMSWorkspaceName $OMSWorkspace -Query $Query -Token $Token -Top $NumberOfResults -Start $StartTime -End $EndTime -APIVersion '2015-03-20'

     .EXAMPLE
        # Executes Search Query against OMS. Returns results from query.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        $subscriptionId = "3c1d68a5-4064-4522-94e4-e0378165555e"
        $ResourceGroupName = "oi-default-east-us"
        $OMSWorkspace = "Test"	
        $Query = "shutdown Type=Event EventLog=System Source=User32 EventID=1074 | Select TimeGenerated,Computer"
        Invoke-OMSSearchQuery -SubscriptionID $subscriptionId -ResourceGroupName $ResourceGroupName  -OMSWorkspaceName $OMSWorkspace -Query $Query -Token $Token
        
     .EXAMPLE
        # Executes Search Query against OMS. Returns results from query.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        $subscriptionId = "3c1d68a5-4064-4522-94e4-e0378165555e"
        $ResourceGroupName = "oi-default-east-us"
        $OMSWorkspace = "Test"	
        $Query = "shutdown Type=Event EventLog=System Source=User32 EventID=1074 | Select TimeGenerated,Computer"
        $NumberOfResults = 150
        $StartTime = (((get-date)).AddHours(-6).ToUniversalTime()).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $EndTime = ((get-date).ToUniversalTime()).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        Invoke-OMSSearchQuery -SubscriptionID $subscriptionId -ResourceGroupName $ResourceGroupName  -OMSWorkspaceName $OMSWorkspace -Query $Query -Token $Token -Top $NumberOfResults -Start $StartTime -End $EndTime

     .EXAMPLE
        # Executes Search Query against OMS. Returns results from query.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        $Query = "shutdown Type=Event EventLog=System Source=User32 EventID=1074 | Select TimeGenerated,Computer"
        $NumberOfResults = 150
        $StartTime = (((get-date)).AddHours(-6).ToUniversalTime()).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $EndTime = ((get-date).ToUniversalTime()).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        Invoke-OMSSearchQuery -OMSConnection $OMSCon -Query $Query -Token $Token -Top $NumberOfResults -Start $StartTime -End $EndTime -APIVersion '2015-03-20'

     .EXAMPLE
        # Executes Search Query against OMS. Returns results from query.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        $Query = "shutdown Type=Event EventLog=System Source=User32 EventID=1074 | Select TimeGenerated,Computer"
        Invoke-OMSSearchQuery -OMSConnection $OMSCon -Query $Query -Token $Token
        
     .EXAMPLE
        # Executes Search Query against OMS. Returns results from query.
        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
        $Token = Get-AADToken -OMSConnection $OMSCon
        $Query = "shutdown Type=Event EventLog=System Source=User32 EventID=1074 | Select TimeGenerated,Computer"
        $NumberOfResults = 150
        $StartTime = (((get-date)).AddHours(-6).ToUniversalTime()).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $EndTime = ((get-date).ToUniversalTime()).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        Invoke-OMSSearchQuery -OMSConnection $OMSCon -Query $Query -Token $Token -Top $NumberOfResults -Start $StartTime -End $EndTime

    .OUTPUTS
        System.Object. Returns array of objects. Each object
        is result from the query executed. Properties of each
        object depend on the type of data returned.
        For example result from Perf Type can look like this:
        Key               Value
        ---               -----
        Computer          CENTOS7
        ObjectName        Processor
        CounterName       % Processor Time
        InstanceName      _Total
        Min               0,0
        Max               1,0
        SampleCount       45
        TimeGenerated     2016-01-11T21:13:52Z
        BucketStartTime   2016-01-11T21:05:39Z
        BucketEndTime     2016-01-11T21:13:52Z
        SourceSystem      OpsManager
        CounterPath       \\CENTOS7\Processor(_Total)\% Processor Time
        StandardDeviation 0,339934634239519
        MG                00000000-0000-0000-0000-000000000002
        id                8530a411-23bd-e980-04ae-b5dc6fffa365
        Type              Perf
        CounterValue      0,866666666666667
        __metadata        {[Type, Perf], [TimeGenerated, 2016-01-11T21:13:52Z]}

#>
[CmdletBinding(DefaultParameterSetName='NoDateTime')]
[OutputType([object])]
PARAM (
        [Parameter(ParameterSetName='NoDateTime',Position=0,Mandatory=$true)]
        [Parameter(ParameterSetName='DateTime',Position=0,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection-NoDateTime',Position=0,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection-DateTime',Position=0,Mandatory=$true)]
        [String]$Token,

        [Parameter(ParameterSetName='OMSConnection-NoDateTime',Position=1,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection-DateTime',Position=1,Mandatory=$true)]
        [Alias('Connection','c')]
        [Object]$OMSConnection,

        [Parameter(ParameterSetName='NoDateTime',Position=1,Mandatory=$true)]
        [Parameter(ParameterSetName='DateTime',Position=1,Mandatory=$true)]
        [ValidateScript({
            try 
            {
                [System.Guid]::Parse($_) | Out-Null
                $true
            } 
            catch 
            {
                $false
            }
        })]
        [string]$SubscriptionID,

        [Parameter(ParameterSetName='NoDateTime',Position=2,Mandatory=$true)]
        [Parameter(ParameterSetName='DateTime',Position=2,Mandatory=$true)]
        [String]$ResourceGroupName,

        [Parameter(ParameterSetName='NoDateTime',Position=3,Mandatory=$true)]
        [Parameter(ParameterSetName='DateTime',Position=3,Mandatory=$true)]
        [String]$OMSWorkspaceName,

        [Parameter(ParameterSetName='NoDateTime',Position=4,Mandatory=$true)]
        [Parameter(ParameterSetName='DateTime',Position=4,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection-NoDateTime',Position=4,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection-DateTime',Position=4,Mandatory=$true)]
        [String]$Query,

        [Parameter(ParameterSetName='NoDateTime',Position=5,Mandatory=$false)]
        [Parameter(ParameterSetName='DateTime',Position=5,Mandatory=$false)]
        [Parameter(ParameterSetName='OMSConnection-NoDateTime',Position=5,Mandatory=$false)]
        [Parameter(ParameterSetName='OMSConnection-DateTime',Position=5,Mandatory=$false)]
        [int]$Top=10,

        [Parameter(ParameterSetName='DateTime',Position=6,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection-DateTime',Position=6,Mandatory=$true)]
        [ValidatePattern('\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}Z')]
        [string]$Start,
        
        [Parameter(ParameterSetName='DateTime',Position=7,Mandatory=$true)]
        [Parameter(ParameterSetName='OMSConnection-DateTime',Position=7,Mandatory=$true)]
        [ValidatePattern('\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}Z')]
        [string]$End,

        [Parameter(ParameterSetName='NoDateTime',Position=8,Mandatory=$false)]
        [Parameter(ParameterSetName='DateTime',Position=8,Mandatory=$false)]
        [Parameter(ParameterSetName='OMSConnection-NoDateTime',Position=8,Mandatory=$false)]
        [Parameter(ParameterSetName='OMSConnection-DateTime',Position=8,Mandatory=$false)]
        [String]$APIVersion='2015-03-20'

    )
    
    Try
    {
        If ($OMSConnection)
	    {
	        $SubscriptionID    = $OMSConnection.SubscriptionID
	        $ResourceGroupName = $OMSConnection.ResourceGroupName
            $OMSWorkspaceName  = $OMSConnection.WorkSpaceName
        }

        $URIManagement = 'https://management.azure.com'
        $UriProvider = 'providers/microsoft.operationalinsights'
        $OMSApiAction = 'search'
        $uri = '{0}/subscriptions/{1}/resourcegroups/{2}/{3}/workspaces/{4}/{5}?api-version={6}' `
               -f $URIManagement,$SubscriptionID, $ResourceGroupName, $UriProvider, $OMSWorkspaceName,$OMSApiAction, $APIVersion
        
        $QueryArray = @{Query=$Query}
        if ($Start -and $End) 
        { 
            $QueryArray+= @{Start=$Start}
            $QueryArray+= @{End=$End}
        }
        if ($Top) 
        {
            $QueryArray+= @{Top=$Top}
        }

        $enc = New-Object 'System.Text.ASCIIEncoding'
        
        $body = ConvertTo-Json `
                    -InputObject $QueryArray `
                    -ErrorAction Stop

        $byteArray = $enc.GetBytes($body)
        $contentLength = $byteArray.Length
        $headers = @{'Authorization'=$Token;'Accept'='application/json'}
        $headers.Add('Content-Length',$contentLength)
        $headers.Add('Content-Type','application/json')
        
        $result = Invoke-WebRequest `
                        -Method Post `
                        -Uri $uri `
                        -Headers $headers `
                        -Body $body `
                        -UseBasicParsing `
                        -ErrorAction Stop
    }
    Catch
    {
        $ErrorMessage = 'Failed to query OMS API. Check parameters.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Error: '
        $ErrorMessage += $_
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
    }
    
    
    #region Verbose
    $VerboseMessage = (Get-Date -Format HH:mm:ss).ToString() + ' - Web Request Status code: ' + $result.StatusCode
        Write-Verbose `
             -Message $VerboseMessage 
    #endergion

    if($result.StatusCode -ge 200 -and $result.StatusCode -le 399)
    {
        if($null -ne $result.Content)
        {
            [void][System.Reflection.Assembly]::LoadWithPartialName('System.Web.Extensions')        
            $jsonserial= New-Object `
                            -TypeName System.Web.Script.Serialization.JavaScriptSerializer `
                            -ErrorAction Stop
            $jsonserial.MaxJsonLength  =  [int]::MaxValue
            $json = $jsonserial.DeserializeObject($result.Content)
            if($null -ne $json)
            {
                $return = $json
                if($null -ne $json.value)
                {
                    $return = $json.value
                }
                Else
                {
                    $return = $null
                }
                #region Verbose
                $VerboseMessage = (Get-Date -Format HH:mm:ss).ToString() + ' - Number of records returned from search: ' + $return.count
                    Write-Verbose `
                         -Message $VerboseMessage 
                #endergion
            }
            Else
            {
                $return = $null
            }
        }
    }
    else
    {
        $ErrorMessage = 'Failed to execute query. Check parameters.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Web request Error: '
        $ErrorMessage += $result
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
    }
    
    return $return
}


#Load Load Active Directory Authentication Library (ADAL) Assemblies
If (!([AppDomain]::CurrentDomain.GetAssemblies() |Where-Object { $_.FullName -eq 'Microsoft.IdentityModel.Clients.ActiveDirectory, Version=2.14.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35'}))
{
	Write-verbose 'Microsoft.IdentityModel.Clients.ActiveDirectory...'
	Try {
        $ADALDllFilePath = Join-Path $PSScriptRoot 'Microsoft.IdentityModel.Clients.ActiveDirectory.dll'
        Add-Type -path $ADALDllFilePath
    } Catch {
        Throw "Unable to load $ADALDllFilePath. Please verify if the DLLs exist in this location!"
    }
}
New-Alias -Name Execute-OMSSearchQuery -Value Invoke-OMSSearchQuery -Scope Global
#backward compatibility
New-Alias -Name Get-OMSSavedSearches -Value Get-OMSSavedSearch -Scope Global
Export-ModuleMember -Alias Execute-OMSSearchQuery
Export-ModuleMember -Function *
#region Deprecated Get-ARMAzureSubscription
#Function Get-ARMAzureSubscription {
#<# 
#    .SYNOPSIS
#        Get Azure Subscriptions for current identity.
#
#    .DESCRIPTION
#        Get Azure Subscriptions for current identity.
#
#    .PARAMETER Token
#        Token aquired from Get-AADToken cmdlet.
#
#    .PARAMETER APIVersion
#        Api version for Azure subscriptions provider.
#
#    .EXAMPLE
#        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
#        $Token = Get-AADToken -OMSConnection $OMSCon
#        $subscriptions = Get-AzureSubscription -Token $Token
#
#    .EXAMPLE
#        $OMSCon = Get-AutomationConnection -Name 'OMSCon'
#        $Token = Get-AADToken -OMSConnection $OMSCon
#        $subscriptions = Get-AzureSubscription -Token $Token -APIVersion '2015-03-20'
#
#    .OUTPUTS
#        System.Object. Returns array of objects. Each object
#        is Azure subscription information.
#
##>
#[CmdletBinding(DefaultParameterSetName='DefaultParameterSet')]
#[OutputType([object])]
#PARAM (
#		[Parameter(ParameterSetName='DefaultParameterSet',Position=0,Mandatory=$true)]
#        [String]$Token,
#
#        [Parameter(ParameterSetName='DefaultParameterSet',Position=1,Mandatory=$false)]
#        [String]$APIVersion='2015-03-20'
#	)
#    
#    #'2015-01-01'
#    Try
#    {
#        $URI = 'https://management.azure.com/subscriptions?api-version={0}' -f $APIVersion
#
#        $headers = @{'Authorization'=$Token;'Accept'='application/json'}
#	    $headers.Add('Content-Type','application/json')
#	    
#        $result = Invoke-WebRequest `
#                        -Method Get `
#                        -Uri $uri `
#                        -Headers $headers `
#                        -UseBasicParsing `
#                        -ErrorAction Stop
#	    
#        
#    }
#    Catch
#    {
#        $ErrorMessage = 'Failed to query Azure Resource Manager API. Check parameters.'
#        $ErrorMessage += " `n"
#        $ErrorMessage += 'Error: '
#        $ErrorMessage += $_
#        Write-Error -Message $ErrorMessage `
#                    -ErrorAction Stop
#    }
#
#    $json=$null
#	if($result.StatusCode -ge 200 -and $result.StatusCode -le 399)
#    {
#	    if($null -ne $result.Content)
#        {
#	     $json = ConvertFrom-Json `
#                                -InputObject $result.Content `
#                                -ErrorAction Stop
#	    }
#	}
#    Else
#    {
#        $ErrorMessage = 'Failed to get Azure Subscription. Check parameters.'
#        $ErrorMessage += " `n"
#        $ErrorMessage += 'Web request Error: '
#        $ErrorMessage += $result
#        Write-Error -Message $ErrorMessage `
#                    -ErrorAction Stop
#    }
#
#    return $json
#}
#endregion