# Check current audio device names
Write-Host "`n=== ALL AUDIO DEVICES ===" -ForegroundColor Cyan
Get-AudioDevice -List | Format-Table Index, Type, Name -AutoSize

Write-Host "`n=== LOGITECH AND CABLE-C DEVICES ===" -ForegroundColor Yellow
Get-AudioDevice -List | Where-Object { $_.Name -like '*Logitech*' -or $_.Name -like '*CABLE-C*' } | Format-List Index, Type, Name, Id
