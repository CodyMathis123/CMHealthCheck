#requires -version 3
function Export-CMHealthCheckHTML {
    <#
    .SYNOPSIS
        Convert extracted ConfigMgr site information to HTML report
    .DESCRIPTION
        Converts the data output from Get-CMHealthCheck to generate an HTML report file
    .PARAMETER ReportFolder
        Path to output data folder (e.g. ".\2018-9-19\cm01.contoso.com")
    .PARAMETER OutputFolder
        Path to write new report file (default = User Documents folder)
    .PARAMETER Detailed
        Collect more granular data for final reporting
    .PARAMETER CustomerName
        Name of customer (default = "Customer Name")
    .PARAMETER AuthorName
        Report Author name (default = "Your Name")
    .PARAMETER CopyrightName
        Text to use for copyright footer string (default = "Your Company Name")
    .PARAMETER Theme
        CSS style theme name, or 'Custom' to specify a file (default = 'Ocean')
    .PARAMETER CssFilename
        CSS file path to import when Theme is set to 'Custom'
    .PARAMETER DynamicTableRows
        Apply mouse-over dynamic table row effects
    .PARAMETER Overwrite
        Overwrite existing report file if found
    .PARAMETER Healthcheckfilename
        Healthcheck configuration XML file name (default = ".\assets\cmhealthcheck.xml")
        The file can be local, UNC or URI sourced as well
    .PARAMETER MessagesFilename
        Status and error message lookup table (default = ".\assets\messages.xml")
        The file can be local, UNC or URI sourced as well
    .PARAMETER Healthcheckdebug
        Enable verbose output (or use -Verbose)
    .PARAMETER ReviewTables
        Show review tables for adding comments after each section
    .EXAMPLE
        Export-CMHealthCheckHTML -ReportFolder "2018-9-19\cm01.contoso.com" -Detailed -CustomerName "Contoso" -AuthorName "David Stein"
    .EXAMPLE
        Export-CMHealthCheckHTML -ReportFolder "2018-9-19\cm01.contoso.com" -Detailed -CustomerName "Contoso" -AuthorName "David Stein" -CopyrightName "ACME Consulting" -Overwrite -Verbose
    .EXAMPLE
        Export-CMHealthCheckHTML -ReportFolder "2018-9-19\cm01.contoso.com" -OutputFolder "c:\reports" -Detailed -CustomerName "Contoso" -AuthorName "David Stein" -CopyrightName "ACME Consulting" -Theme 'Ocean' -DynamicTableRows -Verbose
    .NOTES
        * 1.0.4 - 12/04/2017 - David Stein
        * 1.0.5 - 09/22/2018 - David Stein
        * Thanks to Rafael Perez for inventing this - http://www.rflsystems.co.uk
        * Thanks to Carl Webster for the basis of Word functions - http://www.carlwebster.com
        * Thanks to David O'Brien for additional Word function - http://www.david-obrien.net/2013/06/20/huge-powershell-inventory-script-for-configmgr-2012/
        * Thanks to Starbucks for empowering me to survive hours of clicking through the Office Word API reference
    #>
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $True, HelpMessage = "Collected data folder")] 
            [ValidateNotNullOrEmpty()]
            [string] $ReportFolder,
        [parameter(Mandatory=$False, HelpMessage="Log folder path")]
            [ValidateNotNullOrEmpty()]
            [string] $OutputFolder = "$($env:USERPROFILE)\Documents",
        [Parameter (Mandatory = $False, HelpMessage = "Export full data, not only summary")] 
            [switch] $Detailed,
        [parameter (Mandatory = $False, HelpMessage = "Customer company name")] 
            [string] $CustomerName = "Customer Name",
        [parameter (Mandatory = $False, HelpMessage = "Author's full name")] 
            [string] $AuthorName = "Your Name",
        [parameter (Mandatory = $False, HelpMessage = "Footer text")]
            [string] $CopyrightName  = "Skatterbrainz",
        [Parameter (Mandatory = $False, HelpMessage = "HealthCheck query file name")] 
            [string] $Healthcheckfilename = "", 
        [Parameter (Mandatory = $False, HelpMessage = "HealthCheck messages file name")]
            [string] $MessagesFilename = "", 
        [Parameter (Mandatory = $False, HelpMessage = "Debug more?")] 
            $Healthcheckdebug = $False,
        [parameter (Mandatory = $False, HelpMessage = "Theme Name")]
            [ValidateSet('Ocean','Emerald','Monochrome','Custom')]
            [string] $Theme = 'Ocean',
        [parameter (Mandatory = $False, HelpMessage = "CSS template file")]
            [string] $CssFilename = "",
        [parameter (Mandatory = $False, HelpMessage = "Table Row Style option")]
            [ValidateSet('Solid','Alternating','Dynamic')]
            [string] $TableRowStyle = 'Solid',
        [parameter (Mandatory = $False, HelpMessage = "Image Log file")]
            [string] $ImageFile = "",
        [parameter (Mandatory = $False, HelpMessage = "Overwrite existing report file")]
            [switch] $Overwrite
    )
    $time1      = Get-Date -Format "hh:mm:ss"
    $ModuleData = Get-Module CMHealthCheck
    $ModuleVer  = $ModuleData.Version -join '.'
    $ModulePath = $ModuleData.Path -replace 'CMHealthCheck.psm1', ''
    $tsLog      = Join-Path -Path $OutputFolder -ChildPath "Export-CMHealthCheckHTML-Transcript.log"
    $logfile    = Join-Path -Path $OutputFolder -ChildPath "Export-CMHealthCheckHTML.log"
    try {
        Stop-Transcript -ErrorAction SilentlyContinue
    }
    catch {}
    finally {
        Start-Transcript -Path $tsLog -Append -ErrorAction SilentlyContinue
    }
    $Script:TableRowStyle = $TableRowStyle
    $TempFilename      = "cmhealthreport.htm"
    $bLogValidation    = $False
    $bAutoProps        = $True
    $poshversion       = $PSVersionTable.PSVersion.Major
    $osversion         = (Get-WmiObject -Class Win32_OperatingSystem).Caption
    
    if ($Healthcheckfilename -eq "") {
        $Healthcheckfilename = Join-Path -Path $ModulePath -ChildPath "assets\cmhealthcheck.xml"
    }
    Write-Verbose "using healthcheck file: $HealthcheckFilename"

	if ($MessagesFilename -eq "") {
        $MessagesFilename = Join-Path -Path $ModulePath -ChildPath "assets\messages.xml"
    }
    if ($ImageFile -eq "") {
        $ImageFile = Join-Path -Path $ModulePath -ChildPath "assets\cmhclogo-275x237.png"
    }
    Write-Verbose "using messages file: $MessagesFilename"

    if ($Theme -eq 'Custom') {
        if ($CssFilename -eq "") {
            Write-Warning "No stylesheet was specified for [custom] option. Using default.css"
            $CssFilename = Join-Path -Path $ModulePath -ChildPath "assets\default.css"
        }
        else {
            if (!(Test-Path $CssFilename)) {
                Write-Warning "$CssFilename was not found!"
                break
            }
        }
    }
    else {
        $CssFilename = Join-Path -Path $ModulePath -ChildPath "assets\$Theme.css"
        if (!(Test-Path $CssFilename)) {
            Write-Warning "$CssFilename was not found!"
            break
        }
    }
    Write-Log -Message "importing css template: $CssFilename" -LogFile $logfile
    $css = Get-Content $CssFilename

    if ($healthcheckdebug -eq $true) { 
        $PSDefaultParameterValues = @{"*:Verbose"=$True}
    }

    $logFolder = Join-Path -Path $PWD.Path -ChildPath "_Logs\"
    $reportFile = Join-Path -Path $OutputFolder -ChildPath $TempFilename
    if (-not (Test-Path $logFolder)) {
        Write-Verbose "creating log folder: $logFolder"
        mkdir $logFolder -Force | Out-Null
    }
    else {
        Write-Verbose "log folder already exists: $logFolder"
    }
    if ($reportFolder.Substring($reportFolder.length-1) -ne '\') { $reportFolder+= '\' }
    
    $Error.Clear()

    $poshversion = $PSVersionTable.PSVersion.Major
    Show-CMHCInfo
    
    [xml]$HealthCheckXML = Get-CmHealthCheckFile -XmlSource $HealthcheckFilename
    [xml]$MessagesXML    = Get-CmHealthCheckFile -XmlSource $MessagesFilename
     
    if ($HealthCheckXML -and $MessagesXML) {
        $bLogValidation = $true
        Write-Log -Message "----- Provisioning config table -----" -LogFile $logfile
        $ConfigTable = New-Object System.Data.DataTable 'ConfigTable'
        $ConfigTable = Get-CmXMLFile -Path $reportFolder -FileName "config.xml"
        if ($ConfigTable -eq "") {
            Invoke-Error -Message "File $configfile does not exist, no futher action taken"; break
        }
        Write-Log -Message "Provisioning report table" -LogFile $logfile
        $ReportTable = New-Object System.Data.DataTable 'ReportTable'
        $ReportTable = Get-CmXMLFile -Path $reportFolder -FileName "report.xml"
        if ($ReportTable -eq "") {
            Invoke-Error -Message "File $repfile does not exist, no futher action taken"; break
        }
        Write-Log -Message "Assigning number of days from config data..." -LogFile $logfile
        if ($poshversion -eq 3) { 
            $NumberOfDays = $ConfigTable.Rows[0].NumberOfDays
        }
        else { 
            $NumberOfDays = $ConfigTable.NumberOfDays
        }

        if (!(Test-Powershell64bit)) { Invoke-Error -Message "Powershell is not 64bit, no futher action taken"; break }
        
        Write-Log -Message "initializing HTML content" -LogFile $logfile
        $htmlContent = @"
<html>
    <head>
        <title="CMHealthCheck Report">
        <style type="text/css">
        $css
        </style>
        <meta content="text/html; charset=UTF-8" http-equiv="Content-Type" />
    </head>
    <body>
"@

        Write-Log -Message "inserting title caption" -LogFile $logfile
        $htmlContent += "<table class=`"reportTable`" style=`"border-color:#fff`"><tr><td style=`"width:120px`">"
        $htmlContent += "<img src=`"$ImageFile`" alt=`"$ImageFile`" width=`100`" border=`"0`" />"
        $htmlContent += "</td><td style=`"vertical-align:top`"><h1>CMHealthCheck Report</h1>"
        $htmlContent += "<p>(Install-Module CMHealthCheck) Version: $ModuleVer</p>"
        $htmlContent += "</td></tr></table>"

        $htmlTable = [ordered]@{
            Customer       = $CustomerName
            Author         = "$AuthorName ($($env:USERNAME))"
            ReportDate     = (Get-Date).ToLongDateString()
            ReportFolder   = $ReportFolder
            WindowsVersion = $(Get-WmiObject -Class Win32_OperatingSystem).Caption
            ComputerName   = $($env:COMPUTERNAME)
        }
        $htmlContent += New-HtmlTableVertical -Caption "Report Information" -TableHash $htmlTable
        
        Write-Log -Message "--- inserting abstract content block" -LogFile $logfile

        $htmlContent += "<table class=`"reportTable`"><tr><td>"
        $htmlContent += "This document provides a point-in-time report of the current state of the System Center Configuration Manager site environment for $CustomerName. "
        $htmlContent += "For questions, concerns or comments, please consult the author of this assessment report. "
        $htmlContent += "This report was generated using CMHealthCheck $ModuleVer on $(Get-Date). Thanks to Raphael Perez and David O'Brien for "
        $htmlContent += "their work which laid the foundation on which this code was developed."
        $htmlContent += "</td></tr></table>"

        Write-Log -Message "--- entering section reports" -LogFile $logfile

        $htmlContent += Write-HtmlReportSection -HealthCheckXML $HealthCheckXML -Section '1' -LogFile $logfile
        $htmlContent += Write-HtmlReportSection -HealthCheckXML $HealthCheckXML -Section '2' -LogFile $logfile
        $htmlContent += Write-HtmlReportSection -HealthCheckXML $HealthCheckXML -Section '3' -LogFile $logfile
        $htmlContent += Write-HtmlReportSection -HealthCheckXML $HealthCheckXML -Section '4' -LogFile $logfile
        if ($Detailed) {
            $htmlContent += Write-HtmlReportSection -HealthCheckXML $HealthCheckXML -Section '5' -LogFile $logfile
        }
        $htmlContent += Write-HtmlReportSection -HealthCheckXML $HealthCheckXML -Section '6' -LogFile $logfile

        #Set-DocAppendix

        Write-Log -Message "inserting copyright footer" -LogFile $logfile
        $htmlContent += "<p class=`"footer`">CMHealthCheck $ModuleVer . Copyright &copy; $((Get-Date).Year) $CopyrightName</p>"
        $htmlContent += "</body></html>"

        Write-Log -Message "writing output file: $ReportFile" -LogFile $logfile
        $htmlContent | Out-File -FilePath $ReportFile -Force
    }
    else {
        Write-Log -Message "Unable to load Healthcheck or Messages XML data" -Severity 3 -LogFile $logfile -ShowMsg
        $error.Clear()
    }

    $Difference = Get-TimeOffset -StartTime $time1
    Write-Log -Message "Completed in: $Difference (hh:mm:ss)" -LogFile $logfile -ShowMsg
    Stop-Transcript
}
Export-ModuleMember -Function Export-CMHealthcheckHTML