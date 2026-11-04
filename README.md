# VII Next-Gen Appalachia 4.0 - Auto Installer

An installer for the **VII Next-Gen Appalachia 4.0** ReShade presets for **Fallout 76**.
It finds the game folder, installs ReShade, and copies the presets, shaders and textures into place.
It can also uninstall everything again.

Presets: **Cinematic**, **Natural Edition**, **Natural Cinematic Edition**, **Vibrant**, or **All**.

> This repository exists so the installer can be reviewed in full (for example by the Nexus Mods
> security team). Everything that runs is plain text. There is no compiled code, no packer and no obfuscation.

## What is in this repository

| Path | What it is |
|---|---|
| `installer/THIRD_PARTY_NOTICES.txt` | Credits and licence status of every third-party shader. |
| `installer/Install.bat` | 11-line launcher. Checks the `payload` folder exists, then starts `Installer.ps1`. |
| `installer/Installer.ps1` | The whole installer (about 520 lines of PowerShell, Windows Forms window). |
| `installer/payload/presets/` | The four preset `.ini` files. |
| `installer/payload/ReShade.ini` | ReShade settings (depth-buffer options etc.). |
| `installer/payload/reshade-shaders/` | The shaders (`.fx`/`.fxh`) and textures (`.png`) the presets use, except the files listed under "Not bundled" below. |
| `installer/payload/reshade-shaders-vibrant/` | `Vibrance.fx`, installed only for Vibrant / All. |
| `installer/README.txt` | The end-user instructions shipped inside the release zip. |
| `tools/build-release.ps1`, `tools/build-release.sh` | Build the release zip (Windows / Linux). |
| `tools/list-dependencies.py` | Shows which shader files and textures a preset needs (how the payload was trimmed). |
| `SHA256SUMS.txt` | SHA-256 of every file in `installer/`. |
| `.github/workflows/build.yml` | Builds the zip on GitHub's servers and checks the hashes. |
| `docs/` | `BUILD.md` (step-by-step build), `SECURITY_REVIEW.md` (line-by-line map), `THIRD_PARTY.md` (shader credits and licences). |

There are **no binaries** in this repository. The only binary the installer ever puts on a user's PC is
`ReShade64.dll`, which it takes from the official ReShade setup downloaded from reshade.me at install time.

### Not bundled (downloaded at install time)

Five shader files are deliberately **not** in this repository because their licences do not clearly allow
redistribution. The installer downloads them from the authors' official GitHub repositories instead:

| File(s) | Downloaded from |
|---|---|
| `qUINT_mxao.fx`, `qUINT_lightroom.fx`, `qUINT_common.fxh` | `github.com/martymcmodding/qUINT` |
| `ReShadeUI.fxh`, `GaussianBlur.fx` | `github.com/crosire/reshade-shaders` |

## How it works (summary)

1. **Find the game.** Reads Steam / Bethesda launcher locations from the registry (read only) and checks common
   folders for `Fallout76.exe`. The user can also browse to the folder.
2. **Install ReShade.** Reads the newest version number from `https://reshade.me/`, downloads
   `ReShade_Setup_<version>.exe` (the standard build, not the add-on build), extracts `ReShade64.dll` from the
   archive appended to that file (the setup is **not executed**) and saves it as `dxgi.dll` in the game folder.
3. **Copy files.** Copies the bundled shaders and textures into `<game>\reshade-shaders`, downloads the five
   files listed above from their official repositories into the same folder, copies the chosen preset(s) and
   `ReShade.ini` into the game folder, and sets the chosen preset as the start-up preset.
4. **Uninstall (optional).** Removes only what the installer put there (`docs/SECURITY_REVIEW.md` lists every delete).

The only network access is to `reshade.me` and to `github.com` for the two repositories above (see `docs/SECURITY_REVIEW.md`).

## Build it yourself

There is nothing to compile; "building" means zipping the `installer/` folder. In short:

```powershell
git clone <this repository>
cd <repository folder>
.\tools\build-release.ps1          # Windows (PowerShell 5.1 or 7)
# or:  ./tools/build-release.sh    # Linux / macOS / WSL (needs `zip`)
```

The zip appears in `dist/`. Full step-by-step instructions, including how to verify the files and how to test the
installer safely, are in [`docs/BUILD.md`](docs/BUILD.md).

## How this project was built

1. The presets and custom `VII_*.fx` effects were made by the author inside a normal ReShade setup for Fallout 76.
2. The author's shader folder was trimmed to only the files the presets actually use, by following the `Techniques=`
   line of each preset, every `#include`, and every texture file name (`tools/list-dependencies.py` repeats this check).
3. The installer was written in PowerShell with a Windows Forms window, so it needs nothing installed beyond Windows.
4. ReShade is **not** bundled. The script downloads the official setup from reshade.me and extracts the DLL from it.
   Shader files without a clear redistribution licence are not bundled either; they are downloaded from the official repositories.
5. The author tested install and uninstall on a real Fallout 76 install (install log shows ReShade 6.8.0 installing and
   all four presets copying correctly).
6. The installer script was written with the help of an AI assistant (Claude, by Anthropic) and then tested and
   adjusted by the author. The code in this repository is the complete result; there are no other parts.

## Reporting a problem

If you spot something suspicious in the code, please open an issue. Every line is meant to be readable.
