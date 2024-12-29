<#
.SYNOPSIS
    Assign a user account read permissions on a service object.
.DESCRIPTION
    The Set-RemoteServicePermissions cmdlet will assign a non-admin account the permissions required to read the status of a service object remotely. For most service objects this access right is assigned to locally authenticated users only. Activity is logged to the Application event log under the "MonitorPermissions" source.
.PARAMETER AccountName
    Specifies the user name of the account which will have permissions assigned.
.PARAMETER ServiceName
    Specifies the name of the service object which will have permissions assigned.
.PARAMETER DomainName
    Specifies the NETBIOS name of the domain the computer is joined to, or the computer name for a workgroup. If not set the USERDOMAIN environment variable value is used.
.OUTPUTS
    None on success.
    A terminating error if the cmdlet fails.
.EXAMPLE
    .\Set-RemoteServicePermissions.ps1 -AccountName 'MyUser' -ServiceName 'MyService'
.EXAMPLE
    .\Set-RemoteServicePermissions.ps1 -AccountName 'MyUser' -ServiceName 'MyService' -DomainName 'MYDOMAIN'
#>
Param(
    [Parameter(Mandatory=$True)]
    [String] $AccountName,
    [Parameter(Mandatory=$True)]
    [String] $ServiceName,
    [Parameter(Mandatory=$False)]
    [String] $DomainName = ''
)

$ErrorActionPreference = 'Stop'

Function Write-Log ([String]$Message, [Int]$EventId, [String]$EventType = 'Information')
{
    $EventSource = 'MonitorPermissions'
    if (![Diagnostics.EventLog]::SourceExists($EventSource))
    {
        New-EventLog -LogName 'Application' -Source $EventSource
    }

    Write-EventLog -LogName 'Application' -Source $EventSource -Message $Message -EventId $EventId -EntryType $EventType
}

if ($DomainName -eq '')
{
    # the NETBIOS name of the domain the computer is joined to, or the computer name for a WORKGROUP machine
    $DomainName = $env:USERDOMAIN
}

# initial value for log messages
$CurrentPermissions = 'Unknown'
$NewPermissions = 'No change.'

try
{
    # retrieve the current service Security Descriptor as an SDDL string, command output can be an array of lines
    $Sddl = (cmd.exe /c sc sdshow $ServiceName) -join "`r`n"

    if ($Sddl -like '*FAILED*')
    {
        $NewPermissions = "Error reading permissions.`r`n"
        $NewPermissions += $Sddl
        throw $NewPermissions
    }
    else
    {
        $CurrentPermissions = $Sddl
    }

    # discover the SID for the provided account name
    # https://stackoverflow.com/questions/18326214/how-does-system-security-principal-ntaccount-translate-resolve-specified-user
    $Account = (New-Object System.Security.Principal.NTAccount($AccountName))
    $AccountSid = $Account.Translate([Security.Principal.SecurityIdentifier])
    $AccountSidByteArray = New-Object -TypeName byte[] -ArgumentList $AccountSid.BinaryLength
    $AccountSid.GetBinaryForm($AccountSidByteArray, 0)

    if ($Sddl -notmatch $AccountSid.Value)
    {
        # create a Security Descriptor object using the service SDDL
        $ServiceSd = New-Object -TypeName Security.AccessControl.CommonSecurityDescriptor `
            -ArgumentList @($true, $false, $Sddl.Trim())

        # Generate an ACE equivilent to the SDDL "(A;;CCLCSWLORC;;;<SID>)". The same as assigning "Read" in the GUI
        # permissions editor. This allows the service status to be read remotely.
        # https://docs.microsoft.com/en-us/windows/win32/services/service-security-and-access-rights
        $ServiceSd.DiscretionaryAcl.AddAccess(
            [Security.AccessControl.AccessControlType]::Allow,
            $AccountSid,
            131213, # CCLCSWLORC in SDDL
            [Security.AccessControl.InheritanceFlags]::None,
            [Security.AccessControl.PropagationFlags]::None
        )

        # convert the Security Descriptor object back into SDDL
        $NewSddl = $ServiceSd.GetSddlForm([Security.AccessControl.AccessControlSections]::All)

        $ScOutput = (cmd.exe /c sc sdset $ServiceName $NewSddl) -join "`r`n"
        
        if ($ScOutput -like '*SUCCESS*')
        {
            $NewPermissions = "Permissions modified successfuly.`r`n"
            $NewPermissions += $NewSddl
        }
        else
        {
            $NewPermissions = "Error modifying permissions.`r`n"
            $NewPermissions += $ScOutput
            throw $NewPermissions 
        }
    }
}
catch
{
    $ErrorText = $_.ToString()+"`r`n"
    $ErrorText += $_.InvocationInfo.PositionMessage
    Write-Log -Message $ErrorText -EventId 19803 -EventType 'Error'
    throw
}
finally
{
    $LogText = `
@"
Account Name: $AccountName
Domain Name: $DomainName

Current Service Permissions:
$CurrentPermissions

New Service Permissions:
$NewPermissions
"@
    Write-Log -Message $LogText -EventId 19804 -EventType 'Information'
    Write-Host $LogText
}
