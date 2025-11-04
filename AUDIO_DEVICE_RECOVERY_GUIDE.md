# Audio Device Recovery Guide

## Problem: VB-Audio Cable Installation Corrupts Device Names

When installing VB-Audio Cable C+D (or any additional audio drivers), Windows may incorrectly rename existing audio devices, breaking your audio routing configuration.

### Common Issues After Cable C+D Installation:
- Physical devices get renamed with "CABLE-C" or "CABLE-D" prefix
- Voicemeeter outputs get renamed or disappear
- Audio stops working completely
- Scripts fail because device names don't match

---

## Quick Fix Procedure

### Option 1: Rename via Windows Sound Settings (Easiest ✅)

1. **Open System Sounds Menu:**
   - Right-click Speaker icon in system tray
   - Click **"Sound settings"**
   - Scroll down and click **"More sound settings"** (or "Sound Control Panel")
   
2. **Fix Playback Devices:**
   - Go to **"Playback"** tab
   - Find devices with wrong names (e.g., "CABLE-C Input (Logitech...)")
   - Right-click → **"Properties"**
   - In the **"General"** tab, edit the device name field
   - Rename to the correct name from the list below
   - Click **OK** and **Apply**

3. **Fix Recording Devices:**
   - Go to **"Recording"** tab
   - Repeat the same process for any wrongly named recording devices

4. **Restart Audio Service:**
   - Open **Services** (Win+R → `services.msc`)
   - Find **"Windows Audio"**
   - Right-click → **Restart**

---

## Reference: Correct Device Names

### Playback Devices (Outputs)
```
✓ Haut-parleurs (Realtek(R) Audio)
✓ Haut-parleurs (Logitech PRO X Gaming Headset)
✓ CABLE-A Input (VB-Audio Virtual Cable A)
✓ CABLE-B Input (VB-Audio Virtual Cable B)
✓ CABLE-C Input (VB-Audio Cable C)          [if installed]
✓ CABLE-D Input (VB-Audio Cable D)          [if installed]
```

### Recording Devices (Inputs)
```
✓ CABLE-A Output (VB-Audio Virtual Cable A)
✓ CABLE-B Output (VB-Audio Virtual Cable B)
✓ CABLE-C Output (VB-Audio Cable C)         [if installed]
✓ CABLE-D Output (VB-Audio Cable D)         [if installed]
✓ Microphone (RODE NT-USB)
✓ Microphone (Logitech PRO X Gaming Headset)
✓ Voicemeeter Out B1 (VB-Audio Voicemeeter VAIO)
✓ Voicemeeter Out B2 (VB-Audio Voicemeeter VAIO)
✓ Voicemeeter Out B3 (VB-Audio Voicemeeter VAIO)
```

---

## Alternative Solutions

### Option 2: Restart Computer
Often the simplest solution - Windows will re-enumerate devices on reboot.

### Option 3: Uninstall and Reinstall VB-Audio Drivers

**Correct Installation Order:**
1. Uninstall ALL VB-Audio software (Cable A, B, C, D, and Voicemeeter)
2. **Reboot** (mandatory)
3. Reinstall in this order:
   - VB-Audio Cable (becomes Cable A)
   - VB-Audio Cable A+B
   - Voicemeeter Potato
   - VB-Audio Cable C+D (install LAST)
4. **Reboot** again (mandatory)

### Option 4: Physical Device Reset
For USB devices (like Logitech headsets):
1. Unplug from USB
2. Wait 10 seconds
3. Plug back in
4. Windows should detect it with correct name

---

## Prevention Tips

1. **Always reboot after installing/uninstalling audio drivers**
2. **Install VB-Audio drivers in the correct order** (A, B, Voicemeeter, then C+D)
3. **Keep a backup** of your Voicemeeter settings XML file
4. **Document your working device names** (like this file!)
5. **Close Voicemeeter** before installing new audio drivers

---

## Verification Script

Run this command to check all current device names:
```powershell
Get-AudioDevice -List | Format-Table Index, Type, Name -AutoSize
```

Or use the included script:
```powershell
.\check_devices.ps1
```

---

## What Causes This Problem?

VB-Audio Cable drivers register themselves in Windows' MMDevice registry. When installing Cable C+D:
- The installer may incorrectly associate existing device GUIDs with new driver names
- Physical hardware devices can be "captured" by virtual cable naming schemes
- Registry corruption occurs if audio service isn't properly restarted
- Missing reboot prevents proper device enumeration

The root issue is that Windows stores device "friendly names" in:
```
HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\{GUID}
HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture\{GUID}
```

When Cable C+D installer runs, it can overwrite these names for existing devices.

---

## Emergency Recovery

If nothing works:
1. Uninstall Cable C+D completely
2. Reboot
3. Check device names with `Get-AudioDevice -List`
4. If still broken, uninstall ALL VB-Audio products
5. Reboot
6. Reinstall in correct order with reboots between each

---

**Last Updated:** November 4, 2025  
**Working Configuration Snapshot:** All device names verified and documented above
