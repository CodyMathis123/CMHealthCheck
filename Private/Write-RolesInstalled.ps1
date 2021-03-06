function Write-RolesInstalled {
    param (
	    [string] $FileName,
	    [string] $TableName,
	    [string] $SiteCode,
	    [int] $NumberOfDays,
	    [string] $LogfFle,
		[string] $ServerName,
		[bool] $ContinueOnError = $true
    )
    Write-Log -Message "[function: write-rolesinstalled]" -LogFile $logfile
    $WMISMSListRoles = Get-CmWmiObject -Query "select distinct RoleName from SMS_SCI_SysResUse where NetworkOSPath = '\\\\$Servername'" -computerName $smsprovider -namespace "root\sms\site_$SiteCodeNamespace" -logfile $logfile
    $SMSListRoles = @()
    foreach ($WMIServer in $WMISMSListRoles) { $SMSListRoles += $WMIServer.RoleName }
    $DPProperties = Get-CmWmiObject -Query "select * from SMS_SCI_SysResUse where RoleName = 'SMS Distribution Point' and NetworkOSPath = '\\\\$Servername' and SiteCode = '$SiteCode'" -computerName $smsprovider -namespace "root\sms\site_$SiteCodeNamespace" -logfile $logfile
 	$Fields = @("SiteServer", "IIS", "SQLServer", "DP", "PXE", "MultiCast", "PreStaged", "MP", "FSP", "SSRS", "EP", "SUP", "AI", "AWS", "PWS", "SMP", "Console", "Client", "CPC", "DWP", "DMP")
	$RolesInstalledTable = New-CmDataTable -TableName $tableName -Fields $Fields
	$row = $RolesInstalledTable.NewRow()
	$row.SiteServer = ($SMSListRoles -contains 'SMS Site Server').ToString()
	$row.SQLServer  = ($SMSListRoles -contains 'SMS SQL Server').ToString()
	$row.DP = ($SMSListRoles -contains 'SMS Distribution Point').ToString()
	if ($DPProperties -eq $null) {
		$row.PXE = "False"
		$row.MultiCast = "False"
		$row.PreStaged = "False"
	}
	else {
		$row.PXE = (($DPProperties.Props | Where-Object {$_.PropertyName -eq "IsPXE"}).Value -eq 1).ToString()
		$row.MultiCast = (($DPProperties.Props | Where-Object {$_.PropertyName -eq "IsMulticast"}).Value -eq 1).ToString()
		$row.PreStaged = (($DPProperties.Props | Where-Object {$_.PropertyName -eq "PreStagingAllowed"}).Value -eq 1).ToString()
	}
	$row.MP      = ($SMSListRoles -contains 'SMS Management Point').ToString()
	$row.FSP     = ($SMSListRoles -contains 'SMS Fallback Status Point').ToString()
	$row.SSRS    = ($SMSListRoles -contains 'SMS SRS Reporting Point').ToString()
	$row.EP      = ($SMSListRoles -contains 'SMS Endpoint Protection Point').ToString()
	$row.SUP     = ($SMSListRoles -contains 'SMS Software Update Point').ToString()
	$row.AI      = ($SMSListRoles -contains 'AI Update Service Point').ToString()
	$row.AWS     = ($SMSListRoles -contains 'SMS Application Web Service').ToString()
	$row.PWS     = ($SMSListRoles -contains 'SMS Portal Web Site').ToString()
	$row.SMP     = ($SMSListRoles -contains 'SMS State Migration Point').ToString()
	$row.CPC     = ($SMSListRoles -contains 'SMS Cloud Proxy Connector').ToString()
	$row.DWP     = ($SMSListRoles -contains 'Data Warehouse Service Point').ToString()
	$row.DMP     = ($SMSListRoles -contains 'SMS Dmp Connector').ToString()
	$row.Console = (Test-RegistryExist -ComputerName $servername -Logfile $logfile -KeyName 'SOFTWARE\\Wow6432Node\\Microsoft\\ConfigMgr10\\AdminUI').ToString()
	$row.Client  = (Test-RegistryExist -ComputerName $servername -Logfile $logfile -KeyName 'SOFTWARE\\Microsoft\\CCM\\CCMExec').ToString()
	$row.IIS     = ((Get-RegistryValue -ComputerName $server -Logfile $logfile -KeyName 'SOFTWARE\\Microsoft\\InetStp' -KeyValue 'InstallPath') -ne $null).ToString()
    $RolesInstalledTable.Rows.Add($row)
    , $RolesInstalledTable | Export-Clixml -Path ($filename)
}