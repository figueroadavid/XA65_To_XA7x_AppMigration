Function Import-XA65Apps {
    <#
    .SYNOPSIS
        Imports an XML file containing the application data from a XenApp 6.5 farm and creates applications in a XenApp 7.x farm
    .DESCRIPTION
        It uses the XML file created by the Export-XA65AppData.ps1 script to create the applications.
        During the import process, it can import them to a specified Application Group, or a specified Desktop/Delivery group.
        If the XML file contains the IconData, it will import that icon for the application.
    .PARAMETER FilePath
        The path to the XML file
    .PARAMETER AdminAddress
        The name or IP address of the controller for the XenApp 7.x farm.
    .PARAMETER DeliveryGroup
        The delivery group to assign the applications to.  This parameter is mutually exclusive with the ApplicationGroup parameter.
    .PARAMETER ApplicationGroup
        The application group to assign the applications to. This parameter is mutually exclusive with the DeliveryGroup parameter.
    .EXAMPLE
        PS C:\> Import-XA65Apps -FilePath c:\temp\OfficeApps.xml -AdminAddress Server2 -ApplicationGroup 'Office Apps'

        This imports the XML file at c:\temp\OfficeApps.xml into the ApplicationGroup called 'Office Apps' using the DeliveryController Server2.
    .INPUTS
        [System.String]
    .OUTPUTS
        [none]
    .NOTES
        The XML file has to be the specified format.
        <?xml version="1.0" encoding="UTF-8"?>
        <apps zdc="servername" runtime="20190629_095333">
            <app>
                <BrowserName type="encodedstring"></BrowserName>
                <DisplayName type="encodedstring"></DisplayName>
                <Description type="encodedstring"></Description>
                <FolderPath type="encodedstring"></FolderPath>
                <CommandLineExecutable type="encodedstring"></CommandLineExecutable>
                <WorkingDirectory type="encodedstring"></WorkingDirectory>
                <ClientFolder type="encodedstring"></ClientFolder>
                <StartMenuFolder type="encodedstring"></StartMenuFolder>
                <ContentAddress type="encodedstring"></ContentAddress>
                <Enabled type="bool"></Enabled>
                <AddToClientStartMenu type="bool"></AddToClientStartMenu>
                <AddtoClientDesktop type="bool"></AddtoClientDesktop>
                <SslConnectionEnabled type="bool"></SslConnectionEnabled>
                <EncryptionRequired type="bool"></EncryptionRequired>
                <WaitOnPrinterCreation type="bool"></WaitOnPrinterCreation>
                <PreLaunch type="bool"></PreLaunch>
                <EncryptionLevel type="string"></EncryptionLevel>
                <ColorDepth type="string"></ColorDepth>
                <CPUPriorityLevel type="string"></CPUPriorityLevel>
                <ApplicationType type="string"></ApplicationType>
                <Account type="string"></Account>
                <EncodedIconData type="base64"></EncodedIconData>
            </app>
            <app>...</app>
        </apps>
    #>

    [cmdletbinding(DefaultParameterSetName = 'ByDG')]
    param(
        [parameter(Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'The path to the import file created by the Get-XA65AppExportData function')]
        [ValidateScript( { test-path -Path $_ })]
        [string]$FilePath,

        [parameter(Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'The server name to use for the app import')]
        [Alias('ComputerName')]
        [string]$AdminAddress,

        [parameter(Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'The Delivery Group to create the applications in', ParameterSetName = 'ByDG')]
        [Alias('DesktopGroup')]
        [string]$DeliveryGroup,

        [parameter(Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'The Application Group to create the application in', ParameterSetName = 'ByAG')]
        [string]$ApplicationGroup
    )

    Begin {
        $CRLF = [environment]::NewLine
        function ConvertFrom-EncodedText {
            param(
                [parameter(Mandatory)]
                [AllowNull()]
                [AllowEmptyString()]
                [string]$EncodedString
            )
            if ([string]::IsNullOrEmpty($EncodedString)) {
                'EMPTY_STRING'
            }
            else {
                [System.Web.HttpUtility]::HtmlDecode([System.Web.HttpUtility]::HtmlDecode($EncodedString))
            }
        }

        function ConvertTo-BoolValue {
            param(
                [parameter(Mandatory)]
                [AllowNull()]
                [AllowEmptyString()]
                [string]$IncomingValue
            )
            if ($IncomingValue -eq 'True') {
                $true
            }
            else {
                $false
            }
        }

        function Split-CmdLine {
            <#
              .SYNOPSIS
                Short function to parse a command line into 2 pieces; the executable part, and the arguments.

              .DESCRIPTION
                This function uses a regular expression to break up the command line into separate pieces, and then
                it creates a PSCustomObject with the executable part of the command line and the arguments

              .PARAMETER CmdLine
                This is the command line to be split.  It must be presented as a single string in order to be
                split correctly.  If the command contains quotes, the entire line must be surrounded with single quotes.

              .PARAMETER QuoteType
                This is the style of quote marks used internally in the cmdline string.

              .EXAMPLE
                PS C:\> Split-CmdLine -CmdLine 'iexplore https://www.google.com'

                CommandLineExecutable CommandLineArguments
                --------------------- --------------------
                iexplore              https://www.google.com

                This is a base split with a simple command line with no spaces, etc.

              .EXAMPLE
                PS C:\> Split-CmdLine -CmdLine '"C:\Program Files (x86)\Internet Explorer\iexplore.exe" https://www.google.com'

                CommandLineExecutable                                   CommandLineArguments
                ---------------------                                   --------------------
                "C:\Program Files (x86)\Internet Explorer\iexplore.exe"  https://www.google.com

                This is a slightly more complex split with spaces in the executable path

              .EXAMPLE
                PS C:\> $cmdline = '"c:\Program files (x86)\Internet Explorer\iexplore.exe" -k \\a //b https://www.google.com "testing testing"'

                PS C:\> Split-CmdLine -CmdLine $cmdline

                CommandLineExecutable                                   CommandLineArguments
                ---------------------                                   --------------------
                "c:\Program files (x86)\Internet Explorer\iexplore.exe"  -k \\a //b https://www.google.com "testing testing"

                This is a fictional command line that shows a wide variety of parameters being split, and they are handled correctly.

              .EXAMPLE
                PS C:\> $cmdline = '"c:\Program files (x86)\Internet Explorer\iexplore.exe" -k \\a //b https://www.google.com "testing testing"'

                PS C:\> Split-CmdLine -CmdLine $cmdline

                CommandLineExecutable                                   CommandLineArguments
                ---------------------                                   --------------------
                "c:\Program files (x86)\Internet Explorer\iexplore.exe"  -k \\a //b https://www.google.com "testing testing"
                                                                        ^
                Notice that the CommandLineArguments property starts with a space.  In order to eliminate this, the -Trim switch is provided.

                PS C:\> Split-CmdLine -CmdLine $cmdline -Trim

                CommandLineExecutable                                   CommandLineArguments
                ---------------------                                   --------------------
                "c:\Program files (x86)\Internet Explorer\iexplore.exe" -k \\a //b https://www.google.com "testing testing"
                                                                        ^

              .EXAMPLE
                PS C:\> Split-CmdLine -CmdLine $cmdline

                CommandLineExecutable CommandLineArguments
                --------------------- --------------------
                'c:\Program           files (x86)\Internet Explorer\iexplore.exe' -k \\a //b https://www.google.com 'testing testing'

                In this example, the quoting is reversed, and the cmdline has embedded single quotes while the entire string is surrounded by double quotes.
                To fix that, use the QuoteStyle parameter to switch the designated surrouding quotes to Single quotes


                PS C:\> C:\WINDOWS\system32> Split-CmdLine -CmdLine $cmdline -QuoteType Single

                CommandLineExecutable                                   CommandLineArguments
                ---------------------                                   --------------------
                'c:\Program files (x86)\Internet Explorer\iexplore.exe'  -k \\a //b https://www.google.com 'testing testing'

                With this change, the command string breaks up correctly.


              .INPUTS
                [System.String]

              .OUTPUTS
                [PSCustomObject]

              .NOTES
                The RegEx is the most important part and was designed by @Vexx32, @chrisdent and @seeminglyscience.
                All 3 of these guys are Powershell giants, and hang around the Powershell Slack channel
                Slack Invite Link:      https://aka.ms/psslack
                Discord Invite Link:    https://aka.ms/psdiscord

                @Vexx32
                https://github.com/vexx32
                I highly recommend @Vexx32's PSKoans - it is an excellent module for learning Powershell

                @seeminglyscience
                https://github.com/seeminglyscience

                @chrisdent
                https://github.com/indented-automation
                https://www.packtpub.com/authors/chris-dent

                The property mapping between XA65 & XA7x was done according to this article:
                https://docs.citrix.com/en-us/xenapp-and-xendesktop/7-15-ltsr/upgrade-migrate/xenapp-worker-upgrade.html

            #>

            [cmdletbinding()]
            param(
                [parameter(Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'The string to break apart into the executable piece, and the arguments piece')]
                [string]$CmdLine,

                [parameter(ValueFromPipelineByPropertyName)]
                [switch]$Trim,

                [parameter(ValueFromPipelineByPropertyName, HelpMessage = 'The quote style used inside the string.  The default is double quotes (")')]
                [ValidateSet('Single', 'Double')]
                [string]$QuoteType = 'Double'
            )

            switch ($QuoteType) {
                'Double' { $Pattern = '("[^"]+")| ' }
                'Single' { $Pattern = "('[^']+')| " }
            }


            $CmdArray = $CmdLine -split $Pattern, 2
            if ( [system.string]::IsNullOrEmpty($CmdArray[0]) ) {
                $Executable = $CmdArray[1]
                $ArgumentList = $CmdArray[2]
            }
            else {
                $Executable = $CmdArray[0]
                $ArgumentList = $CmdArray[1]
            }

            if ($Trim) {
                $ArgumentList = $ArgumentList.Trim()
            }

            [PSCustomObject]@{
                CommandLineExecutable = $Executable
                CommandLineArguments  = $ArgumentList
            }
        }

        try {
            Add-PSSnapin -Name Citrix.Broker.Admin.V2 -ErrorAction Stop
        }
        catch {
            Throw 'Unable to load the Citrix.Broker.Admin.V2 pssnapin that is required'
        }

        $xml = [xml]::new()
        $xml.Load( $FilePath )

        switch ($PSCmdlet.ParameterSetName) {
            'ByDG' {
                $ExistingDeliveryGroupList = Get-BrokerDesktopGroup -AdminAddress $AdminAddress | Select-Object -ExpandProperty Name

                if ($ExistingDeliveryGroupList -contains $DeliveryGroup) {
                    Write-verbose -Message ('{0} Delivery Group already exists, continuing' -f $DeliveryGroup)
                    $GroupName = $DeliveryGroup
                }
                else {
                    Throw ('DeliveryGroup [{0}] does not exist; exiting' -f $DeliveryGroup)
                }
                break
            }
            'ByAG' {
                $ExistingApplicationGroupList = Get-BrokerApplicationGroup -AdminAddress $AdminAddress | Select-Object -ExpandProperty Name
                if ($ExistingApplicationGroupList -contains $ApplicationGroup) {
                    Write-Verbose -Message ('{0} Application group already exists, continuing' -f $ApplicationGroup)
                    $GroupName = $ApplicationGroup
                }
                else {
                    throw ('ApplicationGroup [{0}] does not exist, exiting' -f $ApplicationGroup)
                }
            }
        }

        $AppNodes = $xml.SelectNodes('//app')
    }

    Process {
        $AppCount = $AppNodes.Count
        $CurrentAppCount = 0
        $ProgressBarProperties = @{
            Activity         = 'Importing Applications: ({0} of {1})' -f $CurrentAppCount, $AppCount
            CurrentOperation = 'Importing'
            PercentComplete  = [int][math]::Round($CurrentAppCount / $AppCount * 100, [System.MidpointRounding]::AwayFromZero)
            Status           = 'AppNameHere'
        }
        Write-Progress @ProgressBarProperties

        foreach ($AppNode in $AppNodes) {
            $CurrentAppCount++

            if ($AppNode.ApplicationType -eq 'ServerDesktop') {
                Write-Warning -Message ('This application ({0}) is a Published Desktop and is not handled by this script' -f $AppNode.Name)
                Continue
            }

            $BrowserName = ConvertFrom-EncodedText -EncodedString $AppNode.BrowserName.InnerText
            $ApplicationType = $AppNode.ApplicationType.InnerText
            if ($ApplicationType -eq 'ServerInstalled') { $ApplicationType = 'HostedOnDesktop' }

            $PropertyList = @{
                Name                     = $BrowserName
                AdminAddress             = $AdminAddress
                AdminFolder              = $GroupName
                UserFilterEnabled        = $true
                ApplicationType          = $ApplicationType
                BrowserName              = $BrowserName
                ShortCutAddedToStartMenu = ConvertTo-BoolValue -IncomingValue $AppNode.AddToClientStartMenu.InnerText
                ShortcutAddedToDesktop   = ConvertTo-BoolValue -IncomingValue $appNode.AddtoClientDesktop.InnerText
                WaitForPrinterCreation   = ConvertTo-BoolValue -IncomingValue $AppNode.WaitOnPrinterCreation.InnerText
            }

            $PublishedName = ConvertFrom-EncodedText -EncodedString $AppNode.DisplayName.InnerText
            if ($PublishedName -ne 'EMPTY_STRING') { $PropertyList.PublishedName = $PublishedName }
            $Description = ConvertFrom-EncodedText -EncodedString $AppNode.Description.InnerText
            if ($Description -ne 'EMPTY_STRING') { $PropertyList.Description = $Description }
            $ClientFolder = ConvertFrom-EncodedText -EncodedString $AppNode.ClientFolder.InnerText
            if ($ClientFolder -ne 'EMPTY_STRING') { $PropertyList.ClientFolder = $ClientFolder }
            $StartMenuFolder = ConvertFrom-EncodedText -EncodedString $AppNode.StartMenuFolder.InnerText
            if ($StartMenuFolder -ne 'EMPTY_STRING') { $PropertyList.StartMenuFolder = $StartMenuFolder }
            $WorkingDirectory = ConvertFrom-EncodedText -EncodedString $AppNode.WorkingDirectory.InnerText
            if ($WorkingDirectory -ne 'EMPTY_STRING') { $PropertyList.WorkingDirectory = $WorkingDirectory }

            if ($ApplicationType -eq 'PublishedContent') {
                $ContentAddress = ConvertFrom-EncodedText -EncodedString $AppNode.ContentAddress.InnerText
                $PropertyList.ContentAddress = $ContentAddress
                $PropertyList.CommandLineExecutable = $ContentAddress
            }
            else {
                $CLIObject = Split-CmdLine -CmdLine (ConvertFrom-EncodedText -EncodedString $AppNode.CommandLineExecutable.InnerText)
                $CommandLineExecutable = $CLIObject.CommandLineExecutable.Replace('"', '').Replace('<', '').Replace('>', '').Replace('|', '').Replace('*', '').Replace('?', '')
                $PropertyList.CommandLineExecutable = $CommandLineExecutable
                $PropertyList.CommandLineArguments = $CLIObject.CommandLineArguments
            }

            if ($PSCmdlet.ParameterSetName -eq 'byAG') { $PropertyList.ApplicationGroup = $ApplicationGroup }
            if ($PSCmdlet.ParameterSetName -eq 'byDG') { $PropertyList.DesktopGroup = $DeliveryGroup }

            if ($AppNode.SelectSingleNode('.//EncodedIconData')) {
                $ProgressBarProperties = @{
                    Activity         = 'Importing Applications: ({0} of {1})' -f $CurrentAppCount, $AppCount
                    CurrentOperation = 'Creating Icon'
                    PercentComplete  = [int][math]::Round($CurrentAppCount / $AppCount * 100, [System.MidpointRounding]::AwayFromZero)
                    Status           = $BrowserName
                }
                Write-Progress @ProgressBarProperties
                $EncodedIconData = $AppNode.EncodedIconData.InnerText.Replace($CRLF, '')
                $NewIcon = New-BrokerIcon -EncodedIconData $EncodedIconData -AdminAddress $AdminAddress
                $PropertyList.IconUID = $NewIcon.UID
            }

            Write-Verbose -Message ('PropertyList created:{0}{1}' -f $CRLF, ($PropertyList.GetEnumerator() | Out-String))
            Write-Verbose -Message 'Remove any blank parameters or EMPTY_STRING parameters'

            try {
                $NewApp = New-BrokerApplication @PropertyList -ErrorAction Stop
            }
            catch {
                Write-Warning -Message ('Unable to create application ({0}); Error is {1}' -f $BrowserName, $Error[0].Exception.Message)
            }
        }

        if ($NewApp) {
            $AccountsToAdd = $AppNode.SelectNodes('.//Account') | Select-Object -ExpandProperty InnerText
            foreach ($Account in $AccountsToAdd) {
                Try {
                    Add-BrokerUser -AdminAddress $AdminAddress -Name $Account -Application $NewApp -ErrorAction Stop
                    Write-Verbose -Message ('Adding user ({0}) to Application ({1})' -f $Account, $NewApp.BrowserName)
                }
                catch {
                    Write-Warning -Message ('Unable to add user ({0}) to Application ({1})' -f $Account, $NewApp.BrowserName)
                }
            }
        }

        $ProgressBarProperties = @{
            Activity         = 'Importing Applications: ({0} of {1})' -f $CurrentAppCount, $AppCount
            CurrentOperation = 'Creating Icon'
            PercentComplete  = [int][math]::Round($CurrentAppCount / $AppCount * 100, [System.MidpointRounding]::AwayFromZero)
            Status           = $BrowserName
            Completed        = $true
        }
        Write-Progress @ProgressBarProperties
    }

    End {
    }
}
