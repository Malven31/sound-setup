# Get-AudioDevice -list
$utf8 = [System.Text.Encoding]::UTF8
$ascii = [System.Text.Encoding]::ASCII

$RegistryNamePropertyId = '{b3f8fa53-0004-438e-9003-51a46e139bfc},6'
$RegistryClassPropertyId = '{a45c254e-df1c-4efd-8020-67d146a850e0},2'


$regAudio = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio"
$nameId = "{b3f8fa53-0004-438e-9003-51a46e139bfc},6"
$classId = "{a45c254e-df1c-4efd-8020-67d146a850e0},2"
$driverDetails = "{83da6326-97a6-4088-9453-a1923f573b29},3"

function get-DefaultDevice($type) {
    $devices = foreach ($key in  Get-ChildItem "$regAudio\$type\") {
        foreach ($item in Get-ItemProperty $key.PsPath) { $item }
    }
    foreach ($device in $devices) {
        $details = Get-ItemProperty "$($device.PSPath)\Properties"
        $name = "$($details.$classId) ($($details.$nameId))"
        Write-Output '--------------------'
        Write-Output $name
        Write-Output $details
    }
    # $defaultDevice = $activeDevices | Sort-Object -Property "Level:0", "Level:1", "Level:2" | select -last 1
    # $details = Get-ItemProperty "$($defaultDevice.PSPath)\Properties"
    # $name = "$($details.$classId) ($($details.$nameId))"
    # return @{
    #     name   = $name
    #     driver = $details.$driverDetails
    # }
}
# get-DefaultDevice "Render"
# $OsRender = get-DefaultDevice "Render"
# $OsCapture = get-DefaultDevice "Capture"

# Write-Output $OsRender

$soundDevices = Get-AudioDevice -list

# foreach ($sound in $sounds) {
#     Write-Output $sound.Name
# }

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

# $id = Get-AudioDeviceIdFromName -Name 'Haut-parleurs (VB-Audio Virtual Cable)'
# write-output $id
# $id2 = Get-AudioDeviceIdFromName -Name 'Mixage stéréo (Realtek High Definition Audio)'
# write-output $id2

function Get-ShortId {
    param([string]$LongId)
    $pattern = '(?<=\}\.\{).+?(?=\})'
    [regex]::Matches($longId, $pattern).Value
}

# $shortId = Get-ShortId -LongId '{0.0.1.00000000}.{73ac7f8d-2226-4452-9ab6-d06ee1a8d609}' 
# Write-Output $shortId


function Get-ShortIdFromName {
    param([string]$Name)
    $id = Get-AudioDeviceIdFromName -Name $Name
    return Get-ShortId -LongId $id
}

Get-ShortIdFromName -Name 'SONY TV  *000 (NVIDIA High Definition Audio)'