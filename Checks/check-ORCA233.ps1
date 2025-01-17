<#

233 - Check EF is turned on where MX not set to ATP

#>

using module "..\ORCA.psm1"

class ORCA233 : ORCACheck
{
    <#
    
        CONSTRUCTOR with Check Header Data
    
    #>

    ORCA233()
    {
        $this.Control=233
        $this.Area="Connectors"
        $this.Name="Domains"
        $this.PassText="Domains are pointed directly at EOP or enhanced filtering is used"
        $this.FailRecommendation="Send mail directly to EOP or configure enhanced filtering"
        $this.Importance="Exchange Online Protection (EOP) and Advanced Threat Protection (ATP) works best when the mail exchange (MX) record is pointed directly at the service. <p>In the event another third-party service is being used, a very important signal (the senders IP address) is obfuscated and hidden from EOP & ATP, generating a larger quantity of false positives and false negatives. By configuring Enhanced Filtering with the IP addresses of these services the true senders IP address can be discovered, reducing the false-positive and false-negative impact.</p>"
        $this.ExpandResults=$True
        $this.CheckType=[CheckType]::ObjectPropertyValue
        $this.ObjectType="Domain"
        $this.ItemName="Points to Service"
        $this.DataType="Enhanced Filtering"
        $this.Links= @{
            "Security & Compliance Center - Enhanced Filtering"="https://aka.ms/orca-connectors-action-skiplisting"
            "Enhanced Filtering for Connectors"="https://aka.ms/orca-connectors-docs-1"
        }
    }

    <#
    
        RESULTS
    
    #>

    GetResults($Config)
    {

        $Connectors = @()

        # Analyze connectors
        ForEach($Connector in $($Config["InboundConnector"] | Where-Object {$_.Enabled}))
        {
            # Set regex options for later match
            $options = [Text.RegularExpressions.RegexOptions]::IgnoreCase

            ForEach($senderdomain in $Connector.SenderDomains)
            {
                # Perform match on sender domain
                $match = [regex]::Match($senderdomain,"^smtp:\*;(\d*)$",$options)

                if($match.success)
                {

                    # Positive match
                    $Connectors += New-Object -TypeName PSObject -Property @{
                        Identity=$Connector.Identity
                        Priority=$($match.Groups[1].Value)
                        TlsSenderCertificateName=$Connector.TlsSenderCertificateName
                        EFTestMode=$Connector.EFTestMode
                        EFSkipLastIP=$Connector.EFSkipLastIP
                        EFSkipIPs=$Connector.EFSkipIPs
                        EFSkipMailGateway=$Connector.EFSkipMailGateway
                        EFUsers=$Connector.EFUsers
                    }
                }
            }

        }

        $EFDisabledConnectors = @($Connectors | Where-Object {($_.EFSkipIPs.Count -eq 0 -and $_.EFSkipLastIP -eq $False) -or $_.EFTestMode -eq $True -or $_.EFUsers.Count -gt 0})

        If($EFDisabledConnectors.Count -gt 0 -or $Connectors.Count -eq 0)
        {
            $EnhancedFiltering = $False
        }
        else
        {
            $EnhancedFiltering = $True
        }

        ForEach($Domain in $Config["AcceptedDomains"]) 
        {

            # Get the MX record report for this domain

            $MXRecords = @($Config["MXReports"] | Where-Object {$_.Domain -eq $($Domain.DomainName)})

            # Construct config object

            $ConfigObject = [ORCACheckConfig]::new()

            $ConfigObject.Object=$($Domain.Name)

            If($MXRecords.PointsToService -Contains $False)
            {
                $PointsToService = $False
            }
            else
            {
                $PointsToService = $True
            }

            If($PointsToService)
            {

                $ConfigObject.ConfigItem="Yes"
                $ConfigObject.ConfigData="Not Required"
                $ConfigObject.SetResult([ORCAConfigLevel]::Standard,"Pass")

            }
            else
            {
                $ConfigObject.ConfigItem="No"

                If($EnhancedFiltering)
                {
                    $ConfigObject.ConfigData="Configured"
                    $ConfigObject.SetResult([ORCAConfigLevel]::Standard,"Pass")
                }
                else
                {
                    $ConfigObject.ConfigData="Not Configured"
                    $ConfigObject.SetResult([ORCAConfigLevel]::Informational,"Fail")
                    $ConfigObject.InfoText = "This domain is not pointed to EOP and all default inbound connectors are not configured for skip listing. Check the enhanced filtering segment for more information."
                }
            }

            $this.AddConfig($ConfigObject)

        }

    }

}