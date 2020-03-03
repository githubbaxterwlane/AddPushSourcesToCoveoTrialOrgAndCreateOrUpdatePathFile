function CreateOrGetPushSources {

    [CmdLetBinding()]
	param (

		[string]
		$authToken
	)
    
    $localSettings = @{
        
        appJson = "application/json";
        environmentName = "DevTrial";
    };

    function Invoke-Main {

        [CmdletBinding()]
        param (

            [Parameter(Mandatory)]
            [string]
            $authToken
        )

        $pushSourcesToReturn = @();

        $currentPushSources = Get-PushSource -authToken $authToken;

        if ($currentPushSources -and $currentPushSources.Count > 0) {
            Write-Verbose "$($MyInvocation.MyCommand.Name): There were $($currentPushSources.Count) push sources found."
        } else {
            Write-Verbose "$($MyInvocation.MyCommand.Name): No push sources were found." 
        }

        [string[]]$pushSourceNames = Get-PushSourceNames

        foreach($curPushSourceName in $pushSourceNames) {

            [bool]$alreadyExists = $false

            foreach($curExistingSource in $currentPushSources) {

                if ($curExistingSource.name -eq $curPushSourceName) {

                    $alreadyExists = $true;

                    Write-Verbose "$($MyInvocation.MyCommand.Name): No need to create this push source, it exists already: $curPushSourceName";

                    $pushSourcesToReturn += $curExistingSource;

                    break;
                }
            }

            if (-not $alreadyExists) {

                $pushSourceCreationResponse = New-PushSource -name $curPushSourceName -sourceVisibility SHARED -authToken $authToken; 

                Write-Verbose "$($MyInvocation.MyCommand.Name): New Push Source Has been Created $curPushSourceName";

                $pushSourcesToReturn += $pushSourceCreationResponse;
            }

        }

        return $pushSourcesToReturn;
    }
    
    function Get-PushSource {

        [CmdletBinding()]
        param (

            [Parameter(Mandatory)]
            [string]
            $authToken
        )
        
        $sources = Get-Source -authToken $authToken

        [System.Object[]]$pushSources = @()

        [string]$pushSourceTypeName = "PUSH"

        foreach($curSource in $sources) {

            if ($curSource.sourceType -eq $pushSourceTypeName) {

                $pushSources += $curSource;
            }
        }

        Write-Verbose "$($MyInvocation.MyCommand): $($pushSources.Count) Push Type sources found.";

        return $pushSources
    }

    function Get-Source {

        [CmdletBinding()]
        param (
        
            [Parameter(Mandatory)]
            [string]
            $authToken
        )
    
        [string]$restEndpoint = Get-SourcesUri -authToken $authToken

        $sources = Invoke-RestMethod -Method Get -Headers (Get-BearerTokenAuthorizationHeaderKeyValuePair -authToken $authToken) -ContentType $localSettings.appJson -Uri $restEndpoint

        Write-Verbose "$($MyInvocation.MyCommand.Name): $($sources.Count) sources found.";

        return $sources
    }

    function Get-Organization {

        [CmdletBinding()]
        param (
        
            [Parameter(Mandatory)]
            [string]
            $authToken
        )

        [string]$restEndpoint = Get-OrganizationsUri

        $organization = Invoke-RestMethod -Method Get -Headers (Get-BearerTokenAuthorizationHeaderKeyValuePair -authToken $authToken) -ContentType $localSettings.appJson -Uri $restEndpoint

        Write-Verbose "$($MyInvocation.MyCommand.Name): Got org $($organization.Name)"

        return $organization;
    }

    function New-PushSource {

        [CmdletBinding()]
        param (

            [Parameter(Mandatory)]
            [string]
            $name,

            [Parameter(Mandatory)]
            [ValidateSet("PRIVATE", "SECURED", "SHARED")]
            [string]
            $sourceVisibility,
        
            [Parameter(Mandatory)]
            [string]
            $authToken
        )

        [string]$sourceType = "PUSH"

        [string]$restEndpoint = Get-SourcesUri -authToken $authToken

        $requestBody = @{

            sourceType = $sourceType;
            name = $name;
            sourceVisibility = $sourceVisibility;
            pushEnabled = $true;
        }

        $requestBodyJson = ($requestBody | ConvertTo-Json)

        $response = Invoke-RestMethod -Method Post -Headers (Get-BearerTokenAuthorizationHeaderKeyValuePair -authToken $authToken) -Body $requestBodyJson -ContentType $localSettings.appJson -Uri $restEndpoint

        Write-Verbose "$($MyInvocation.MyCommand.Name): Created new push source $name";

        return $response
    }

    function Get-PushSourceNames {

        [CmdletBinding()]

        [string]$seriesCMName = Format-PushSourceName -sourceType Series -forDb CM 
        [string]$seriesCDName = Format-PushSourceName -sourceType Series -forDb CD
        [string]$productCMName = Format-PushSourceName -sourceType Product -forDb CM
        [string]$productCDName = Format-PushSourceName -sourceType Product -forDb CD

        [string[]]$pushSourceNames = $seriesCMName, $productCMName, $seriesCDName, $productCDName

        Write-Verbose "$($MyInvocation.MyCommand.Name): $($pushSourceNames.Count) push source names being returned.";
        Write-Verbose "$($MyInvocation.MyCommand.Name): $pushSourceNames";

        return $pushSourceNames;
    }

    function Format-PushSourceName {

        [CmdLetBinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateSet("Product", "Series")]
            [string]
            $sourceType,

            [Parameter(Mandatory)]
            [ValidateSet("CM", "CD")]
            [string]
            $forDb,

            [string]
            $index = "Index",
                          
            [string]
            $environmentName = $localSettings.environmentName,
                
            [string]
            $wordSeperator = "-",
                
            [string]
            $instance = "Int"
        )

        [string]$name = "$sourceType$wordSeperator$index$wordSeperator$forDb$wordSeperator$environmentName$wordSeperator$instance";

        Write-Verbose "$($MyInvocation.MyCommand.Name): $name";

        return $name;
    }

    function Get-SourcesUri {

        [CmdletBinding()]
        param (
        
            [Parameter(Mandatory)]
            [string]
            $authToken
        )

        [string]$sourcesSegment = "sources"

        [string]$orgsUri = Get-OrganizationsUri

        $orgInfo = Get-Organization -authToken $authToken;

        [string]$orgId = $orgInfo.id;

        [string]$uri = "$orgsUri/$orgId/$sourcesSegment";

        Write-Verbose "$($MyInvocation.MyCommand.Name): $uri";

        return $uri;
    }

    function Get-OrganizationsUri {

        [CmdletBinding()]

        [string]$organizationsSegment = "organizations";

        [string]$coveoCloudBaseUri = Get-CoveoCloudRestApiBaseUri;

        [string]$uri = "$coveoCloudBaseUri/organizations";

        Write-Verbose "$($MyInvocation.MyCommand.Name): $uri";

        return $uri;
    }

    function Get-BearerTokenAuthorizationHeaderKeyValuePair {

        [CmdletBinding()]
        param (

            [Parameter(Mandatory)]
            [string]
            $authToken
        )

        [string]$bearerTokenTypeName = "Bearer"

        [string]$value = "$bearerTokenTypeName $authToken"

        $returnKeyValuePair = Get-AuthorizationHeaderKeyValuePair -value $value

        Write-Verbose "$($MyInvocation.MyCommand.Name): $returnKeyValuePair";

        return $returnKeyValuePair;
    }

    function Get-AuthorizationHeaderKeyValuePair {
        
        [CmdletBinding()]        
        param (

            [Parameter(Mandatory)]
            [string]
            $value
        )

        [string]$authorizationHeaderKey = "Authorization"

        $headerAuthKeyValuePair = @{ $authorizationHeaderKey = $value };

        Write-Verbose "$($MyInvocation.MyCommand.Name): returning '$headerAuthKeyValuePair'";

        return $headerAuthKeyValuePair;
    }

    function Get-CoveoCloudRestApiBaseUri {

        [CmdletBinding()]        

        [string]$uri = "https://platform.cloud.coveo.com/rest"

        Write-Verbose "$($MyInvocation.MyCommand.Name): returning '$uri'";

        return $uri
    }
	
	return Invoke-Main -authToken $authToken;
};

function PatchSitecoreToUsePushSources {

    [CmdletBinding()]
    param (

        $pushSources
    )

    function Invoke-Main {

        Update-PushSourceConfigFile;

    }

    function Update-PushSourceConfigFile {

    
        param (
            [ValidateNotNullOrEmpty()]        
            [string]
            $path = "\\blane-pk\C$\inetpub\wwwroot\daltile.sc\App_Config\Include\Feature\zzz.Feature.SiteSearch-sources override to baxters gmail account as a trial.config",

            [Parameter(Mandatory)]
            [string]
            $authToken
        )

        if(-Not (Test-Path -Path $path -PathType Leaf)) {

            Throw "$path - NOT FOUND!"
        }


        [xml]$configXml = Get-Content -Path $path

        $pushSources = Get-bwlPushSource -authToken $authToken

        [string]$prodctCMSourceName = Format-bwlPushSourceName -sourceType Product -forDb CM
        [string]$seriesCMSourceName = Format-bwlPushSourceName -sourceType Series -forDb CM
        [string]$productCDSourceName = Format-bwlPushSourceName -sourceType Product -forDb CD
        [string]$seriesCDSourceName = Format-bwlPushSourceName -sourceType Series -forDb CD

        foreach ($curPushSource in $pushSources) {

            switch ($curPushSource.name) {
                    
                $prodctCMSourceName { Set-bwlPushSourceConfigsForSource -pushSourceType Product-CM -configXmlDoc $configXml -pushSourceInfo $curPushSource -authToken $authToken ; break; }
                $seriesCMSourceName { Set-bwlPushSourceConfigsForSource -pushSourceType Series-CM -configXmlDoc $configXml -pushSourceInfo $curPushSource -authToken $authToken ; break; }
                $productCDSourceName { Set-bwlPushSourceConfigsForSource -pushSourceType Product-CD -configXmlDoc $configXml -pushSourceInfo $curPushSource -authToken $authToken ; break; }
                $seriesCDSourceName { Set-bwlPushSourceConfigsForSource -pushSourceType Series-CD -configXmlDoc $configXml -pushSourceInfo $curPushSource -authToken $authToken ; break; }
            }
        }

        $configXml.Save($path);

    }

    function Set-PushSourceConfigsForSource {

        param (

            [Parameter(Mandatory)]
            [ValidateSet("Product-CM", "Series-CM", "Product-CD", "Series-CD")]
            [string]
            $pushSourceType,

            [Parameter(Mandatory)]        
            [xml]
            $configXmlDoc,

            [Parameter(Mandatory)]                
            $pushSourceInfo,

            [Parameter(Mandatory)]
            [string]
            $authToken
        )

        $orgInfo = Get-bwlOrganization -authToken $authToken

        [string]$settingNamePrefix = "DaltileGroup.Feature.SiteSearch.Repositories."

        switch ($pushSourceType) {

            "Product-CM" { $settingNamePrefix += "ProductIndexPushSourceRepository."; break; }
            "Series-CM" { $settingNamePrefix += "SeriesIndexPushSourceRepository."; break; }
            "Product-CD" { $settingNamePrefix += "ProductIndexCdPushSourceRepository."; break; }
            "Series-CD" { $settingNamePrefix += "SeriesIndexCdPushSourceRepository."; break; }
        }

        Set-SitecoreSettingValueAttribute -propertyNamePrefix $settingNamePrefix -propertyName "SourceName" -newValue $pushSourceInfo.name -configXmlDoc $configXmlDoc

        [string]$orgId = $orgInfo.Id
        [string]$orgSettingValue = "organizations/$orgId"
        Set-SitecoreSettingValueAttribute -propertyNamePrefix $settingNamePrefix -propertyName "Organization" -newValue $orgSettingValue -configXmlDoc $configXmlDoc

        [string]$sourceId = $pushSourceInfo.Id
        [string]$sourceSettingValue = "sources/$sourceId"
        Set-SitecoreSettingValueAttribute -propertyNamePrefix $settingNamePrefix -propertyName "Source" -newValue $sourceSettingValue -configXmlDoc $configXmlDoc

        Set-SitecoreSettingValueAttribute -propertyNamePrefix $settingNamePrefix -propertyName "AuthenticationHeaderValue" -newValue $authToken -configXmlDoc $configXmlDoc
    }

    function Set-SitecoreSettingValueAttribute {


        param (

            [Parameter(Mandatory)]        
            [string]
            $propertyNamePrefix,

            [Parameter(Mandatory)]        
            [string]
            $propertyName,
                
            [Parameter(Mandatory)]        
            [string]
            $newValue,

            [Parameter(Mandatory)]        
            [xml]
            $configXmlDoc
        )    

        [string]$settingElementName = "setting"
        [string]$nameAttributeName = "name"
        [string]$valueAttrributeName = "value"

        $element = $configXmlDoc.SelectSingleNode("configuration/sitecore/settings/setting[@$nameAttributeName='$propertyNamePrefix$propertyName']")

        $element.SetAttribute($valueAttrributeName, $newValue)

    }

    Invoke-Main;
}

$pushSources = CreateOrGetPushSources -authToken "xxdaa6a1a8-79e6-48cf-a058-4b2308beb41a" -Verbose;