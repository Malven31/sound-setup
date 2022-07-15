$RegistryBasePath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio'

$Capture = 'Capture'
$Render = 'Render'

$audioServiceName = 'audiosrv'

$RegistryListenToPropertyId = '24dbb0fc-9311-4b3d-9cf0-18ff155639d4'
$RegistryListenToTargetProperty = '{' + $RegistryListenToPropertyId + '},0'
$RegistryListenToEnabledProperty = '{' + $RegistryListenToPropertyId + '},1'


# -----

# list audio devices :
# Get-AudioDevice -list

$Realtek_PlaybackId = '904288f3-8070-4d77-9a46-9fff8ecbb889'
$VBAudioCables_PlaybackId = '3e917a69-ba45-4e6f-8c56-22b96f2d6356' # => default playback
$VBAudioCables_A_PlaybackId = '73064900-6e39-4857-be85-1a7d6f2e6db0'
$VBAudioCables_B_PlaybackId = 'eb92dae9-92f7-415a-8006-bf2980e77717'
$SonyTV_PlaybackId = 'd2857e0c-0d20-4234-aa96-3f24c0e9bea4'

$StereoMixing_RecorderId = '73ac7f8d-2226-4452-9ab6-d06ee1a8d609' # to SonyTV -> LISTEN
$VBAudioCables_RecorderId = '103cfecc-aac7-41d3-90db-776dd0a4f6c1' # Realtek -> LISTEN
$VBAudioCables_A_RecorderId = 'b368f879-0c27-4e18-908d-d5914a6d9a8b' # VBAudioCables => default recording
$VBAudioCables_B_RecorderId = '36f61fb3-dd77-46d7-887c-06f871a27a12' # Realtek -> LISTEN


# -----

Function Get-CompleteId {
    param ([string]$Id, [bool]$IsPlayback)
    if ($IsPlayback) {
        return '{0.0.0.00000000}.{' + $Id + '}'
    }
    else {
        return '{0.0.1.00000000}.{' + $Id + '}'
    }
}

$completeId = Get-CompleteId -Id $VBAudioCables_RecorderId -IsPlayback 0

# Write-Output $completeId

# # Set variables to indicate value and key to set
# $RegistryPath = 'HKCU:\Software\CommunityBlog\Scripts'
# $Name         = 'Version'
# $Value        = '42'
# # Create the key if it does not exist
# If (-NOT (Test-Path $RegistryPath)) {
#   New-Item -Path $RegistryPath -Force | Out-Null
# }  
# # Now set the value
# New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Get-ItemProperty -Path $RegistryBasePath'\Capture'

# Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio


# Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture\{103cfecc-aac7-41d3-90db-776dd0a4f6c1}\Properties' -Name '{24dbb0fc-9311-4b3d-9cf0-18ff155639d4},0'


# $value = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture\{b368f879-0c27-4e18-908d-d5914a6d9a8b}\Properties' -Name $RegistryListenToEnabledProperty
# Write-Output $value



# $myregdata = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture\{103cfecc-aac7-41d3-90db-776dd0a4f6c1}\Properties" | Select -ExpandProperty $RegistryListenToEnabledProperty) -join ','
# $myregdata = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture\{103cfecc-aac7-41d3-90db-776dd0a4f6c1}\Properties" | Select -ExpandProperty $RegistryListenToEnabledProperty)
# Write-Output $myregdata



Function Set-RegistryAudioDeviceListen {
    param ([string]$DeviceType, [string]$DeviceId, [bool]$ListenEnabled, [string]$DeviceToListenId, [bool]$DeviceToListenIsPlayback)
    $path = $RegistryBasePath + "\" + $DeviceType + "\{" + $DeviceId + "}\Properties"

    $getObjectListenEnabled = Get-ItemProperty -path $path -name $RegistryListenToEnabledProperty
    # $getObjectListenTarget = Get-ItemProperty -path $path -name $RegistryListenToTargetProperty

    if ($ListenEnabled) {
        $getObjectListenEnabled.$RegistryListenToEnabledProperty[8] = 255
        $getObjectListenEnabled.$RegistryListenToEnabledProperty[9] = 255
    }
    else {
        $getObjectListenEnabled.$RegistryListenToEnabledProperty[8] = 0
        $getObjectListenEnabled.$RegistryListenToEnabledProperty[9] = 0
    }

    $enabledValue = $getObjectListenEnabled.$RegistryListenToEnabledProperty
    $targetValue = Get-CompleteId -Id $DeviceToListenId -IsPlayback $DeviceToListenIsPlayback
    
    # Write-Output '---'
    # Write-Output $path
    # Write-Output '---'
    # Write-Output $RegistryListenToEnabledProperty
    # Write-Output '---'
    # Write-Output $enabledValue
    # Write-Output '---'
    # Write-Output $completeToListenId

    Set-ItemProperty -path $path -name $RegistryListenToEnabledProperty -Value $enabledValue
    Set-ItemProperty -path $path -name $RegistryListenToTargetProperty -Value $targetValue
}

Set-RegistryAudioDeviceListen -DeviceType $Capture -DeviceId $VBAudioCables_RecorderId -ListenEnabled 0 -DeviceToListenId $Realtek_PlaybackId -DeviceToListenIsPlayback 1
# Restart-Service -Name $audioServiceName

# $path = $RegistryBasePath + "\" + $DeviceType + "\{103cfecc-aac7-41d3-90db-776dd0a4f6c1}\Properties"
# $objName = $RegistryListenToEnabledProperty
# $getObj = Get-ItemProperty -path $path -name $objName
# $objValue = $getObj.DefaultConnectionSettings
# Write-Output $getObj.$RegistryListenToEnabledProperty[8]
# Write-Output $getObj.$RegistryListenToEnabledProperty[9]
# Set-ItemProperty -path $path -name $objName -Value $objValue



# Write-Output $myregdata
# Function Set-RegBinaryData {
#     param ([array]$Data, [bool]$ListenEnabled)
#     $BinaryData = @()
#     for ($x = 0; $x -lt $Data.Length; $x++) {
#         If (8..9 -contains $x) {

#             if ($ListenEnabled) {
#                 $BinaryData += 255
#             }
#             else {
#                 $BinaryData += 0
#             }
#         }
#         else {
#             $BinaryData += $Data[$x]
#         }
#     }
#     Write-Output $BinaryData
#     return $BinaryData
# }

# Set-RegBinaryData -Data $myregdata -ListenEnabled 0