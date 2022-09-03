# SOUNT SETUP

## HOW TO LAUNCH

- Edit `enable_audio_cables.ps1` file, write the names of target Audio Devices.

- Execute `enable_audio_cables.ps1`.

- If errors (probably due to new registry keys not created yet):
    1) Go to Sound -> settings -> Recorders and enable/disable all **Listen to this device** property (and apply each time).
    2) Reboot computer.
    3) Execute `enable_audio_cables.ps1` once more.


---

## TO DO

- Create registry key with base value if does not exist