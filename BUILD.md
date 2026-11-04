# Build and verify - step by step

The installer is a PowerShell script plus data files. **There is no compile step.** The "build" is:
take the `installer/` folder and put it in a zip. The steps below do that and let you check every file.

## 1. Requirements

- To build on Windows: Windows 10 or 11 with the built-in Windows PowerShell 5.1 (or PowerShell 7).
- To build on Linux / macOS / WSL: `bash` and `zip`.
- To run the installer: Windows 10 or 11 and an internet connection (it downloads ReShade from reshade.me and five shader files from GitHub).
- Optional, for the dependency check: Python 3 (standard library only).

## 2. Get the source

```
git clone <repository URL>
cd <repository folder>
```

## 3. Verify the source files (optional but recommended)

Every file in `installer/` is listed with its SHA-256 in `SHA256SUMS.txt`.

PowerShell:

```powershell
$bad = 0
foreach ($line in Get-Content SHA256SUMS.txt) {
  if (-not $line.Trim()) { continue }
  $p = $line -split '  ', 2
  if ((Get-FileHash -Algorithm SHA256 -LiteralPath $p[1]).Hash.ToLower() -ne $p[0]) { "MISMATCH: $($p[1])"; $bad++ }
}
if ($bad -eq 0) { 'All hashes match.' }
```

Linux / macOS / WSL:

```
sha256sum -c SHA256SUMS.txt
```

## 4. Build the release zip

Windows (PowerShell):

```powershell
.\tools\build-release.ps1
```

Linux / macOS / WSL:

```
./tools/build-release.sh
```

Output: `dist/VII_Next-Gen_Appalachia_4_0_Definitive_Edition_Auto_Installer.zip`.
Inside the zip everything sits in one folder called `VII Next-Gen Appalachia 4.0 Definitive Edition Auto Installer`.

What the build script does, in full: lists every file under `installer/` (skipping any `install-log.txt`), and writes
each one into a new zip under that top-level folder with forward-slash paths. It does not modify any file.
Zip files contain timestamps, so the hash of the zip differs from build to build; compare the per-file hashes
(step 3) rather than the hash of the zip.

The same build also runs automatically on GitHub (`.github/workflows/build.yml`): it checks `SHA256SUMS.txt`, builds the
zip on a clean Windows runner, and uploads it as a build artifact, so you can see the zip was produced from this source.

## 5. Check the payload is complete (optional)

```
python tools/list-dependencies.py \
  --shaders installer/payload/reshade-shaders/Shaders \
  --shaders installer/payload/reshade-shaders-vibrant/Shaders \
  --textures installer/payload/reshade-shaders/Textures \
  --downloaded qUINT_mxao.fx,qUINT_lightroom.fx,qUINT_common.fxh,ReShadeUI.fxh,GaussianBlur.fx \
  installer/payload/presets/*.ini
```

This prints, for each preset, the effect files it uses and confirms every `#include` and texture is either bundled
or in the list of files the installer downloads.
It ends with `RESULT: all dependencies found`.

## 6. Test the installer safely (no game needed)

Use a throw-away folder instead of the real game. The installer only checks that a file called `Fallout76.exe` exists.

```powershell
mkdir C:\temp\fake76
New-Item C:\temp\fake76\Fallout76.exe -ItemType File | Out-Null
cd "<extracted release folder>"
powershell -NoProfile -ExecutionPolicy Bypass -File .\Installer.ps1 -Silent -Edition All -GamePath C:\temp\fake76
```

Then look at what appeared in `C:\temp\fake76`:

- `dxgi.dll` (ReShade, taken from reshade.me's official setup)
- `ReShade.ini`
- the four `VII Next-Gen Appalachia 4.0 (...)` preset files
- the `reshade-shaders` folder (including `qUINT\...`, `ReShadeUI.fxh` and `GaussianBlur.fx`, which the installer downloaded)

Run the uninstall the same way and confirm they are all removed again:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Installer.ps1 -Silent -Uninstall -GamePath C:\temp\fake76
```

A log of each run is written to `install-log.txt` next to the script.
To watch network traffic while testing, use a tool such as Wireshark or Fiddler. You should see requests to
`reshade.me` and `github.com` (the two repositories listed in the README) only, plus the normal Windows traffic.

## Command-line options

```
Installer.ps1 [-Silent] [-Uninstall] [-GamePath <folder>]
              [-Edition Cinematic|Natural|NaturalCinematic|Vibrant|All]
```

Without `-Silent` the Windows Forms window opens.
