# App Migration from XA 6.5 to XA 7.x

This set of scripts is designed to migrate applications from XenApp 6.5 to XenApp 7.x.  It was built around XenApp 7.15, but it may work with previous versions.  The scripts assume that the account running these scripts has the necessary read permissions on the XA 6.5 farm, and the ability to create applications on the XA7x farm.

There are 3 scripts involved:

1. `Get-XA65AppsForImportByFolder.ps1` - this script is optional, and is designed to make the process easier to do in bulk.  It is a simple wrapper script to export the browser names of applications from a XenApp 6.5 farm folder.
2. `Export-XA65AppData.ps1` -  this script actually exports most of the application properties from one or more XenApp 6.5 applications.  The script creates an XML file of the data. Optionally, the icons for the applications can be exported also.
3. `Import-XA65Apps` - This script reads in the XML file created from #2 above, and imports it into XenApp 7.x.  It is designed to import the applications into a pre-existing Application Group or Desktop/Delivery Group.

---
## General Workflow
---

The general design of the 3 scripts is to create a collection of the application browsernames, and feed it into the _`Export-XA65AppData`_ script which will create the XML file. The _`Import-XA65Apps`_ script then reads in the XML file and creates the application based on that data.

```powershell
PS C:\> $Apps = Get-XA65AppsForImportByFolder -ComputerName Server1 -FolderPath 'Office Apps'
PS C:\> Export-XA65AppData -ComputerName Server1 -BrowserName $Apps -ExportPath C:\Temp\OfficeApps.xml -IncludeIconData
PS C:\> Import-XA65Apps -AdminAddress Server2 -FilePath C:\Temp\OfficeApps.xml -ApplicationGroup 'Office Apps'
```


---
## _Get-XA65AppsForImportByFolder_
---

### Notes:
The script simply outputs the list of application browser names from the folder.  The script expects the full path of the folder path to be provided, such as `Applications/Office Apps`, however, this is not required.  For simplicity, the script will automatically prepend `Applications/` to the provided path if it is not supplied.  The folder path's existence is verified before attempting to retrieve the applications.

### ScriptHelp
    .SYNOPSIS
        Wrapper script to retrieve the application browsernames to feed into the Export-XA65AppData.ps1 script
    .DESCRIPTION
        Simple wrapper script around the Get-XAApplication cmdlet to retrieve the browsernames for the applications
        based on the folderpath supplied.  By default, the script will prepend 'Applications' to the folder path if
        it is not supplied.
    .PARAMETER ComputerName
        The ZDC/XML server for establishing a connection
    .PARAMETER FolderPath
        The path of the folder that will be used to retrieve applications.  If the folderpath is missing the initial 'Applications/'
        portion of the Folderpath, it will be prepended.
    .EXAMPLE
        PS C:\> Export-XA65AppsForImportByFolder -ComputerName 'zdcserver01' -FolderPath 'Office Apps'
        Excel 2016
        Word 2016
        Powerpoint 2016
        Outlook 2016
        Access 2016
    .INPUTS
        [system.string]
    .OUTPUTS
        [system.string]
    .NOTES
        The script prepends 'Applications' to the folder path if it does not start with 'Applications' as a convenience measure.

---
## _Export-XA65AppData_
---

### Notes:
This is the first critical piece of the process.  This script retrieves both the Application object and the ApplicationReport object from the farm.  Many of the properties are stored into an XML file.  Any string type data that _could_ be risky for the XML file is run through the `[system.web.httputility]::htmlencode()` routine.  The properties were based off the documentation for Citrix' XA 6.5 to XA 7.x migration scripts and some investigation.

### ScriptHelp

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


---
## _Import-XA65Apps_
---

### Notes:
This script reads in the XML file generated by the previous script and creates new published applications in the XenApp 7.x farm.  As noted earlier, the script was designed around XenApp 7.15, but will likely work with most versions of XenApp 7.x.

### ScriptHelp

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
