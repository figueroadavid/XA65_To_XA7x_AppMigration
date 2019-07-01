Function Get-XA65AppsForImportByFolder
{
    <#
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
        
    #>

    [cmdletbinding()]
    param(
        [parameter(Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'The ZDC/XML server to connect to in order to retrieve applications')]
        [string]$ComputerName,

        [parameter(Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'The name of the folder housing applications to retrieve')]
        [string]$FolderPath
    )

    if($FolderPath.Split('/')[0] -ne 'Applications')
    {
        $FolderPath = 'Applications', $FolderPath -join '/' 
    }

    $AllFolderPaths = Get-XAFolder -ComputerName $ComputerName -FolderPath 'Applications' -Recurse | Select-Object -ExpandProperty FolderPath 

    if ($AllFolderPaths -contains $FolderPath)
    {
        Get-XAApplication -ComputerName $ComputerName -FolderPath $FolderPath | Select-Object -ExpandProperty BrowserName
    }
    else {
        Throw ('FolderPath ({0}) does not contain any applications' -f $FolderPath)       
    }
}