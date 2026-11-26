# Open with VS Code: right-click menu for Windows

Adds **Open with VS Code** to the File Explorer right-click menu:

| Where you right-click | What opens |
|---|---|
| A folder | That folder in VS Code |
| Empty space inside a folder | The current folder |
| A drive (C:\, D:\ …) | That drive |
| Any file | That file |

No admin rights needed. It only changes settings for your own Windows account.

## Install
It's a single file. Share either one as is, no zip needed:

| File | Icon | Notes |
|---|---|---|
| **`OpenWithVSCode.exe`** | Its own icon | Easiest to share |
| **`OpenWithVSCode.cmd`** | Standard script icon | Plain text: you can read exactly what it does |

1. Double-click the file.
2. Click **Install**.

The setup window finds VS Code for you. You can also change the menu text, pick where the entry shows up, and (on Windows 11) skip **Show more options**.

After installing you can delete the downloaded file. Setup keeps its own copy in `%LOCALAPPDATA%\Programs\OpenWithVSCode`.

> **"Windows protected your PC"?** Windows shows this for downloaded programs and scripts that aren't code-signed. Click **More info → Run anyway**, or right-click the file → **Properties** → tick **Unblock** first.

## Windows 11
New right-click menus hide older entries under **Show more options**. Hold **Shift** while you right-click to go straight to the full menu.

To always get the full menu, tick **Skip "Show more options"** in setup. This changes the right-click menu for every app, not only this one. Untick it, or uninstall, to switch back.

## Change or uninstall
Like any other app: **Settings → Apps → Installed apps → Open with VS Code → ⋯**, then:
- **Modify** to reopen the setup window,
- **Uninstall** to remove everything.

Or run the `.exe` or `.cmd` again and click **Update** or **Uninstall**.

## Command line
```bat
OpenWithVSCode.cmd                                   :: setup window
OpenWithVSCode.cmd -Install                          :: install with defaults
OpenWithVSCode.cmd -Install -NoFiles                 :: folders only, not files
OpenWithVSCode.cmd -Install -Label "Code here"       :: custom menu text
OpenWithVSCode.cmd -Install -CodePath "D:\VSCode\Code.exe"
OpenWithVSCode.cmd -Install -Locations Folder,Background
OpenWithVSCode.cmd -Install -ClassicMenu             :: Windows 11: skip "Show more options"
OpenWithVSCode.cmd -Uninstall                        :: add -Quiet for no output
```

The `.exe` takes the same options, but it has no console, so it prints nothing. Use it with `-Quiet` for scripted installs, or use the `.cmd` to see the output.

## How the single file works
`OpenWithVSCode.cmd` is a batch file and a PowerShell script in one. The few batch lines at the top are a comment to PowerShell. When run, they copy the file to `%TEMP%\OpenWithVSCode-setup.ps1` and start it with Windows PowerShell, which ships with Windows. To change the app, edit the PowerShell code below the `#>` line. Keep the file plain ASCII with Windows (CRLF) line endings so `cmd` reads it correctly.

`OpenWithVSCode.exe` is a small launcher ([build/Launcher.cs](build/Launcher.cs)) with `OpenWithVSCode.cmd` built in. When run, it writes the script to `%TEMP%` and starts it the same way. After editing the `.cmd`, rebuild the `.exe`:

```powershell
powershell -ExecutionPolicy Bypass -File .uilduild.ps1
```

This needs nothing beyond Windows: it draws the icon ([build/app.ico](build/app.ico)) and compiles with the C# compiler that ships with Windows. The version number comes from `$AppVersion` in the `.cmd`.

## Two "Open with" entries?
If you ticked **Add "Open with Code" action** when installing VS Code, its own entry shows up next to this one. To keep only this one, run the VS Code installer again and untick those options.

## What it changes
Everything is under `HKEY_CURRENT_USER` (`%V` = the folder clicked, `%1` = the file clicked):

```
Software\Classes\Directory\shell\OpenWithVSCode              "Code.exe" "%V"
Software\Classes\Directory\Background\shell\OpenWithVSCode   "Code.exe" "%V"
Software\Classes\Drive\shell\OpenWithVSCode                  "Code.exe" "%V"
Software\Classes\*\shell\OpenWithVSCode                      "Code.exe" "%1"
Software\Microsoft\Windows\CurrentVersion\Uninstall\OpenWithVSCode   (Installed apps entry)
Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}       (only if you skip "Show more options")
```

Uninstalling removes all of these and the `%LOCALAPPDATA%\Programs\OpenWithVSCode` folder. It only reverts the Windows 11 menu setting if this app turned it on.
