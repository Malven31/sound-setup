$RegistryBase = 'HKLM:\'
$RegistryFolder = 'SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio'
$RegistryPath = $RegistryBase + $RegistryFolder


$RegistryListenToPropertyId = '24dbb0fc-9311-4b3d-9cf0-18ff155639d4'
$RegistryListenToTargetProperty = '{' + $RegistryListenToPropertyId + '},0'
$RegistryListenToEnabledProperty = '{' + $RegistryListenToPropertyId + '},1'


$soundDevices = Get-AudioDevice -list

# Source the privileges script to get the Enable-Privilege function
. "$PSScriptRoot\privileges.ps1"

function Remove-Diacritics {
    param([string]$Text)
    if (-not $Text) { return $Text }
    $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
    return -join ($normalized.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
}

function Invoke-EncodingBug {
    param([string]$Text)
    if (-not $Text) { return $Text }
    $bytes = [System.Text.Encoding]::GetEncoding(1252).GetBytes($Text)
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Get-AudioDeviceIdFromName {
    param([string]$Name)
    $normalizedInput = Remove-Diacritics $Name
    $buggyInput = Invoke-EncodingBug $Name
    foreach ($sound in $soundDevices) {
        $normalizedDeviceName = Remove-Diacritics $sound.Name
        if ($normalizedDeviceName -eq $normalizedInput) {
            return $sound.Id
        }
        # Also try contains for partial matches
        if ($normalizedDeviceName -like "*$normalizedInput*" -or $normalizedInput -like "*$normalizedDeviceName*") {
            Write-Host "Found match using normalized/diacritics-insensitive comparison: $($sound.Name)" -ForegroundColor Green
            return $sound.Id
        }
        # Try buggy encoding match
        if ($sound.Name -eq $buggyInput) {
            Write-Host "Found match using simulated encoding bug: $($sound.Name) == $buggyInput" -ForegroundColor Magenta
            return $sound.Id
        }
        if ($sound.Name -like "*$buggyInput*") {
            Write-Host "Found partial match using simulated encoding bug: $($sound.Name) ~ $buggyInput" -ForegroundColor Magenta
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
    }
    catch {
        Write-Host "Error: $_"
        return $null  # Return null in case of failure
    }
}



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
                }
                else {
                    $true
                }
            }
            else {
                $false
            }
        }
        else {
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
        }
        catch {
            Write-Host "Error creating registry path: $_" -ForegroundColor Red
            return
        }
    }

    $enabled = Test-RegistryValue $path $RegistryListenToEnabledProperty
    if (-Not $enabled) {
        Write-Host " - Creating registry value: $RegistryListenToEnabledProperty" -ForegroundColor Yellow
        New-ItemProperty -path $path -name $RegistryListenToEnabledProperty -PropertyType Binary -Value ([byte[]](0x0b, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
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

Function Disable-UnusedAudioDevices {
    param ([string[]]$DeviceNamesToKeepEnabled)
    
    Write-Host " - Hiding unused audio devices from list..." -ForegroundColor Yellow
    
    $allDevices = Get-AudioDevice -List
    $devicesToHide = $allDevices | Where-Object { 
        $_.Name -notin $DeviceNamesToKeepEnabled 
    }
    
    if ($devicesToHide.Count -eq 0) {
        Write-Host "   - All devices are in the keep-enabled list" -ForegroundColor Gray
        return
    }
    
    Write-Host "   - Found $($devicesToHide.Count) devices that are not in your active setup" -ForegroundColor Gray
    Write-Host "   - Note: These devices cannot be disabled via PowerShell, but you can:" -ForegroundColor Cyan
    Write-Host "     1. Right-click speaker icon → Sound settings → More sound settings" -ForegroundColor DarkGray
    Write-Host "     2. Right-click each unused device → Disable" -ForegroundColor DarkGray
    Write-Host "`n   - Unused devices:" -ForegroundColor Yellow
    
    foreach ($device in $devicesToHide) {
        Write-Host "     - $($device.Name)" -ForegroundColor DarkGray
    }
    
    Write-Host ""
}


