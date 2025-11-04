# $Capture = 'Capture'
# $Render = 'Render'

$audioServiceName = 'audiosrv'


$soundDevices = Get-AudioDevice -list

# Source the privileges script to get the Enable-Privilege function
. "$PSScriptRoot\privileges.ps1"
# Source the utilities script to get the all functions
. "$PSScriptRoot\utilities.ps1"


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


# -----

# SORTIES (PLAYBACK DEVICES)
# $Realtek_PlaybackId = Get-ShortIdFromName -Name 'Haut-parleurs (Realtek(R) Audio)'
# $LogitechHeadset_PlaybackId = Get-ShortIdFromName -Name 'Haut-parleurs (Logitech PRO X Gaming Headset)'
$VBAudioCables_A_PlaybackId = Get-ShortIdFromName -Name 'CABLE-A Input (VB-Audio Virtual Cable A)' # => default all applications sound
# $VBAudioCables_B_PlaybackId = Get-ShortIdFromName -Name 'CABLE-B Input (VB-Audio Virtual Cable B)' # => discord sound (set in Discord settings)

# ENTREES (RECORDING DEVICES)
# Note: CABLE-A Output and CABLE-B Output are connected to Voicemeeter as hardware inputs
# Voicemeeter handles the mixing and routing to physical outputs (Logitech, Realtek)
$VBAudioCables_A_RecorderId = Get-ShortIdFromName -Name 'CABLE-A Output (VB-Audio Virtual Cable A)' # Computer sounds for recording
# $VBAudioCables_B_RecorderId = Get-ShortIdFromName -Name 'CABLE-B Output (VB-Audio Virtual Cable B)' # Discord for recording
$VoicemeeterOut_B1_RecorderId = Get-ShortIdFromName -Name 'Voicemeeter Out B1 (VB-Audio Voicemeeter VAIO)' # Recording Track 1 (Microphone)
# $VoicemeeterOut_B2_RecorderId = Get-ShortIdFromName -Name 'Voicemeeter Out B2 (VB-Audio Voicemeeter VAIO)' # Recording Track 2 (Computer)
# $VoicemeeterOut_B3_RecorderId = Get-ShortIdFromName -Name 'Voicemeeter Out B3 (VB-Audio Voicemeeter VAIO)' # Recording Track 3 (Discord)

# -----



$PlaybackDefaultId = Get-CompleteId -Id $VBAudioCables_A_PlaybackId -IsPlayback 1
Write-Host " - Setting CABLE-A as default playback device (for computer sounds)" -ForegroundColor Yellow
Set-AudioDevice -ID $PlaybackDefaultId | Out-Null

# Note: Set Discord output to CABLE-B manually in Discord settings
Write-Host " - Remember: Set Discord output to 'CABLE-B Input' in Discord Voice settings" -ForegroundColor Cyan

# Set default recording device (optional - for applications that need to record)
$RecordDefaultId = Get-CompleteId -Id $VBAudioCables_A_RecorderId -IsPlayback 0
Write-Host " - Setting CABLE-A Output as default recording device" -ForegroundColor Yellow
Set-AudioDevice -ID $RecordDefaultId | Out-Null

# Set Voicemeeter Out B1 as the default communication device (microphone through Voicemeeter)
$MicrophoneCommunicationId = Get-CompleteId -Id $VoicemeeterOut_B1_RecorderId -IsPlayback 0
Write-Host " - Setting Voicemeeter Out B1 as default communication device (for Discord/Teams/etc)" -ForegroundColor Yellow
Set-AudioDevice -ID $MicrophoneCommunicationId -Communication | Out-Null

# Disable unused audio devices to reduce clutter
Write-Host "`n"
$devicesToKeep = @(
    # Playback devices (outputs) to keep enabled
    'Haut-parleurs (Realtek(R) Audio)',
    'Haut-parleurs (Logitech PRO X Gaming Headset)',
    'CABLE-A Input (VB-Audio Virtual Cable A)',
    'CABLE-B Input (VB-Audio Virtual Cable B)',
    'CABLE-C Input (VB-Audio Cable C)',
    'CABLE-D Input (VB-Audio Cable D)',
    
    # Recording devices (inputs) to keep enabled
    'CABLE-A Output (VB-Audio Virtual Cable A)',
    'CABLE-B Output (VB-Audio Virtual Cable B)',
    'CABLE-C Output (VB-Audio Cable C)',
    'CABLE-D Output (VB-Audio Cable D)',
    'Microphone (RODE NT-USB)',
    'Microphone (Logitech PRO X Gaming Headset)',
    'Voicemeeter Out B1 (VB-Audio Voicemeeter VAIO)',  # Mic recording
    'Voicemeeter Out B2 (VB-Audio Voicemeeter VAIO)',  # Computer recording
    'Voicemeeter Out B3 (VB-Audio Voicemeeter VAIO)'   # Discord recording
)

Disable-UnusedAudioDevices -DeviceNamesToKeepEnabled $devicesToKeep

Write-Host " - Restarting Windows Audio Service to apply changes..." -ForegroundColor Yellow
try {
    Restart-Service -Name $audioServiceName -Force -ErrorAction Stop
    Write-Host "   [OK] Audio service restarted successfully" -ForegroundColor Green
}
catch {
    Write-Host "   [ERROR] Could not restart audio service (requires administrator privileges)" -ForegroundColor Red
    Write-Host "   -> Please run this script as Administrator, or restart manually:" -ForegroundColor Yellow
    Write-Host "     1. Open Services (services.msc)" -ForegroundColor Gray
    Write-Host "     2. Find Windows Audio service" -ForegroundColor Gray
    Write-Host "     3. Right-click -> Restart" -ForegroundColor Gray
}

Write-Host "`n - Setup complete!" -ForegroundColor Green
Write-Host "   Your audio flow:" -ForegroundColor White
Write-Host "   1. Computer sounds -> CABLE-A -> Voicemeeter -> Logitech + Realtek" -ForegroundColor Gray
Write-Host "   2. Discord (set manually) -> CABLE-B -> Voicemeeter -> Logitech + Realtek" -ForegroundColor Gray
Write-Host "   3. In Voicemeeter: Enable A1, A2, B2 for Stereo Input 1 (CABLE-A)" -ForegroundColor Gray
Write-Host "   4. In Voicemeeter: Enable A1, A2, B3 for Stereo Input 2 (CABLE-B)" -ForegroundColor Gray
Write-Host "   5. For OBS: Use Voicemeeter Out B1, B2, B3 as separate audio tracks" -ForegroundColor Gray
Write-Host ""