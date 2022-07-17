$RegistryBase = 'HKLM:\'
$RegistryFolder = 'SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio'
$RegistryPath = $RegistryBase + $RegistryFolder

$Capture = 'Capture'
$Render = 'Render'

$audioServiceName = 'audiosrv'

$RegistryListenToPropertyId = '24dbb0fc-9311-4b3d-9cf0-18ff155639d4'
$RegistryListenToTargetProperty = '{' + $RegistryListenToPropertyId + '},0'
$RegistryListenToEnabledProperty = '{' + $RegistryListenToPropertyId + '},1'


$soundDevices = Get-AudioDevice -list

$utf8 = [System.Text.Encoding]::UTF8
$ascii = [System.Text.Encoding]::ASCII

function Get-AudioDeviceIdFromName {
    param([string]$Name)
    $encodedName = $ascii.GetBytes($Name)
    foreach ($sound in $soundDevices) {
        $encodedSoundName = [System.Text.Encoding]::UTF8.GetBytes($sound.Name)
        if ($ascii.GetString($encodedSoundName) -eq $ascii.GetString($encodedName)) {
            return $sound.Id
        }
    }
    $AudioDeviceError = New-Object System.Exception "There is no Sound Device named : $Name"
    throw $AudioDeviceError
}

function Get-ShortId {
    param([string]$LongId)
    $pattern = '(?<=\}\.\{).+?(?=\})'
    [regex]::Matches($longId, $pattern).Value
}

function Get-ShortIdFromName {
    param([string]$Name)
    $id = Get-AudioDeviceIdFromName -Name $Name
    return Get-ShortId -LongId $id
}


# -----

$Realtek_PlaybackId = Get-ShortIdFromName -Name 'Haut-parleurs (Realtek High Definition Audio)'
$VBAudioCables_PlaybackId = Get-ShortIdFromName -Name 'Haut-parleurs (VB-Audio Virtual Cable)' # => default playback
$VBAudioCables_A_PlaybackId = Get-ShortIdFromName -Name 'Haut-parleurs (VB-Audio Cable A)'
$VBAudioCables_B_PlaybackId = Get-ShortIdFromName -Name 'Haut-parleurs (VB-Audio Cable B)'
$SonyTV_PlaybackId = Get-ShortIdFromName -Name 'SONY TV  *00 (NVIDIA High Definition Audio)'

$StereoMixing_RecorderId = Get-ShortIdFromName -Name 'Mixage stéréo (Realtek High Definition Audio)' # to SonyTV -> LISTEN
$VBAudioCables_RecorderId = Get-ShortIdFromName -Name 'CABLE Output (VB-Audio Virtual Cable)' # Realtek -> LISTEN
$VBAudioCables_A_RecorderId = Get-ShortIdFromName -Name 'CABLE-A Output (VB-Audio Cable A)' # VBAudioCables => default recording
$VBAudioCables_B_RecorderId = Get-ShortIdFromName -Name 'CABLE-B Output (VB-Audio Cable B)' # Realtek -> LISTEN


# -----

function Enable-Privilege {
    param(
        ## The privilege to adjust. This set is taken from
        ## http://msdn.microsoft.com/en-us/library/bb530716(VS.85).aspx
        [ValidateSet(
            "SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege", "SeBackupPrivilege",
            "SeChangeNotifyPrivilege", "SeCreateGlobalPrivilege", "SeCreatePagefilePrivilege",
            "SeCreatePermanentPrivilege", "SeCreateSymbolicLinkPrivilege", "SeCreateTokenPrivilege",
            "SeDebugPrivilege", "SeEnableDelegationPrivilege", "SeImpersonatePrivilege", "SeIncreaseBasePriorityPrivilege",
            "SeIncreaseQuotaPrivilege", "SeIncreaseWorkingSetPrivilege", "SeLoadDriverPrivilege",
            "SeLockMemoryPrivilege", "SeMachineAccountPrivilege", "SeManageVolumePrivilege",
            "SeProfileSingleProcessPrivilege", "SeRelabelPrivilege", "SeRemoteShutdownPrivilege",
            "SeRestorePrivilege", "SeSecurityPrivilege", "SeShutdownPrivilege", "SeSyncAgentPrivilege",
            "SeSystemEnvironmentPrivilege", "SeSystemProfilePrivilege", "SeSystemtimePrivilege",
            "SeTakeOwnershipPrivilege", "SeTcbPrivilege", "SeTimeZonePrivilege", "SeTrustedCredManAccessPrivilege",
            "SeUndockPrivilege", "SeUnsolicitedInputPrivilege")]
        $Privilege,
        ## The process on which to adjust the privilege. Defaults to the current process.
        $ProcessId = $pid,
        ## Switch to disable the privilege, rather than enable it.
        [Switch] $Disable
    )
   
    ## Taken from P/Invoke.NET with minor adjustments.
    $definition = @'
    using System;
    using System.Runtime.InteropServices;
     
    public class AdjPriv
    {
     [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
     internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
      ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
     
     [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
     internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
     [DllImport("advapi32.dll", SetLastError = true)]
     internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
     [StructLayout(LayoutKind.Sequential, Pack = 1)]
     internal struct TokPriv1Luid
     {
      public int Count;
      public long Luid;
      public int Attr;
     }
     
     internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
     internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
     internal const int TOKEN_QUERY = 0x00000008;
     internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
     public static bool EnablePrivilege(long processHandle, string privilege, bool disable)
     {
      bool retVal;
      TokPriv1Luid tp;
      IntPtr hproc = new IntPtr(processHandle);
      IntPtr htok = IntPtr.Zero;
      retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
      tp.Count = 1;
      tp.Luid = 0;
      if(disable)
      {
       tp.Attr = SE_PRIVILEGE_DISABLED;
      }
      else
      {
       tp.Attr = SE_PRIVILEGE_ENABLED;
      }
      retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
      retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
      return retVal;
     }
    }
'@
   
    $processHandle = (Get-Process -id $ProcessId).Handle
    $type = Add-Type $definition -PassThru
    $type[0]::EnablePrivilege($processHandle, $Privilege, $Disable)
}


Function Get-CompleteId {
    param ([string]$Id, [bool]$IsPlayback)
    if ($IsPlayback) {
        return '{0.0.0.00000000}.{' + $Id + '}'
    }
    else {
        return '{0.0.1.00000000}.{' + $Id + '}'
    }
}



Function Set-RegistryAudioDeviceListen {
    param ([string]$DeviceType, [string]$DeviceId, [bool]$ListenEnabled, [string]$DeviceToListenId)
    $path = $RegistryPath + "\" + $DeviceType + "\{" + $DeviceId + "}\Properties"

    $getObjectListenEnabled = Get-ItemProperty -path $path -name $RegistryListenToEnabledProperty
    $getObjectListenTarget = Get-ItemProperty -path $path -name $RegistryListenToTargetProperty

    if ($ListenEnabled) {
        $getObjectListenEnabled.$RegistryListenToEnabledProperty[8] = 255
        $getObjectListenEnabled.$RegistryListenToEnabledProperty[9] = 255
    }
    else {
        $getObjectListenEnabled.$RegistryListenToEnabledProperty[8] = 0
        $getObjectListenEnabled.$RegistryListenToEnabledProperty[9] = 0
    }

    $enabledValue = $getObjectListenEnabled.$RegistryListenToEnabledProperty
    $getObjectListenTarget.$RegistryListenToTargetProperty = Get-CompleteId -Id $DeviceToListenId -IsPlayback 1
    $targetValue = $getObjectListenTarget.$RegistryListenToTargetProperty

    Enable-Privilege SeTakeOwnershipPrivilege 
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
        $RegistryFolder + "\" + $DeviceType + "\{" + $DeviceId + "}\Properties",
        [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::takeownership
    )
    # You must get a blank acl for the key b/c you do not currently have access
    $acl = $key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
    $me = [System.Security.Principal.NTAccount]"$env:userdomain\$env:username"
    $acl.SetOwner($me)
    $key.SetAccessControl($acl)
    
    # After you have set owner you need to get the acl with the perms so you can modify it.
    $acl = $key.GetAccessControl()
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule ("$env:userdomain\$env:username", "FullControl", "Allow")
    $acl.SetAccessRule($rule)
    $key.SetAccessControl($acl)
    
    $key.Close()

    Set-ItemProperty -path $path -name $RegistryListenToEnabledProperty -Value $enabledValue -Force
    Set-ItemProperty -path $path -name $RegistryListenToTargetProperty -Value $targetValue -Force
}


$PlaybackDefaultId = Get-CompleteId -Id $VBAudioCables_PlaybackId -IsPlayback 1
Set-AudioDevice -ID $PlaybackDefaultId

$RecordDefaultId = Get-CompleteId -Id $VBAudioCables_A_RecorderId -IsPlayback 0
Set-AudioDevice -ID $RecordDefaultId


Set-RegistryAudioDeviceListen `
    -DeviceType $Capture `
    -DeviceId $StereoMixing_RecorderId `
    -ListenEnabled 1 `
    -DeviceToListenId $SonyTV_PlaybackId

Set-RegistryAudioDeviceListen `
    -DeviceType $Capture `
    -DeviceId $VBAudioCables_RecorderId `
    -ListenEnabled 1 `
    -DeviceToListenId $Realtek_PlaybackId

Set-RegistryAudioDeviceListen `
    -DeviceType $Capture `
    -DeviceId $VBAudioCables_A_RecorderId `
    -ListenEnabled 0 `
    -DeviceToListenId $VBAudioCables_PlaybackId

Set-RegistryAudioDeviceListen `
    -DeviceType $Capture `
    -DeviceId $VBAudioCables_B_RecorderId `
    -ListenEnabled 1 `
    -DeviceToListenId $Realtek_PlaybackId


Restart-Service -Name $audioServiceName