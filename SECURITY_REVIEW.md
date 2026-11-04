# Security review guide

Everything the installer can do is in two plain-text files: `installer/Install.bat` (11 lines) and
`installer/Installer.ps1`. Line numbers below refer to the files in this repository.

## Quick facts

| Question | Answer |
|---|---|
| Compiled or obfuscated code? | None. The script is readable text. |
| Binaries in the repository / zip? | None. No `.exe`, no `.dll`. |
| Network access | Downloads from `reshade.me` (lines 179 and 225 of `Installer.ps1`) and from `github.com` (line 268, the list at the top of the script). Nothing else. |
| Downloaded code executed? | No. The ReShade setup is saved to a temp folder and only **read** as a file; `ReShade64.dll` is extracted from the archive appended to it (`Export-ReShadeDll`, lines 190-216) and written as `dxgi.dll`. The setup is never run. The GitHub downloads are zip files from which five named shader text files are copied out (`Install-DownloadedShaders`, lines 259-306). Nothing from them is run by the installer. |
| Registry | **Read only**, to find Steam and the Bethesda launcher (lines 88 and 116). No registry writes. |
| Persistence | None: no startup entries, scheduled tasks or services. |
| Elevation | The script never asks for administrator rights. If the game folder is not writable it tells the user to run it as administrator themselves. |
| Data collected or sent | None. Nothing is uploaded; the log stays in a local text file. |
| `-ExecutionPolicy Bypass` | Line 11 of `Install.bat`. Applies to that one PowerShell process only, so an unsigned script can start when double-clicked. It changes no system setting. |
| Dynamic code | None: no `Invoke-Expression`, no encoded commands, no downloaded scripts, no `Start-Process`. (Search the script for them.) |

## The network requests

| Line | Code | Purpose |
|---|---|---|
| 179 | `Invoke-WebRequest -Uri 'https://reshade.me/' ...` | Reads the home page to find the newest ReShade version number (regex `ReShade_Setup_<version>.exe`). Falls back to a fixed version if it fails. |
| 225 | `Invoke-WebRequest -Uri "https://reshade.me/downloads/ReShade_Setup_$ver.exe" -OutFile $setup ...` | Downloads the official standard ReShade setup into a temporary folder. |
| 268 | `Invoke-WebRequest -Uri $u -OutFile $zip ...` inside `Install-DownloadedShaders` | Downloads the repository zip files named in `$DownloadSources` (top of the script): `github.com/martymcmodding/qUINT` and `github.com/crosire/reshade-shaders`. Only the five files named there are copied out of them. |

## Where it writes

| What | Where | Function / lines |
|---|---|---|
| ReShade DLL | `<game folder>\dxgi.dll` (an existing one is first copied to `dxgi.dll.vii-backup`) | `Install-ReShadeDll`, 218-234 |
| Bundled shaders and textures | `<game folder>\reshade-shaders\...` | `Copy-Tree`, 237-257 |
| Downloaded shader files | `<game folder>\reshade-shaders\Shaders\...` | `Install-DownloadedShaders`, 259-306 |
| Presets | `<game folder>\VII Next-Gen Appalachia 4.0 (...).ini` | `Invoke-Install` |
| ReShade settings | `<game folder>\ReShade.ini` (an existing one is first copied to `ReShade.ini.vii-backup`); keys edited by `Set-IniValue` | `Invoke-Install`, `Set-IniValue` 149-175 |
| Write test | a tiny file `.vii_write_test` in the game folder, deleted immediately | 316 |
| Temp files | the downloaded setup, zips and work folder under the Windows temp folder, deleted at the end | 372 |
| Log | `install-log.txt` next to the installer | `Write-Log`, 71-81 |

## Everything that deletes files

| Lines | What | When |
|---|---|---|
| 249 and 293 | An older copy of a bundled or downloaded shader/texture with the same file name elsewhere inside `<game>\reshade-shaders` | Install. Prevents effects loading twice after an upgrade. |
| 316 | The `.vii_write_test` probe file | Install |
| 372 | The installer's own temp work folder | End of install |
| 387-388 | `dxgi.dll` (restores `dxgi.dll.vii-backup` if there was one) | Uninstall only |
| 391-395 | `ReShade.ini`, its backup, `ReShade.log`, `ReShadePreset.ini`, the VII preset files | Uninstall only |
| 399 | The `reshade-shaders` folder | Uninstall only, after a confirmation box |
| 402 | ReShade's shader cache in the Windows temp folder | Uninstall only |

Uninstall always asks for confirmation in the window and only acts inside the folder the user selected
(it first checks that `Fallout76.exe` is there).

## Suggested review in five minutes

1. Read `Install.bat` (11 lines).
2. In `Installer.ps1`, search for `Invoke-WebRequest` (3 hits), `Get-ItemProperty` (2 hits, registry reads),
   `Remove-Item` / `Move-Item` (all listed above), and for `Invoke-Expression`, `iex`, `Start-Process`,
   `-EncodedCommand`, `FromBase64`, `Set-ItemProperty`, `New-ItemProperty`, `schtasks`,
   `Register-ScheduledTask` (no hits).
3. Read `Export-ReShadeDll` (lines 190-216): it locates the ZIP end-of-central-directory record at the end of the
   setup file, opens the embedded archive in memory, and copies only the entry named `ReShade64.dll` to disk.
4. Run the safe test in `docs/BUILD.md` (section 6) against a dummy folder and compare what appears with the tables above.
5. Every other file in the payload is a `.fx`/`.fxh` shader (text), a `.png` texture, or a `.ini` settings file.
