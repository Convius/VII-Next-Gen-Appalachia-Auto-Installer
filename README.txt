VII Next-Gen Appalachia 4.0 - ReShade installer for Fallout 76
================================================================

1. Extract this whole zip to a normal folder (not from inside the zip viewer).
2. Double-click Install.bat.
   (If your game is in Program Files, right-click it and choose "Run as administrator".)
3. Check the detected Fallout 76 folder, choose a preset, click Install.
4. Start the game and press Home to open ReShade.

Presets
- Cinematic
- Natural Edition
- Natural Cinematic Edition
- Vibrant (adds the Vibrance effect)
- All presets (Cinematic is active at first; switch in the ReShade preset dropdown)

What it does
- Downloads ReShade from reshade.me (standard build, no add-on support) and installs it as dxgi.dll.
  It also downloads the few shader files mentioned below, so an internet connection is needed.
- Installs the shaders, textures and custom VII effects the presets use (bundled in payload\reshade-shaders).
- A few shader files whose licences do not clearly allow redistribution (qUINT MXAO / Lightroom and two ReShade
  files) are not bundled; the installer downloads them from the authors' official GitHub repositories.
  See THIRD_PARTY_NOTICES.txt.
- Vibrance.fx (payload\reshade-shaders-vibrant) is only installed with Vibrant or All,
  and only the Vibrant preset enables it.
- Installs your ReShade.ini (depth settings etc.). Screenshot folder is set to
  Documents\My Games\Fallout 76\Photos on the new PC.
- Removes older copies of the same effects (for example from an earlier version of this installer)
  so nothing loads twice.
- Existing dxgi.dll and ReShade.ini are backed up as *.vii-backup.

Uninstall: run Install.bat again, choose "Uninstall ReShade and all effects" and click Uninstall.
It removes ReShade (dxgi.dll), ReShade.ini, the VII presets (including the old "Main" one from earlier versions)
and the whole reshade-shaders folder, restores any dxgi.dll that was there before, and leaves your
screenshots alone. Close the game first.

The installer closes itself after a successful install or uninstall (once you click OK on the message).

Note: VII_Camera_Fix.fx and the optional VII effects are installed but only the ones listed in each preset are enabled.

A log of every run is written to install-log.txt next to the installer.
