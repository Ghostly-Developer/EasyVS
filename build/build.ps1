<#
.SYNOPSIS
    Builds OpenWithVSCode.exe: OpenWithVSCode.cmd packed into a small launcher with an icon.

.DESCRIPTION
    Uses only what ships with Windows: Windows PowerShell and the .NET Framework 4 C# compiler.
      1. Draws the app icon into build\app.ico.
      2. Compiles build\Launcher.cs with OpenWithVSCode.cmd embedded as a resource.
    The version comes from $AppVersion in OpenWithVSCode.cmd.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\build\build.ps1
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$here   = $PSScriptRoot
$root   = Split-Path $here -Parent
$script = Join-Path $root 'OpenWithVSCode.cmd'
$exe    = Join-Path $root 'OpenWithVSCode.exe'
$ico    = Join-Path $here 'app.ico'
$csc    = Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:SystemRoot 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path $csc)) { throw 'The .NET Framework 4 C# compiler (csc.exe) was not found.' }

$source = Get-Content -Raw -LiteralPath $script
if ($source -notmatch "\`$AppVersion\s*=\s*'([\d.]+)'") { throw "Couldn't read `$AppVersion from OpenWithVSCode.cmd." }
$version = $Matches[1]
if ($source -match '[^\x00-\x7F]') { throw 'OpenWithVSCode.cmd must be plain ASCII (cmd.exe misreads other characters).' }

# ---------------------------------------------------------------------------
# 1. Icon: a folder with a blue </> badge, drawn on a 256-unit grid at each size.
# ---------------------------------------------------------------------------
function New-RoundRect([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $p = New-Object Drawing.Drawing2D.GraphicsPath
    $d = [single]($r * 2)
    $p.AddArc($x, $y, $d, $d, [single]180, [single]90)
    $p.AddArc([single]($x + $w - $d), $y, $d, $d, [single]270, [single]90)
    $p.AddArc([single]($x + $w - $d), [single]($y + $h - $d), $d, $d, [single]0, [single]90)
    $p.AddArc($x, [single]($y + $h - $d), $d, $d, [single]90, [single]90)
    $p.CloseFigure()
    $p
}

function New-IconPng([int]$size) {
    $bmp = New-Object Drawing.Bitmap($size, $size, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode   = 'AntiAlias'
    $g.PixelOffsetMode = 'HighQuality'
    $g.Clear([Drawing.Color]::Transparent)
    $g.ScaleTransform([single]($size / 256), [single]($size / 256))

    $back  = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(214, 150, 28))
    $front = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(246, 190, 66))
    $badge = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(30, 102, 208))

    $g.FillPath($back,  (New-RoundRect 16 36 104 52 14))     # folder tab
    $g.FillPath($back,  (New-RoundRect 16 56 224 64 16))     # back of the folder
    $g.FillPath($front, (New-RoundRect 16 76 224 148 18))    # front of the folder
    $g.FillPath($badge, (New-RoundRect 112 108 136 136 32))  # code badge

    # </> drawn as lines, thicker at small sizes so it stays readable.
    $width = 15
    if ($size -le 32) { $width = 20 }
    $pen = New-Object Drawing.Pen([Drawing.Color]::White, [single]$width)
    $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
    $pt = { param($x, $y) New-Object Drawing.PointF([single]$x, [single]$y) }
    $g.DrawLines($pen, [Drawing.PointF[]]@((& $pt 156 152), (& $pt 136 176), (& $pt 156 200)))
    $g.DrawLines($pen, [Drawing.PointF[]]@((& $pt 204 152), (& $pt 224 176), (& $pt 204 200)))
    $g.DrawLine($pen, (& $pt 188 146), (& $pt 172 206))

    $g.Dispose()
    $ms = New-Object IO.MemoryStream
    if ($size -ge 256) {
        # Large size as PNG (smaller file; supported since Windows Vista).
        $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
    } else {
        # Small sizes as classic 32-bit bitmaps, which every icon reader understands.
        $bw = New-Object IO.BinaryWriter($ms)
        $maskRow = [int]([Math]::Ceiling($size / 32) * 4)
        $bw.Write([uint32]40); $bw.Write([int32]$size); $bw.Write([int32]($size * 2))   # BITMAPINFOHEADER
        $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]0)
        $bw.Write([uint32]($size * $size * 4 + $maskRow * $size))
        $bw.Write([int32]0); $bw.Write([int32]0); $bw.Write([uint32]0); $bw.Write([uint32]0)
        $rect = New-Object Drawing.Rectangle(0, 0, $size, $size)
        $data = $bmp.LockBits($rect, 'ReadOnly', [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $row = New-Object byte[] ($size * 4)
        for ($y = $size - 1; $y -ge 0; $y--) {                                            # BGRA, bottom-up
            [Runtime.InteropServices.Marshal]::Copy([IntPtr]($data.Scan0.ToInt64() + $y * $data.Stride), $row, 0, $row.Length)
            $bw.Write($row)
        }
        $bmp.UnlockBits($data)
        $bw.Write((New-Object byte[] ($maskRow * $size)))                                 # AND mask (unused with alpha)
        $bw.Flush()
    }
    $bmp.Dispose()
    , $ms.ToArray()
}

$sizes  = 16, 20, 24, 32, 40, 48, 64, 256
$images = foreach ($s in $sizes) { , (New-IconPng $s) }

$out = New-Object IO.MemoryStream
$w = New-Object IO.BinaryWriter($out)
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)   # ICONDIR
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {                                    # ICONDIRENTRY x n
    $dim = $sizes[$i] % 256                                                  # 256 is stored as 0
    $w.Write([byte]$dim); $w.Write([byte]$dim); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([uint16]1); $w.Write([uint16]32)
    $w.Write([uint32]$images[$i].Length); $w.Write([uint32]$offset)
    $offset += $images[$i].Length
}
foreach ($img in $images) { $w.Write($img) }                                 # PNG data
$w.Flush()
[IO.File]::WriteAllBytes($ico, $out.ToArray())
Write-Host "Icon:    $ico"

# ---------------------------------------------------------------------------
# 2. Compile the launcher.
# ---------------------------------------------------------------------------
$info = Join-Path ([IO.Path]::GetTempPath()) 'OpenWithVSCode-AssemblyInfo.cs'
@"
using System.Reflection;
[assembly: AssemblyTitle("Open with VS Code")]
[assembly: AssemblyDescription("Adds Open with VS Code to the File Explorer right-click menu")]
[assembly: AssemblyProduct("Open with VS Code")]
[assembly: AssemblyVersion("$version.0")]
[assembly: AssemblyFileVersion("$version.0")]
"@ | Set-Content -LiteralPath $info -Encoding UTF8

& $csc /nologo /target:winexe /optimize+ /platform:anycpu `
    "/out:$exe" "/win32icon:$ico" "/resource:$script,OpenWithVSCode.ps1" `
    /reference:System.Windows.Forms.dll `
    (Join-Path $here 'Launcher.cs') $info
if ($LASTEXITCODE -ne 0) { throw "csc.exe failed with exit code $LASTEXITCODE." }
Remove-Item -LiteralPath $info -ErrorAction SilentlyContinue

Write-Host "Built:   $exe (version $version, $([Math]::Round((Get-Item $exe).Length / 1KB)) KB)" -ForegroundColor Green
