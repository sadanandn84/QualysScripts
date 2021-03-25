param(
[System.Security.SecureString][Parameter(Mandatory=$true)]$password,
[System.Security.SecureString][Parameter(Mandatory=$true)]$Azureauthkey
)
$qualysPassword = (New-Object System.Management.Automation.PSCredential('dummy', $password)).GetNetworkCredential().Password
$azureAuthenticationKey = (New-Object System.Management.Automation.PSCredential('dummy', $Azureauthkey)).GetNetworkCredential().Password
# PS script to add Azure AV connector in bulk
$config = Get-Content ./config.json | ConvertFrom-Json
$Username = $config.defaults.username
$URL = $config.defaults.baseurl
$debug = $config.defaults.debug
$subscriptions = $config.defaults.subscriptions
$directoryId = $config.defaults.directoryId
$applicationId = $config.defaults.applicationId



# Exclude the below block, if you are using Powershell 6
# The below code block helps bypass self-signed or expired certificate issues
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

#BYPASS SELF-SIGNED OR EXPIRED CERTS BLOCK ENDS HERE



function getSubscriptions($subscription)
{
$file = Import-Csv -Path $subscription
$file | ForEach-Object {
			$connectorName = $_.ConnectorName
            $modules = $_.Modules -split " "
            foreach ($module in $modules)
            {
                $activateModules += "<ActivationModule>$module</ActivationModule>"
            }
            AddConnector $_.SubscriptionId $connectorName $activateModules
		}
    
	}
    

function main()
{
    
    $subscriptionIds = @()
	
	if (($Username -eq $null) -OR ($URL -eq $null) -OR ($subscriptions -eq $null) -OR ($directoryId -eq $null) -OR ($applicationId -eq $null))
	{
		write-host "Config information in ./config.json is not configured correctly. Exiting..."
		break
	}
	else
	{

		$URI = $URL + "/qps/rest/2.0/create/am/azureassetdataconnector"
        $Qualyscreds = "${Username}:${qualysPassword}"
		$base64AuthInfo = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Qualyscreds))

		$Headers = @{ Authorization = "Basic $base64AuthInfo"}
		$headers.Add("X-Requested-With","Powershell")

		if ($debug -ne $null)
		{
			$debugfile = New-Item -itemType File -Name ("debug-" + $((Get-Date).tostring("dd-MM-yyyy-hh-mm-ss")) + ".log")
		}
		getSubscriptions $subscriptions
	}
}

function AddConnector($subscriptionIds,$connectorName, $activateModules)
{
	echo "------------------------------Creating AZURE Connectors--------------------------------"
	Add-Content "------------------------------Creating AZURE Connectors--------------------------------" -Path $debugfile.Name
    $xml_body = "<?xml version='1.0' encoding='UTF-8'?><ServiceRequest><data><AzureAssetDataConnector><name>$connectorName</name><authRecord><applicationId>$applicationId</applicationId><directoryId>$directoryId</directoryId><subscriptionId>$subscriptionIds</subscriptionId><authenticationKey>$azureAuthenticationKey</authenticationKey></authRecord><activation><add>$activateModules</add></activation></AzureAssetDataConnector></data></ServiceRequest>"
    
    try
	{
		echo "Azure Connector with below details is being created"
		echo $xml_body
		Add-Content "Connector with below details" -Path $debugfile.Name
		Add-Content $xml_body -Path $debugfile.Name
		$result = Invoke-RestMethod -Method Post -Headers $Headers -Uri $URI -Body $xml_body -ContentType "text/xml"
		Write-Host "StatusCode" ($result.ServiceResponse.responseCode)
		if ($debug -ne $null)
		{
			Add-Content  -Path $debugfile.Name "is created Successfully"
			Add-Content  -Path $debugfile.Name $result.ServiceResponse.data
			Add-Content  -Path $debugfile.Name "-------------------------------------------------------------------------"
		}
	}
	catch
	{
		Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
		Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
		if ($debug -ne $null)
		{
			Add-Content  -Path $debugfile.Name "is not created Successfully"
			Add-Content  -Path $debugfile.Name $_.Exception
			Add-Content  -Path $debugfile.Name "-------------------------------------------------------------------------"
		}
	}
}		
main