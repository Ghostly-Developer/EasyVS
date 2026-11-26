# Open with VS Code: right-click menu for Windows

Adds **Open with VS Code** to the File Explorer right-click menu for:

| Where you right-click | What opens |
|---|---|
| A folder | That folder as a VS Code workspace |
| Empty space inside a folder | The current folder |
| A drive (C:\, D:\ …) | That drive |
| Any file | That file |

It only writes to your own user's registry (`HKEY_CURRENT_USER`), so it needs **no admin rights**.

## Install
1. Unzip this folder anywhere.
2. Double-click **`install.bat`**.
3. Right-click any folder → **Open with VS Code**.

> **Windows 11:** the entry is in the classic menu. Click **Show more options**, or hold **Shift** while right-clicking.

## Uninstall
Double-click **`uninstall.bat`**.

## Options (PowerShell)
```powershell
.\install.ps1 -NoFiles                          # folders only, not files
.\install.ps1 -Label "Code here"                # custom menu text
.\install.ps1 -CodePath "D:\VSCode\Code.exe"    # VS Code installed somewhere unusual
```

The script finds VS Code on its own. It checks the default user and system install paths, VS Code Insiders, the `code` command on your PATH and the uninstall registry.

## How it works
It creates these registry keys (`%V` = the folder clicked, `%1` = the file clicked):

```
HKCU\Software\Classes\Directory\shell\OpenWithVSCode              "Code.exe" "%V"
HKCU\Software\Classes\Directory\Background\shell\OpenWithVSCode   "Code.exe" "%V"
HKCU\Software\Classes\Drive\shell\OpenWithVSCode                  "Code.exe" "%V"
HKCU\Software\Classes\*\shell\OpenWithVSCode                      "Code.exe" "%1"
```

If you ticked "Add 'Open with Code' action" when installing VS Code, you may see two entries. Untick that option by reinstalling, or keep only one of them.
