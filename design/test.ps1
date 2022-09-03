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


echo $Realtek_PlaybackId
echo $VBAudioCables_PlaybackId
echo $StereoMixing_RecorderId
