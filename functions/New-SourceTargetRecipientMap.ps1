﻿Function New-SourceTargetRecipientMap
{    
    [cmdletbinding(DefaultParameterSetName = 'LookupMap')]
    param
    (
        [parameter()]
        $SourceRecipients
        ,
        [parameter()]
        $ExchangeSystem
        ,
        [parameter()]
        [hashtable]$DomainReplacement = @{}
        ,
        [parameter(ParameterSetName = 'CustomMap')]
        [hashtable]$CustomMap
    )
    $SourceTargetRecipientMap = @{}
    $TargetSourceRecipientMap = @{}
    foreach ($sr in $SourceRecipients)
    {
        Connect-OneShellSystem -Identity $ExchangeSystem
        $ExchangeSession = Get-OneShellSystemPSSession -id $ExchangeSystem
        $ProxyAddressesToCheck = $sr.proxyaddresses | Where-Object -FilterScript {$_ -ilike 'smtp:*'} | ForEach-Object {$_.split(':')[1]}
        switch ($PSCmdlet.ParameterSetName)
        {
            'LookupMap'
            {
                $rawrecipientmatches =
                @(
                    foreach ($pa2c in $ProxyAddressesToCheck)
                    {
                        $domain = $pa2c.split('@')[1] 
                        if ($domain -in $DomainReplacement.Keys)
                        {
                            $pa2c = $pa2c.replace($domain,$($DomainReplacement.$domain))
                        }
                        if (Test-ExchangeProxyAddress -ProxyAddress $pa2c -ProxyAddressType SMTP -ExchangeSession $ExchangeSession)
                        {$null}
                        else
                        {
                            Test-ExchangeProxyAddress -ProxyAddress $pa2c -ProxyAddressType SMTP -ExchangeSession $ExchangeSession -ReturnConflicts
                        }
                    }
                )
            }
            'CustomMap'
            {
                $rawrecipientmatches =
                @(
                    foreach ($pa2c in $ProxyAddressesToCheck)
                    {
                        if ($CustomMap.ContainsKey($pa2c))
                        {
                            $LookupAddress = $CustomMap.$($pa2c).TargetIdentity
                            if (Test-ExchangeProxyAddress -ProxyAddress $LookupAddress -ProxyAddressType SMTP -ExchangeSession $ExchangeSession)
                            {$null}
                            else
                            {
                                Test-ExchangeProxyAddress -ProxyAddress $LookupAddress -ProxyAddressType SMTP -ExchangeSession $ExchangeSession -ReturnConflicts
                            }
                        }
                    }
                )
            }
        }
        $recipientmatches = @($rawrecipientmatches | Select-Object -Unique | Where-Object -FilterScript {$_ -ne $null})
        if ($recipientmatches.Count -eq 1)
        {
            $SourceTargetRecipientMap.$($sr.ObjectGUID.guid)=$recipientmatches
            $TargetSourceRecipientMap.$($recipientmatches[0])=$($sr.ObjectGUID.guid)
        }
        elseif ($recipientmatches.Count -eq 0) {
            $SourceTargetRecipientMap.$($sr.ObjectGUID.guid)=$null
        }
        else
        {
            $SourceTargetRecipientMap.$($sr.ObjectGUID.guid)=$recipientmatches
        }
    }#foreach
    $RecipientMap = @{
        SourceTargetRecipientMap = $SourceTargetRecipientMap
        TargetSourceRecipientMap = $TargetSourceRecipientMap
    }
    $RecipientMap
}
