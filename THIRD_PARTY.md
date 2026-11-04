# Third-party shaders: credits and licence status

Summary only; the headers inside the files and the upstream projects are authoritative. Not legal advice.
The same information ships in the release zip as `THIRD_PARTY_NOTICES.txt`.

## Bundled, licence allows redistribution

| File(s) | Author / source | Licence (per file header or project) |
|---|---|---|
| `ReShade.fxh` | ReShade (crosire) | CC0-1.0 (SPDX line in file) |
| `SweetFX/CAS.fx` | AMD FidelityFX CAS | MIT-style text in file |
| `SweetFX/Curves.fx`, `FakeHDR.fx`, `Vignette.fx`, `Vibrance.fx` | CeeJay.dk | SweetFX is published under the MIT licence (Copyright 2014 CeeJayDK) |
| `Deband.fx` | haasn (Niklas Haas) | MIT text in file |
| `Colourfulness.fx` | bacondither | BSD-style text in file |
| `FilmGrain2.fx` | Martins Upitis (martinsh) | CC BY 3.0 per header |
| `LightDoF.fx` | luluco250 | CC BY-SA 4.0 per header |
| `GShade-Shaders/LocalContrast.fx` | Jakub Maksymilian Fober | CC BY-SA 3.0 per header |
| `Fubax/Letterbox.fx` | Jakub Maksymilian Fober | Public Domain Mark 1.0 per header |
| `brussell/UIDetect.fx`, `.fxh`, `Textures/UIDetectMaskRGB.png` | brussell | CC BY 4.0 per header |
| `PD80/*`, `Textures/PD80/*` | prod80 (Bas Veth) | MIT, Copyright (c) 2020 prod80 (stated in prod80's effect headers) |
| `VII_*.fx` | the author of this preset | original work |

## Bundled, licence not stated

| File | Note |
|---|---|
| `GShade-Shaders/Clarity2.fx` | By Ioxa (lightly optimised by Marot Satil for GShade). Published by the author for free use on the ReShade forum; no licence text accompanies the file. |

## Not bundled (downloaded at install time from the official repositories)

| File(s) | Why | Source |
|---|---|---|
| `qUINT_mxao.fx`, `qUINT_lightroom.fx`, `qUINT_common.fxh` | Marty McFly / Pascal Gilcher: "All rights reserved" | `github.com/martymcmodding/qUINT` |
| `ReShadeUI.fxh`, `GaussianBlur.fx` | No licence text in the files | `github.com/crosire/reshade-shaders` |

ReShade itself is not included; it is downloaded from <https://reshade.me/> at install time.
