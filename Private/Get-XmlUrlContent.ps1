function Get-XmlUrlContent {
    param (
        [parameter(Mandatory=$True, HelpMessage="Target URL")]
        [ValidateNotNullOrEmpty()]
        [string] $Url
	)
	Write-Log -Message "reading data from remote file: $Url" -Severity 1 -LogFile $logfile
    $content = ""
    try {
		[xml]$content = ((New-Object System.Net.WebClient).DownloadString($Url))
    }
    catch {}
    if ($content -ne "") {
        $lines = $content -split "`n"
        $result = ""
        for ($i = 1; $i -lt $lines.count; $i++) {
            $result += $lines[$i] + "`n"
        }
    }
    Write-Output $result
}