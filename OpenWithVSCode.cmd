<# : Batch launcher. PowerShell reads everything up to the closing mark below as a comment.
@echo off
rem Double-click to open the "Open with VS Code" setup window.
rem Command line: OpenWithVSCode.cmd -Install [-NoFiles] [-Label "..."] [-ClassicMenu] | -Uninstall
set "OWV_PS1=%TEMP%\OpenWithVSCode-setup.ps1"
copy /y "%~f0" "%OWV_PS1%" >nul || (echo Could not write to the TEMP folder. & pause & exit /b 1)
if "%~1"=="" (
    start "" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%OWV_PS1%"
) else (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%OWV_PS1%" %*
)
exit /b %errorlevel%
#>
<#
.SYNOPSIS
    Adds "Open with VS Code" to the Windows File Explorer right-click menu.

.DESCRIPTION
    Run it with no arguments (double-click OpenWithVSCode.cmd or .exe) to open the setup window.

    Installing:
      - adds the menu entry for folders, folder backgrounds, drives and files
      - copies this script to %LOCALAPPDATA%\Programs\OpenWithVSCode
      - lists "Open with VS Code" in Settings > Apps > Installed apps, so it can
        be changed or uninstalled from there like any other app

    Everything goes into HKEY_CURRENT_USER: no admin rights are needed and only
    your own Windows account is affected.

.PARAMETER Install
    Install (or update) without opening the setup window.

.PARAMETER Uninstall
    Remove everything this script added, without opening the setup window.

.PARAMETER CodePath
    Full path to Code.exe. Leave it out and the script finds VS Code itself.

.PARAMETER Label
    Text shown in the menu. Default: "Open with VS Code".

.PARAMETER Locations
    Where the entry appears: Folder, Background, Drive, File. Default: all four.

.PARAMETER NoFiles
    Shortcut for leaving File out of -Locations.

.PARAMETER ClassicMenu
    Windows 11 only. -ClassicMenu makes right-click show the full menu straight
    away, so the entry is no longer hidden under "Show more options".
    -ClassicMenu:$false turns that back off. Applies to your whole account and
    takes effect after File Explorer restarts (or you sign out and back in).

.PARAMETER Quiet
    No console output and no pop-ups.

.EXAMPLE
    OpenWithVSCode.cmd
    Opens the setup window.
.EXAMPLE
    OpenWithVSCode.cmd -Install -NoFiles -Label "Code here"
.EXAMPLE
    OpenWithVSCode.cmd -Install -CodePath "D:\Apps\VSCode\Code.exe"
.EXAMPLE
    OpenWithVSCode.cmd -Uninstall
#>
param(
    [switch]$Install,
    [switch]$Uninstall,
    [string]$CodePath,
    [string]$Label = 'Open with VS Code',
    [ValidateSet('Folder', 'Background', 'Drive', 'File')]
    [string[]]$Locations = @('Folder', 'Background', 'Drive', 'File'),
    [switch]$NoFiles,
    [switch]$ClassicMenu,
    [switch]$Quiet,
    [switch]$Popup   # Used by the Settings "Uninstall" button: report the result in a message box.
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
$AppName        = 'Open with VS Code'
$AppId          = 'OpenWithVSCode'   # Our own key name, so we never touch the VS Code installer's entries
$AppVersion     = '2.0.0'
$ScriptFileName = 'OpenWithVSCode.ps1'
$InstallDir     = Join-Path $env:LOCALAPPDATA 'Programs\OpenWithVSCode'
$UninstallKey   = "Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppId"
# Windows 11: an empty InprocServer32 under this CLSID brings back the full (classic) right-click menu.
$ClassicMenuKey = 'Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
$PowerShellExe  = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$IsWin11        = [Environment]::OSVersion.Version.Build -ge 22000

# Where the entry can appear. %V = the folder clicked, %1 = the file clicked.
$Places = [ordered]@{
    Folder     = @{ Class = 'Directory';            Arg = '%V'; Text = 'Folders' }
    Background = @{ Class = 'Directory\Background'; Arg = '%V'; Text = 'Empty space inside a folder' }
    Drive      = @{ Class = 'Drive';                Arg = '%V'; Text = 'Drives (C:\, D:\ ...)' }
    File       = @{ Class = '*';                    Arg = '%1'; Text = 'Files' }
}

# Use .NET for the registry: PowerShell's registry provider treats "*" (all files) as a wildcard.
$HKCU = [Microsoft.Win32.Registry]::CurrentUser

# ---------------------------------------------------------------------------
# Registry helpers
# ---------------------------------------------------------------------------
function Test-Key([string]$Path) {
    $k = $HKCU.OpenSubKey($Path)
    if ($k) { $k.Close(); return $true }
    return $false
}

function Get-Value([string]$Path, [string]$Name) {
    $k = $HKCU.OpenSubKey($Path)
    if (-not $k) { return $null }
    try { return $k.GetValue($Name) } finally { $k.Close() }
}

function Remove-Key([string]$Path) {
    if (Test-Key $Path) { $HKCU.DeleteSubKeyTree($Path, $false) }
}

function Get-MenuKeyPath([string]$Place) {
    "Software\Classes\$($Places[$Place].Class)\shell\$AppId"
}

# ---------------------------------------------------------------------------
# Finding VS Code
# ---------------------------------------------------------------------------
function Find-VSCode {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\Code.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft VS Code\Code.exe')
    )
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Microsoft VS Code\Code.exe')
    }
    $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code Insiders\Code - Insiders.exe')
    $candidates += (Join-Path $env:ProgramFiles 'Microsoft VS Code Insiders\Code - Insiders.exe')

    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c -PathType Leaf) { return $c }
    }

    # The "code" command on PATH lives in <install>\bin\code.cmd
    $cmd = Get-Command code -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd -and $cmd.Source) {
        $installDir = Split-Path (Split-Path $cmd.Source -Parent) -Parent
        foreach ($exe in 'Code.exe', 'Code - Insiders.exe') {
            $p = Join-Path $installDir $exe
            if (Test-Path -LiteralPath $p -PathType Leaf) { return $p }
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
            if (Test-Path -LiteralPath $p -PathType Leaf) { return $p }
        }
    }
    return $null
}

# True if the VS Code installer added its own "Open with Code" entry (you'd see two).
function Test-VSCodeOwnEntry {
    foreach ($hive in [Microsoft.Win32.Registry]::CurrentUser, [Microsoft.Win32.Registry]::LocalMachine) {
        foreach ($name in 'VSCode', 'VSCodeInsiders') {
            $k = $hive.OpenSubKey("Software\Classes\Directory\shell\$name")
            if ($k) { $k.Close(); return $true }
        }
    }
    return $false
}

# ---------------------------------------------------------------------------
# Current state
# ---------------------------------------------------------------------------
function Get-State {
    $placesFound = @()
    $menuText = $null
    $exe = $null
    foreach ($name in $Places.Keys) {
        $key = Get-MenuKeyPath $name
        if (Test-Key $key) {
            $placesFound += $name
            if (-not $menuText) { $menuText = Get-Value $key '' }
            if (-not $exe) {
                $cmd = Get-Value "$key\command" ''
                if ($cmd -match '^"([^"]+)"') { $exe = $Matches[1] }
            }
        }
    }
    $registered = Test-Key $UninstallKey
    [pscustomobject]@{
        Installed      = $registered -or $placesFound.Count -gt 0
        Registered     = $registered
        Places         = $placesFound
        Label          = $menuText
        CodePath       = $exe
        CodeFound      = [bool]($exe -and (Test-Path -LiteralPath $exe -PathType Leaf))
        ClassicMenu    = Test-Key "$ClassicMenuKey\InprocServer32"
        VSCodeOwnEntry = Test-VSCodeOwnEntry
    }
}

# ---------------------------------------------------------------------------
# Install / uninstall
# ---------------------------------------------------------------------------
function Set-MenuEntry([string]$Place, [string]$Exe, [string]$MenuText) {
    $path = Get-MenuKeyPath $Place
    $key = $HKCU.CreateSubKey($path)
    $key.SetValue('', $MenuText)
    $key.SetValue('Icon', "`"$Exe`",0")
    $key.Close()

    $cmdKey = $HKCU.CreateSubKey("$path\command")
    $cmdKey.SetValue('', "`"$Exe`" `"$($Places[$Place].Arg)`"")
    $cmdKey.Close()
}

# Turns the Windows 11 full right-click menu on or off. Returns $true if anything changed.
function Set-ClassicMenu([bool]$On) {
    $isOn = Test-Key "$ClassicMenuKey\InprocServer32"
    if ($On -eq $isOn) { return $false }
    if ($On) {
        $k = $HKCU.CreateSubKey("$ClassicMenuKey\InprocServer32")
        $k.SetValue('', '')
        $k.Close()
    } else {
        Remove-Key $ClassicMenuKey
    }
    return $true
}

# Returns $true if File Explorer needs a restart for the change to show.
function Install-App {
    param(
        [string]$Exe,
        [string]$MenuText,
        [string[]]$Where,
        [object]$Classic = $null   # $true / $false to change the Windows 11 menu setting, $null to leave it
    )
    if (-not $Exe -or -not (Test-Path -LiteralPath $Exe -PathType Leaf)) {
        throw "Code.exe was not found at:`n$Exe"
    }
    if ([string]::IsNullOrWhiteSpace($MenuText)) { throw 'The menu text cannot be empty.' }
    if (-not $Where -or $Where.Count -eq 0) { throw 'Pick at least one place for the menu entry.' }
    if (-not $PSCommandPath) { throw 'Run this from OpenWithVSCode.cmd or OpenWithVSCode.exe.' }

    # 1. Keep a copy of this script, so uninstalling works after the download folder is deleted.
    $target = Join-Path $InstallDir $ScriptFileName
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    $source = [IO.Path]::GetFullPath($PSCommandPath)
    if ($source -ne [IO.Path]::GetFullPath($target)) {
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
    try { Unblock-File -LiteralPath $target } catch { }

    # 2. Menu entries: add the chosen places, remove the others.
    foreach ($name in $Places.Keys) {
        if ($Where -contains $name) { Set-MenuEntry $name $Exe $MenuText.Trim() }
        else { Remove-Key (Get-MenuKeyPath $name) }
    }

    # 3. Windows 11 full menu (only remember that we turned it on, so uninstall reverts only our change).
    $classicOurs = [int](Get-Value $UninstallKey 'ClassicMenuSetByUs' -as [int])
    $restart = $false
    if ($IsWin11 -and $null -ne $Classic) {
        $restart = Set-ClassicMenu ([bool]$Classic)
        if ($restart) { $classicOurs = [int][bool]$Classic }
    }

    # 4. The entry in Settings > Apps > Installed apps.
    $run = "`"$PowerShellExe`" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$target`""
    $k = $HKCU.CreateSubKey($UninstallKey)
    $k.SetValue('DisplayName', $AppName)
    $k.SetValue('DisplayVersion', $AppVersion)
    $k.SetValue('Publisher', $AppName)
    $k.SetValue('DisplayIcon', "$Exe,0")
    $k.SetValue('InstallLocation', $InstallDir)
    $k.SetValue('InstallDate', (Get-Date -Format 'yyyyMMdd'))
    $k.SetValue('UninstallString', "$run -Uninstall -Popup")
    $k.SetValue('QuietUninstallString', "$run -Uninstall -Quiet")
    $k.SetValue('ModifyPath', $run)
    $k.SetValue('NoRepair', 1, [Microsoft.Win32.RegistryValueKind]::DWord)
    $k.SetValue('EstimatedSize', [int][Math]::Max(1, [Math]::Ceiling((Get-Item -LiteralPath $target).Length / 1KB)), [Microsoft.Win32.RegistryValueKind]::DWord)
    $k.SetValue('ClassicMenuSetByUs', $classicOurs, [Microsoft.Win32.RegistryValueKind]::DWord)
    $k.Close()

    return $restart
}

# Returns $true if File Explorer needs a restart for the change to show.
function Uninstall-App {
    foreach ($name in $Places.Keys) { Remove-Key (Get-MenuKeyPath $name) }

    $restart = $false
    if ((Get-Value $UninstallKey 'ClassicMenuSetByUs') -eq 1 -and (Test-Key $ClassicMenuKey)) {
        Remove-Key $ClassicMenuKey
        $restart = $true
    }
    Remove-Key $UninstallKey

    if (Test-Path -LiteralPath $InstallDir) {
        # Don't hold the folder open as the working directory.
        Set-Location -LiteralPath $env:TEMP
        [Environment]::CurrentDirectory = $env:TEMP
        try {
            Remove-Item -LiteralPath $InstallDir -Recurse -Force
        } catch {
            # Still in use (e.g. this script is running from there): delete it a moment later.
            Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -WindowStyle Hidden `
                -ArgumentList "/c ping -n 3 127.0.0.1 >nul & rmdir /s /q `"$InstallDir`""
        }
    }
    return $restart
}

function Restart-Explorer {
    Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
    # Windows normally restarts Explorer by itself; start it if it hasn't come back.
    for ($i = 0; $i -lt 10; $i++) {
        Start-Sleep -Milliseconds 500
        if (Get-Process explorer -ErrorAction SilentlyContinue) { return }
    }
    Start-Process explorer.exe
}

# ---------------------------------------------------------------------------
# Setup window
# ---------------------------------------------------------------------------
function Show-Message([string]$Text, [string]$Icon = 'Information', [string]$Buttons = 'OK', $Owner = $null) {
    Add-Type -AssemblyName System.Windows.Forms
    if ($Owner) { return [Windows.Forms.MessageBox]::Show($Owner, $Text, $AppName, $Buttons, $Icon) }
    return [Windows.Forms.MessageBox]::Show($Text, $AppName, $Buttons, $Icon)
}

function Confirm-ExplorerRestart($Owner = $null) {
    $answer = Show-Message -Owner $Owner -Icon Question -Buttons YesNo -Text (
        "The right-click menu change takes effect after File Explorer restarts.`n`n" +
        "Restart File Explorer now? Open Explorer windows will close.")
    if ($answer -eq 'Yes') { Restart-Explorer }
}

function Show-Gui {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    try {
        Add-Type -Namespace OpenWithVSCodeSetup -Name Native -MemberDefinition `
            '[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
        [void][OpenWithVSCodeSetup.Native]::SetProcessDPIAware()
    } catch { }
    [Windows.Forms.Application]::EnableVisualStyles()

    $g = [Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
    $scale = $g.DpiX / 96
    $g.Dispose()
    function px([double]$n) { [int][Math]::Round($n * $scale) }
    function Pad($l, $t, $r, $b) { New-Object Windows.Forms.Padding (px $l), (px $t), (px $r), (px $b) }

    $W     = px 460
    $font  = New-Object Drawing.Font('Segoe UI', 9)
    $muted = [Drawing.Color]::FromArgb(96, 96, 96)
    $s     = Get-State
    $ui    = @{ Checks = [ordered]@{} }

    $form = New-Object Windows.Forms.Form
    $form.Text            = "$AppName - Setup"
    $form.Font            = $font
    $form.AutoScaleMode   = 'None'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox     = $false
    $form.MinimizeBox     = $false
    $form.StartPosition   = 'CenterScreen'

    $root = New-Object Windows.Forms.TableLayoutPanel
    $root.ColumnCount  = 1
    $root.AutoSize     = $true
    $root.AutoSizeMode = 'GrowAndShrink'
    $root.Location     = New-Object Drawing.Point((px 16), (px 12))
    $form.Controls.Add($root)

    function Add-Row($control, $margin = $null) {
        if ($margin) { $control.Margin = $margin }
        [void]$root.Controls.Add($control)
        $control
    }
    function New-Label([string]$Text, $Color = $null, $Font = $null) {
        $l = New-Object Windows.Forms.Label
        $l.Text = $Text
        $l.AutoSize = $true
        $l.MaximumSize = New-Object Drawing.Size($W, 0)
        if ($Color) { $l.ForeColor = $Color }
        if ($Font) { $l.Font = $Font }
        $l
    }

    # Header
    [void](Add-Row (New-Label $AppName $null (New-Object Drawing.Font('Segoe UI Semibold', 14))) (Pad 0 0 0 0))
    [void](Add-Row (New-Label 'Adds an entry to the File Explorer right-click menu. No admin rights needed.' $muted) (Pad 2 0 0 6))
    $ui.Status = Add-Row (New-Label '' $null (New-Object Drawing.Font('Segoe UI Semibold', 9))) (Pad 2 4 0 10)

    # VS Code path
    [void](Add-Row (New-Label 'VS Code program (Code.exe)') (Pad 2 0 0 2))
    $codeRow = New-Object Windows.Forms.TableLayoutPanel
    $codeRow.ColumnCount = 2
    $codeRow.AutoSize = $true
    $ui.Code = New-Object Windows.Forms.TextBox
    $ui.Code.Width = $W - (px 96)
    $ui.Code.Margin = Pad 0 1 6 0
    $browse = New-Object Windows.Forms.Button
    $browse.Text = 'Browse...'
    $browse.AutoSize = $true
    $browse.MinimumSize = New-Object Drawing.Size((px 88), 0)
    $browse.Margin = Pad 0 0 0 0
    $codeRow.Controls.Add($ui.Code, 0, 0)
    $codeRow.Controls.Add($browse, 1, 0)
    [void](Add-Row $codeRow (Pad 0 0 0 10))

    # Menu text
    [void](Add-Row (New-Label 'Menu text') (Pad 2 0 0 2))
    $ui.Label = New-Object Windows.Forms.TextBox
    $ui.Label.Width = $W
    [void](Add-Row $ui.Label (Pad 0 0 0 12))

    # Places
    [void](Add-Row (New-Label 'Show it when you right-click' $null (New-Object Drawing.Font('Segoe UI Semibold', 9))) (Pad 2 0 0 2))
    foreach ($name in $Places.Keys) {
        $c = New-Object Windows.Forms.CheckBox
        $c.Text = $Places[$name].Text
        $c.AutoSize = $true
        $ui.Checks[$name] = Add-Row $c (Pad 10 1 0 1)
    }

    # Windows 11 full menu
    if ($IsWin11) {
        $ui.Classic = New-Object Windows.Forms.CheckBox
        $ui.Classic.Text = 'Skip "Show more options" (show the full menu right away)'
        $ui.Classic.AutoSize = $true
        [void](Add-Row $ui.Classic (Pad 2 12 0 0))
        $hint = New-Label ('Windows 11 setting for your account: right-click shows the classic menu for every app. ' +
            'Without it, the entry is under "Show more options" (or hold Shift when you right-click).') $muted
        $hint.MaximumSize = New-Object Drawing.Size(($W - (px 20)), 0)
        [void](Add-Row $hint (Pad 20 0 0 0))
    }

    if ($s.VSCodeOwnEntry) {
        [void](Add-Row (New-Label ('Note: the VS Code installer also added its own "Open with Code" entry, so you may see two. ' +
            'To drop that one, run the VS Code installer again and untick its "Open with Code" options.') $muted) (Pad 2 12 0 0))
    }

    # Buttons
    $buttons = New-Object Windows.Forms.TableLayoutPanel
    $buttons.ColumnCount = 2
    $buttons.AutoSize = $true
    $buttons.Anchor = 'Left, Right'
    [void]$buttons.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('AutoSize')))
    [void]$buttons.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent', 100)))
    function New-Button([string]$Text) {
        $b = New-Object Windows.Forms.Button
        $b.Text = $Text
        $b.AutoSize = $true
        $b.MinimumSize = New-Object Drawing.Size((px 96), (px 30))
        $b.Margin = Pad 6 0 0 0
        $b
    }
    $ui.Uninstall = New-Button 'Uninstall'
    $ui.Uninstall.Margin = Pad 0 0 0 0
    $ui.Install = New-Button 'Install'
    $close = New-Button 'Close'
    $close.DialogResult = 'Cancel'
    $right = New-Object Windows.Forms.FlowLayoutPanel
    $right.FlowDirection = 'RightToLeft'
    $right.WrapContents = $false
    $right.AutoSize = $true
    $right.Dock = 'Fill'
    $right.Margin = Pad 0 0 0 0
    $right.Controls.AddRange(@($close, $ui.Install))
    $buttons.Controls.Add($ui.Uninstall, 0, 0)
    $buttons.Controls.Add($right, 1, 0)
    [void](Add-Row $buttons (Pad 0 18 0 0))

    $form.AcceptButton = $ui.Install
    $form.CancelButton = $close
    $form.Add_Shown({ $ui.Install.Focus() })

    # Fill in the current settings
    if ($s.CodeFound) { $ui.Code.Text = $s.CodePath }
    else {
        $found = Find-VSCode
        if ($found) { $ui.Code.Text = $found } elseif ($s.CodePath) { $ui.Code.Text = $s.CodePath }
    }
    if ($s.Label) { $ui.Label.Text = $s.Label } else { $ui.Label.Text = $Label }
    foreach ($name in $Places.Keys) {
        $ui.Checks[$name].Checked = ($s.Places.Count -eq 0) -or ($s.Places -contains $name)
    }
    if ($ui.Classic) { $ui.Classic.Checked = $s.ClassicMenu }
    if ($ui.Code.Text -and (Test-Path -LiteralPath $ui.Code.Text -PathType Leaf)) {
        try { $form.Icon = [Drawing.Icon]::ExtractAssociatedIcon($ui.Code.Text) } catch { }
    }

    function Update-Status {
        $st = Get-State
        if (-not $st.Installed) {
            $ui.Status.Text = 'Not installed yet.'
            $ui.Status.ForeColor = $muted
            $ui.Install.Text = 'Install'
            $ui.Uninstall.Enabled = $false
        } elseif (-not $st.CodeFound) {
            $ui.Status.Text = "Installed, but VS Code is no longer at $($st.CodePath). Check the path below and click Update."
            $ui.Status.ForeColor = [Drawing.Color]::FromArgb(176, 96, 0)
            $ui.Install.Text = 'Update'
            $ui.Uninstall.Enabled = $true
        } else {
            $ui.Status.Text = 'Installed. Change anything below and click Update.'
            $ui.Status.ForeColor = [Drawing.Color]::FromArgb(16, 124, 16)
            $ui.Install.Text = 'Update'
            $ui.Uninstall.Enabled = $true
        }
    }
    Update-Status

    # Events
    $browse.Add_Click({
        $dlg = New-Object Windows.Forms.OpenFileDialog
        $dlg.Title = 'Find Code.exe'
        $dlg.Filter = 'VS Code (Code.exe)|Code.exe;Code - Insiders.exe|Programs (*.exe)|*.exe'
        $current = $ui.Code.Text.Trim('" ')
        if ($current -and (Test-Path -LiteralPath (Split-Path $current -Parent) -ErrorAction SilentlyContinue)) {
            $dlg.InitialDirectory = Split-Path $current -Parent
        }
        if ($dlg.ShowDialog($form) -eq 'OK') { $ui.Code.Text = $dlg.FileName }
    })

    $ui.Install.Add_Click({
        try {
            $where = @($Places.Keys | Where-Object { $ui.Checks[$_].Checked })
            $classic = $null
            if ($ui.Classic) { $classic = $ui.Classic.Checked }
            $form.UseWaitCursor = $true
            $restart = Install-App -Exe $ui.Code.Text.Trim('" ') -MenuText $ui.Label.Text -Where $where -Classic $classic
            $form.UseWaitCursor = $false
            Update-Status
            $msg = 'Done. Right-click a folder in File Explorer to try it.'
            if ($IsWin11 -and -not $ui.Classic.Checked) {
                $msg += "`n`nOn Windows 11 it's under ""Show more options"" (or hold Shift while you right-click)."
            }
            [void](Show-Message -Owner $form -Text $msg)
            if ($restart) { Confirm-ExplorerRestart $form }
        } catch {
            $form.UseWaitCursor = $false
            [void](Show-Message -Owner $form -Icon Error -Text "Couldn't install:`n`n$($_.Exception.Message)")
        }
    })

    $ui.Uninstall.Add_Click({
        $answer = Show-Message -Owner $form -Icon Question -Buttons YesNo -Text "Remove ""$($ui.Label.Text)"" from the right-click menu?"
        if ($answer -ne 'Yes') { return }
        try {
            $restart = Uninstall-App
            Update-Status
            [void](Show-Message -Owner $form -Text 'Removed. The right-click menu entry is gone.')
            if ($restart) { Confirm-ExplorerRestart $form }
        } catch {
            [void](Show-Message -Owner $form -Icon Error -Text "Couldn't uninstall:`n`n$($_.Exception.Message)")
        }
    })

    # Size the window to its contents.
    $root.PerformLayout()
    $pref = $root.GetPreferredSize([Drawing.Size]::Empty)
    $form.ClientSize = New-Object Drawing.Size(($pref.Width + (px 32)), ($pref.Height + (px 28)))

    [void]$form.ShowDialog()
    $form.Dispose()
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
function Write-Info([string]$Text, [string]$Color = 'Gray') {
    if (-not $Quiet) { Write-Host $Text -ForegroundColor $Color }
}

try {
    if ($Install -and $Uninstall) { throw 'Use -Install or -Uninstall, not both.' }

    if ($Uninstall) {
        $restart = Uninstall-App
        if ($Popup -and -not $Quiet) {
            [void](Show-Message -Text "$AppName was removed from the right-click menu.")
            if ($restart) { Confirm-ExplorerRestart }
        } else {
            Write-Info "Removed $AppName from the right-click menu." 'Cyan'
            if ($restart) { Write-Info 'Restart File Explorer (or sign out and in) to bring back the Windows 11 menu.' }
        }
    }
    elseif ($Install) {
        if (-not $CodePath) {
            $state = Get-State
            if ($state.CodeFound) { $CodePath = $state.CodePath } else { $CodePath = Find-VSCode }
        }
        if (-not $CodePath) { throw 'Could not find Code.exe. Run again with its path, e.g.: -CodePath "C:\path\to\Code.exe"' }

        $where = @($Locations | Where-Object { -not ($NoFiles -and $_ -eq 'File') })
        $classic = $null
        if ($PSBoundParameters.ContainsKey('ClassicMenu')) {
            if ($IsWin11) { $classic = $ClassicMenu.IsPresent }
            else { Write-Info '-ClassicMenu only applies to Windows 11; ignoring it.' 'Yellow' }
        }

        $restart = Install-App -Exe $CodePath -MenuText $Label -Where $where -Classic $classic
        Write-Info "Using VS Code at: $CodePath"
        Write-Info "Added '$Label' to the right-click menu for: $($where -join ', ')" 'Green'
        Write-Info "Listed in Settings > Apps > Installed apps as '$AppName'."
        if ($restart) { Write-Info 'Restart File Explorer (or sign out and in) for the Windows 11 menu change.' 'Yellow' }
        elseif ($IsWin11 -and -not (Get-State).ClassicMenu) {
            Write-Info "On Windows 11 it's under 'Show more options' (or hold Shift while you right-click)."
        }
    }
    else {
        Show-Gui
    }
}
catch {
    $message = $_.Exception.Message
    if ((-not $Install -and -not $Uninstall) -or ($Popup -and -not $Quiet)) {
        [void](Show-Message -Icon Error -Text $message)
    } else {
        if (-not $Quiet) { Write-Host $message -ForegroundColor Red }
    }
    exit 1
}
