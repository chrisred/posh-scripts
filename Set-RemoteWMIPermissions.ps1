<#
.SYNOPSIS
    Assign a user account remote WMI permissions on the computer this cmdlet is executed on.
.DESCRIPTION
    The Set-RemoteWMIPermissions cmdlet will assign a non-admin account the permissions required to access WMI namespaces and the Service Control Manager remotely. The most common use case is for monitoring solutions which read performance counter (or other values) via WMI queries. Activity is logged to the Application event log under the "MonitorPermissions" source.
.PARAMETER AccountName
    Specifies the user name of the account which will have permissions assigned.
.PARAMETER DomainName
    Specifies the NETBIOS name of the domain the computer is joined to, or the computer name for a workgroup. If not set the USERDOMAIN environment variable value is used.
.OUTPUTS
    None on success.
    A terminating error if the cmdlet fails.
.EXAMPLE
    .\Set-RemoteWMIPermissions.ps1 -AccountName 'MyUser'
.EXAMPLE
    .\Set-RemoteWMIPermissions.ps1 -AccountName 'MyUser' -DomainName 'MYDOMAIN'
#>
Param(
    [Parameter(Mandatory=$True)]
    [String] $AccountName,
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
$CurrentWmiPermissions = 'Unknown'
$CurrentScmPermissions = 'Unknown'
$NewWmiPermissions = 'No change.'
$NewScmPermissions = 'No change.'

try
{
    # retrieve the current WMI root namespace ACL and also dump to a string
    $WmiRootAcl = (Invoke-WmiMethod -Namespace "root" -Path "__SystemSecurity=@" -Name GetSecurityDescriptor).Descriptor
    $CurrentWmiPermissions = $WmiRootAcl.DACL | `
        Select-Object @{'Name'='Name'; 'Expression'={$_.Trustee.Name}},AccessMask,AceFlags,AceType | Out-String

    # retrieve the current SCM Security Descriptor as an SDDL string
    $ScmSddl = (cmd.exe /c sc sdshow scmanager) -join "`r`n"
    $CurrentScmPermissions = $ScmSddl

    # discover the SID for the provided account name
    # https://stackoverflow.com/questions/18326214/how-does-system-security-principal-ntaccount-translate-resolve-specified-user
    $Account = (New-Object System.Security.Principal.NTAccount($AccountName))
    $AccountSid = $Account.Translate([Security.Principal.SecurityIdentifier])
    $AccountSidByteArray = New-Object -TypeName byte[] -ArgumentList $AccountSid.BinaryLength
    $AccountSid.GetBinaryForm($AccountSidByteArray, 0)

    #
    # Apply WMI Permissions
    #

    # check if $Account already has a WMI ACL entry
    $WmiPermissionSet = $false
    foreach ($WmiAce in $WmiRootAcl.DACL)
    {
        if ($WmiAce.Trustee.SIDString -eq $AccountSid.Value)
        {
            $WmiPermissionSet = $true
        }
    }

    if ($WmiPermissionSet -eq $false)
    {
        # create a Trustee object to reference the account to which permissions will be assigned
        $WmiTrustee = (New-Object -TypeName 'WmiClass' -ArgumentList 'Win32_Trustee').CreateInstance()
        $WmiTrustee.Name = $AccountName
        $WmiTrustee.Domain = $DomainName
        $WmiTrustee.SID = $AccountSidByteArray
        $WmiTrustee.SIDString = $AccountSid.Value
        $WmiTrustee.SidLength = $AccountSid.BinaryLength

        # create an Access Control Entry object which defines the permissions for remote WMI read access
        # https://docs.microsoft.com/en-us/windows/win32/wmisdk/--ace
        $WmiAce = (New-Object -TypeName 'WmiClass' -ArgumentList 'Win32_ACE').CreateInstance()

        # Access Mask (permissions)
        # 35     - "Execute Methods", "Enable Account", "Remote Enable"
        # 131105 - "Enable Account", "Remote Enable", "Read Security"
        # 131107 - "Execute Methods", "Enable Account", "Remote Enable", "Read Security"
        $WmiAce.AccessMask = 131105
        # Flags (inheritance)
        # 2 - "Applies to this namespace and subnamespaces"
        $WmiAce.AceFlags = 2
        $WmiAce.AceType = 0
        $WmiAce.Trustee = $WmiTrustee

        # append the ACE to the ACL of the root WMI namespace
        $WmiRootAcl.DACL += $WmiAce
        # set the new ACL to the root namespace
        $WmiOutput = Invoke-WmiMethod -Namespace "root" -Path "__SystemSecurity=@" -Name SetSecurityDescriptor -ArgumentList $WmiRootAcl

        if ($WmiOutput.ReturnValue -eq 0)
        {
            $NewWmiPermissions = "Permissions modified successfuly (Return Code: $($WmiOutput.ReturnValue)).`r`n"
            $NewWmiPermissions += $WmiRootAcl.DACL | `
                Select-Object @{'Name'='Name'; 'Expression'={$_.Trustee.Name}},AccessMask,AceFlags,AceType | Out-String
        }
        else
        {
            $NewWmiPermissions = "Error modifying permissions (Return Code: $($WmiOutput.ReturnValue))."
            throw $NewWmiPermissions 
        }
    }

    #
    # Apply Service Control Manager (SCM) permissions
    #

    # check if $Account is already present in the SDDL string
    $ScmPermissionSet = $false
    if ($ScmSddl -like "*$($AccountSid.Value)*")
    {
        $ScmPermissionSet = $true
    }

    if ($ScmPermissionSet -eq $false)
    {
        # create a Security Descriptor object using the SCM SDDL
        $ScmSd = New-Object -TypeName Security.AccessControl.CommonSecurityDescriptor `
            -ArgumentList @($true, $false, $ScmSddl.Trim())

        # Generate an ACE equivilent to the SDDL "(A;;LCRPRC;;;<SID>)", which are the rights the GENERIC_READ (GR) access
        # right assigns to the Service Control Manager. This allows services and their status to be read remotely.
        # https://docs.microsoft.com/en-us/windows/win32/services/service-security-and-access-rights
        $ScmSd.DiscretionaryAcl.AddAccess(
            [Security.AccessControl.AccessControlType]::Allow,
            $AccountSid,
            131092, # GENERIC_READ (GR) or "LCRPRC"
            [Security.AccessControl.InheritanceFlags]::None,
            [Security.AccessControl.PropagationFlags]::None
        )

        # convert the Security Descriptor object back into SDDL
        $NewSddl = $ScmSd.GetSddlForm([Security.AccessControl.AccessControlSections]::All)

        $ScmOutput = (cmd.exe /c sc sdset scmanager $NewSddl) -join "`r`n"
        
        if ($ScmOutput -like '*SUCCESS*')
        {
            $NewScmPermissions = "Permissions modified successfuly.`r`n"
            $NewScmPermissions += $NewSddl
        }
        else
        {
            $NewScmPermissions = "Error modifying permissions.`r`n"
            $NewScmPermissions += $ScmOutput
            throw $NewScmPermissions 
        }
    }
}
catch
{
    $ErrorText = $_.ToString()+"`r`n"
    $ErrorText += $_.InvocationInfo.PositionMessage
    Write-Log -Message $ErrorText -EventId 19801 -EventType 'Error'
    throw
}
finally
{
    $LogText = `
@"
Account Name: $AccountName
Domain Name: $DomainName

Current WMI Permissions:
$CurrentWmiPermissions

Current SCM Permissions (SDDL):
$CurrentScmPermissions

New WMI Permissions:
$NewWmiPermissions

New SCM Permissions:
$NewScmPermissions
"@
    Write-Log -Message $LogText -EventId 19802 -EventType 'Information'
}
