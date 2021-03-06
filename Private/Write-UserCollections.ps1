function Write-UserCollections {
    param (
		[string] $FileName,
		[string] $TableName,
		[string] $SiteCode,
		[int] $NumberOfDays,
		[string] $LogFile,
		[string] $ServerName,
		[bool] $ContinueOnError = $true
    )
	Write-Log -Message "function... Write-UserCollections ****" -LogFile $logfile
    $query = "select Name, CollectionID, Comment, MemberCount from v_Collection where CollectionType = 1 order by Name"
    $colls = @(Invoke-DbaQuery -SqlInstance $ServerName -Database "CM_$SiteCode" -Query $query -ErrorAction SilentlyContinue)
    if ($null -eq $colls) { return }
	$Fields = @("Name","CollectionID","Comment","MemberCount")
	$collDetails = New-CmDataTable -TableName $tableName -Fields $Fields
	foreach ($coll in $colls) {
		$row = $collDetails.NewRow()
		$row.Name = $coll.Name
		$row.CollectionID = $coll.CollectionID
		$row.Comment = $coll.Comment
		$row.MemberCount = [int]($coll.MemberCount)
	    $collDetails.Rows.Add($row)
    }
    , $collDetails | Export-CliXml -Path ($filename)
}