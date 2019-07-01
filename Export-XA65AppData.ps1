Function Export-XA65AppData {
    <#
    .SYNOPSIS
        Retrieves Application Data for XenApp 6.x applications and exports it an XML file
    .DESCRIPTION
        The script retrieves the Application and ApplicationReports of the supplied application BrowserName(s) and
        creates an XML document containing the data.
        The string information is converted to be XML safe, and the icon for the application is optionally included.
    .EXAMPLE
        PS C:\> Export-XA65AppData -ComputerName myzdc01.domain.tld -BrowserName Notepad -ExportPath c:\NotepadExport.xml

        This creates an XML file export of the published copy of Notepad
    .INPUTS
        [system.string]
    .OUTPUTS
        none
    .NOTES
        This is designed to create an export file of the application data.  That export file can
        then be imported with the Import-XA65Apps script.

        The format of the XML file is (it does support multiple apps in a single file):
        <?xml version="1.0" encoding="UTF-8"?>
        <apps zdc="<computername>" runtime="<timestamp of the export">
            <app>
                <BrowserName></BrowserName>
                <DisplayName></DisplayName>
                <Description></Description>
                <FolderPath></FolderPath>
                <CommandLineExecutable></CommandLineExecutable>
                <WorkingDirectory></WorkingDirectory>
                <ClientFolder></ClientFolder>
                <StartMenuFolder></StartMenuFolder>
                <ContentAddress></ContentAddress>
                <Enabled></Enabled>
                <AddToClientStartMenu></AddToClientStartMenu>
                <AddtoClientDesktop></AddtoClientDesktop>
                <SslConnectionEnabled></SslConnectionEnabled>
                <EncryptionRequired></EncryptionRequired>
                <WaitOnPrinterCreation></WaitOnPrinterCreation>
                <PreLaunch></PreLaunch>
                <EncryptionLevel></EncryptionLevel>
                <ColorDepth></ColorDepth>
                <CPUPriorityLevel></CPUPriorityLevel>
                <ApplicationType></ApplicationType>
                <Account></Account>
                <Account></Account>
                <Account></Account>
                <EncodedIconData></EncodedIconData>
            </app>
        </apps>

        All of the string data is encoded for XML safety.
    .PARAMETER ComputerName
        The name of the XML server for the XenApp 6.5 farm
    .PARAMETER BrowserName
        The browsername(s) of the app(s) to export.  Each application is exported to the XML file and
        each export file can contain multiple application exports.
    .PARAMETER ExportPath
        The file path to export the data.  If the file exists, the script will overwrite the file automatically.
    .PARAMETER IncludeIconData
        This switch tells the script to automatically include the EncodedIconData from the applications.
    #>

    [cmdletbinding()]
    param(
        [parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateScript( { Test-Connection -ComputerName $_ })]
        [string]$ComputerName = $env:COMPUTERNAME,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$BrowserName,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Exportpath,

        [parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$IncludeIconData
    )

    Begin {
        Add-PSSnapin -Name Citrix.XenApp.Commands -ErrorAction SilentlyContinue

        $XMLWriterSettings = New-Object -typename System.Xml.XmlWriterSettings
        $XMLWriterSettings.Indent = $true
        $XMLWriterSettings.IndentChars = "`t"
        $XMLWriterSettings.Encoding = [system.text.Encoding]::UTF8

        $XMLStringBuilder = New-Object -Type System.Text.StringBuilder
        $XMLWriter = [System.Xml.XmlWriter]::Create($XMLStringBuilder, $XMLWriterSettings)
        $xmlwriter.WriteStartDocument()
        $XMLWriter.WriteStartElement('apps')
        $XMLWriter.WriteAttributeString('zdc', $ComputerName)
        $XMLWriter.WriteAttributeString('runtime', [datetime]::Now.ToString('yyyyMMdd_hhmmss'))
    }

    Process {
        $TotalAppCount = $BrowserName.Count 
        $CurrentAppCount = 0

        $ProgressBarProperties = @{
            Activity         = 'Export Applications: ({0} of {1})' -f $CurrentAppCount, $TotalAppCount
            CurrentOperation = 'Exporting..'
            PercentComplete  = [int][math]::Round($CurrentAppCount / $TotalAppCount * 100, [System.MidpointRounding]::AwayFromZero)
            Status           = 'Starting..'
        }
        Write-Progress @ProgressBarProperties

        foreach ($app in $BrowserName) {

            $CurrentAppCount++
            $ProgressBarProperties = @{
                Activity         = 'Export Applications: ({0} of {1})' -f $CurrentAppCount, $TotalAppCount
                CurrentOperation = 'Exporting: {0}' -f $app
                PercentComplete  = [int][math]::Round($CurrentAppCount / $TotalAppCount * 100, [System.MidpointRounding]::AwayFromZero)
                Status           = 'App Properties'
            }
            Write-Progress @ProgressBarProperties

            try {
                $AppObject = Get-XAApplication -ComputerName $ComputerName -BrowserName $App -ErrorAction Stop
                Write-Verbose -Message ('Retrieved application: {0}' -f $app)
            }
            catch {
                Write-Warning -Message ('Unable to retrieve Application Object [{0}]' -f $app)
                continue
            }

            try {
                $AppObjectReport = Get-XAApplicationReport -ComputerName $ComputerName -BrowserName $BrowserName -ErrorAction Stop
                Write-Verbose -Message ('Retrieved ApplicationReport for {0}' -f $app)
            }
            catch {
                Write-Warning -Message ('Unable to retrieve Application Report for {0}' -f $app)
                continue
            }

            $XMLWriter.WriteStartElement('app')
                $XMLWriter.WriteStartElement('BrowserName')
                    $XMLWriter.WriteAttributeString('type','encodedstring')
                    $XMLWriter.WriteString([System.Web.HttpUtility]::HtmlEncode($AppObject.BrowserName))
                $XMLWriter.WriteEndElement()
                
                $XMLWriter.WriteStartElement('DisplayName')
                    $XMLWriter.WriteAttributeString('type','encodedstring')
                    $XMLWriter.WriteString([System.Web.HttpUtility]::HtmlEncode($AppObject.DisplayName))
                $XMLWriter.WriteEndElement()
                
                $XMLWriter.WriteStartElement('Description')
                    $XMLWriter.WriteAttributeString('type','encodedstring')
                    $XMLWriter.WriteString([System.Web.HttpUtility]::HtmlEncode($AppObject.Description))
                $XMLWriter.WriteEndElement()
                
                $XMLWriter.WriteStartElement('FolderPath')
                    $XMLWriter.WriteAttributeString('type','encodedstring')
                    $XMLWriter.WriteString([System.Web.HttpUtility]::HtmlEncode($AppObject.FolderPath))
                $XMLWriter.WriteEndElement()
                
                $XMLWriter.WriteStartElement('CommandLineExecutable')
                    $XMLWriter.WriteAttributeString('type','encodedstring')
                    $XMLWriter.WriteString([System.Web.HttpUtility]::HtmlEncode($AppObject.CommandLineExecutable))
                $XMLWriter.WriteEndElement()
                
                $XMLWriter.WriteStartElement('WorkingDirectory')
                    $XMLWriter.WriteAttributeString('type','encodedstring')
                    $XMLWriter.WriteString([System.Web.HttpUtility]::HtmlEncode($AppObject.WorkingDirectory))
                $XMLWriter.WriteEndElement()
                
                $XMLWriter.WriteStartElement('ClientFolder')
                    $XMLWriter.WriteAttributeString('type','encodedstring')
                    $XMLWriter.WriteString([System.Web.HttpUtility]::HtmlEncode($AppObject.ClientFolder))
                $XMLWriter.WriteEndElement()
                
                $XMLWriter.WriteStartElement('StartMenuFolder')
                    $XMLWriter.WriteAttributeString('type','encodedstring')
                    $XMLWriter.WriteString([System.Web.HttpUtility]::HtmlEncode($AppObject.StartMenuFolder))
                $XMLWriter.WriteEndElement()
                
                $XMLWriter.WriteStartElement('ContentAddress')
                    $XMLWriter.WriteAttributeString('type','encodedstring')
                    $XMLWriter.WriteString([System.Web.HttpUtility]::HtmlEncode($AppObject.ContentAddress))
                $XMLWriter.WriteEndElement()
        
                $XMLWriter.WriteStartElement('Enabled')
                    $XMLWriter.WriteAttributeString('type','bool')
                    $XMLWriter.WriteString($AppObject.Enabled)
                $XMLWriter.WriteEndElement()

                $XMLWriter.WriteStartElement('AddToClientStartMenu')
                    $XMLWriter.WriteAttributeString('type','bool')
                    $XMLWriter.WriteString($AppObject.AddToClientStartMenu)
                $XMLWriter.WriteEndElement()

                $XMLWriter.WriteStartElement('AddtoClientDesktop')
                    $XMLWriter.WriteAttributeString('type','bool')
                    $XMLWriter.WriteString($AppObject.AddtoClientDesktop)
                $XMLWriter.WriteEndElement()

                $XMLWriter.WriteStartElement('SslConnectionEnabled')
                    $XMLWriter.WriteAttributeString('type','bool')
                    $XMLWriter.WriteString($AppObject.SslConnectionEnabled)
                $XMLWriter.WriteEndElement()

                $XMLWriter.WriteStartElement('EncryptionRequired')
                    $XMLWriter.WriteAttributeString('type','bool')
                    $XMLWriter.WriteString($AppObject.EncryptionRequired)
                $XMLWriter.WriteEndElement()

                $XMLWriter.WriteStartElement('WaitOnPrinterCreation')
                    $XMLWriter.WriteAttributeString('type','bool')
                    $XMLWriter.WriteString($AppObject.WaitOnPrinterCreation)
                $XMLWriter.WriteEndElement()

                $XMLWriter.WriteStartElement('PreLaunch')
                    $XMLWriter.WriteAttributeString('type','bool')
                    $XMLWriter.WriteString($AppObject.PreLaunch)
                $XMLWriter.WriteEndElement()

                $XMLWriter.WriteStartElement('EncryptionLevel')
                    $XMLWriter.WriteAttributeString('type','string')
                    $XMLWriter.WriteString($AppObject.EncryptionLevel)
                $XMLWriter.WriteEndElement()

                $XMLWriter.WriteStartElement('ColorDepth')
                    $XMLWriter.WriteAttributeString('type','string')
                    $XMLWriter.WriteString($AppObject.ColorDepth)
                $XMLWriter.WriteEndElement()

                $XMLWriter.WriteStartElement('CPUPriorityLevel')
                    $XMLWriter.WriteAttributeString('type','string')
                    $XMLWriter.WriteString($AppObject.CPUPriorityLevel)
                $XMLWriter.WriteEndElement()

                $XMLWriter.WriteStartElement('ApplicationType')
                    $XMLWriter.WriteAttributeString('type','string')
                    $XMLWriter.WriteString($AppObject.ApplicationType)
                $XMLWriter.WriteEndElement()

                $AppObjectReport.Accounts | ForEach-Object {
                    $XMLWriter.WriteStartElement('Account')
                        $XMLWriter.WriteAttributeString('type', 'account')
                            $XMLWriter.WriteString($_.AccountDisplayName)
                        $XMLWriter.WriteEndElement()
                }

                Write-Verbose -Message ('App properties for ({0}) stored, not including Icon Data' -f $app)

                if ($IncludeIconData) {

                    $ProgressBarProperties = @{
                        Activity         = 'Export Applications: ({0} of {1})' -f $CurrentAppCount, $TotalAppCount
                        CurrentOperation = 'Exporting: {0}' -f $app
                        PercentComplete  = [int][math]::Round($CurrentAppCount / $TotalAppCount * 100, [System.MidpointRounding]::AwayFromZero)
                        Status           = 'Icon data'
                    }
                    Write-Progress @ProgressBarProperties

                    $EncodedIconData = Get-XAApplicationIcon -ComputerName $ComputerName -BrowserName $app | Select-Object -ExpandProperty EncodedIconData
                    $XMLWriter.WriteStartElement('EncodedIconData')
                        $XMLWriter.WriteAttributeString('type', 'base64')
                    $XMLWriter.WriteString(
                        ($EncodedIconData  -replace '.{64}', "$&`r`n")
                    )
                    $XMLWriter.WriteEndElement()
                    Write-Verbose -Message ('Icon Data for ({0}) stored' -f $app)
                }
            $XMLWriter.WriteEndElement()
        }

        $ProgressBarProperties = @{
            Activity         = 'Export Applications: ({0} of {1})' -f $CurrentAppCount, $TotalAppCount
            CurrentOperation = 'Exporting: {0}' -f $app
            PercentComplete  = [int][math]::Round($CurrentAppCount / $TotalAppCount * 100, [System.MidpointRounding]::AwayFromZero)
            Status           = 'App Properties'
        }
        Write-Progress @ProgressBarProperties -Completed
    }


    End {
        $XMLWriter.WriteEndElement()
        $xmlwriter.WriteEndDocument()
        $xmlwriter.Flush()

        ($XMLStringBuilder.ToString()) -replace 'UTF-16', 'UTF-8' | Out-File -FilePath $Exportpath -Encoding utf8 -Force

        $xmlwriter.Close()
        $xmlwriter.Dispose()
        Write-Verbose -Message ('Export complete: File located at {0}' -f $Exportpath)
    }

}
