param([string]$Name = 'LumenDeck')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$fw = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$csc = Join-Path $fw 'csc.exe'
$bin = Join-Path $root 'bin'
$ico = Join-Path $root 'app.ico'

if (-not (Test-Path $ico)) {
  Add-Type -AssemblyName System.Drawing
  $bmp = New-Object System.Drawing.Bitmap(64, 64)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::Transparent)
  $rect = New-Object System.Drawing.Rectangle(2, 2, 60, 60)
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::FromArgb(255, 16, 22, 40), [System.Drawing.Color]::FromArgb(255, 64, 92, 176), 45)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddArc(2, 2, 60, 60, 180, 90)
  $path.AddArc(2, 2, 60, 60, 270, 90)
  $path.AddArc(2, 2, 60, 60, 0, 90)
  $path.AddArc(2, 2, 60, 60, 90, 90)
  $path.CloseFigure()
  $g.FillPath($brush, $path)
  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 150, 185, 255), 3)
  $g.DrawEllipse($pen, 17, 17, 30, 30)
  $pen2 = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 220, 235, 255), 4)
  $g.DrawLine($pen2, 32, 25, 32, 34)
  $g.DrawLine($pen2, 32, 39, 32, 41)
  $h = $bmp.GetHicon()
  $icon = [System.Drawing.Icon]::FromHandle($h)
  $fs = [System.IO.File]::Create($ico)
  $icon.Save($fs)
  $fs.Close()
  $g.Dispose()
  $bmp.Dispose()
}

$refs = @(
  (Join-Path $fw 'WPF\PresentationFramework.dll'),
  (Join-Path $fw 'WPF\PresentationCore.dll'),
  (Join-Path $fw 'WPF\WindowsBase.dll'),
  (Join-Path $fw 'System.Xaml.dll'),
  (Join-Path $fw 'System.Windows.Forms.dll'),
  (Join-Path $fw 'System.Drawing.dll'),
  (Join-Path $fw 'System.Web.Extensions.dll'),
  (Join-Path $fw 'System.Net.Http.dll'),
  (Join-Path $fw 'Microsoft.CSharp.dll'),
  (Join-Path $fw 'System.Core.dll'),
  (Join-Path $fw 'System.Runtime.Serialization.dll')
)
$missing = $refs | Where-Object { -not (Test-Path $_) }
if ($missing) { throw ('missing references: ' + ($missing -join ', ')) }

$sources = @(Get-ChildItem (Join-Path $root 'src') -Recurse -Filter *.cs | ForEach-Object { $_.FullName })
if ($sources.Count -eq 0) { throw 'no C# sources' }

New-Item -ItemType Directory -Force -Path $bin | Out-Null
$exe = Join-Path $bin ($Name + '.exe')
if (Test-Path $exe) { Remove-Item $exe -Force }

& $csc /nologo /target:winexe /platform:x64 /optimize+ /langversion:5 /warn:4 "/out:$exe" "/win32manifest:$(Join-Path $root 'app.manifest')" "/win32icon:$ico" "/resource:$ico,LumenDeck.ico" ("/reference:" + ($refs -join ';')) $sources
if ($LASTEXITCODE -ne 0) { throw "compile failed ($LASTEXITCODE)" }

$log = Join-Path $bin 'selftest.log'
if (Test-Path $log) { Remove-Item $log -Force }
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.Arguments = '--selftest'
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$selftest = [System.Diagnostics.Process]::Start($psi)
$finished = $selftest.WaitForExit(20000)
if (-not $finished) { try { $selftest.Kill() } catch {}; throw 'selftest timeout' }
if (Test-Path $log) { Get-Content $log }
if ($selftest.ExitCode -ne 0) { throw "selftest failed ($($selftest.ExitCode))" }
Write-Host "OK: $exe"
