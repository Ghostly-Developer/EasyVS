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
1. Extract the zip (right-click it → **Extract All**).
2. Double-click **`Setup.cmd`**.
3. Click **Install**.

The setup window finds VS Code for you. You can also change the menu text, pick where the entry shows up, and (on Windows 11) skip **Show more options**.

After installing you can delete the extracted folder. Setup keeps its own copy in `%LOCALAPPDATA%\Programs\OpenWithVSCode`.

> **"Windows protected your PC"?** Windows shows this for downloaded scripts. Click **More info → Run anyway**. To avoid it, right-click the zip → **Properties** → tick **Unblock** before extracting.

## Windows 11
New right-click menus hide older entries under **Show more options**. Hold **Shift** while you right-click to go straight to the full menu.

To always get the full menu, tick **Skip "Show more options"** in setup. This changes the right-click menu for every app, not only this one. Untick it, or uninstall, to switch back.

## Change or uninstall
Like any other app: **Settings → Apps → Installed apps → Open with VS Code → ⋯**, then:
- **Modify** to reopen the setup window,
- **Uninstall** to remove everything.

Or run `Setup.cmd` again and click **Update** or **Uninstall**.

## Command line
```powershell
.\OpenWithVSCode.ps1                                  # setup window
.\OpenWithVSCode.ps1 -Install                         # install with defaults
.\OpenWithVSCode.ps1 -Install -NoFiles                # folders only, not files
.\OpenWithVSCode.ps1 -Install -Label "Code here"      # custom menu text
.\OpenWithVSCode.ps1 -Install -CodePath "D:\VSCode\Code.exe"
.\OpenWithVSCode.ps1 -Install -Locations Folder,Background
.\OpenWithVSCode.ps1 -Install -ClassicMenu            # Windows 11: skip "Show more options"
.\OpenWithVSCode.ps1 -Uninstall                       # add -Quiet for no output
```
If PowerShell blocks the script, run it as `powershell -ExecutionPolicy Bypass -File .\OpenWithVSCode.ps1 …`.

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
