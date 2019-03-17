param(
    [string]$userName,
    [string]$userPass
)
#region Grant logon as a service rights
$computerName = 'localhost'
Invoke-Command -ComputerName $computerName -Script {
    param([string] $userName)
    $tempPath = [System.IO.Path]::GetTempPath()
    $import = Join-Path -Path $tempPath -ChildPath "import.inf"
    if (Test-Path $import) { Remove-Item -Path $import -Force }
    $export = Join-Path -Path $tempPath -ChildPath "export.inf"
    if (Test-Path $export) { Remove-Item -Path $export -Force }
    $secedt = Join-Path -Path $tempPath -ChildPath "secedt.sdb"
    if (Test-Path $secedt) { Remove-Item -Path $secedt -Force }
    try {
        Write-Output ("Granting SeServiceLogonRight to user account: {0} on host: {1}." -f $userName, $computerName)
        $sid = ((New-Object System.Security.Principal.NTAccount($userName)).Translate([System.Security.Principal.SecurityIdentifier])).Value
        secedit /export /cfg $export
        $sids = (Select-String $export -Pattern "SeServiceLogonRight").Line
        foreach ($line in @("[Unicode]", "Unicode=yes", "[System Access]", "[Event Audit]", "[Registry Values]", "[Version]", "signature=`"`$CHICAGO$`"", "Revision=1", "[Profile Description]", "Description=GrantLogOnAsAService security template", "[Privilege Rights]", "$sids,*$sid")) {
            Add-Content $import $line
        }
        secedit /import /db $secedt /cfg $import
        secedit /configure /db $secedt
        gpupdate /force
        Remove-Item -Path $import -Force
        Remove-Item -Path $export -Force
        Remove-Item -Path $secedt -Force
    }
    catch {
        Write-Output ("Failed to grant SeServiceLogonRight to user account: {0} on host: {1}." -f $userName, $computerName)
        $error[0]
    }
} -ArgumentList $userName
#endregion

#region Set vRA software bootstrap agent logon using domain account
$serviceName = 'vRASoftwareAgentBootstrap'
$filter = 'Name=' + "'" + $serviceName + "'" + ''
$service = Get-WMIObject -ComputerName $computerName -namespace "root\cimv2" -class Win32_Service -Filter $filter
Write-Output "Changing service $serviceName to run as account $userName."
$service.Change($null, $null, $null, $null, $null, $null, $userName, $userPass)
#endregion

#region Restart service
Write-Output "Restarting service $serviceName."
Restart-Service -Name $serviceName
####Force if needed
Start-Sleep -s 5
$serviceState = Get-WMIObject -class Win32_Service | Where-Object Name -eq $serviceName | Select-Object State
if ($serviceState.State -ne 'Running'){
  Write-Output "Service not restarted. Forcing kill"
  $ServicePID = (Get-WMIObject -class Win32_Service | Where-Object Name -eq $serviceName).processID
  Stop-Process $ServicePID -Force
  Start-Service -Name $serviceName
  }
#endregion