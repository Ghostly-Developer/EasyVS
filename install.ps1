<#
.SYNOPSIS
    Adds "Open with VS Code" to the Windows Explorer right-click menu.

.DESCRIPTION
    Adds the entry for:
      - folders            (right-click a folder)
      - folder background  (right-click empty space inside an open folder)
      - drives             (right-click C:\, D:\, ...)
      - files              (right-click any file; skip with -NoFiles)

    Writes only to HKEY_CURRENT_USER, so it needs no admin rights and
    affects only your Windows account.

.PARAMETER CodePath
    Full path to Code.exe. Leave it out and the script finds VS Code itself.

.PARAMETER Label
    Text shown in the menu. Default: "Open with VS Code".

.PARAMETER NoFiles
    Don't add the entry to the menu for files, only for folders.

.EXAMPLE
    .\install.ps1
.EXAMPLE
    .\install.ps1 -Label "Code here" -NoFiles
.EXAMPLE
    .\install.ps1 -CodePath "D:\Apps\VSCode\Code.exe"
#>
param(
    [string]$CodePath,
    [string]$Label = "Open with VS Code",
    [switch]$NoFiles
)

$ErrorActionPreference = 'Stop'
$KeyName = 'OpenWithVSCode'   # Our own key name, so we never touch the VS Code installer's entries

function Find-VSCode {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\Code.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft VS Code\Code.exe')
    )
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Microsoft VS Code\Code.exe')
    }
    $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code Insiders\Code - Insiders.exe')

    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }

    # Fall back to the "code" command on PATH (it lives in <install>\bin\code.cmd)
    $cmd = Get-Command code -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) {
        $installDir = Split-Path (Split-Path $cmd.Source -Parent) -Parent
        foreach ($exe in 'Code.exe', 'Code - Insiders.exe') {
            $p = Join-Path $installDir $exe
            if (Test-Path -LiteralPath $p) { return $p }
        }
    }

    # Last resort: the uninstall entries VS Code writes
    $uninstallRoots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($root in $uninstallRoots) {
        $entry = Get-ItemProperty $root -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like 'Microsoft Visual Studio Code*' -and $_.InstallLocation } |
            Select-Object -First 1
        if ($entry) {
            $p = Join-Path $entry.InstallLocation 'Code.exe'
            if (Test-Path -LiteralPath $p) { return $p }
        }
    }
    return $null
}

function Add-MenuEntry([string]$classPath, [string]$argument) {
    # Use .NET directly: PowerShell's registry provider treats "*" (all files) as a wildcard.
    $root = [Microsoft.Win32.Registry]::CurrentUser
    $key  = $root.CreateSubKey("Software\Classes\$classPath\shell\$KeyName")
    $key.SetValue('', $Label)
    $key.SetValue('Icon', "`"$CodePath`",0")
    $key.Close()

    $cmdKey = $root.CreateSubKey("Software\Classes\$classPath\shell\$KeyName\command")
    $cmdKey.SetValue('', "`"$CodePath`" `"$argument`"")
    $cmdKey.Close()
    Write-Host "  + $classPath" -ForegroundColor Green
}

if (-not $CodePath) { $CodePath = Find-VSCode }
if (-not $CodePath -or -not (Test-Path -LiteralPath $CodePath)) {
    Write-Host "Could not find Code.exe." -ForegroundColor Red
    Write-Host 'Run again with its path, e.g.:  .\install.ps1 -CodePath "C:\path\to\Code.exe"'
    exit 1
}

Write-Host "Using VS Code at: $CodePath"
Write-Host "Adding '$Label' to the right-click menu:"

Add-MenuEntry 'Directory'            '%V'   # right-click a folder
Add-MenuEntry 'Directory\Background' '%V'   # right-click inside a folder
Add-MenuEntry 'Drive'                '%V'   # right-click a drive
if (-not $NoFiles) {
    Add-MenuEntry '*'                '%1'   # right-click any file
}

Write-Host ""
Write-Host "Done. Right-click a folder to try it." -ForegroundColor Cyan
Write-Host "On Windows 11 it appears under 'Show more options' (or press Shift+F10)."
