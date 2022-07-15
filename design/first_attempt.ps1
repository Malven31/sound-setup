$speakerid = ''
$microphone1id = ''

$audioServiceName = 'audiosrv'

write-output 'Trying to set headset'

# list audio devices :
Get-AudioDevice -list


# Restart-Service -Name $audioServiceName
