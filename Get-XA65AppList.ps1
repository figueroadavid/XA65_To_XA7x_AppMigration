$ScriptBlock = {
  Add-PSSnapin -Name Citrix.XenApp.commands -ErrorAction SilentlyContinue
  
  $FarmName = Get-XAFarm | Select-Object -ExpandProperty FarmName
  $CSVOutput = New-Object -TypeName system.collections.arraylist
    
  $AppReport = Get-XAApplicationReport -BrowserName * 
  foreach ($Report in $AppReport)
  {
    $Properties = @{
      BrowserName = $Report.BrowserName
      CommandLine = $Report.CommandLineExecutable
      UserNames = ($Report.Accounts | Select-Object ) -join ';'
    }
    $AppObject = New-Object -TypeName PSObject -Property $Properties
    $null = $CSVOutput.Add( $AppObject )
  }
  
  $CSVOutput| Select-Object -Property BrowserName,CommandLine,UserNames | Export-CSV -Path ('C:\{0}_Export.csv' -f $FarmName) -NoTypeInformation -Force
  }


'usodpwvxa704','usodpwvxax005','usodpwvxax010','txlwpwvxa100','txaupwvxa100' | ForEach-Object {
  Invoke-Command -ComputerName $_ -ScriptBlock $ScriptBlock -AsJob
}

$zdclist = 'usodpwvxa704','usodpwvxax005','usodpwvxax010','txlwpwvxa100','txaupwvxa100'