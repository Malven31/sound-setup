$RegistryBase = 'HKLM:\'
$RegistryFolder = 'SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio'
$RegistryPath = $RegistryBase + $RegistryFolder

$Capture = 'Capture'
# $Render = 'Render'

$audioServiceName = 'audiosrv'

$RegistryListenToPropertyId = '24dbb0fc-9311-4b3d-9cf0-18ff155639d4'
$RegistryListenToTargetProperty = '{' + $RegistryListenToPropertyId + '},0'
$RegistryListenToEnabledProperty = '{' + $RegistryListenToPropertyId + '},1'


$soundDevices = Get-AudioDevice -list

# Source the privileges script to get the Enable-Privilege function
. "$PSScriptRoot\privileges.ps1"

$utf8 = [System.Text.Encoding]::UTF8

# Separate devices into playback and recording categories
$playbackDevices = $soundDevices | Where-Object { $_.Type -eq 'Playback' }
$recordingDevices = $soundDevices | Where-Object { $_.Type -eq 'Recording' }

# Display playback devices
Write-Host " - Available playback devices:" -ForegroundColor Yellow
foreach ($device in $playbackDevices) {
    Write-Host "     - $($device.Name)" -ForegroundColor Cyan
}

# Display recording devices
Write-Host "`n - Available recording devices:" -ForegroundColor Yellow
foreach ($device in $recordingDevices) {
    Write-Host "     - $($device.Name)" -ForegroundColor Cyan
}
Write-Host "`n"


function Get-AudioDeviceIdFromName {
    param([string]$Name)
    foreach ($sound in $soundDevices) {
        # Simple direct string comparison - case insensitive
        if ($sound.Name -like $Name) {
            return $sound.Id
        }
    }
    
    # Enhanced comparison using normalization for accented characters
    foreach ($sound in $soundDevices) {
        # Using string normalization to handle accented characters
        $normalizedName = $Name.Normalize([Text.NormalizationForm]::FormD) -replace '[^\p{Ll}\p{Lu}\p{Lt}\p{Lo}\p{Nd}\p{Pc}\p{Lm}]', ''
        $normalizedDeviceName = $sound.Name.Normalize([Text.NormalizationForm]::FormD) -replace '[^\p{Ll}\p{Lu}\p{Lt}\p{Lo}\p{Nd}\p{Pc}\p{Lm}]', ''
        
        if ($normalizedDeviceName -like "*$normalizedName*" -or $normalizedName -like "*$normalizedDeviceName*") {
            Write-Host "Found match using normalized comparison: $($sound.Name)" -ForegroundColor Green
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
    try {
        $id = Get-AudioDeviceIdFromName -Name $Name
        if (-not $id) {
            throw "No ID found for the given name: $Name"
        }
        return Get-ShortId -LongId $id
    } catch {
        Write-Host "Error: $_"
        return $null  # Return null in case of failure
    }
}


# -----

# SORTIES
$Realtek_PlaybackId = Get-ShortIdFromName -Name 'Haut-parleurs (Realtek(R) Audio)'
$VBAudioCables_PlaybackId = Get-ShortIdFromName -Name 'CABLE Input (VB-Audio Virtual Cable)' # => default playback
$VBAudioCables_A_PlaybackId = Get-ShortIdFromName -Name 'CABLE-A Input (VB-Audio Virtual Cable A)' # default all applications sound
$VBAudioCables_B_PlaybackId = Get-ShortIdFromName -Name 'CABLE-B Input (VB-Audio Virtual Cable B)' # discord sound
$SonyTV_PlaybackId = Get-ShortIdFromName -Name 'SONY TV  *00 (NVIDIA High Definition Audio)'

# ENTREES
$StereoMixing_RecorderId = Get-ShortIdFromName -Name 'Mixage stéréo (Realtek(R) Audio)' # to SonyTV -> LISTEN
# $StereoMixing_RecorderId = 'ab19b82f-ccb7-43d6-990d-d5f5ee1387d4' # to SonyTV -> LISTEN
$VBAudioCables_RecorderId = Get-ShortIdFromName -Name 'CABLE Output (VB-Audio Virtual Cable)' # Realtek -> LISTEN
$VBAudioCables_A_RecorderId = Get-ShortIdFromName -Name 'CABLE-A Output (VB-Audio Virtual Cable A)' # VBAudioCables => default recording / Realtek -> LISTEN
$VBAudioCables_B_RecorderId = Get-ShortIdFromName -Name 'CABLE-B Output (VB-Audio Virtual Cable B)' # Realtek -> LISTEN
$Microphone_RecorderId = Get-ShortIdFromName -Name 'Microphone (RODE NT-USB)' # Mic

# -----


Function Get-CompleteId {
    param ([string]$Id, [bool]$IsPlayback)
    # Write-Host " - Getting ID" -ForegroundColor Yellow
    if ($IsPlayback) {
        return '{0.0.0.00000000}.{' + $Id + '}'
    }
    else {
        return '{0.0.1.00000000}.{' + $Id + '}'
    }
}


Function Test-RegistryValue {
    param(
        [Alias("PSPath")]
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$Path
        ,
        [Parameter(Position = 1, Mandatory = $true)]
        [String]$Name
        ,
        [Switch]$PassThru
    ) 

    process {
        if (Test-Path $Path) {
            $Key = Get-Item -LiteralPath $Path
            if ($null -ne $Key.GetValue($Name, $null)) {
                if ($PassThru) {
                    Get-ItemProperty $Path $Name
                } else {
                    $true
                }
            } else {
                $false
            }
        } else {
            $false
        }
    }
}

Function Set-RegistryAudioDeviceListen {
    param ([string]$DeviceType, [string]$DeviceId, [bool]$ListenEnabled, [string]$DeviceToListenId)
    
    # Early return if either device ID is null or empty
    if (-not $DeviceId -or -not $DeviceToListenId) {
        Write-Host "Error: Device ID or DeviceToListen ID is null/empty. Aborting..." -ForegroundColor Red
        return
    }
    
    Write-Host " - Setting Listen : `"$DeviceId`" to `"$DeviceToListenId`"" -ForegroundColor Yellow
    $path = $RegistryPath + "\" + $DeviceType + "\{" + $DeviceId + "}\Properties"

    # Check if the registry path exists and create it if it doesn't
    if (-Not (Test-Path $path)) {
        Write-Host " - Creating registry path: $path" -ForegroundColor Yellow
        try {
            New-Item -Path $path -Force | Out-Null
        } catch {
            Write-Host "Error creating registry path: $_" -ForegroundColor Red
            return
        }
    }

    $enabled = Test-RegistryValue $path $RegistryListenToEnabledProperty
    if (-Not $enabled) {
        Write-Host " - Creating registry value: $RegistryListenToEnabledProperty" -ForegroundColor Yellow
        New-ItemProperty -path $path -name $RegistryListenToEnabledProperty -PropertyType Binary -Value ([byte[]](0x0b,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00))
    }
    $target = Test-RegistryValue $path $RegistryListenToTargetProperty
    if (-Not $target) {
        Write-Host " - Creating registry value: $RegistryListenToTargetProperty" -ForegroundColor Yellow
        New-ItemProperty -path $path -name $RegistryListenToTargetProperty -PropertyType String
    }

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

    Enable-Privilege SeTakeOwnershipPrivilege  | Out-Null
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
Write-Host " - Setting default playback device" -ForegroundColor Yellow
Set-AudioDevice -ID $PlaybackDefaultId | Out-Null

$RecordDefaultId = Get-CompleteId -Id $VBAudioCables_A_RecorderId -IsPlayback 0
Write-Host " - Setting default recording device" -ForegroundColor Yellow
Set-AudioDevice -ID $RecordDefaultId | Out-Null

# Set RODE microphone as the default communication device for recording
$MicrophoneCommunicationId = Get-CompleteId -Id $Microphone_RecorderId -IsPlayback 0
Write-Host " - Setting RODE NT-USB as default communication device" -ForegroundColor Yellow
Set-AudioDevice -ID $MicrophoneCommunicationId -Communication | Out-Null

# Set-RegistryAudioDeviceListen `
#     -DeviceType $Capture `
#     -DeviceId $StereoMixing_RecorderId `
#     -ListenEnabled 1 `
#     -DeviceToListenId $SonyTV_PlaybackId

Set-RegistryAudioDeviceListen `
    -DeviceType $Capture `
    -DeviceId $VBAudioCables_RecorderId `
    -ListenEnabled 1 `
    -DeviceToListenId $VBAudioCables_A_PlaybackId

Set-RegistryAudioDeviceListen `
    -DeviceType $Capture `
    -DeviceId $VBAudioCables_A_RecorderId `
    -ListenEnabled 1 `
    -DeviceToListenId $Realtek_PlaybackId

Set-RegistryAudioDeviceListen `
    -DeviceType $Capture `
    -DeviceId $VBAudioCables_B_RecorderId `
    -ListenEnabled 1 `
    -DeviceToListenId $Realtek_PlaybackId

Write-Host " - Restarting Windows Audio Service" -ForegroundColor Yellow
Restart-Service -Name $audioServiceName -Force