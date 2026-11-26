<#
.SYNOPSIS
    Removes the "Open with VS Code" entries that install.ps1 added.
#>
$ErrorActionPreference = 'Stop'
$KeyName = 'OpenWithVSCode'
$root = [Microsoft.Win32.Registry]::CurrentUser

foreach ($classPath in 'Directory', 'Directory\Background', 'Drive', '*') {
    $path = "Software\Classes\$classPath\shell\$KeyName"
    $existing = $root.OpenSubKey($path)
    if ($existing) {
        $existing.Close()
        $root.DeleteSubKeyTree($path, $false)
        Write-Host "  - removed $classPath" -ForegroundColor Yellow
    }
}
Write-Host "Done. The 'Open with VS Code' menu entries are gone." -ForegroundColor Cyan
