$ScriptBlock = {
  Add-PSSnapin -Name Citrix.Broker.Admin.V2 -ErrorAction SilentlyContinue
  $BrokerApps = Get-BrokerApplication -MaxRecordCount 10000
  
  $CSVOutput = New-Object -TypeName System.Collections.arraylist
  
  foreach ($App in $BrokerApps)
  {
    $Properties = [ordered]@{
      Browsername = $App.BrowserName
      ExeName = $App.CommandLineExecutable
      Arguments = $App.CommandLineArguments 
      UserNames = $App.AssociateUserNames -join ';'
    }
    $CustomObject = New-Object -TypeName PSCustomObject -Property $Properties
    
    $null = $CSVOutput.Add( $CustomObject )
  }
  $CSVOutput | Export-Csv -Path ('C:\{0}_export.csv' -f $env:COMPUTERNAME) -NoTypeInformation
}

$DeliveryControllers = 'usodpwvcxxdc01', 'usodpwvxadc001', 'usoddwvcxxdc01'

foreach ($Controller in $DeliveryControllers)
{
  Invoke-Command -ComputerName $Controller -ScriptBlock $ScriptBlock -AsJob

}