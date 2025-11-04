# Script to fix Logitech headset device name
# Must be run as Administrator

# Source the privileges script
. "$PSScriptRoot\privileges.ps1"

$deviceGuid = 'b93d839f-f0b5-4c01-93a2-5e8b7190e263'
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\{$deviceGuid}"

Write-Host "`n=== Fixing Logitech Headset Device Name ===" -ForegroundColor Cyan
Write-Host "Device GUID: $deviceGuid" -ForegroundColor Gray

# Check if the registry key exists
if (Test-Path $registryPath) {
    Write-Host "`n[1] Found device registry key" -ForegroundColor Green
    
    # Enable SeRestorePrivilege to modify system registry
    try {
        Enable-Privilege SeRestorePrivilege
        Enable-Privilege SeTakeOwnershipPrivilege
        Write-Host "[2] Privileges enabled" -ForegroundColor Green
    }
    catch {
        Write-Host "[!] Warning: Could not enable all privileges. Some operations may fail." -ForegroundColor Yellow
    }
    
    # Show current name
    Write-Host "`n[3] Current device properties:" -ForegroundColor Yellow
    try {
        $properties = Get-ItemProperty -Path "$registryPath\Properties"
        $currentName = $properties.'{a45c254e-df1c-4efd-8020-67d146a850e0},2'
        if ($currentName) {
            Write-Host "    Current Name: $([System.Text.Encoding]::Unicode.GetString($currentName))" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "    Could not read current name" -ForegroundColor Red
    }
    
    # The correct friendly name should be
    $correctName = "Haut-parleurs (Logitech PRO X Gaming Headset)"
    Write-Host "`n[4] Setting new name to: $correctName" -ForegroundColor Yellow
    
    # Convert name to byte array (Unicode with null terminator)
    $nameBytes = [System.Text.Encoding]::Unicode.GetBytes($correctName + "`0")
    
    # Try to set the friendly name property
    $propertyPath = "$registryPath\Properties"
    $propertyName = '{a45c254e-df1c-4efd-8020-67d146a850e0},2'  # FriendlyName property
    
    try {
        Set-ItemProperty -Path $propertyPath -Name $propertyName -Value $nameBytes -Type Binary -Force
        Write-Host "[5] Device name updated successfully!" -ForegroundColor Green
        
        Write-Host "`n[6] Restarting Windows Audio Service..." -ForegroundColor Yellow
        Restart-Service -Name audiosrv -Force
        Write-Host "[7] Audio service restarted!" -ForegroundColor Green
        
        Write-Host "`n=== SUCCESS ===" -ForegroundColor Green
        Write-Host "Your Logitech headset should now show as:" -ForegroundColor White
        Write-Host "  $correctName" -ForegroundColor Cyan
        Write-Host "`nPlease verify with: Get-AudioDevice -List" -ForegroundColor Yellow
    }
    catch {
        Write-Host "`n[ERROR] Failed to update registry:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host "`nAlternative solutions:" -ForegroundColor Yellow
        Write-Host "1. Restart your computer (may automatically fix the name)" -ForegroundColor Gray
        Write-Host "2. Uninstall and reinstall Logitech G Hub software" -ForegroundColor Gray
        Write-Host "3. Unplug and replug the USB headset" -ForegroundColor Gray
    }
}
else {
    Write-Host "[ERROR] Registry key not found: $registryPath" -ForegroundColor Red
    Write-Host "The device GUID may have changed. Running device detection..." -ForegroundColor Yellow
    
    Write-Host "`nAll Logitech devices:" -ForegroundColor Cyan
    Get-AudioDevice -List | Where-Object { $_.Name -like '*Logitech*' } | Format-Table Index, Type, Name
}
