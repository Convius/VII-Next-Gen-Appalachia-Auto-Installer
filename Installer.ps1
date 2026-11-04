#requires -Version 5.1
<#
  VII Next-Gen Appalachia 4.0 - ReShade installer for Fallout 76

  - Finds Fallout 76 automatically (Steam, Bethesda launcher, common folders)
  - Downloads ReShade from reshade.me (standard build, no add-on support)
  - Installs the shaders/textures the presets use (bundled in .\payload). Files whose licences do not
    clearly allow redistribution (qUINT, ReShadeUI.fxh, GaussianBlur.fx) are NOT bundled; they are
    downloaded from the authors' official GitHub repositories at install time.
  - Installs your custom VII_*.fx files from .\payload\shaders
  - Lets you pick Cinematic, Natural, Natural Cinematic, Vibrant, or All. Vibrance.fx is only installed with Vibrant/All.

  Command line (optional):
    Installer.ps1 -Silent -Uninstall -GamePath "D:\SteamLibrary\steamapps\common\Fallout76"
    Installer.ps1 -Silent -Edition Vibrant -GamePath "D:\SteamLibrary\steamapps\common\Fallout76"
#>
[CmdletBinding()]
param(
    [switch]$Silent,
    [switch]$Uninstall,
    [string]$GamePath = '',
    [ValidateSet('Cinematic', 'Natural', 'NaturalCinematic', 'Vibrant', 'All')][string]$Edition = 'Cinematic'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Payload    = Join-Path $ScriptRoot 'payload'
$LogFile    = Join-Path $ScriptRoot 'install-log.txt'

$PresetNames = @{
    Cinematic        = 'VII Next-Gen Appalachia 4.0 (Cinematic).ini'
    Natural          = 'VII Next-Gen Appalachia 4.0 (Natural Edition).ini'
    NaturalCinematic = 'VII Next-Gen Appalachia 4.0 (Natural Cinematic Edition).ini'
    Vibrant          = 'VII Next-Gen Appalachia 4.0 (Vibrant).ini'
}
# Preset name used by older versions of this installer (removed on uninstall)
$LegacyPresetNames = @('VII Next-Gen Appalachia 4.0 (Main).ini')

# Files that are NOT bundled because their licences do not clearly allow redistribution.
# They are downloaded from the official repositories at install time. Sha256 is the version the
# presets were tuned with (a different version only produces a notice in the log).
$DownloadSources = @(
    @{
        Name  = 'qUINT'
        Urls  = @('https://github.com/martymcmodding/qUINT/archive/HEAD.zip')
        Files = @(
            @{ Name = 'qUINT_mxao.fx';       Dest = 'qUINT'; Sha256 = 'fdd84443706a92753ac255d9912ceb5f8e03a4bba88ddfb06a85b5654a9590e1' },
            @{ Name = 'qUINT_lightroom.fx';  Dest = 'qUINT'; Sha256 = '99a0d6ffadca4ab8af74415580a1810dc9d28031ddac942936137ea2c114c53c' },
            @{ Name = 'qUINT_common.fxh';    Dest = 'qUINT'; Sha256 = '30cf03a1869e33e9b92f09f79ac9217c001472d014ab91ef3e87e0d41e3f55ec' }
        )
    },
    @{
        Name  = 'reshade-shaders'
        Urls  = @('https://github.com/crosire/reshade-shaders/archive/refs/heads/master.zip',
                  'https://github.com/crosire/reshade-shaders/archive/HEAD.zip')
        Files = @(
            @{ Name = 'ReShadeUI.fxh';    Dest = ''; Sha256 = '78adf672df47460297eb9fe6dd238d2aafa24510b52b84feb1a745dff70eb901' },
            @{ Name = 'GaussianBlur.fx';  Dest = ''; Sha256 = 'b45a82eb9de6104ca3e982d031e05614a629740827119ca6eae58018588b50cb' }
        )
    }
)

# Used only if reshade.me cannot be scraped for the newest version number.
$FallbackReShadeVersion = '6.1.1'

# ---------------------------------------------------------------- logging
$script:LogBox = $null
function Write-Log([string]$Message) {
    $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message
    try { Add-Content -LiteralPath $LogFile -Value $line } catch { }
    if ($script:LogBox) {
        $script:LogBox.AppendText($Message + "`r`n")
        [Windows.Forms.Application]::DoEvents()
    } else {
        Write-Host $Message
    }
}

# ---------------------------------------------------------------- game detection
function Get-SteamLibraries {
    $libs = @()
    $steam = $null
    foreach ($k in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
        try {
            $p = Get-ItemProperty -Path $k -ErrorAction Stop
            if ($p.SteamPath) { $steam = $p.SteamPath } elseif ($p.InstallPath) { $steam = $p.InstallPath }
        } catch { }
        if ($steam) { break }
    }
    if ($steam) {
        $steam = $steam -replace '/', '\'
        $libs += $steam
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            $text = Get-Content -LiteralPath $vdf -Raw
            foreach ($m in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
                $libs += ($m.Groups[1].Value -replace '\\\\', '\')
            }
        }
    }
    return @($libs | Select-Object -Unique)
}

function Find-Fallout76 {
    $candidates = New-Object System.Collections.Generic.List[string]

    foreach ($lib in (Get-SteamLibraries)) {
        $candidates.Add((Join-Path $lib 'steamapps\common\Fallout76'))
    }

    foreach ($k in @('HKLM:\SOFTWARE\WOW6432Node\Bethesda Softworks\Fallout76', 'HKLM:\SOFTWARE\Bethesda Softworks\Fallout76')) {
        try {
            $p = Get-ItemProperty -Path $k -ErrorAction Stop
            foreach ($prop in @('Path', 'Installed Path', 'InstallPath')) {
                if ($p.$prop) { $candidates.Add([string]$p.$prop) }
            }
        } catch { }
    }

    $rel = @(
        'SteamLibrary\steamapps\common\Fallout76',
        'Steam\steamapps\common\Fallout76',
        'Games\Steam\steamapps\common\Fallout76',
        'Program Files (x86)\Steam\steamapps\common\Fallout76',
        'Program Files\Steam\steamapps\common\Fallout76',
        'Program Files (x86)\Bethesda.net Launcher\games\Fallout76',
        'Bethesda.net Launcher\games\Fallout76',
        'Games\Bethesda.net Launcher\games\Fallout76',
        'Games\Fallout76',
        'Fallout76',
        'XboxGames\Fallout 76\Content'
    )
    foreach ($d in [IO.DriveInfo]::GetDrives()) {
        if ($d.DriveType -ne 'Fixed') { continue }
        foreach ($r in $rel) { $candidates.Add((Join-Path $d.RootDirectory.FullName $r)) }
    }

    $found = @()
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath (Join-Path $c 'Fallout76.exe'))) { $found += $c.TrimEnd('\') }
    }
    return @($found | Select-Object -Unique)
}

# ---------------------------------------------------------------- ini helpers
function Set-IniValue([string]$Path, [string]$Section, [string]$Key, [string]$Value) {
    $lines = New-Object System.Collections.Generic.List[string]
    if (Test-Path -LiteralPath $Path) {
        foreach ($l in [IO.File]::ReadAllLines($Path)) { $lines.Add($l) }
    }
    $secIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -ieq "[$Section]") { $secIdx = $i; break }
    }
    if ($secIdx -lt 0) {
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim() -ne '') { $lines.Add('') }
        $lines.Add("[$Section]")
        $lines.Add("$Key=$Value")
    } else {
        $end = $lines.Count
        for ($i = $secIdx + 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim().StartsWith('[')) { $end = $i; break }
        }
        $keyIdx = -1
        for ($i = $secIdx + 1; $i -lt $end; $i++) {
            if ($lines[$i] -match ('^\s*' + [regex]::Escape($Key) + '\s*=')) { $keyIdx = $i; break }
        }
        if ($keyIdx -ge 0) { $lines[$keyIdx] = "$Key=$Value" } else { $lines.Insert($secIdx + 1, "$Key=$Value") }
    }
    [IO.File]::WriteAllLines($Path, $lines.ToArray(), (New-Object Text.UTF8Encoding($false)))
}

# ---------------------------------------------------------------- ReShade itself
function Get-LatestReShadeVersion {
    try {
        $html = (Invoke-WebRequest -Uri 'https://reshade.me/' -UseBasicParsing -Headers @{ Referer = 'https://reshade.me/' }).Content
        $best = $null
        foreach ($m in [regex]::Matches($html, 'ReShade_Setup_(\d+\.\d+(?:\.\d+)?)\.exe')) {
            $v = [version]$m.Groups[1].Value
            if (-not $best -or $v -gt $best) { $best = $v }
        }
        if ($best) { return $best.ToString() }
    } catch { }
    return $null
}

function Export-ReShadeDll([string]$SetupExe, [string]$OutDll) {
    $bytes = [IO.File]::ReadAllBytes($SetupExe)
    $eocd = -1
    $min = [Math]::Max(0, $bytes.Length - 70000)
    for ($i = $bytes.Length - 22; $i -ge $min; $i--) {
        if ($bytes[$i] -eq 0x50 -and $bytes[$i + 1] -eq 0x4B -and $bytes[$i + 2] -eq 5 -and $bytes[$i + 3] -eq 6) { $eocd = $i; break }
    }
    if ($eocd -lt 0) { throw 'Could not find the embedded archive inside the ReShade setup file.' }
    $cdSize = [int64][BitConverter]::ToUInt32($bytes, $eocd + 12)
    $cdOff  = [int64][BitConverter]::ToUInt32($bytes, $eocd + 16)
    $zipStart = [int64]$eocd - $cdSize - $cdOff
    if ($zipStart -lt 0) { throw 'Embedded archive layout was not recognised.' }
    $len = [int64]$bytes.Length - $zipStart
    $zipBytes = New-Object byte[] $len
    [Array]::Copy($bytes, $zipStart, $zipBytes, [int64]0, $len)

    Add-Type -AssemblyName System.IO.Compression
    $ms = New-Object IO.MemoryStream(, $zipBytes)
    $zip = New-Object IO.Compression.ZipArchive($ms, [IO.Compression.ZipArchiveMode]::Read)
    try {
        $entry = $zip.Entries | Where-Object { $_.Name -ieq 'ReShade64.dll' } | Select-Object -First 1
        if (-not $entry) { throw ('ReShade64.dll not found in setup. Entries: ' + (($zip.Entries | ForEach-Object { $_.Name }) -join ', ')) }
        $es = $entry.Open()
        $fs = [IO.File]::Create($OutDll)
        try { $es.CopyTo($fs) } finally { $fs.Close(); $es.Close() }
    } finally { $zip.Dispose(); $ms.Dispose() }
}

function Install-ReShadeDll([string]$Game, [string]$Work) {
    $ver = Get-LatestReShadeVersion
    if ($ver) { Write-Log "  Latest ReShade on reshade.me: $ver" }
    else { $ver = $FallbackReShadeVersion; Write-Log "  Could not read reshade.me, using ReShade $ver" }

    $setup = Join-Path $Work "ReShade_Setup_$ver.exe"
    $url = "https://reshade.me/downloads/ReShade_Setup_$ver.exe"
    Invoke-WebRequest -Uri $url -OutFile $setup -UseBasicParsing -Headers @{ Referer = 'https://reshade.me/' }

    $target = Join-Path $Game 'dxgi.dll'
    if ((Test-Path -LiteralPath $target) -and -not (Test-Path -LiteralPath ($target + '.vii-backup'))) {
        Copy-Item -LiteralPath $target -Destination ($target + '.vii-backup')
        Write-Log '  Existing dxgi.dll backed up as dxgi.dll.vii-backup'
    }
    Export-ReShadeDll $setup $target
    Write-Log "  ReShade $ver installed as dxgi.dll (Fallout 76 uses DirectX 11)"
}

# ---------------------------------------------------------------- bundled shaders
function Copy-Tree([string]$Source, [string]$Dest, [bool]$RemoveDuplicateNames = $false) {
    if (-not (Test-Path -LiteralPath $Source)) { return 0 }
    $count = 0
    foreach ($f in (Get-ChildItem -LiteralPath $Source -Recurse -File)) {
        $rel = $f.FullName.Substring($Source.Length).TrimStart('\', '/')
        $target = Join-Path $Dest $rel
        $dir = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        if ($RemoveDuplicateNames -and (Test-Path -LiteralPath $Dest)) {
            # Old copies of the same effect in another sub-folder (for example from an earlier
            # version of this installer) would load twice, so remove them first.
            foreach ($old in (Get-ChildItem -LiteralPath $Dest -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $f.Name -and $_.FullName -ine $target })) {
                Remove-Item -LiteralPath $old.FullName -Force
                Write-Log ('  Removed old duplicate: ' + $old.FullName.Substring($Dest.Length).TrimStart('\'))
            }
        }
        Copy-Item -LiteralPath $f.FullName -Destination $target -Force
        $count++
    }
    return $count
}

function Install-DownloadedShaders([string]$DestShaders, [string]$Work) {
    $failed = 0
    foreach ($src in $DownloadSources) {
        $zip = Join-Path $Work ('dl_' + $src.Name + '.zip')
        $dir = Join-Path $Work ('dl_' + $src.Name)
        $ok = $false
        foreach ($u in $src.Urls) {
            try {
                Write-Log "  Downloading $($src.Name) from $u"
                Invoke-WebRequest -Uri $u -OutFile $zip -UseBasicParsing
                Expand-Archive -LiteralPath $zip -DestinationPath $dir -Force
                $ok = $true
                break
            } catch {
                Write-Log ('    failed: ' + $_.Exception.Message)
            }
        }
        foreach ($f in $src.Files) {
            $found = $null
            if ($ok) {
                $hits = @(Get-ChildItem -LiteralPath $dir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $f.Name })
                $pref = @($hits | Where-Object { $_.FullName -match '(?i)\\Shaders\\' })
                if ($pref.Count -gt 0) { $found = $pref[0] } elseif ($hits.Count -gt 0) { $found = $hits[0] }
            }
            if (-not $found) {
                Write-Log "  ! Could not get $($f.Name) from $($src.Name). The effects that need it will not load."
                $failed++
                continue
            }
            $targetDir = $DestShaders
            if ($f.Dest) { $targetDir = Join-Path $DestShaders $f.Dest }
            if (-not (Test-Path -LiteralPath $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
            $target = Join-Path $targetDir $f.Name
            foreach ($old in (Get-ChildItem -LiteralPath $DestShaders -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $f.Name -and $_.FullName -ine $target })) {
                Remove-Item -LiteralPath $old.FullName -Force
                Write-Log ('  Removed old duplicate: ' + $old.FullName.Substring($DestShaders.Length).TrimStart('\'))
            }
            Copy-Item -LiteralPath $found.FullName -Destination $target -Force
            $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash.ToLower()
            if ($f.Sha256 -and $actual -ne $f.Sha256) {
                Write-Log "  Installed $($f.Name) (newer/different version than the presets were tuned with - the look may differ slightly)"
            } else {
                Write-Log "  Installed $($f.Name)"
            }
        }
    }
    return $failed
}

function Invoke-Install([string]$Game, [string]$Choice) {
    if (-not (Test-Path -LiteralPath (Join-Path $Game 'Fallout76.exe'))) {
        throw "Fallout76.exe was not found in:`r`n$Game`r`n`r`nPick the folder that contains Fallout76.exe."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $Payload 'presets'))) {
        throw 'The payload folder is missing. Extract the whole zip first, then run Install.bat again.'
    }
    $probe = Join-Path $Game '.vii_write_test'
    try { Set-Content -LiteralPath $probe -Value 'x'; Remove-Item -LiteralPath $probe -Force }
    catch { throw "Cannot write to this folder.`r`nRight-click Install.bat and choose 'Run as administrator'." }

    $editions = if ($Choice -eq 'All') { @('Cinematic', 'Natural', 'NaturalCinematic', 'Vibrant') } else { @($Choice) }
    $work = Join-Path ([IO.Path]::GetTempPath()) ('vii_installer_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    $destRoot = Join-Path $Game 'reshade-shaders'
    $failures = 0

    try {
        Write-Log "Game folder: $Game"
        Write-Log "Version: $Choice"

        Write-Log '[1/3] Installing ReShade ...'
        Install-ReShadeDll $Game $work

        Write-Log '[2/3] Copying shaders and textures ...'
        $n = Copy-Tree (Join-Path $Payload 'reshade-shaders') $destRoot $true
        if ($editions -contains 'Vibrant') {
            $n += Copy-Tree (Join-Path $Payload 'reshade-shaders-vibrant') $destRoot $true
            Write-Log '  Vibrance effect included (Vibrant only)'
        }
        Write-Log "  Copied $n bundled shader/texture files."
        Write-Log '  Downloading the files that cannot be bundled (licences) ...'
        $dl = @(Install-DownloadedShaders (Join-Path $destRoot 'Shaders') $work)
        $failures = [int]$dl[-1]

        Write-Log '[3/3] Installing presets and configuring ReShade ...'
        foreach ($e in $editions) {
            Copy-Item -LiteralPath (Join-Path $Payload ('presets\' + $PresetNames[$e])) -Destination (Join-Path $Game $PresetNames[$e]) -Force
            Write-Log "  Installed preset: $($PresetNames[$e])"
        }

        $ini = Join-Path $Game 'ReShade.ini'
        $userIni = Join-Path $Payload 'ReShade.ini'
        if (Test-Path -LiteralPath $ini) {
            Copy-Item -LiteralPath $ini -Destination ($ini + '.vii-backup') -Force
            Write-Log '  Existing ReShade.ini backed up as ReShade.ini.vii-backup'
        }
        if (Test-Path -LiteralPath $userIni) {
            Copy-Item -LiteralPath $userIni -Destination $ini -Force
            Write-Log '  Installed ReShade.ini (your depth settings and options)'
            $photos = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'My Games\Fallout 76\Photos\'
            Set-IniValue $ini 'SCREENSHOT' 'SavePath' $photos
        }
        Set-IniValue $ini 'GENERAL' 'EffectSearchPaths'  '.\reshade-shaders\Shaders\**'
        Set-IniValue $ini 'GENERAL' 'TextureSearchPaths' '.\reshade-shaders\Textures\**'
        $activePreset = Join-Path $Game $PresetNames[$editions[0]]
        Set-IniValue $ini 'GENERAL' 'PresetPath'        $activePreset
        Set-IniValue $ini 'GENERAL' 'StartupPresetPath' $activePreset

        Write-Log ''
        Write-Log 'Done. Start Fallout 76 and press Home to open ReShade.'
        Write-Log 'The first launch takes a while because the shaders compile.'
    }
    finally {
        try { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    }
    return $failures
}

# ---------------------------------------------------------------- uninstall
function Invoke-Uninstall([string]$Game) {
    if (-not (Test-Path -LiteralPath (Join-Path $Game 'Fallout76.exe'))) {
        throw "Fallout76.exe was not found in:`r`n$Game`r`n`r`nPick the folder that contains Fallout76.exe."
    }
    Write-Log "Game folder: $Game"
    Write-Log 'Removing ReShade and all installed effects ...'
    try {
        $dll = Join-Path $Game 'dxgi.dll'
        $bak = $dll + '.vii-backup'
        if (Test-Path -LiteralPath $dll) { Remove-Item -LiteralPath $dll -Force; Write-Log '  Removed dxgi.dll (ReShade)' }
        if (Test-Path -LiteralPath $bak) { Move-Item -LiteralPath $bak -Destination $dll -Force; Write-Log '  Restored your original dxgi.dll' }

        $files = @('ReShade.ini', 'ReShade.ini.vii-backup', 'ReShade.log', 'ReShadePreset.ini')
        foreach ($p in $PresetNames.Values) { $files += $p }
        foreach ($p in $LegacyPresetNames) { $files += $p }
        foreach ($name in $files) {
            $path = Join-Path $Game $name
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force; Write-Log "  Removed $name" }
        }

        $shaders = Join-Path $Game 'reshade-shaders'
        if (Test-Path -LiteralPath $shaders) { Remove-Item -LiteralPath $shaders -Recurse -Force; Write-Log '  Removed reshade-shaders folder (all shaders and textures)' }

        $cache = Join-Path ([IO.Path]::GetTempPath()) 'ReShade'
        if (Test-Path -LiteralPath $cache) { Remove-Item -LiteralPath $cache -Recurse -Force -ErrorAction SilentlyContinue; Write-Log '  Cleared the shader cache' }
    }
    catch {
        throw ("Could not remove everything: " + $_.Exception.Message + "`r`n`r`nClose Fallout 76 (and the launcher) and try again.")
    }
    Write-Log ''
    Write-Log 'Done. ReShade has been removed. Your screenshots were not touched.'
}

# ---------------------------------------------------------------- entry points
if ($Silent) {
    if (-not $GamePath) {
        $found = Find-Fallout76
        if ($found.Count -eq 0) { Write-Host 'Fallout 76 not found. Pass -GamePath.'; exit 1 }
        $GamePath = $found[0]
    }
    try {
        if ($Uninstall) { Invoke-Uninstall $GamePath; exit 0 }
        $r = @(Invoke-Install $GamePath $Edition)
        if ([int]$r[-1] -gt 0) { exit 2 }
        exit 0
    }
    catch { Write-Host ('ERROR: ' + $_.Exception.Message); exit 1 }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object Windows.Forms.Form
$form.Text = 'VII Next-Gen Appalachia 4.0 - Installer'
$form.ClientSize = New-Object Drawing.Size(625, 680)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$title = New-Object Windows.Forms.Label
$title.Text = 'VII Next-Gen Appalachia 4.0'
$title.Font = New-Object Drawing.Font('Segoe UI', 15, [Drawing.FontStyle]::Bold)
$title.Location = New-Object Drawing.Point(20, 12)
$title.AutoSize = $true
$form.Controls.Add($title)

$sub = New-Object Windows.Forms.Label
$sub.Text = 'ReShade installer for Fallout 76. Installs ReShade, all required shaders and textures, and your preset.'
$sub.Location = New-Object Drawing.Point(22, 46)
$sub.Size = New-Object Drawing.Size(580, 20)
$form.Controls.Add($sub)

# --- game folder
$gb1 = New-Object Windows.Forms.GroupBox
$gb1.Text = '1. Fallout 76 folder'
$gb1.Location = New-Object Drawing.Point(20, 76)
$gb1.Size = New-Object Drawing.Size(585, 90)
$form.Controls.Add($gb1)

$combo = New-Object Windows.Forms.ComboBox
$combo.Location = New-Object Drawing.Point(15, 27)
$combo.Size = New-Object Drawing.Size(445, 24)
$gb1.Controls.Add($combo)

$browse = New-Object Windows.Forms.Button
$browse.Text = 'Browse...'
$browse.Location = New-Object Drawing.Point(470, 25)
$browse.Size = New-Object Drawing.Size(100, 27)
$gb1.Controls.Add($browse)

$detectLabel = New-Object Windows.Forms.Label
$detectLabel.Location = New-Object Drawing.Point(15, 60)
$detectLabel.Size = New-Object Drawing.Size(555, 20)
$gb1.Controls.Add($detectLabel)

# --- action
$gbMode = New-Object Windows.Forms.GroupBox
$gbMode.Text = 'What do you want to do?'
$gbMode.Location = New-Object Drawing.Point(20, 176)
$gbMode.Size = New-Object Drawing.Size(585, 56)
$form.Controls.Add($gbMode)

$rbInstall = New-Object Windows.Forms.RadioButton
$rbInstall.Text = 'Install'
$rbInstall.Location = New-Object Drawing.Point(15, 23)
$rbInstall.Size = New-Object Drawing.Size(200, 22)
$rbInstall.Checked = $true
$gbMode.Controls.Add($rbInstall)

$rbUninstall = New-Object Windows.Forms.RadioButton
$rbUninstall.Text = 'Uninstall ReShade and all effects'
$rbUninstall.Location = New-Object Drawing.Point(230, 23)
$rbUninstall.Size = New-Object Drawing.Size(330, 22)
$gbMode.Controls.Add($rbUninstall)

# --- version
$gb2 = New-Object Windows.Forms.GroupBox
$gb2.Text = '2. Which preset?'
$gb2.Location = New-Object Drawing.Point(20, 242)
$gb2.Size = New-Object Drawing.Size(585, 170)
$form.Controls.Add($gb2)

$rbCin = New-Object Windows.Forms.RadioButton
$rbCin.Text = 'Cinematic'
$rbCin.Location = New-Object Drawing.Point(15, 24)
$rbCin.Size = New-Object Drawing.Size(550, 22)
$rbCin.Checked = $true
$gb2.Controls.Add($rbCin)

$rbNat = New-Object Windows.Forms.RadioButton
$rbNat.Text = 'Natural Edition'
$rbNat.Location = New-Object Drawing.Point(15, 51)
$rbNat.Size = New-Object Drawing.Size(550, 22)
$gb2.Controls.Add($rbNat)

$rbNatCin = New-Object Windows.Forms.RadioButton
$rbNatCin.Text = 'Natural Cinematic Edition'
$rbNatCin.Location = New-Object Drawing.Point(15, 78)
$rbNatCin.Size = New-Object Drawing.Size(550, 22)
$gb2.Controls.Add($rbNatCin)

$rbVib = New-Object Windows.Forms.RadioButton
$rbVib.Text = 'Vibrant (adds the Vibrance effect)'
$rbVib.Location = New-Object Drawing.Point(15, 105)
$rbVib.Size = New-Object Drawing.Size(550, 22)
$gb2.Controls.Add($rbVib)

$rbAll = New-Object Windows.Forms.RadioButton
$rbAll.Text = 'All presets (Cinematic is active at first - switch in the ReShade preset dropdown)'
$rbAll.Location = New-Object Drawing.Point(15, 132)
$rbAll.Size = New-Object Drawing.Size(550, 22)
$gb2.Controls.Add($rbAll)

$install = New-Object Windows.Forms.Button
$install.Text = 'Install'
$install.Font = New-Object Drawing.Font('Segoe UI', 11, [Drawing.FontStyle]::Bold)
$install.Location = New-Object Drawing.Point(20, 424)
$install.Size = New-Object Drawing.Size(585, 42)
$form.Controls.Add($install)

$script:LogBox = New-Object Windows.Forms.TextBox
$script:LogBox.Multiline = $true
$script:LogBox.ReadOnly = $true
$script:LogBox.ScrollBars = 'Vertical'
$script:LogBox.Font = New-Object Drawing.Font('Consolas', 9)
$script:LogBox.Location = New-Object Drawing.Point(20, 478)
$script:LogBox.Size = New-Object Drawing.Size(585, 130)
$form.Controls.Add($script:LogBox)

$note = New-Object Windows.Forms.Label
$note.Text = ('Heads-up: using ReShade in an online game is at your own risk. This installer uses the standard ' +
              '(non-add-on) ReShade build. Needs an internet connection to install (only to download ReShade). If the game is in Program Files, run Install.bat as administrator.')
$note.Location = New-Object Drawing.Point(20, 616)
$note.Size = New-Object Drawing.Size(585, 55)
$form.Controls.Add($note)

# --- behaviour
$found = Find-Fallout76
foreach ($f in $found) { [void]$combo.Items.Add($f) }
if ($found.Count -gt 0) {
    $combo.SelectedIndex = 0
    $detectLabel.Text = "Detected $($found.Count) install(s). Pick another or use Browse if this is wrong."
} else {
    $detectLabel.Text = 'Fallout 76 was not detected automatically. Use Browse to pick the folder with Fallout76.exe.'
}

$browse.Add_Click({
    $dlg = New-Object Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Select the Fallout 76 folder (the one that contains Fallout76.exe)'
    if ($dlg.ShowDialog() -eq 'OK') { $combo.Text = $dlg.SelectedPath }
})

$rbUninstall.Add_CheckedChanged({
    $gb2.Enabled = -not $rbUninstall.Checked
    if ($rbUninstall.Checked) { $install.Text = 'Uninstall' } else { $install.Text = 'Install' }
})

$install.Add_Click({
    $path = $combo.Text.Trim().TrimEnd('\')
    $install.Enabled = $false
    $browse.Enabled = $false
    $script:LogBox.Clear()
    try {
        if ($rbUninstall.Checked) {
            $ask = [Windows.Forms.MessageBox]::Show("This removes ReShade, every installed shader and texture (the whole reshade-shaders folder), the VII presets and ReShade.ini from:`r`n`r`n$path`r`n`r`nContinue?", 'Uninstall', 'YesNo', 'Warning')
            if ($ask -eq 'Yes') {
                Invoke-Uninstall $path
                [void][Windows.Forms.MessageBox]::Show('ReShade has been removed.', 'Done', 'OK', 'Information')
                $form.Close()
            }
        } else {
            $choice = if ($rbAll.Checked) { 'All' } elseif ($rbVib.Checked) { 'Vibrant' } elseif ($rbNatCin.Checked) { 'NaturalCinematic' } elseif ($rbNat.Checked) { 'Natural' } else { 'Cinematic' }
            $res = @(Invoke-Install $path $choice)
            if ([int]$res[-1] -gt 0) {
                [void][Windows.Forms.MessageBox]::Show('Installed, but some shader files could not be downloaded (see the log in the window). Check your internet connection and run the installer again.', 'Finished with warnings', 'OK', 'Warning')
            } else {
                [void][Windows.Forms.MessageBox]::Show('Installed. Start Fallout 76 and press Home to open ReShade.', 'Done', 'OK', 'Information')
                $form.Close()
            }
        }
    } catch {
        Write-Log ('ERROR: ' + $_.Exception.Message)
        [void][Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Failed', 'OK', 'Error')
    } finally {
        $install.Enabled = $true
        $browse.Enabled = $true
    }
})

[void]$form.ShowDialog()
