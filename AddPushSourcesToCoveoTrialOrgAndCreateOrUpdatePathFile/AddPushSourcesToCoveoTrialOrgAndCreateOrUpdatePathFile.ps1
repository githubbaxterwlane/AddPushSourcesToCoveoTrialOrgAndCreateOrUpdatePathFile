function CreateOrGetPushSources {

    [CmdLetBinding()]
    [OutputType([CoveoOrganizationPushSources])]
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
        [OutputType([CoveoOrganizationPushSources])]
        param (

            [Parameter(Mandatory)]
            [string]
            $authToken
        )

        $orgPushSources = [CoveoOrganizationPushSources]::new();
        $orgPushSources.Organization = Get-Organization -authToken $authToken;

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

                    $orgPushSources.PushSources += $curExistingSource;

                    break;
                }
            }

            if (-not $alreadyExists) {

                $pushSourceCreationResponse = New-PushSource -name $curPushSourceName -sourceVisibility SHARED -authToken $authToken; 

                Write-Verbose "$($MyInvocation.MyCommand.Name): New Push Source Has been Created $curPushSourceName";

                $orgPushSources.PushSources += $pushSourceCreationResponse;
            }

        }

        return $orgPushSources;
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
        [OutputType([CoveoSource[]])]
        param (
        
            [Parameter(Mandatory)]
            [string]
            $authToken
        )
    
        [string]$restEndpoint = Get-SourcesUri -authToken $authToken

        $sources = Invoke-RestMethod -Method Get -Headers (Get-BearerTokenAuthorizationHeaderKeyValuePair -authToken $authToken) -ContentType $localSettings.appJson -Uri $restEndpoint

        if ($sources){

            Write-Verbose "$($MyInvocation.MyCommand.Name): $($sources.Count) sources found.";

            [CoveoSource[]]$returnSources = @();

            foreach($curSource in $sources) {

                [CoveoSource]$curReturnSource = Get-CoveoSourceFromResponse -response $curSource;

                $returnSources += $curReturnSource;
            }

            return $returnSources;
        } else {

            Write-Verbose "$($MyInvocation.MyCommand.Name): No sources were found."

            return [CoveoSource[]] @();
        }
    }

    function Get-Organization {

        [CmdletBinding()]
        [OutputType([CoveoOrganization])]
        param (
        
            [Parameter(Mandatory)]
            [string]
            $authToken
        )

        [string]$restEndpoint = Get-OrganizationsUri

        $organization = Invoke-RestMethod -Method Get -Headers (Get-BearerTokenAuthorizationHeaderKeyValuePair -authToken $authToken) -ContentType $localSettings.appJson -Uri $restEndpoint

        if ($organization) {

            Write-Verbose "$($MyInvocation.MyCommand.Name): Got org $($organization.displayName)"

            [CoveoOrganization]$coveoOrg = [CoveoOrganization]::new();

            $coveoOrg.DisplayName = $organization.displayName;
            $coveoOrg.Id = $organization.id;
            $coveoOrg.OwnerEmail = $organization.owner.email;
            $coveoOrg.PublicContentOnly = $organization.publicContentOnly;
            $coveoOrg.ReadOnly = $organization.readonly;
            $coveoOrg.Type = $organization.type;

            return $coveoOrg;

        } else {
            Throw "No organization could be found for the token '$authToken'!"
        }
    }

    function New-PushSource {

        [CmdletBinding()]
        [OutputType([CoveoSource])]
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

        [CoveoSource]$coveoSource = Get-CoveoSourceFromResponse -response $response;

        Write-Verbose "$($MyInvocation.MyCommand.Name): Created new push source $($coveoSource.Name).";

        return $coveoSource;
    }

    function Get-CoveoSourceFromResponse {

        [OutputType([CoveoSource])]
        param(

            $response
        )

        if ($response) {

            [CoveoSource]$returnSource = [CoveoSource]::new();

            $returnSource.Id = $response.id;
            $returnSource.Name = $response.name;
            $returnSource.OnPremisesEnabled = $response.onPremisesEnabled;
            $returnSource.PushEnabled = $response.pushEnabled;
            $returnSource.ResourceId = $response.resourceId;
            $returnSource.SourceType = $response.sourceType;
            $returnSource.SourceVisibility = $response.sourceVisiblity;

            return $returnSource;
        } else {

            return $null;
        }
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

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [CoveoOrganizationPushSources]
        $organizationPushSources,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]
        $authToken,

        [ValidateNotNull()]
        [string]
        $daltileSiteName = "daltile.sc"
    )

    function Invoke-Main {

        [CmdletBinding()]
        param (

            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            [CoveoOrganizationPushSources]
            $organizationPushSources,

            [Parameter(Mandatory)]
            [ValidateNotNull()]
            [string]
            $authToken,

            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            [string]
            $daltileSiteName
        )

        Update-PushSourceConfigFile -organizationPushSources $organizationPushSources -authToken $authToken;
    }

    function Update-PushSourceConfigFile {
    
        [CmdletBinding()]
        param (

            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            [CoveoOrganizationPushSources]
            $organizationPushSources,

            [Parameter(Mandatory)]
            [ValidateNotNull()]
            [string]
            $authToken,

            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            [string]
            $daltileSiteName
        )
               
        [xml]$configXml = Get-XmlDocument;

        [System.Xml.XmlElement]$settingsElement = $configXml.SelectSingleNode("configuration/sitecore/settings");

        for ($i = 0; $i -lt $organizationPushSources.PushSources.Count; $i++) { 
    
            [CoveoSource]$curPushSource = $organizationPushSources.PushSources[$i];

            $comment = $configXml.CreateComment($curPushSource.Name);
            $settingsElement.AppendChild($comment);

            [string]$settingsNamePrefix = Get-SettingNamePrefix -coveoSource $curPushSource;
            [string]$databaseName = Get-DatabaseNameForSource -coveoSource $curPushSource;

            Add-SettingElement -settingNamePrefix $settingsNamePrefix -settingName "SourceName" -settingValue $curPushSource.Name -settingsElement $settingsElement;
            Add-SettingElement -settingNamePrefix $settingsNamePrefix -settingName "ForDatabaseName" -settingValue $databaseName -settingsElement $settingsElement;
            Add-SettingElement -settingNamePrefix $settingsNamePrefix -settingName "BaseAddressRoot" -settingValue "https://push.cloud.coveo.com/v1/" -settingsElement $settingsElement;
            Add-SettingElement -settingNamePrefix $settingsNamePrefix -settingName "Organization" -settingValue "organizations/$($organizationPushSources.Organization.Id)" -settingsElement $settingsElement;
            Add-SettingElement -settingNamePrefix $settingsNamePrefix -settingName "Source" -settingValue "sources/$($curPushSource.Id)" -settingsElement $settingsElement;
            Add-SettingElement -settingNamePrefix $settingsNamePrefix -settingName "AuthenticationHeaderValue" -settingValue $authToken -settingsElement $settingsElement;
            
        }

        Save-XmlDocAsPatchFile -docToSave $configXml -daltileSiteName $daltileSiteName;

    }
    
    function Get-XmlDocument {

        [string]$docString = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration xmlns:patch="http://www.sitecore.net/xmlconfig/"
               xmlns:role="http://www.sitecore.net/xmlconfig/role/"
               xmlns:env="http://www.sitecore.net/xmlconfig/env/"
               xmlns:integrations="http://www.sitecore.net/xmlconfig/integrations/"
               xmlns:localenv="$(Get-LocalEnvRequireUrl)">

    <sitecore>
        <settings>
        </settings>
    </sitecore>
</configuration>
"@

        [xml]$doc = $docString;

        return $doc;
    }

    function Get-SettingNamePrefix {
        
        [CmdletBinding()]        
        param(

            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [CoveoSource]
            $coveoSource
        )

        [string]$namespace = "DaltileGroup.Feature.SiteSearch.Repositories";
        [string]$repoName = $null;

        if ($coveoSource.Name.StartsWith("Series-Index-CM", [System.StringComparison]::InvariantCultureIgnoreCase)) {
            $repoName = "SeriesIndexPushSourceRepository";
        } elseif ($coveoSource.Name.StartsWith("Product-Index-CM", [System.StringComparison]::InvariantCultureIgnoreCase)) {
            $repoName = "ProductIndexPushSourceRepository";
        } elseif ($coveoSource.Name.StartsWith("Series-Index-CD", [System.StringComparison]::InvariantCultureIgnoreCase)) {
            $repoName = "SeriesIndexCdPushSourceRepository";
        } elseif ($coveoSource.Name.StartsWith("Product-Index-CD", [System.StringComparison]::InvariantCultureIgnoreCase)) {
            $repoName = "ProductIndexCdPushSourceRepository";
        } else {
            $repoName = "CouldNotDetermineRepoFromSourceName";
        }

        [string]$prefix = "$namespace.$repoName."

        return $prefix;
    }

    function Get-DatabaseNameForSource {

        [CmdletBinding()]        
        param(

            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [CoveoSource]
            $coveoSource
        )

        [string]$dbName = $null;

        if ($coveoSource.Name.Contains("-CM-")) {
            $dbName = "master";
        } elseif ($coveoSource.Name.Contains("-CD-")) {
            $dbName = "web";
        } else {
            $dbName = "CouldNotFindCMOrCdInTheSourceName";
        }

        return $dbName;
    }

    function Add-SettingElement {

        [CmdletBinding()]        
        param(

            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [string]
            $settingNamePrefix,

            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [string]
            $settingName,

            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [string]
            $settingValue,

            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            [System.Xml.XmlElement]
            $settingsElement
        )

        [string]$setting = "setting";
        [string]$name = "name";
        [string]$value = "value";
        [string]$localenv = 'localenv';
        [string]$require = "require"
        [string]$env = "LOCAL"

        [System.Xml.XmlElement]$newSettingElement = $settingsElement.OwnerDocument.CreateElement($setting);
        
        [System.Xml.XmlAttribute]$nameAtt = $settingsElement.OwnerDocument.CreateAttribute($name);        
        $nameAtt.Value = "$settingNamePrefix$settingName";
        $newSettingElement.Attributes.Append($nameAtt);

        [System.Xml.XmlAttribute]$valueAtt = $settingsElement.OwnerDocument.CreateAttribute($value);        
        $valueAtt.Value = $settingValue;
        $newSettingElement.Attributes.Append($valueAtt);

        [System.Xml.XmlAttribute]$localEnvRequireAtt = $settingsElement.OwnerDocument.CreateAttribute($localenv, $require, (Get-LocalEnvRequireUrl));        
        $localEnvRequireAtt.Value = $env;
        $newSettingElement.Attributes.Append($localEnvRequireAtt);

        $settingsElement.AppendChild($newSettingElement);
    }

    function Save-XmlDocAsPatchFile {

        [CmdLetBinding()]
        param (

            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            [System.Xml.XmlDocument]
            $docToSave,

            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            [string]
            $daltileSiteName
        )

        [string]$patchFileFullPath = Get-PatchFileFullPath -daltileSiteName $daltileSiteName;

        $docToSave.Save($patchFileFullPath);
    }

    function Get-PatchFileFullPath {

        [CmdLetBinding()]
        [OutputType([string])]
        param (

            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            [string]
            $daltileSiteName
        )

        [string]$siteRootPath = Get-DaltileSiteRootPath -daltileSiteName $daltileSiteName;

        [string]$featureFolderPath = "App_Config\Include\Feature";

        [string]$patchFileName = "zzzz.51605D0EB2E74959947A35E5747BC61F.LocalDevCoveoPushSourcesPatchFileOf.Feature.SiteSearchModule.config"

        [string]$fullPath = [System.IO.Path]::Combine($siteRootPath, $featureFolderPath, $patchFileName);

        return $fullPath;
    }

    function Get-DaltileSiteRootPath {

        [CmdLetBinding()]
        [OutputType([string])]
        param (

            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            [string]
            $daltileSiteName
        )

        Write-Verbose "$($MyInvocation.MyCommand.Name): IIS Site Name = '$daltileSiteName'"

        [Microsoft.IIs.PowerShell.Framework.ConfigurationElement]$website = Get-website -Name $daltileSiteName;

        return $website.physicalPath;
    }

    function Get-LocalEnvRequireUrl {

        [string]$url = "http://www.sitecore.net/xmlconfig/localenv/";

        return $url;
    }   

    Invoke-Main -organizationPushSources $organizationPushSources -authToken $authToken -daltileSiteName $daltileSiteName;
}

class CoveoOrganizationPushSources {

    OrganizationPushSources() {
        
        $this.Organization = [CoveoOrganization]::new();

        $this.PushSources = [CoveoSource[]] @();
    }

    [CoveoOrganization]$Organization;

    [CoveoSource[]]$PushSources;
}

class CoveoOrganization {

    [string]$Id;
    [string]$DisplayName
    [string]$OwnerEmail;
    [bool]$PublicContentOnly;
    [bool]$ReadOnly;
    [string]$Type;
}

class CoveoSource {

    [string]$SourceType;
    [string]$Id;
    [string]$Name;
    [string]$SourceVisibility;
    [bool]$PushEnabled;
    [bool]$OnPremisesEnabled;
    [string]$ResourceId;    
}

[string]$token = "xxdaa6a1a8-79e6-48cf-a058-4b2308beb41a";
[string]$daltileSiteName = "daltile.sc";

$orgPushSources = CreateOrGetPushSources -authToken $token -Verbose;

PatchSitecoreToUsePushSources -organizationPushSources $orgPushSources -authToken $token -daltileSiteName $daltileSiteName;
